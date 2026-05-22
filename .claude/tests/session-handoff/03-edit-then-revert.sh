#!/usr/bin/env bash
# .claude/tests/session-handoff/03-edit-then-revert.sh
# Spec 023 — Scenario 3: session edits then reverts to start state.
#
# Given carryover present at start (so porcelain is non-empty, otherwise the
# pre-existing empty-porcelain early-exit fires before the snapshot check),
# when the session edits a tracked file then `git restore`s it back to the
# committed version, the porcelain returns to the start state, and Stop must
# NOT block (snapshot match path).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-023-03-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"
echo "initial" >tracked.txt
git add tracked.txt
git commit -q -m initial
# Carryover: an untracked file (must persist for porcelain to be non-empty
# even after we revert the tracked-file edit below).
echo "carryover-untracked" >carryover.txt

mkdir -p "$TMPDIR/.claude"
touch "$TMPDIR/.claude/SESSION.md"
touch -d "1 hour ago" "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-revert-03"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

# SessionStart captures porcelain "?? carryover.txt"
printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

start_porcelain="$(cat "$TMPDIR/.claude/.session-state/$SESSION_ID/start-porcelain.txt")"
if [ -z "$start_porcelain" ]; then
  printf 'FAIL: snapshot is empty; test premise broken (need non-empty carryover)\n'
  exit 1
fi

sleep 1

# Mid-session: edit tracked then revert via git restore
echo "transient" >tracked.txt
git -C "$TMPDIR" restore tracked.txt

# Confirm porcelain is back to start state
end_porcelain="$(git -C "$TMPDIR" status --porcelain)"
if [ "$start_porcelain" != "$end_porcelain" ]; then
  printf 'FAIL: porcelain did not return to start state\n'
  printf 'start: %s\n' "$start_porcelain"
  printf 'end:   %s\n' "$end_porcelain"
  exit 1
fi

stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop blocked despite porcelain reverting to start state\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
