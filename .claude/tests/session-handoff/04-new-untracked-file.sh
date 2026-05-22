#!/usr/bin/env bash
# .claude/tests/session-handoff/04-new-untracked-file.sh
# Spec 023 — Scenario 4: session adds a new untracked file.
#
# Given carryover present at start, when the session creates a new untracked
# file (porcelain grows by one entry), then Stop MUST block — new artifact is
# a legitimate handoff trigger.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-023-04-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"
echo "initial" >tracked.txt
git add tracked.txt
git commit -q -m initial
echo "carryover" >carryover.txt

mkdir -p "$TMPDIR/.claude"
touch "$TMPDIR/.claude/SESSION.md"
touch -d "1 hour ago" "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-new-untracked-04"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

sleep 1

# Mid-session: create a new untracked file via the Write tool (simulated by
# echo + tracker payload — Write would have triggered PostToolUse).
echo "new-artifact" >new-file.txt
printf '%s' "{\"session_id\":\"$SESSION_ID\",\"tool_input\":{\"file_path\":\"new-file.txt\"}}" | bash "$TRACK_HOOK"

stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if ! printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop did not block when a new untracked file appeared\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
