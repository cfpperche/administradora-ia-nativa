#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/05-own-edits-reverted.sh
# Spec 030 — Scenario "own edits reverted".
#
# Given session A tracked an edit to foo.ts and then ran `git restore foo.ts`,
# when A's Stop fires, the block must NOT fire because the path is no longer
# dirty even though the tracker still remembers it.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-030-05-XXXXXX)"
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

SESSION_ID="test-own-reverted-05"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Edit + track + revert.
echo "own-edit" >>foo.ts
track_payload='{"session_id":"'"$SESSION_ID"'","tool_input":{"file_path":"foo.ts"}}'
printf '%s' "$track_payload" | bash "$TRACK_HOOK"
git restore foo.ts

# Sanity: tracker remembers it, porcelain clean.
TRACK_FILE="$TMPDIR/.claude/.session-state/$SESSION_ID/edited-files.txt"
if ! grep -Fxq 'foo.ts' "$TRACK_FILE"; then
  printf 'FAIL: tracker should remember foo.ts (precondition)\n'
  exit 1
fi
if git status --porcelain | grep -Fq ' foo.ts'; then
  printf 'FAIL: precondition broken — foo.ts still dirty after restore\n'
  git status --porcelain
  exit 1
fi

stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: reverted edit still triggered block (tracker remembered, porcelain clean)\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
