#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/03-own-edits-uncommitted.sh
# Spec 030 — Scenario "own edits uncommitted".
#
# Given session A tracked an edit to foo.ts (via the tracker hook) and the
# file is still dirty in the worktree, when A's Stop fires without
# SESSION.md being updated, then the block decision must be emitted.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-030-03-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"
echo "initial" >foo.ts
git add foo.ts
git commit -q -m initial

mkdir -p "$TMPDIR/.claude"
touch "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-own-uncommitted-03"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Session A modifies foo.ts AND records it via the tracker.
echo "own-edit" >>foo.ts
track_payload='{"session_id":"'"$SESSION_ID"'","tool_input":{"file_path":"foo.ts"}}'
printf '%s' "$track_payload" | bash "$TRACK_HOOK"

# Sanity: tracker recorded the path.
TRACK_FILE="$TMPDIR/.claude/.session-state/$SESSION_ID/edited-files.txt"
if ! grep -Fxq 'foo.ts' "$TRACK_FILE"; then
  printf 'FAIL: tracker did not record foo.ts (precondition)\n'
  exit 1
fi

# SESSION.md NOT updated this session → stale relative to started-at.
sleep 1
stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if ! printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: own uncommitted edits should have blocked\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
