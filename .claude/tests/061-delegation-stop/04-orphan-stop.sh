#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/04-orphan-stop.sh
# Spec 061 — Scenario: orphan stop (no matching dispatch row).
#
# Given a SubagentStop payload whose tool_use_id / (session_id, agent_type)
# match no open dispatch row in the audit log, When the hook runs, Then the
# close row is still appended but records correlation=unmatched and
# duration_ms=null (no dispatch ts to diff against).
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"

TMP="$(mktemp -d -t spec-061-04-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
AUDIT="$TMP/.claude/delegation-audit.jsonl"

AGENT_ID="agent-test-0004"
TUID="toolu_TEST0000000000000004"
SESSION="sess-061-04"
ATYPE="Explore"

TRANSCRIPT="$TMP/agent-${AGENT_ID}.jsonl"
printf '%s\n' '{"type":"assistant","message":[{"type":"text","text":"orphan"}]}' >"$TRANSCRIPT"
printf '%s\n' "{\"toolUseId\":\"$TUID\",\"agentType\":\"$ATYPE\"}" >"$TMP/agent-${AGENT_ID}.meta.json"

# Seed an UNRELATED dispatch row — proves the hook does not false-match.
printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","session_id":"some-other-session","tool_use_id":"toolu_UNRELATED","subagent_type":"general-purpose","task_summary":"unrelated"}' >"$AUDIT"

PAYLOAD="$(jq -cn --arg s "$SESSION" --arg a "$AGENT_ID" --arg t "$ATYPE" --arg tr "$TRANSCRIPT" \
  '{session_id:$s,agent_id:$a,agent_type:$t,agent_transcript_path:$tr,last_assistant_message:"orphaned stop",stop_hook_active:false,hook_event_name:"SubagentStop"}')"

hook_exit=0
printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"; exit 1; }

ROW="$(grep '"event":"subagent-stop"' "$AUDIT" | tail -1 || true)"
[ -n "$ROW" ] || { printf 'FAIL: no close row appended\n'; cat "$AUDIT"; exit 1; }

got="$(printf '%s' "$ROW" | jq -r '.correlation')"
[ "$got" = "unmatched" ] || { printf 'FAIL: correlation=%s want unmatched\n' "$got"; exit 1; }

if ! printf '%s' "$ROW" | jq -e '.duration_ms == null' >/dev/null; then
  printf 'FAIL: duration_ms=%s want null\n' "$(printf '%s' "$ROW" | jq -c '.duration_ms')"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
