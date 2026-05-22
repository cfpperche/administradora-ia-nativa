#!/usr/bin/env bash
# .claude/tests/supply-chain-composer/02-composer-require-override.sh
# Spec 047 V2 — Scenario: `composer require <pkg>` with valid OVERRIDE marker passes.
#
# Asserts:
#   (a) hook exit 0
#   (b) audit row with decision="block-override", override_reason populated

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-047-V2b-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

cmd=$'composer require laravel/cashier\n# OVERRIDE: cashier needed for billing tier model'
stdin_json="$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}, session_id:"V2b"}')"
stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0 (override silent-pass)\n  stderr: %s\n' "$hook_exit" "$(cat "$stderr_file")"
  exit 1
fi

if [ -s "$stderr_file" ]; then
  printf 'FAIL: stderr non-empty under valid override\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
row=$(cat "$audit_log")
for check in \
  '.decision == "block-override"' \
  '.manager == "composer"' \
  '.action == "require"' \
  '.override_reason != null'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed: %s\n  row: %s\n' "$check" "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
