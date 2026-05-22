#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/06-missing-sidecar.sh
# Spec 061 — Scenario: missing transcript sidecar .meta.json.
#
# Given the transcript exists but its sidecar .meta.json does not (so no
# toolUseId bridge key is reachable), When SubagentStop fires, Then the close
# row records tool_use_id=null and falls back to the (session_id, agent_type)
# heuristic — correlation=heuristic-session-type, with a numeric duration_ms.
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"

TMP="$(mktemp -d -t spec-061-06-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
AUDIT="$TMP/.claude/delegation-audit.jsonl"

AGENT_ID="agent-test-0006"
TUID="toolu_TEST0000000000000006"
SESSION="sess-061-06"
ATYPE="Explore"

TRANSCRIPT="$TMP/agent-${AGENT_ID}.jsonl"
printf '%s\n' '{"type":"assistant","message":[{"type":"text","text":"no sidecar"}]}' >"$TRANSCRIPT"
# Deliberately NO agent-<id>.meta.json sidecar written.

# Dispatch row matches on (session_id, subagent_type) so the heuristic resolves.
DTS="$(date -u -d '-4 seconds' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-4S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
printf '%s\n' "{\"ts\":\"$DTS\",\"session_id\":\"$SESSION\",\"tool_use_id\":\"$TUID\",\"subagent_type\":\"$ATYPE\",\"task_summary\":\"seed\"}" >"$AUDIT"

PAYLOAD="$(jq -cn --arg s "$SESSION" --arg a "$AGENT_ID" --arg t "$ATYPE" --arg tr "$TRANSCRIPT" \
  '{session_id:$s,agent_id:$a,agent_type:$t,agent_transcript_path:$tr,last_assistant_message:"no sidecar",stop_hook_active:false,hook_event_name:"SubagentStop"}')"

hook_exit=0
printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"; exit 1; }

ROW="$(grep '"event":"subagent-stop"' "$AUDIT" | tail -1 || true)"
[ -n "$ROW" ] || { printf 'FAIL: no close row appended\n'; cat "$AUDIT"; exit 1; }

if ! printf '%s' "$ROW" | jq -e '.tool_use_id == null' >/dev/null; then
  printf 'FAIL: tool_use_id=%s want null (no sidecar to bridge from)\n' \
    "$(printf '%s' "$ROW" | jq -c '.tool_use_id')"
  exit 1
fi

got="$(printf '%s' "$ROW" | jq -r '.correlation')"
[ "$got" = "heuristic-session-type" ] || { printf 'FAIL: correlation=%s want heuristic-session-type\n' "$got"; exit 1; }

if ! printf '%s' "$ROW" | jq -e '.duration_ms | type == "number"' >/dev/null; then
  printf 'FAIL: duration_ms not numeric under heuristic match (got %s)\n' \
    "$(printf '%s' "$ROW" | jq -c '.duration_ms')"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
