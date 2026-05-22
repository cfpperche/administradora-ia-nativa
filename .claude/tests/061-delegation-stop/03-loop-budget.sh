#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/03-loop-budget.sh
# Spec 061 — Scenario: sub-agent stopped due to loop-budget exhaustion.
#
# Given .claude/.delegation-state/agents/<agent_id>/consecutive_failures holds
# a count >= CLAUDE_DELEGATION_LOOP_BUDGET (default 5), When SubagentStop
# fires, Then the close row records exit=loop-budget-exceeded instead of ok.
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"

TMP="$(mktemp -d -t spec-061-03-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
AUDIT="$TMP/.claude/delegation-audit.jsonl"

AGENT_ID="agent-test-0003"
TUID="toolu_TEST0000000000000003"
SESSION="sess-061-03"
ATYPE="general-purpose"

# Pre-seed the loop-budget state file at the default cap.
STATE="$TMP/.claude/.delegation-state/agents/$AGENT_ID"
mkdir -p "$STATE"
printf '5\n' >"$STATE/consecutive_failures"

TRANSCRIPT="$TMP/agent-${AGENT_ID}.jsonl"
printf '%s\n' '{"type":"assistant","message":[{"type":"text","text":"stuck"}]}' >"$TRANSCRIPT"
printf '%s\n' "{\"toolUseId\":\"$TUID\",\"agentType\":\"$ATYPE\"}" >"$TMP/agent-${AGENT_ID}.meta.json"

DTS="$(date -u -d '-2 seconds' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-2S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
printf '%s\n' "{\"ts\":\"$DTS\",\"session_id\":\"$SESSION\",\"tool_use_id\":\"$TUID\",\"subagent_type\":\"$ATYPE\",\"task_summary\":\"seed\"}" >"$AUDIT"

PAYLOAD="$(jq -cn --arg s "$SESSION" --arg a "$AGENT_ID" --arg t "$ATYPE" --arg tr "$TRANSCRIPT" \
  '{session_id:$s,agent_id:$a,agent_type:$t,agent_transcript_path:$tr,last_assistant_message:"loop budget hit",stop_hook_active:false,hook_event_name:"SubagentStop"}')"

hook_exit=0
printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"; exit 1; }

ROW="$(grep '"event":"subagent-stop"' "$AUDIT" | tail -1 || true)"
[ -n "$ROW" ] || { printf 'FAIL: no close row appended\n'; cat "$AUDIT"; exit 1; }

got="$(printf '%s' "$ROW" | jq -r '.exit')"
[ "$got" = "loop-budget-exceeded" ] || { printf 'FAIL: exit=%s want loop-budget-exceeded\n' "$got"; exit 1; }

printf 'PASS: %s\n' "$(basename "$0")"
