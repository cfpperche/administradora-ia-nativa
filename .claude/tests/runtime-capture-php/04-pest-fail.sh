#!/usr/bin/env bash
# .claude/tests/runtime-capture-php/04-pest-fail.sh
# Spec 047 V3 — Scenario: pest Tests: N failed → detector=pest, FAIL.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"
TMPDIR="$(mktemp -d -t spec-047-V3d-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "vendor/bin/pest"},
  tool_response: {
    stdout: "   FAIL  Tests\\Feature\\UserTest\n  ✗ it creates a user — Expected true to be false\n\n  Tests:    1 failed, 2 passed (3 assertions)\n",
    stderr: "",
    exit_code: 1
  },
  session_id: "V3d",
  tool_use_id: "use-V3d"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d\n' "$hook_exit"; exit 1; }

state="$TMPDIR/.claude/.runtime-state/last-run.json"
for check in \
  '.detector == "pest"' \
  '.inferred_status == "FAIL"'; do
  if [ "$(jq -r "$check" "$state")" != "true" ]; then
    printf 'FAIL: %s\n  state: %s\n' "$check" "$(cat "$state")"
    exit 1
  fi
done

printf 'PASS\n'
