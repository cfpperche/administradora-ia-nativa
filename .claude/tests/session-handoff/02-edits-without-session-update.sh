#!/usr/bin/env bash
# .claude/tests/session-handoff/02-edits-without-session-update.sh
# Spec 023 — Scenario 2: session edits a file, SESSION.md not updated.
#
# Given a clean session start, when the session edits a tracked file
# (porcelain changes), then Stop MUST block (today's behavior preserved).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-023-02-XXXXXX)"
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
# Backdate SESSION.md so the mtime-newer-than-started-at check fails
touch -d "1 hour ago" "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-edit-02"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

# SessionStart captures clean porcelain snapshot (empty file)
printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Mid-session edit — porcelain now differs from empty snapshot.
# Spec 030: record the edit via the tracker so the primary path sees it
# (replaces pre-030 reliance on raw porcelain-delta).
sleep 1
echo "edited-mid-session" >tracked.txt
printf '%s' "{\"session_id\":\"$SESSION_ID\",\"tool_input\":{\"file_path\":\"tracked.txt\"}}" | bash "$TRACK_HOOK"

# SESSION.md NOT bumped — primary path (spec 030) should block
stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

if ! printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop did not block on real edits without SESSION.md update\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
