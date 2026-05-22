#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/08-block-once-invariant.sh
# Spec 030 — Scenario "block-once invariant preserved".
#
# Given a session triggered the nag once (own edits + stale SESSION.md), when
# Stop fires again WITHOUT resolution, then the second Stop must NOT re-emit
# a block decision. Spec 030 changes the accuracy of the block decision, not
# its cardinality — the existing `nagged` marker short-circuit at line 41-43
# of session-stop.sh must still win.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-030-08-XXXXXX)"
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

SESSION_ID="test-block-once-08"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Edit + track + don't update SESSION.md → first Stop should block.
echo "own-edit" >>foo.ts
track_payload='{"session_id":"'"$SESSION_ID"'","tool_input":{"file_path":"foo.ts"}}'
printf '%s' "$track_payload" | bash "$TRACK_HOOK"

sleep 1

first_stop="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"
if ! printf '%s' "$first_stop" | grep -q '"decision":"block"'; then
  printf 'FAIL: first Stop should have blocked (precondition)\n'
  printf 'first_stop: %s\n' "$first_stop"
  exit 1
fi

# Confirm the nagged marker exists.
NAGGED="$TMPDIR/.claude/.session-state/$SESSION_ID/nagged"
if [ ! -f "$NAGGED" ]; then
  printf 'FAIL: nagged marker not created after first block\n'
  exit 1
fi

# Second Stop without resolution — must NOT re-block.
second_stop="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"
if printf '%s' "$second_stop" | grep -q '"decision":"block"'; then
  printf 'FAIL: second Stop re-emitted block — block-once invariant violated\n'
  printf 'second_stop: %s\n' "$second_stop"
  exit 1
fi

printf 'PASS\n'
exit 0
