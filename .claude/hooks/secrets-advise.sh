#!/usr/bin/env bash
# .claude/hooks/secrets-advise.sh
# PostToolUse(Edit|Write|MultiEdit) hook — on-edit secrets advisory.
#
# Soft-signal companion to the commit-time secrets-scan gate (spec 006).
# Opt-in via env var; never blocks; parent-agent exempt (same actor-split
# pattern as the post-edit validator — `agent_id` absent → exit 0 silently).
#
# Diff-only scan: writes the *new content* of the edit to a temp dir and
# runs `gitleaks detect --no-git --source <tmpdir>`, so gitleaks does not
# need a git repository and only the just-written bytes are inspected.
#
# Exit codes: always 0 (advisory; blocks are the commit-gate's job).
# Output:      one `secrets-advisory: <detector> at <file>:<line>` line per
#              finding, on stderr. Surfaces to the agent on its next turn.
#
# Tunables:
#   CLAUDE_SECRETS_ADVISE_ON_EDIT=1   enable (unset/empty/other → silent)
#
# bash 3.2-compatible: no associative arrays, no mapfile, no `[[ =~ ]]`.
# NOTE: `set -e` is intentionally OMITTED — this hook must exit 0 even when
# subcommands fail. Use explicit checks instead.

set -uo pipefail

# Opt-in gate: short-circuit fast when the env var isn't set to exactly "1".
# Anything else (unset, empty, "0", "true", "yes") leaves the hook silent.
[ "${CLAUDE_SECRETS_ADVISE_ON_EDIT:-}" = "1" ] || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

# Actor split — mirrors post-edit-validate.sh lines 20-21. Parent edits
# don't carry `agent_id`; sub-agent edits do. Parent → silent exit.
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
[ -z "$AGENT_ID" ] && exit 0

# Graceful degrade when the engine is absent. The commit-gate prints a
# warning in that case; the advisory just disappears (no signal is better
# than a noisy false warning on every edit).
command -v gitleaks >/dev/null 2>&1 || exit 0

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -z "$FILE_PATH" ] && exit 0

# Route by tool variant. The payload shape differs:
#   Edit       → tool_input.new_string         (single string)
#   Write      → tool_input.content            (single string)
#   MultiEdit  → tool_input.edits[].new_string (array of strings)
# Build a newline-delimited list of "chunks" to scan. For Edit/Write this
# is one chunk; for MultiEdit it's one chunk per edit. Each chunk is
# written to its own file in the temp dir so gitleaks reports per-chunk
# line numbers that map back to the new content directly.

TMPDIR_SCAN="$(mktemp -d 2>/dev/null || true)"
[ -z "$TMPDIR_SCAN" ] && exit 0
trap 'rm -rf "$TMPDIR_SCAN" 2>/dev/null || true' EXIT

# Stem of the file path — used to name chunks inside the temp dir, so
# gitleaks reports a recognizable file name in its JSON (cosmetic only;
# the advisory line uses the original FILE_PATH for attribution).
STEM="$(basename "$FILE_PATH")"
[ -z "$STEM" ] && STEM="chunk"

case "$TOOL_NAME" in
  Edit)
    printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty' \
      > "$TMPDIR_SCAN/$STEM" 2>/dev/null || exit 0
    ;;
  Write)
    printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' \
      > "$TMPDIR_SCAN/$STEM" 2>/dev/null || exit 0
    ;;
  MultiEdit)
    # Count edits first; then write each new_string to its own chunk file.
    # If the array is missing or empty, there's nothing to scan.
    N_EDITS="$(printf '%s' "$INPUT" | jq -r '.tool_input.edits // [] | length' 2>/dev/null || echo 0)"
    [ -z "$N_EDITS" ] && N_EDITS=0
    [ "$N_EDITS" -eq 0 ] && exit 0
    i=0
    while [ "$i" -lt "$N_EDITS" ]; do
      printf '%s' "$INPUT" | jq -r ".tool_input.edits[$i].new_string // empty" \
        > "$TMPDIR_SCAN/${i}-$STEM" 2>/dev/null || true
      i=$((i + 1))
    done
    ;;
  *)
    # Unknown tool — be safe and exit 0.
    exit 0
    ;;
esac

# Run gitleaks against the temp dir. `--no-git` is required because the
# dir isn't a repo. Failures here (binary missing mid-flight, write error
# on the report file, etc.) degrade to no advisory.
REPORT="$(mktemp 2>/dev/null || true)"
[ -z "$REPORT" ] && exit 0
trap 'rm -rf "$TMPDIR_SCAN" "$REPORT" 2>/dev/null || true' EXIT

gitleaks detect \
  --no-git \
  --source "$TMPDIR_SCAN" \
  --no-banner \
  --log-level=error \
  --report-format=json \
  --report-path="$REPORT" \
  >/dev/null 2>&1 || true

# gitleaks writes `[]` (or nothing) when there are no findings. Be defensive:
# treat a missing/empty/unparseable file as zero findings.
[ -s "$REPORT" ] || exit 0

N_FINDINGS="$(jq -r 'if type == "array" then length else 0 end' "$REPORT" 2>/dev/null || echo 0)"
[ -z "$N_FINDINGS" ] && N_FINDINGS=0
[ "$N_FINDINGS" -eq 0 ] && exit 0

# Emit one advisory line per finding. The detector is gitleaks' RuleID
# (compact, grep-friendly); the file path is the agent-facing FILE_PATH
# (not the temp-dir path); the line is gitleaks' StartLine, which maps
# directly back to the new_string/content because we wrote that text
# verbatim to a fresh file. Precise mapping; no `:1` fallback needed.
jq -r --arg fp "$FILE_PATH" \
  '.[] | "secrets-advisory: " + (.RuleID // "unknown") + " at " + $fp + ":" + ((.StartLine // 1) | tostring)' \
  "$REPORT" >&2 2>/dev/null || true

exit 0
