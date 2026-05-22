#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/02-edit-count.sh
# Spec 061 — Scenario: sub-agent makes edits.
#
# Given a per-sub-agent transcript carrying 3 Edit + 1 Write tool_use blocks
# across multiple assistant entries, When SubagentStop fires, Then the close
# row records edit_count=4 — counted from the transcript JSONL, not from the
# session-scoped edit tracker.
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"

TMP="$(mktemp -d -t spec-061-02-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
AUDIT="$TMP/.claude/delegation-audit.jsonl"

AGENT_ID="agent-test-0002"
TUID="toolu_TEST0000000000000002"
SESSION="sess-061-02"
ATYPE="general-purpose"

TRANSCRIPT="$TMP/agent-${AGENT_ID}.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":[{"type":"tool_use","name":"Edit","id":"t1"},{"type":"tool_use","name":"Edit","id":"t2"}]}'
  printf '%s\n' '{"type":"assistant","message":[{"type":"text","text":"intermediate reasoning"}]}'
  printf '%s\n' '{"type":"user","message":[{"type":"tool_result","tool_use_id":"t1"}]}'
  printf '%s\n' '{"type":"assistant","message":[{"type":"tool_use","name":"Write","id":"t3"},{"type":"tool_use","name":"Edit","id":"t4"}]}'
  printf '%s\n' '{"type":"assistant","message":[{"type":"tool_use","name":"Read","id":"t5"},{"type":"tool_use","name":"Bash","id":"t6"}]}'
} >"$TRANSCRIPT"
printf '%s\n' "{\"toolUseId\":\"$TUID\",\"agentType\":\"$ATYPE\"}" >"$TMP/agent-${AGENT_ID}.meta.json"

DTS="$(date -u -d '-3 seconds' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-3S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
printf '%s\n' "{\"ts\":\"$DTS\",\"session_id\":\"$SESSION\",\"tool_use_id\":\"$TUID\",\"subagent_type\":\"$ATYPE\",\"task_summary\":\"seed\"}" >"$AUDIT"

PAYLOAD="$(jq -cn --arg s "$SESSION" --arg a "$AGENT_ID" --arg t "$ATYPE" --arg tr "$TRANSCRIPT" \
  '{session_id:$s,agent_id:$a,agent_type:$t,agent_transcript_path:$tr,last_assistant_message:"edits done",stop_hook_active:false,hook_event_name:"SubagentStop"}')"

hook_exit=0
printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"; exit 1; }

ROW="$(grep '"event":"subagent-stop"' "$AUDIT" | tail -1 || true)"
[ -n "$ROW" ] || { printf 'FAIL: no close row appended\n'; cat "$AUDIT"; exit 1; }

got="$(printf '%s' "$ROW" | jq -r '.edit_count')"
[ "$got" = "4" ] || { printf 'FAIL: edit_count=%s want 4 (3 Edit + 1 Write; Read/Bash excluded)\n' "$got"; exit 1; }

printf 'PASS: %s\n' "$(basename "$0")"
