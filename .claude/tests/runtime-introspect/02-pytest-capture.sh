#!/usr/bin/env bash
# .claude/tests/runtime-introspect/02-pytest-capture.sh
# V2 — Scenario: Python test capture (pytest).
#
# Asserts pytest invocation captures correctly with non-zero exit when the
# suite fails. Also covers the `python -m pytest` form.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V2-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

run_case() {
  local label="$1"
  local cmd="$2"
  local want_detector="$3"
  local want_exit="$4"

  local stdin_json hook_exit

  stdin_json="$(jq -cn --arg c "$cmd" --argjson e "$want_exit" '{
    tool_name: "Bash",
    tool_input: {command: $c},
    tool_response: {
      stdout: "============= 1 failed, 4 passed in 0.12s =============",
      stderr: "",
      exit_code: $e
    },
    session_id: "V2-session",
    tool_use_id: "tool-use-V2"
  }')"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi

  local state_file="$TMPDIR/.claude/.runtime-state/last-run.json"
  if [ ! -f "$state_file" ]; then
    printf 'FAIL [%s]: last-run.json not created\n' "$label"
    exit 1
  fi

  for check in \
    ".command == \"$cmd\"" \
    ".detector == \"$want_detector\"" \
    ".exit == $want_exit"; do
    if [ "$(jq -r "$check" "$state_file")" != "true" ]; then
      printf 'FAIL [%s]: last-run.json assertion: %s\n' "$label" "$check"
      cat "$state_file"
      exit 1
    fi
  done

  rm -f "$state_file"
}

run_case "bare pytest, failure exit" \
  "pytest tests/" "pytest" 1

run_case "python -m pytest" \
  "python -m pytest" "python-pytest" 0

run_case "python3 -m pytest" \
  "python3 -m pytest tests/unit/" "python-pytest" 0

printf 'PASS\n'
exit 0
