#!/usr/bin/env bash
# .claude/tests/supply-chain-composer/03-bare-install-dirty-composer-json.sh
# Spec 047 V2 — Scenario: bare `composer install` + uncommitted composer.json → advisory.
#
# Asserts:
#   (a) hook exit 0 (advisory, never blocks)
#   (b) stderr contains "supply-chain-advisory: bare \`composer install\` with uncommitted manifest(s)"
#   (c) audit row decision="advisory-bare-install", manager="composer", action="install"

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-047-V2c-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

# Set up a git repo with composer.json modified-uncommitted.
cd "$TMPDIR"
git init -q
git config user.email "test@test.local"
git config user.name "test"
echo '{"name":"acme/test"}' > composer.json
git add composer.json && git commit -q -m initial
# Modify composer.json so it's dirty.
echo '{"name":"acme/test","require":{"laravel/cashier":"^15"}}' > composer.json

stdin_json="$(jq -cn '{tool_input:{command:"composer install"}, session_id:"V2c"}')"
stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0 (bare-install is advisory-only)\n  stderr: %s\n' "$hook_exit" "$(cat "$stderr_file")"
  exit 1
fi

if ! grep -q "supply-chain-advisory: bare .composer install. with uncommitted manifest" "$stderr_file"; then
  printf 'FAIL: stderr missing bare-install advisory line\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

if ! grep -q "composer.json" "$stderr_file"; then
  printf 'FAIL: stderr advisory does not name composer.json\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
row=$(cat "$audit_log")
for check in \
  '.decision == "advisory-bare-install"' \
  '.manager == "composer"' \
  '.action == "install"'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed: %s\n  row: %s\n' "$check" "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
