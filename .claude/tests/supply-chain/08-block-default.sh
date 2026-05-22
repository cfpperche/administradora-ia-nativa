#!/usr/bin/env bash
# .claude/tests/supply-chain/08-block-default.sh
# V8 — Scenario: Bash dep-install in default (block) mode without override.
#
# Spec 009 promotes the supply-chain Bash preflight from advisory to a
# blocking gate by default. Default state (CLAUDE_SUPPLY_CHAIN_BLOCK unset)
# means: detected dep-install + no valid override marker → exit 2 with a
# corrective stderr template, audit decision="block".
#
# This test deliberately does NOT export CLAUDE_SUPPLY_CHAIN_BLOCK — the
# whole point is the unset/default behaviour. Sibling tests 01, 02, 05, 07
# pin CLAUDE_SUPPLY_CHAIN_BLOCK=0 to preserve advisory-mode regression
# coverage under the new default.
#
# Asserts:
#   (a) hook exits 2 (not 0 — block mode is exit-2 like secrets-scan)
#   (b) stderr starts with `supply-chain-block: npm install detected — packages: axios`
#   (c) stderr ends with the verbatim corrected form (two lines):
#         npm install axios
#         # OVERRIDE: <reason ≥10 chars — why this dep is being added>
#   (d) audit log row with decision="block", manager/action/packages
#       captured, override_reason=null

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-009-V8-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
# Deliberately NOT setting CLAUDE_SUPPLY_CHAIN_BLOCK — default = block mode.
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

stdin_json="$(jq -cn '{tool_input:{command:"npm install axios"}, session_id:"V8-session"}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

# (a) exit 2
if [ "$hook_exit" -ne 2 ]; then
  printf 'FAIL: hook exit=%d, want 2\n' "$hook_exit"
  printf 'Stderr was:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (b) stderr opens with the block-template lead line
if ! grep -q "^supply-chain-block: npm install detected — packages: axios$" "$stderr_file"; then
  printf 'FAIL: stderr missing expected block-template lead line\n'
  printf 'Got stderr:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (c) stderr ends with the verbatim two-line corrected form.
# Last two non-empty lines should be:
#   <leading indent>npm install axios
#   <leading indent># OVERRIDE: <reason ≥10 chars — why this dep is being added>
last_two="$(grep -v '^$' "$stderr_file" | tail -2)"
expected_cmd_line='npm install axios'
expected_override_line='# OVERRIDE: <reason ≥10 chars — why this dep is being added>'

if ! printf '%s\n' "$last_two" | grep -qE "^[[:space:]]*${expected_cmd_line}\$"; then
  printf 'FAIL: stderr does not end with original command line\n'
  printf 'Expected (trimmed): %s\n' "$expected_cmd_line"
  printf 'Got last two lines:\n%s\n' "$last_two"
  exit 1
fi
if ! printf '%s\n' "$last_two" | grep -qF "$expected_override_line"; then
  printf 'FAIL: stderr does not end with override-marker placeholder\n'
  printf 'Expected (substring): %s\n' "$expected_override_line"
  printf 'Got last two lines:\n%s\n' "$last_two"
  exit 1
fi

# (d) audit row shape
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
  '.decision == "block"' \
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
