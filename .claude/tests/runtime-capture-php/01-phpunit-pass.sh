#!/usr/bin/env bash
# .claude/tests/runtime-capture-php/01-phpunit-pass.sh
# Spec 047 V3 — Scenario: vendor/bin/phpunit clean run → detector=phpunit, PASS.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-047-V3a-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "vendor/bin/phpunit --colors=never"},
  tool_response: {
    stdout: "PHPUnit 10.5.0 by Sebastian Bergmann and contributors.\n\n......                                  6 / 6 (100%)\n\nTime: 00:00.012, Memory: 6.00 MB\n\nOK (6 tests, 18 assertions)\n",
    stderr: "",
    exit_code: 0
  },
  session_id: "V3a",
  tool_use_id: "use-V3a"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d\n' "$hook_exit"; exit 1; }

state="$TMPDIR/.claude/.runtime-state/last-run.json"
[ -f "$state" ] || { printf 'FAIL: state file missing\n'; exit 1; }

for check in \
  '.detector == "phpunit"' \
  '.inferred_status == "PASS"' \
  '(.inference_basis | contains("OK (N tests"))'; do
  if [ "$(jq -r "$check" "$state")" != "true" ]; then
    printf 'FAIL: %s\n  state: %s\n' "$check" "$(cat "$state")"
    exit 1
  fi
done

printf 'PASS\n'
