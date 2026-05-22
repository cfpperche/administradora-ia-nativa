#!/usr/bin/env bash
# .claude/tools/run-routine.sh
# Cron-invoked routine renderer: leader-check + interpolate prompt + enqueue.
#
# Usage:   bash run-routine.sh <slug>
# Exit:    0 on success (including silent-non-leader); 1 on fatal error.
#
# Invoked by crontab block installed via install-routines.sh.
# Writes to .claude/.routines-state/<slug>/queue/<unix-ts>.md when leader.
# Updates last-queue.json + rotates completed/ to FIFO cap 50.

set -uo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "run-routine: usage: run-routine.sh <slug>" >&2
  exit 1
fi

# Resolve project dir: prefer the script's repo (resolved via the script's own path).
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

ROUTINE_FILE="$PROJECT_DIR/.claude/routines/$SLUG.md"
if [[ ! -f "$ROUTINE_FILE" ]]; then
  echo "run-routine: routine file not found: $ROUTINE_FILE" >&2
  exit 1
fi

# --- Phase 1: leader check ----------------------------------------------------
LEADERS_FILE="$HOME/.claude/.agent0-routines-leaders.json"

if [[ ! -f "$LEADERS_FILE" ]]; then
  # No leaders file → no leader designated → silent exit.
  exit 0
fi

# Use jq if available (preferred), else fall back to grep+sed.
is_leader=0
if command -v jq >/dev/null 2>&1; then
  val=$(jq -r --arg path "$PROJECT_DIR" '.[$path] // false' "$LEADERS_FILE" 2>/dev/null || echo "false")
  [[ "$val" == "true" ]] && is_leader=1
else
  # Crude grep: look for "<abs-path>": true
  escaped_path=$(echo "$PROJECT_DIR" | sed 's|/|\\/|g')
  if grep -E "\"$escaped_path\"[[:space:]]*:[[:space:]]*true" "$LEADERS_FILE" >/dev/null 2>&1; then
    is_leader=1
  fi
fi

if [[ "$is_leader" -ne 1 ]]; then
  # Not leader for this repo → silent exit (per .claude/rules/routines.md § Leader-flag model).
  exit 0
fi

# --- Phase 2: prepare state dirs ----------------------------------------------
STATE_DIR="$PROJECT_DIR/.claude/.routines-state/$SLUG"
QUEUE_DIR="$STATE_DIR/queue"
COMPLETED_DIR="$STATE_DIR/completed"
mkdir -p "$QUEUE_DIR" "$COMPLETED_DIR"

# --- Phase 3: interpolation values --------------------------------------------
NOW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_EPOCH=$(date -u +%s)
GIT_HEAD=$(cd "$PROJECT_DIR" && git rev-parse HEAD 2>/dev/null || echo "no-git")

LAST_COMPLETED_FILE="$STATE_DIR/last-completed.json"
LAST_COMPLETED_TS="never"
if [[ -f "$LAST_COMPLETED_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    LAST_COMPLETED_TS=$(jq -r '.ts // "never"' "$LAST_COMPLETED_FILE" 2>/dev/null || echo "never")
  else
    LAST_COMPLETED_TS=$(grep -oE '"ts"[[:space:]]*:[[:space:]]*"[^"]*"' "$LAST_COMPLETED_FILE" 2>/dev/null | sed -E 's|.*"([^"]+)"$|\1|' || echo "never")
    [[ -z "$LAST_COMPLETED_TS" ]] && LAST_COMPLETED_TS="never"
  fi
fi

# --- Phase 4: render the queue entry ------------------------------------------
QUEUE_FILE="$QUEUE_DIR/${NOW_EPOCH}.md"

# Read routine file, substitute placeholders, write to queue.
sed \
  -e "s|{{LAST_COMPLETED_TS}}|$LAST_COMPLETED_TS|g" \
  -e "s|{{GIT_HEAD}}|$GIT_HEAD|g" \
  -e "s|{{REPO_ROOT}}|$PROJECT_DIR|g" \
  -e "s|{{NOW}}|$NOW_TS|g" \
  "$ROUTINE_FILE" > "$QUEUE_FILE"

# --- Phase 5: update last-queue.json ------------------------------------------
LAST_QUEUE_FILE="$STATE_DIR/last-queue.json"
cat > "$LAST_QUEUE_FILE" <<EOF
{
  "ts": "$NOW_TS",
  "queue_file": "${NOW_EPOCH}.md",
  "git_head": "$GIT_HEAD"
}
EOF

# --- Phase 6: FIFO rotation on completed/ -------------------------------------
# Soft cap at 50 — drop oldest by mtime if over.
completed_count=$(ls -1 "$COMPLETED_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$completed_count" -gt 50 ]]; then
  # ls -t sorts newest-first; tail -n +51 drops the first 50 (newest), leaving older ones to delete.
  ls -t "$COMPLETED_DIR"/*.md 2>/dev/null | tail -n +51 | xargs -r rm -f
fi

# Silent success — cron stdout/stderr is captured by install-routines.sh's crontab >> cron.log.
exit 0
