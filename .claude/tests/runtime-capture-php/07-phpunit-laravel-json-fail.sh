#!/usr/bin/env bash
# .claude/tests/runtime-capture-php/07-phpunit-laravel-json-fail.sh
# Spec 047 dogfood finding (2026-05-18) — Laravel 11+ phpunit JSON FAIL shape.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"
TMPDIR="$(mktemp -d -t spec-047-V3g-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "vendor/bin/phpunit"},
  tool_response: {
    stdout: "{\"tool\":\"phpunit\",\"result\":\"failed\",\"tests\":2,\"passed\":1,\"failed\":1,\"assertions\":3,\"duration_ms\":52}\n",
    stderr: "",
    exit_code: 1
  },
  session_id: "V3g",
  tool_use_id: "use-V3g"
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
