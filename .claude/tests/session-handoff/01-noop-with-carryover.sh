#!/usr/bin/env bash
# .claude/tests/session-handoff/01-noop-with-carryover.sh
# Spec 023 — Scenario 1: no-op session with pre-existing carryover.
#
# Given the repo has uncommitted changes when the session starts, when the
# session performs no edits during its lifetime, then Stop must NOT block.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-023-01-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Fake git repo with carryover state (modified tracked + untracked)
cd "$TMPDIR"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"
echo "initial" >tracked.txt
git add tracked.txt
git commit -q -m initial
echo "carryover-modification" >tracked.txt
echo "carryover-untracked" >carryover.txt

mkdir -p "$TMPDIR/.claude"
touch "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-noop-01"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

# SessionStart captures porcelain snapshot
printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

SNAPSHOT="$TMPDIR/.claude/.session-state/$SESSION_ID/start-porcelain.txt"
if [ ! -f "$SNAPSHOT" ]; then
  printf 'FAIL: snapshot file not created at %s\n' "$SNAPSHOT"
  exit 1
fi

# Ensure mtime gap so SESSION.md mtime check would otherwise consider it stale
sleep 1

# No edits during session — porcelain unchanged.
stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop blocked on no-op session with carryover\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
