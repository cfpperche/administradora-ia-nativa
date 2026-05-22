#!/usr/bin/env bash
# .claude/tests/supply-chain-composer/01-composer-require-blocks.sh
# Spec 047 V2 — Scenario: `composer require <pkg>` exits 2 in block mode without override.
#
# Asserts:
#   (a) hook exit 2
#   (b) stderr contains the block template naming manager=composer, package
#   (c) audit row with decision="block", manager="composer", action="require"

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-047-V2a-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

stdin_json="$(jq -cn '{tool_input:{command:"composer require laravel/cashier"}, session_id:"V2a"}')"
stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 2 ]; then
  printf 'FAIL: hook exit=%d, want 2\n' "$hook_exit"
  printf 'stderr:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

if ! grep -q '^supply-chain-block: composer require detected — packages: laravel/cashier$' "$stderr_file"; then
  printf 'FAIL: stderr missing block-template lead line\n  got:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ ! -f "$audit_log" ]; then
  printf 'FAIL: audit log not created\n'
  exit 1
fi

row=$(cat "$audit_log")
for check in \
  '.decision == "block"' \
  '.manager == "composer"' \
  '.action == "require"' \
  '.packages == ["laravel/cashier"]'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed: %s\n  row: %s\n' "$check" "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
