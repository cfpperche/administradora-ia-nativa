#!/usr/bin/env bash
# SessionStart hook: inject .claude/REMINDERS.md content into the agent's context.
#
# Emits a framed block consistent with session-start.sh's output style.
# When the file is absent or contains no bullet lines, emits a single
# "(no pending reminders)" line inside the frame.
#
# POSIX-only utilities (cat, grep, printf). Degrades silently if the file
# is unreadable — never blocks session start.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
REMINDERS_FILE="$PROJECT_DIR/.claude/REMINDERS.md"

bullet_count=0
if [[ -r "$REMINDERS_FILE" ]]; then
  bullet_count=$(grep -cE '^[[:space:]]*- ' "$REMINDERS_FILE" 2>/dev/null || true)
  [[ -z "$bullet_count" ]] && bullet_count=0
fi

printf '=== REMINDERS ===\n'
if [[ "$bullet_count" -gt 0 ]]; then
  cat "$REMINDERS_FILE"
else
  printf '(no pending reminders)\n'
fi
printf '=== end REMINDERS ===\n'
