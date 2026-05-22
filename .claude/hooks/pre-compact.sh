#!/usr/bin/env bash
# PreCompact hook: snapshot the last N real user turns + assistant text/tool_use
# into COMPACT_NOTES.md so the SessionStart hook (source=compact) can re-inject
# the raw signal that /compact's summarizer would otherwise compress away.
#
# Captures verbatim: user messages, assistant text, tool names + truncated args.
# Drops: tool_result bodies (stale post-compact), assistant thinking blocks.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
NOTES_FILE="$PROJECT_DIR/.claude/COMPACT_NOTES.md"
TURNS_TO_KEEP=12

INPUT="$(cat 2>/dev/null || true)"
TRANSCRIPT_PATH=""
TRIGGER="unknown"
CUSTOM=""
if [[ -n "$INPUT" ]]; then
  TRANSCRIPT_PATH="$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
  TRIGGER="$(printf '%s' "$INPUT" | jq -r '.trigger // "unknown"' 2>/dev/null || echo unknown)"
  CUSTOM="$(printf '%s' "$INPUT" | jq -r '.custom_instructions // ""' 2>/dev/null || true)"
fi

[[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]] || exit 0

GIT_BRANCH=""
GIT_STATUS=""
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_BRANCH="$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)"
  GIT_STATUS="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || true)"
fi

TURNS_MD="$(jq -rs --argjson n "$TURNS_TO_KEEP" '
  . as $all
  | [range(0; length) as $i
     | select($all[$i].type == "user"
              and (($all[$i].message.content // null) | type == "string"))
     | $i] as $boundaries
  | ($boundaries | length) as $count
  | (if $count == 0 then 0
     elif $count > $n then $boundaries[$count - $n]
     else $boundaries[0]
     end) as $start
  | $all[$start:]
  | map(
      if .type == "user" and ((.message.content // null) | type == "string") then
        "\n\n### USER\n\n" + .message.content
      elif .type == "assistant" then
        ([(.message.content // [])[]
          | if .type == "text" then
              "\n\n### ASSISTANT\n\n" + (.text // "")
            elif .type == "tool_use" then
              "\n\n`[tool: " + (.name // "?") + " " + ((.input // {}) | tostring | .[0:200]) + "]`"
            else empty end
         ] | add) // ""
      else "" end
    )
  | join("")
' "$TRANSCRIPT_PATH" 2>/dev/null || true)"

{
  echo "# Pre-compact snapshot"
  echo
  echo "Captured by \`.claude/hooks/pre-compact.sh\` immediately before context compaction."
  echo "Last $TURNS_TO_KEEP user turns + assistant text/tool_use, verbatim. Tool outputs and thinking blocks dropped (stale post-compact)."
  echo
  echo "**Trigger:** \`$TRIGGER\`  "
  echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ -n "$CUSTOM" && "$CUSTOM" != "null" ]]; then
    echo
    echo "**User compact instructions:**"
    echo
    echo "> $CUSTOM"
  fi
  if [[ -n "$GIT_BRANCH" ]]; then
    echo
    echo "**Branch:** \`$GIT_BRANCH\`"
    if [[ -n "$GIT_STATUS" ]]; then
      echo
      echo "**Uncommitted changes:**"
      echo
      echo '```'
      printf '%s\n' "$GIT_STATUS"
      echo '```'
    else
      echo "(working tree clean)"
    fi
  fi
  echo
  echo "---"
  printf '%s\n' "$TURNS_MD"
} > "$NOTES_FILE"

exit 0
