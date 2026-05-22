#!/usr/bin/env bash
# .claude/tests/session-state-isolation/02-sessions-independent-blocks.sh
# Spec 017 V2 — Scenario: parallel sessions each block exactly once.
#
# Stop hook signals "block" via stdout JSON `{"decision":"block",...}`. Exit
# code is always 0 (per Claude Code hook contract). We detect blocks by
# grep on the JSON payload AND by the side-effect of touching nagged.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-017-V2-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Initialise repo with uncommitted change
git -C "$TMPDIR" init -q
git -C "$TMPDIR" config user.email "test@example.com"
git -C "$TMPDIR" config user.name "Test"
echo "initial" > "$TMPDIR/file.txt"
git -C "$TMPDIR" add file.txt
git -C "$TMPDIR" commit -q -m "init"
echo "modified" > "$TMPDIR/file.txt"

# Start Session A
printf '{"source":"startup","session_id":"sess-A"}' | bash "$START_HOOK" >/dev/null 2>&1

# Wait briefly so file mtimes for nagged are strictly > started-at (granular
# enough for the -nt check; one second of sleep is conservative on FAT/ext4).
sleep 1

# Start Session B (parallel) — must not affect A's state
printf '{"source":"startup","session_id":"sess-B"}' | bash "$START_HOOK" >/dev/null 2>&1
sleep 1

# Spec 023 — both SessionStarts captured a porcelain snapshot of the same
# carryover state. To test the nag-isolation contract (each session must
# block once independently), this scenario needs *real* WIP during the
# sessions, otherwise 023's snapshot-match early-exit kicks in (correctly:
# no porcelain delta → no handoff needed) and the test premise dies.
# Spec 030 — both sessions also need a tracker entry for the file so the
# primary edit-attribution path recognises the work; without a tracker entry
# the new spec-030 layer would silently exit on "empty tracker" before
# spec-023 has any chance to run.
echo "real-session-work" > "$TMPDIR/in-session.txt"
printf '%s' '{"session_id":"sess-A","tool_input":{"file_path":"in-session.txt"}}' | bash "$TRACK_HOOK"
printf '%s' '{"session_id":"sess-B","tool_input":{"file_path":"in-session.txt"}}' | bash "$TRACK_HOOK"

run_stop() {
  local sid="$1"
  printf '{"session_id":"%s"}' "$sid" | bash "$STOP_HOOK" 2>&1
}

# Stop A call 1: must block (nagged doesn't exist yet for A)
out_A1="$(run_stop sess-A)"
if ! printf '%s' "$out_A1" | grep -q '"decision":"block"'; then
  printf 'FAIL: First Stop for sess-A did not emit block JSON\n'
  printf 'Got: %s\n' "$out_A1"
  exit 1
fi
if [ ! -f "$TMPDIR/.claude/.session-state/sess-A/nagged" ]; then
  printf 'FAIL: First Stop for sess-A did not create sess-A/nagged\n'
  exit 1
fi

sleep 1

# Stop A call 2: must silently exit (A already nagged, no JSON output)
out_A2="$(run_stop sess-A)"
if printf '%s' "$out_A2" | grep -q '"decision":"block"'; then
  printf 'FAIL: Second Stop for sess-A blocked again\n'
  printf 'Got: %s\n' "$out_A2"
  exit 1
fi

# Stop B call 1: must block independently of A's nag
out_B1="$(run_stop sess-B)"
if ! printf '%s' "$out_B1" | grep -q '"decision":"block"'; then
  printf 'FAIL: First Stop for sess-B did not emit block JSON — A nag bled into B (the bug)\n'
  printf 'Got: %s\n' "$out_B1"
  exit 1
fi
if [ ! -f "$TMPDIR/.claude/.session-state/sess-B/nagged" ]; then
  printf 'FAIL: First Stop for sess-B did not create sess-B/nagged\n'
  exit 1
fi

sleep 1

# Stop B call 2: must silently exit
out_B2="$(run_stop sess-B)"
if printf '%s' "$out_B2" | grep -q '"decision":"block"'; then
  printf 'FAIL: Second Stop for sess-B blocked again\n'
  printf 'Got: %s\n' "$out_B2"
  exit 1
fi

printf 'PASS\n'
exit 0
