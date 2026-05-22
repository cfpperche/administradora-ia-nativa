#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/02-bystander.sh
# Spec 030 — Scenario "parallel session bystander".
#
# Given session A has zero edited-files entries (research-only / bystander),
# when a sibling process modifies a tracked file during A's lifetime,
# then A's Stop must NOT emit a block decision.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-030-02-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"
echo "initial" >tracked.txt
git add tracked.txt
git commit -q -m initial

mkdir -p "$TMPDIR/.claude"
touch "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-bystander-02"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

# Session A starts (clean tree).
printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Mark this session as tracker-aware by creating an EMPTY edited-files.txt
# — represents a session that loaded with tracker enabled but did zero edits.
STATE_DIR="$TMPDIR/.claude/.session-state/$SESSION_ID"
touch "$STATE_DIR/edited-files.txt"

# Sibling process modifies a tracked file during A's lifetime.
sleep 1
echo "sibling-edit" >>tracked.txt

# A's Stop fires.
stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: bystander session blocked despite zero own edits\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
