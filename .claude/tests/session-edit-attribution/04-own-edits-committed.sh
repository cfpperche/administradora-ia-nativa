#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/04-own-edits-committed.sh
# Spec 030 — Scenario "own edits committed".
#
# Given session A tracked an edit to foo.ts and then committed it, when A's
# Stop fires, the block must NOT fire because the path is no longer dirty.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-030-04-XXXXXX)"
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

SESSION_ID="test-own-committed-04"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Edit + track + commit.
echo "own-edit" >>foo.ts
track_payload='{"session_id":"'"$SESSION_ID"'","tool_input":{"file_path":"foo.ts"}}'
printf '%s' "$track_payload" | bash "$TRACK_HOOK"
git add foo.ts
git commit -q -m "follow-up"

# Sanity: foo.ts is no longer dirty (other untracked files like .claude/SESSION.md
# may appear in porcelain — that's expected and not part of this scenario).
if git status --porcelain | grep -Fq ' foo.ts'; then
  printf 'FAIL: precondition broken — foo.ts still dirty after commit\n'
  git status --porcelain
  exit 1
fi

stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: clean porcelain still blocked\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
