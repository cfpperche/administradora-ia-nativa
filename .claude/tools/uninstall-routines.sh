#!/usr/bin/env bash
# .claude/tools/uninstall-routines.sh
# Symmetric removal: strip the AGENT0-ROUTINES marker block for THIS repo
# from the user crontab; remove this repo's entry from the leaders file.
#
# Usage:   bash uninstall-routines.sh
# Idempotent — safe to run on a repo that was never installed.

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

LEADERS_FILE="$HOME/.claude/.agent0-routines-leaders.json"

MARKER_START="# AGENT0-ROUTINES-START ($PROJECT_DIR)"
MARKER_END="# AGENT0-ROUTINES-END ($PROJECT_DIR)"

echo "uninstall-routines: repo = $PROJECT_DIR"

# --- Phase 1: strip crontab marker block --------------------------------------
existing_crontab=$(crontab -l 2>/dev/null || true)

if [[ -n "$existing_crontab" ]] && echo "$existing_crontab" | grep -qF "$MARKER_START"; then
  filtered=$(echo "$existing_crontab" | awk -v start="$MARKER_START" -v end="$MARKER_END" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip
  ')
  # Reinstall the filtered crontab.
  if [[ -n "$filtered" ]]; then
    echo "$filtered" | crontab -
  else
    # Empty crontab — explicitly clear.
    crontab -r 2>/dev/null || true
  fi
  echo "uninstall-routines: removed crontab block for this repo"
else
  echo "uninstall-routines: no crontab block found for this repo (already clean)"
fi

# --- Phase 2: remove leader entry ---------------------------------------------
if [[ -f "$LEADERS_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    if jq --arg path "$PROJECT_DIR" 'del(.[$path])' "$LEADERS_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$LEADERS_FILE"
      echo "uninstall-routines: removed leader entry from $LEADERS_FILE"
    else
      rm -f "$tmp"
      echo "uninstall-routines: WARN failed to update $LEADERS_FILE (jq error)" >&2
    fi
  else
    echo "uninstall-routines: WARN jq not available; please remove $PROJECT_DIR entry from $LEADERS_FILE manually" >&2
  fi
else
  echo "uninstall-routines: no leaders file (nothing to remove)"
fi

# --- Phase 3: leave state intact ----------------------------------------------
echo "uninstall-routines: .claude/.routines-state/ NOT touched (queue + completed preserved for inspection)"

exit 0
