#!/usr/bin/env bash
# .claude/skills/routine/scripts/list.sh
# Print status of every routine in this repo: schedule, leader, queue, last-completed.
#
# Usage:   bash list.sh
# Exit:    0 always.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"

ROUTINES_DIR="$PROJECT_DIR/.claude/routines"
STATE_DIR="$PROJECT_DIR/.claude/.routines-state"
LEADERS_FILE="$HOME/.claude/.agent0-routines-leaders.json"

# --- Leader status for this repo ----------------------------------------------
leader_status="n/a"
if [[ -f "$LEADERS_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    raw=$(jq -r --arg path "$PROJECT_DIR" '
      if has($path) then (.[$path] | tostring) else "missing" end
    ' "$LEADERS_FILE" 2>/dev/null || echo "missing")
  else
    if grep -q "\"$PROJECT_DIR\"[[:space:]]*:[[:space:]]*true" "$LEADERS_FILE" 2>/dev/null; then
      raw="true"
    elif grep -q "\"$PROJECT_DIR\"[[:space:]]*:[[:space:]]*false" "$LEADERS_FILE" 2>/dev/null; then
      raw="false"
    else
      raw="missing"
    fi
  fi
  case "$raw" in
    true)  leader_status="yes" ;;
    false) leader_status="no" ;;
    *)     leader_status="n/a" ;;
  esac
fi

# --- Enumerate routines -------------------------------------------------------
if [[ ! -d "$ROUTINES_DIR" ]]; then
  echo "(no routines directory — use /routine new <slug> to create one)"
  exit 0
fi

found=0
for f in "$ROUTINES_DIR"/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f" .md)
  [[ "$base" == ".gitkeep" || "$base" == ".gitkeep.md" ]] && continue
  found=1

  # Extract schedule from frontmatter.
  schedule=$(sed -n '/^---/,/^---/p' "$f" | grep -E '^schedule:' | head -1 | sed -E 's|^schedule:[[:space:]]*||' | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')

  # Count queue.
  queue_count=0
  if [[ -d "$STATE_DIR/$base/queue" ]]; then
    queue_count=$(ls -1 "$STATE_DIR/$base/queue"/*.md 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Last completed.
  last_completed="never"
  lcf="$STATE_DIR/$base/last-completed.json"
  if [[ -f "$lcf" ]]; then
    if command -v jq >/dev/null 2>&1; then
      last_completed=$(jq -r '.ts // "never"' "$lcf" 2>/dev/null || echo "never")
    else
      last_completed=$(grep -oE '"ts"[[:space:]]*:[[:space:]]*"[^"]*"' "$lcf" 2>/dev/null | sed -E 's|.*"([^"]+)"$|\1|')
      [[ -z "$last_completed" ]] && last_completed="never"
    fi
  fi

  printf '%-30s  schedule=%-20s  leader=%-3s  queue=%d  last-completed=%s\n' \
    "$base" "$schedule" "$leader_status" "$queue_count" "$last_completed"
done

if [[ "$found" -eq 0 ]]; then
  echo "(no routines defined — use /routine new <slug> to create one)"
  exit 0
fi

# Footer if leader missing AND routines exist.
if [[ "$leader_status" == "n/a" ]]; then
  echo
  echo "(no leader designated for this repo — run .claude/tools/install-routines.sh to schedule)"
fi

exit 0
