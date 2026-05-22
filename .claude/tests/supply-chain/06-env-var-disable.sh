#!/usr/bin/env bash
# .claude/tests/supply-chain/06-env-var-disable.sh
# V7 — Scenario: CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1 disables both hooks.
#
# Verifies both the Bash preflight AND the Edit/Write advisory exit 0
# silently and write nothing to the audit log when the kill-switch is set.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
BASH_HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"
ADVISE_HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-advise.sh"

TMPDIR="$(mktemp -d -t spec-008-V6-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1

# Bash hook: would normally produce advisory + audit row.
stdin_bash="$(jq -cn '{tool_input:{command:"npm install axios"}, session_id:"V6"}')"
stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_bash" | bash "$BASH_HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [bash hook]: exit=%d\n' "$hook_exit"; exit 1
fi
if [ -s "$stderr_file" ]; then
  printf 'FAIL [bash hook]: expected silent, got stderr:\n%s\n' "$(cat "$stderr_file")"; exit 1
fi

# Edit hook: would normally produce advisory + audit row.
stdin_edit="$(jq -cn '{
  tool_name:"Edit",
  tool_input:{file_path:"/some/path/package.json", old_string:"", new_string:""},
  session_id:"V6",
  agent_id:"V6-sub"
}')"
: > "$stderr_file"
hook_exit=0
printf '%s' "$stdin_edit" | bash "$ADVISE_HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [advise hook]: exit=%d\n' "$hook_exit"; exit 1
fi
if [ -s "$stderr_file" ]; then
  printf 'FAIL [advise hook]: expected silent, got stderr:\n%s\n' "$(cat "$stderr_file")"; exit 1
fi

# Audit log MUST NOT EXIST (env-var disable should write nothing).
audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ -f "$audit_log" ] && [ -s "$audit_log" ]; then
  printf 'FAIL: audit log has content but env-var should have suppressed:\n%s\n' "$(cat "$audit_log")"
  exit 1
fi

printf 'PASS\n'
exit 0
