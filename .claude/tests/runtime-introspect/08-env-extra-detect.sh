#!/usr/bin/env bash
# .claude/tests/runtime-introspect/08-env-extra-detect.sh
# V8 — Scenario: CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT enables custom
# runner capture without modifying the core detector list.
#
# Asserts:
#   (a) `make test` does NOT capture by default
#   (b) `make test` DOES capture when CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="make-test"
#   (c) detector field in the resulting JSON is prefixed `extra:` so audit
#       paths can distinguish core vs extension matches

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V8-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "make test"},
  tool_response: {stdout: "Makefile: 1 test passed\n", stderr: "", exit_code: 0},
  session_id: "V8-session",
  tool_use_id: "tool-use-V8"
}')"

# Sub-case 1: default — `make test` is NOT in the core list, must not capture.
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if [ -f "$state_file" ]; then
  printf 'FAIL: make test captured without EXTRA_DETECT (would defeat the strict-allowlist design)\n'
  exit 1
fi

# Sub-case 2: with EXTRA_DETECT, captures with extra: prefix on detector.
export CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="make-test"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [EXTRA_DETECT set]: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if [ ! -f "$state_file" ]; then
  printf 'FAIL [EXTRA_DETECT set]: state file not created for `make test`\n'
  exit 1
fi

detector="$(jq -r '.detector' "$state_file")"
if [ "$detector" != "extra:make-test" ]; then
  printf 'FAIL: detector=%s, want extra:make-test\n' "$detector"
  cat "$state_file"
  exit 1
fi

printf 'PASS\n'
exit 0
