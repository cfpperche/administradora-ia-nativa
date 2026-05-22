#!/usr/bin/env bash
# .claude/tests/runtime-introspect/01-bun-test-capture.sh
# V1 — Scenario: test-runner output captured (bun test).
#
# Asserts:
#   (a) capture hook exits 0
#   (b) .claude/.runtime-state/last-run.json is created
#   (c) JSON contains correct command, detector="bun-test", exit code, and
#       non-empty started_at

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V1-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "bun test src/server.test.ts"},
  tool_response: {
    stdout: "bun test v1.2.0\n2 pass, 0 fail\n",
    stderr: "",
    exit_code: 0
  },
  session_id: "V1-session",
  tool_use_id: "tool-use-V1"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"
if [ ! -f "$state_file" ]; then
  printf 'FAIL: last-run.json not created at %s\n' "$state_file"
  exit 1
fi

if ! jq -e . "$state_file" >/dev/null 2>&1; then
  printf 'FAIL: last-run.json is not valid JSON\n'
  cat "$state_file"
  exit 1
fi

for check in \
  '.command == "bun test src/server.test.ts"' \
  '.detector == "bun-test"' \
  '.exit == 0' \
  '(.started_at | length) > 0' \
  '.session_id == "V1-session"'; do
  if [ "$(jq -r "$check" "$state_file")" != "true" ]; then
    printf 'FAIL: last-run.json assertion: %s\n' "$check"
    cat "$state_file"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
