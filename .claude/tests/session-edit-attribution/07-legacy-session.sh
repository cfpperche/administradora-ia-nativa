#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/07-legacy-session.sh
# Spec 030 — Scenario "legacy session (pre-030)".
#
# Given a session whose state-dir has NO edited-files.txt at all (started
# before 030 deployed, or with CLAUDE_SKIP_SESSION_HOOKS during start), when
# Stop fires with a dirty porcelain that differs from start-porcelain, then
# the spec-023 fallback path is followed and the nag fires (assuming
# SESSION.md is stale relative to started-at). This pins the contract:
# missing tracker file = legacy session = spec 023 fully in charge.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-030-07-XXXXXX)"
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

SESSION_ID="test-legacy-07"
STATE_DIR="$TMPDIR/.claude/.session-state/$SESSION_ID"

# Manually seed legacy-shape state: started-at + clean start-porcelain
# snapshot, NO edited-files.txt.
mkdir -p "$STATE_DIR"
touch "$STATE_DIR/started-at"
git status --porcelain >"$STATE_DIR/start-porcelain.txt"

# Dirty the worktree (mimics edits done somehow during the session).
sleep 1
echo "modified" >>tracked.txt

# SESSION.md mtime is older than started-at (touched at TMPDIR setup, before
# started-at). Verify pre-Stop:
SESSION_MD_MTIME="$(stat -c %Y "$TMPDIR/.claude/SESSION.md")"
STARTED_MTIME="$(stat -c %Y "$STATE_DIR/started-at")"
if [ "$SESSION_MD_MTIME" -gt "$STARTED_MTIME" ]; then
  printf 'FAIL: precondition broken — SESSION.md newer than started-at\n'
  exit 1
fi

# Confirm edited-files.txt is absent.
if [ -e "$STATE_DIR/edited-files.txt" ]; then
  printf 'FAIL: precondition broken — edited-files.txt should be absent\n'
  exit 1
fi

stdin_json="{\"session_id\":\"$SESSION_ID\"}"
stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

# Spec 023 fallback should fire the block because porcelain differs from
# start-porcelain (which was empty) AND SESSION.md is stale.
if ! printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: legacy session should have blocked via spec-023 fallback\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
