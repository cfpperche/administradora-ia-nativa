#!/usr/bin/env bash
# .claude/tests/supply-chain/03-edit-manifest-advisory.sh
# V3 — Scenario: sub-agent Edit on a dep manifest triggers advisory.
#
# Asserts (for package.json edit by a delegated sub-agent):
#   (a) hook exits 0
#   (b) stderr contains `supply-chain-advisory: edit package.json`
#   (c) audit row decision="advisory", scope="edit", file="package.json",
#       agent_id populated (non-null)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-advise.sh"

TMPDIR="$(mktemp -d -t spec-008-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name:"Edit",
  tool_input:{file_path:"/some/path/package.json", old_string:"", new_string:""},
  session_id:"V3-session",
  agent_id:"V3-sub-agent"
}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if ! grep -q "^supply-chain-advisory: edit package.json — manifest may have new dep$" "$stderr_file"; then
  printf 'FAIL: stderr missing expected advisory line\n'
  printf 'Got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ ! -f "$audit_log" ]; then
  printf 'FAIL: audit log not created\n'
  exit 1
fi

row="$(cat "$audit_log")"
for check in \
  '.decision == "advisory"' \
  '.scope == "edit"' \
  '.file == "package.json"' \
  '.agent_id == "V3-sub-agent"' \
  '.session_id == "V3-session"'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
