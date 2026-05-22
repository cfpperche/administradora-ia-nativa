#!/usr/bin/env bash
# .claude/tests/runtime-introspect/11-failure-path-capture.sh
# V11 — Scenario: failure-path capture under PostToolUseFailure (spec 020).
#
# Spec 011 registered runtime-capture.sh on PostToolUse(Bash), but
# PostToolUse fires only when the underlying Bash command exits 0
# (canonical per .claude/memory/cc-platform-hooks.md). Failing verifiers
# (test failures, type errors, lint errors) route to PostToolUseFailure
# instead — silently dropped pre-spec-020. The fix: also register on
# PostToolUseFailure(Bash), AND teach the hook the divergent payload
# shape that event uses.
#
# Production PostToolUseFailure stdin payload shape (verified empirically
# 2026-05-11 by dump-probe on a failing `bun test` invocation under
# Claude Code 1M-context Opus 4.7):
#
#   {
#     "session_id": "...",
#     "transcript_path": "...",
#     "cwd": "...",
#     "permission_mode": "...",
#     "hook_event_name": "PostToolUseFailure",
#     "tool_name": "Bash",
#     "tool_input": {"command": "...", "description": "..."},
#     "tool_use_id": "...",
#     "error": "<entire failure output as a single string>",
#     "is_interrupt": false,
#     "duration_ms": 78
#   }
#
# DIVERGES from PostToolUse: `tool_response` is ABSENT; failure body is
# at top-level `.error`; `is_interrupt` replaces `tool_response.interrupted`.
# Spec 020 hook update keys on `hook_event_name == "PostToolUseFailure"`
# to route reading accordingly and defaults `inferred_status` to FAIL.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-020-V11-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

run_case() {
  local label="$1"
  local cmd="$2"
  local error_body="$3"
  local want_detector="$4"
  local want_pattern="$5"  # regex the stderr_head must match (failure body content)

  local stdin_json hook_exit
  stdin_json="$(jq -cn \
    --arg c "$cmd" \
    --arg e "$error_body" \
    '{
      session_id: "V11-session",
      transcript_path: "/dev/null",
      cwd: ".",
      hook_event_name: "PostToolUseFailure",
      tool_name: "Bash",
      tool_input: {command: $c, description: "deliberate failure for spec 020 test"},
      tool_use_id: "tool-use-V11",
      error: $e,
      is_interrupt: false,
      duration_ms: 78
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

  if ! jq -e . "$state_file" >/dev/null 2>&1; then
    printf 'FAIL [%s]: last-run.json is not valid JSON\n' "$label"
    cat "$state_file"
    exit 1
  fi

  for check in \
    ".command == \"$cmd\"" \
    ".detector == \"$want_detector\"" \
    '.exit == null' \
    '.inferred_status == "FAIL"' \
    "(.stderr_head | test(\"$want_pattern\"))" \
    '.session_id == "V11-session"'; do
    if [ "$(jq -r "$check" "$state_file")" != "true" ]; then
      printf 'FAIL [%s]: last-run.json assertion: %s\n' "$label" "$check"
      cat "$state_file"
      exit 1
    fi
  done

  rm -f "$state_file"
}

# Case 1: failing pytest under PostToolUseFailure
run_case "failing pytest, PostToolUseFailure shape" \
  "uv run pytest -q" \
  "Exit code 1
=================== FAILURES ===================
test_x: assert False
=================== 1 failed in 0.05s ===================
" \
  "pytest" \
  "1 failed"

# Case 2: failing bun test under PostToolUseFailure
run_case "failing bun test, PostToolUseFailure shape" \
  "bun test src/server.test.ts" \
  "Exit code 1
bun test v1.3.10
src/server.test.ts:
(fail) example test
 0 pass
 1 fail
" \
  "bun-test" \
  "1 fail"

printf 'PASS\n'
exit 0
