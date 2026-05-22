#!/usr/bin/env bash
# .claude/tests/runtime-capture-php/02-phpunit-fail.sh
# Spec 047 V3 — Scenario: phpunit FAILURES! → detector=phpunit, FAIL.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"
TMPDIR="$(mktemp -d -t spec-047-V3b-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "vendor/bin/phpunit"},
  tool_response: {
    stdout: "PHPUnit 10.5.0\n\n.F.E                                4 / 4 (100%)\n\nTime: 00:00.020\n\nFAILURES!\nTests: 4, Assertions: 8, Failures: 1, Errors: 1\n",
    stderr: "",
    exit_code: 1
  },
  session_id: "V3b",
  tool_use_id: "use-V3b"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d\n' "$hook_exit"; exit 1; }

state="$TMPDIR/.claude/.runtime-state/last-run.json"
for check in \
  '.detector == "phpunit"' \
  '.inferred_status == "FAIL"'; do
  if [ "$(jq -r "$check" "$state")" != "true" ]; then
    printf 'FAIL: %s\n  state: %s\n' "$check" "$(cat "$state")"
    exit 1
  fi
done

printf 'PASS\n'
