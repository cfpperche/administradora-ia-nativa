#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/07-unwritable-log.sh
# Spec 061 — Scenario: failure-safe on an unwritable audit log.
#
# Given the audit log file has write permission removed, When SubagentStop
# fires, Then the hook's writability probe trips and it exits 0 silently
# without crashing — no close row is appended. A broken/locked log must never
# block sub-agent termination.
#
# Skipped under uid 0: root bypasses filesystem write bits, so chmod -w cannot
# create the unwritable condition the scenario depends on.
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"

if [ "$(id -u)" = "0" ]; then
  printf 'PASS: %s (skipped — running as root, chmod -w is a no-op)\n' "$(basename "$0")"
  exit 0
fi

TMP="$(mktemp -d -t spec-061-07-XXXXXX)"
trap 'chmod u+w "$TMP/.claude/delegation-audit.jsonl" 2>/dev/null || true; rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
AUDIT="$TMP/.claude/delegation-audit.jsonl"

AGENT_ID="agent-test-0007"
TUID="toolu_TEST0000000000000007"
SESSION="sess-061-07"
ATYPE="Explore"

TRANSCRIPT="$TMP/agent-${AGENT_ID}.jsonl"
printf '%s\n' '{"type":"assistant","message":[{"type":"text","text":"unwritable"}]}' >"$TRANSCRIPT"
printf '%s\n' "{\"toolUseId\":\"$TUID\",\"agentType\":\"$ATYPE\"}" >"$TMP/agent-${AGENT_ID}.meta.json"

# Create the audit log, then strip write permission.
: >"$AUDIT"
chmod -w "$AUDIT"

PAYLOAD="$(jq -cn --arg s "$SESSION" --arg a "$AGENT_ID" --arg t "$ATYPE" --arg tr "$TRANSCRIPT" \
  '{session_id:$s,agent_id:$a,agent_type:$t,agent_transcript_path:$tr,last_assistant_message:"unwritable log",stop_hook_active:false,hook_event_name:"SubagentStop"}')"

hook_exit=0
printf '%s' "$PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d, want 0 (fail-open on unwritable log)\n' "$hook_exit"; exit 1; }

# The log was unwritable, so it must still be empty — no row leaked through.
if [ -s "$AUDIT" ]; then
  printf 'FAIL: audit log is non-empty — a row was written to an unwritable log\n'
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
