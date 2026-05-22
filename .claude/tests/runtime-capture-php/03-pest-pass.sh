#!/usr/bin/env bash
# .claude/tests/runtime-capture-php/03-pest-pass.sh
# Spec 047 V3 — Scenario: vendor/bin/pest clean run → detector=pest, PASS.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"
TMPDIR="$(mktemp -d -t spec-047-V3c-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "vendor/bin/pest"},
  tool_response: {
    stdout: "   PASS  Tests\\Feature\\UserTest\n  ✓ it creates a user with valid attributes\n  ✓ it validates email format\n\n  Tests:    2 passed (5 assertions)\n  Duration: 0.12s\n",
    stderr: "",
    exit_code: 0
  },
  session_id: "V3c",
  tool_use_id: "use-V3c"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?
[ "$hook_exit" -eq 0 ] || { printf 'FAIL: hook exit=%d\n' "$hook_exit"; exit 1; }

state="$TMPDIR/.claude/.runtime-state/last-run.json"
for check in \
  '.detector == "pest"' \
  '.inferred_status == "PASS"'; do
  if [ "$(jq -r "$check" "$state")" != "true" ]; then
    printf 'FAIL: %s\n  state: %s\n' "$check" "$(cat "$state")"
    exit 1
  fi
done

printf 'PASS\n'
