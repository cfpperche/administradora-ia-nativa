#!/usr/bin/env bash
# .claude/tests/session-handoff/05-snapshot-missing-fallback.sh
# Spec 023 — Scenario 6: snapshot missing → fallback to today's mtime logic.
#
# Given a session-state subdir with `started-at` but NO `start-porcelain.txt`
# (older session, or git/fs failure at SessionStart), when porcelain is
# non-empty AND SESSION.md was not updated, then Stop MUST block — falling
# back to today's mtime-only path.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-023-05-XXXXXX)"
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

SESSION_ID="test-fallback-05"
STATE_DIR="$TMPDIR/.claude/.session-state/$SESSION_ID"
mkdir -p "$STATE_DIR"
# Simulate "SessionStart ran but snapshot write failed" — started-at exists,
# snapshot does NOT.
touch "$STATE_DIR/started-at"

if [ -f "$STATE_DIR/start-porcelain.txt" ]; then
  printf 'FAIL: snapshot exists; test premise broken\n'
  exit 1
fi

stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"
stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if ! printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop did not fall back to mtime check when snapshot was missing\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
