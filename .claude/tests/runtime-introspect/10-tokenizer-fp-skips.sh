#!/usr/bin/env bash
# .claude/tests/runtime-introspect/10-tokenizer-fp-skips.sh
# V10 — Scenario: leading-command FP skips (commit messages, grep patterns).
#
# Surfaced by spec 011 validation pass (2026-05-11): a `git commit -m` with
# a heredoc'd body containing verifier-shaped tokens (`bun tsc`) had its
# body tokenised, matched the `bun-tsc` detector, and wrote a false
# snapshot. Same family for `grep -E 'bun test' file`.
#
# Asserts:
#   (a) `git commit -m "..."` with verifier-shaped tokens in body → no capture
#   (b) `git -C /path commit -m "bun tsc ..."` → no capture
#   (c) `grep -E 'bun test' file.md` → no capture
#   (d) `rg 'bun test' .` → no capture
#   (e) Regression: a real `bun test` outside commit/grep context still
#       captures (so the skip isn't too aggressive)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V10-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"

run_skip_case() {
  local label="$1"
  local cmd="$2"

  rm -f "$state_file"

  local stdin_json hook_exit
  stdin_json="$(jq -cn --arg c "$cmd" '{
    tool_name: "Bash",
    tool_input: {command: $c},
    tool_response: {stdout: "ok", stderr: "", interrupted: false, isImage: false, noOutputExpected: false},
    session_id: "V10-session",
    tool_use_id: "tool-use-V10"
  }')"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi

  if [ -f "$state_file" ]; then
    printf 'FAIL [%s]: state file created (tokenizer should have skipped)\n' "$label"
    cat "$state_file"
    exit 1
  fi
}

# (a) git commit with verifier-shaped tokens in body
run_skip_case "git commit heredoc body" \
  $'git commit -m "$(cat <<\'EOF\'\nfix: bun tsc support\n\nThe bun test path was failing.\nEOF\n)"'

# (b) git -C /path commit
run_skip_case "git -C path commit" \
  'git -C /tmp/repo commit -m "feat: bun test pytest harness"'

# (c) grep -E with verifier pattern
run_skip_case "grep -E 'bun test'" \
  "grep -E 'bun test' README.md"

# (d) rg with verifier pattern
run_skip_case "rg 'bun test'" \
  "rg 'bun test' ."

# (e) Regression: bare `bun test` still captures (skip isn't too aggressive).
local_stdin="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "bun test"},
  tool_response: {stdout: " 5 pass\n 0 fail\n", stderr: "", interrupted: false, isImage: false, noOutputExpected: false},
  session_id: "V10-session",
  tool_use_id: "tool-use-V10-regress"
}')"
hook_exit=0
printf '%s' "$local_stdin" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [regression]: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if [ ! -f "$state_file" ]; then
  printf 'FAIL [regression]: bare bun test did NOT capture — skip is too aggressive\n'
  exit 1
fi

detector="$(jq -r '.detector' "$state_file")"
if [ "$detector" != "bun-test" ]; then
  printf 'FAIL [regression]: detector=%s, want bun-test\n' "$detector"
  exit 1
fi

printf 'PASS\n'
exit 0
