#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/06-bash-driven-fallback.sh
# Spec 030 — Scenario "Bash-driven edit (fallback path)".
#
# Given a session that modified files via Bash (not Edit/Write/MultiEdit), so
# the tracker has an EMPTY edited-files.txt, but porcelain still differs from
# start-porcelain — the spec-023 fallback path is NOT consulted on the tracker
# branch (empty tracker → exit 0 silently). This is the deliberate trade: the
# Bash-driven case becomes a silent miss, not a false-positive nag.
#
# This test pins that semantic: empty tracker file = "I edited nothing", even
# if porcelain says otherwise.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-030-06-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"
echo "initial" >bar.md
git add bar.md
git commit -q -m initial

mkdir -p "$TMPDIR/.claude"
touch "$TMPDIR/.claude/SESSION.md"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-bash-fallback-06"
stdin_json="{\"source\":\"startup\",\"session_id\":\"$SESSION_ID\"}"

printf '%s' "$stdin_json" | bash "$START_HOOK" >/dev/null 2>&1

# Tracker file exists but is empty (simulates tracker enabled, but the
# session's mutations went through Bash and never triggered PostToolUse Edit).
STATE_DIR="$TMPDIR/.claude/.session-state/$SESSION_ID"
touch "$STATE_DIR/edited-files.txt"

# Bash-driven mutation: porcelain now non-empty, but tracker stays empty.
sleep 1
sed -i 's/initial/sed-driven/' bar.md

stop_output="$(printf '%s' "$stdin_json" | bash "$STOP_HOOK" 2>&1 || true)"

# Empty tracker → silent exit 0. The Bash-driven edit becomes a silent miss.
# This trade is documented in the spec § Non-goals.
if printf '%s' "$stop_output" | grep -q '"decision":"block"'; then
  printf 'FAIL: empty tracker should short-circuit to silent exit (Bash-edit silent miss is the documented trade)\n'
  printf 'stop_output: %s\n' "$stop_output"
  exit 1
fi

printf 'PASS\n'
exit 0
