#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/01-normal-completion.sh
# Spec 061 — Scenario: sub-agent completes normally.
#
# Given an open PreToolUse(Agent) dispatch row + a matching transcript sidecar
# .meta.json, When SubagentStop fires, Then a sibling close row is appended
# with event=subagent-stop, exit=ok, edit_count=0 (transcript has no tool_use),
# correlation=tool_use_id (exact bridge), tool_use_id mirrored from the
# sidecar, and a numeric duration_ms > 0 (dispatch ts seeded 5s in the past).
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"

TMP="$(mktemp -d -t spec-061-01-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
AUDIT="$TMP/.claude/delegation-audit.jsonl"

AGENT_ID="agent-test-0001"
TUID="toolu_TEST0000000000000001"
SESSION="sess-061-01"
ATYPE="Explore"

TRANSCRIPT="$TMP/agent-${AGENT_ID}.jsonl"
printf '%s\n' '{"type":"assistant","message":[{"type":"text","text":"done"}]}' >"$TRANSCRIPT"
printf '%s\n' "{\"toolUseId\":\"$TUID\",\"agentType\":\"$ATYPE\"}" >"$TMP/agent-${AGENT_ID}.meta.json"

# Open dispatch row, ts 5s in the past so duration_ms is a positive integer.
DTS="$(date -u -d '-5 seconds' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-5S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
printf '%s\n' "{\"ts\":\"$DTS\",\"session_id\":\"$SESSION\",\"tool_use_id\":\"$TUID\",\"subagent_type\":\"$ATYPE\",\"task_summary\":\"seed\"}" >"$AUDIT"

PAYLOAD="$(jq -cn --arg s "$SESSION" --arg a "$AGENT_ID" --arg t "$ATYPE" --arg tr "$TRANSCRIPT" \
  '{session_id:$s,agent_id:$a,agent_type:$t,agent_transcript_path:$tr,last_assistant_message:"all done",stop_hook_active:false,hook_event_name:"SubagentStop"}')"

hook_exit=0
printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"; exit 1; }

ROW="$(grep '"event":"subagent-stop"' "$AUDIT" | tail -1 || true)"
[ -n "$ROW" ] || { printf 'FAIL: no close row appended\n'; cat "$AUDIT"; exit 1; }

assert_field() {
  got="$(printf '%s' "$ROW" | jq -r ".$1")"
  [ "$got" = "$2" ] || { printf 'FAIL: .%s=%q want %q\n' "$1" "$got" "$2"; exit 1; }
}
assert_field event       "subagent-stop"
assert_field exit        "ok"
assert_field agent_id    "$AGENT_ID"
assert_field tool_use_id "$TUID"
assert_field correlation "tool_use_id"
assert_field edit_count  "0"

if ! printf '%s' "$ROW" | jq -e '.duration_ms | type == "number" and . >= 1000' >/dev/null; then
  printf 'FAIL: duration_ms not a number >= 1000 (got %s)\n' \
    "$(printf '%s' "$ROW" | jq -c '.duration_ms')"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
