#!/usr/bin/env bash
# .claude/tests/supply-chain/01-bash-install-advisory.sh
# V1 — Scenario: Bash dep-install triggers advisory + audit.
#
# Asserts:
#   (a) the preflight exits 0 (advisory-only)
#   (b) stderr contains `supply-chain-advisory: npm install — axios`
#   (c) audit log gains exactly one row with:
#       decision="advisory", manager="npm", action="install",
#       packages=["axios"], override_reason=null, scope="bash"

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-008-V1-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SUPPLY_CHAIN_BLOCK=0  # spec 009: pin advisory mode under block-by-default default

stdin_json="$(jq -cn '{tool_input:{command:"npm install axios"}, session_id:"V1-session"}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if ! grep -q "^supply-chain-advisory: npm install — axios$" "$stderr_file"; then
  printf 'FAIL: stderr missing expected advisory line\n'
  printf 'Got stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ ! -f "$audit_log" ]; then
  printf 'FAIL: audit log not created\n'
  exit 1
fi

line_count=$(wc -l < "$audit_log")
if [ "$line_count" -ne 1 ]; then
  printf 'FAIL: audit log has %d lines, want 1\n' "$line_count"
  cat "$audit_log"
  exit 1
fi

row=$(cat "$audit_log")
for check in \
  '.decision == "advisory"' \
  '.scope == "bash"' \
  '.manager == "npm"' \
  '.action == "install"' \
  '.packages == ["axios"]' \
  '.override_reason == null'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
