#!/usr/bin/env bash
# .claude/tools/install-routines.sh
# Bootstrap: (1) WSL2 detection + advisory, (2) interactive leader prompt,
# (3) regenerate the AGENT0-ROUTINES crontab block from .claude/routines/*.md.
#
# Usage:   bash install-routines.sh
# Idempotent — re-running replaces the marker block atomically; the leader
# prompt is shown only if this repo isn't already in the leaders file.

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

ROUTINES_DIR="$PROJECT_DIR/.claude/routines"
RUN_SCRIPT="$PROJECT_DIR/.claude/tools/run-routine.sh"
LEADERS_FILE="$HOME/.claude/.agent0-routines-leaders.json"
LOG_FILE="$PROJECT_DIR/.claude/.routines-state/cron.log"

MARKER_START="# AGENT0-ROUTINES-START ($PROJECT_DIR)"
MARKER_END="# AGENT0-ROUTINES-END ($PROJECT_DIR)"

echo "install-routines: repo = $PROJECT_DIR"

# --- Phase 1: WSL2 detection + advisory ---------------------------------------
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "wsl-advisory: WSL2 detected."
  cron_status=$(service cron status 2>&1 || true)
  if ! echo "$cron_status" | grep -qi running; then
    echo "wsl-advisory: cron not running. To start it:"
    echo "  sudo service cron start"
    echo "  # for persistence across WSL2 sessions, add the line above to ~/.profile"
  fi
fi

# --- Phase 2: leader designation ----------------------------------------------
mkdir -p "$(dirname "$LEADERS_FILE")"
if [[ ! -f "$LEADERS_FILE" ]]; then
  echo "{}" > "$LEADERS_FILE"
fi

current_leader_val="unset"
if command -v jq >/dev/null 2>&1; then
  current_leader_val=$(jq -r --arg path "$PROJECT_DIR" '
    if has($path) then (.[$path] | tostring) else "unset" end
  ' "$LEADERS_FILE" 2>/dev/null || echo "unset")
fi

if [[ "$current_leader_val" == "unset" ]]; then
  # Prompt only when not yet set.
  echo
  read -rp "Designate this machine as routines leader for $PROJECT_DIR? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES|Yes) leader_val="true" ;;
    *) leader_val="false" ;;
  esac

  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg path "$PROJECT_DIR" --argjson v "$leader_val" '.[$path] = $v' "$LEADERS_FILE" > "$tmp" && mv "$tmp" "$LEADERS_FILE"
  else
    echo "install-routines: jq not found — please install jq, then re-run." >&2
    echo "  (jq is required for safe JSON mutation of $LEADERS_FILE)" >&2
    exit 1
  fi
  echo "install-routines: leader=$leader_val for this repo (saved to $LEADERS_FILE)"
else
  echo "install-routines: leader=$current_leader_val (already set; edit $LEADERS_FILE to change)"
  leader_val="$current_leader_val"
fi

# --- Phase 3: prepare state dir for cron.log ----------------------------------
mkdir -p "$(dirname "$LOG_FILE")"

# --- Phase 4: regenerate crontab marker block --------------------------------
# Read existing crontab; strip any existing block for THIS repo; append fresh block.
existing_crontab=$(crontab -l 2>/dev/null || true)

# Strip block for this repo (matches markers literally).
filtered=$(echo "$existing_crontab" | awk -v start="$MARKER_START" -v end="$MARKER_END" '
  $0 == start { skip = 1; next }
  $0 == end   { skip = 0; next }
  !skip
')

# Build new block from .claude/routines/*.md.
block=""
block="${block}${MARKER_START}"$'\n'
routine_count=0
for f in "$ROUTINES_DIR"/*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f" .md)
  [[ "$base" == ".gitkeep" || "$base" == ".gitkeep.md" ]] && continue

  # Skip files that fail validation (the install would still proceed for valid ones).
  if ! bash "$PROJECT_DIR/.claude/skills/routine/scripts/validate.sh" "$base" >/dev/null 2>&1; then
    echo "install-routines: WARN routine '$base' failed validate; skipping its crontab entry" >&2
    continue
  fi

  # Extract schedule from frontmatter.
  schedule=$(sed -n '/^---/,/^---/p' "$f" | grep -E '^schedule:' | head -1 | sed -E 's|^schedule:[[:space:]]*||' | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')
  if [[ -z "$schedule" ]]; then
    echo "install-routines: WARN routine '$base' missing schedule; skipping" >&2
    continue
  fi

  block="${block}${schedule} bash ${RUN_SCRIPT} ${base} >> ${LOG_FILE} 2>&1"$'\n'
  routine_count=$((routine_count + 1))
done
block="${block}${MARKER_END}"

# Compose new crontab: filtered + (newline if non-empty) + block.
if [[ -n "$filtered" ]]; then
  new_crontab="${filtered}"$'\n'"${block}"
else
  new_crontab="${block}"
fi

# Install via crontab -.
echo "$new_crontab" | crontab -

echo "install-routines: registered $routine_count routine(s) in crontab"
echo "install-routines: marker block: $MARKER_START ... $MARKER_END"
echo "install-routines: cron stdout/stderr -> $LOG_FILE"
echo
echo "Active crontab (this repo's block):"
crontab -l 2>/dev/null | awk -v start="$MARKER_START" -v end="$MARKER_END" '
  $0 == start { p = 1 }
  p
  $0 == end   { p = 0 }
'

exit 0
