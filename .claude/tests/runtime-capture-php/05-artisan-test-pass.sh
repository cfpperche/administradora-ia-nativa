#!/usr/bin/env bash
# .claude/tests/runtime-capture-php/05-artisan-test-pass.sh
# Spec 047 V3 — Scenario: php artisan test clean → detector=artisan-test, PASS.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"
TMPDIR="$(mktemp -d -t spec-047-V3e-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "php artisan test"},
  tool_response: {
    stdout: "\n   PASS  Tests\\Unit\\ExampleTest\n  ✓ that true is true\n\n  Tests:    1 passed (1 assertion)\n  Duration: 0.01s\n",
    stderr: "",
    exit_code: 0
  },
  session_id: "V3e",
  tool_use_id: "use-V3e"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d\n' "$hook_exit"; exit 1; }

state="$TMPDIR/.claude/.runtime-state/last-run.json"
for check in \
  '.detector == "artisan-test"' \
  '.inferred_status == "PASS"'; do
  if [ "$(jq -r "$check" "$state")" != "true" ]; then
    printf 'FAIL: %s\n  state: %s\n' "$check" "$(cat "$state")"
    exit 1
  fi
done

printf 'PASS\n'
