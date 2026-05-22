#!/usr/bin/env bash
# .claude/tests/runtime-introspect/03-skip-non-detect.sh
# V3 — Scenario: out-of-scope commands ignored.
#
# Asserts that commands outside the detector allowlist (ls, git status,
# echo, bun install, etc.) do NOT produce a state-file write and do NOT
# produce any audit file (the capacity writes no audit log by design).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

run_skip_case() {
  local label="$1"
  local cmd="$2"

  local stdin_json hook_exit

  stdin_json="$(jq -cn --arg c "$cmd" '{
    tool_name: "Bash",
    tool_input: {command: $c},
    tool_response: {stdout: "", stderr: "", exit_code: 0},
    session_id: "V3-session",
    tool_use_id: "tool-use-V3"
  }')"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi

  if [ -f "$TMPDIR/.claude/.runtime-state/last-run.json" ]; then
    printf 'FAIL [%s]: last-run.json was written for non-detect command\n' "$label"
    exit 1
  fi

  # Capacity explicitly writes no audit log; assert one was not created.
  if [ -f "$TMPDIR/.claude/runtime-audit.jsonl" ]; then
    printf 'FAIL [%s]: runtime-audit.jsonl created (capacity is audit-free by design)\n' "$label"
    exit 1
  fi
}

run_skip_case "ls -la"             "ls -la"
run_skip_case "git status"         "git status"
run_skip_case "echo hello"         "echo hello"
run_skip_case "bun install"        "bun install"
run_skip_case "bun run dev"        "bun run dev"
run_skip_case "cat README.md"      "cat README.md"

printf 'PASS\n'
exit 0
