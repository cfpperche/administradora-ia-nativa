#!/usr/bin/env bash
# .claude/tests/runtime-introspect/16-ansi-strip-strong-inference.sh
# V16 — Scenario: ANSI escape sequences in runner output don't degrade
# inference to the weak `pass/ok` heuristic.
#
# Bug surfaced via shrnk-mono dogfood 2026-05-12: bun's test runner
# emits ANSI color codes (e.g. `\e[32m 0 fail\e[0m`) that prefix the
# canonical line-anchored regex `^[[:space:]]*0 fail[[:space:]]*$` and
# force the inference table to fall through to the weak heuristic
# `pass|✓|ok` keyword match. Status was still PASS but the basis
# string read `pass/ok keyword (weak heuristic)` instead of the
# canonical `'0 fail' line`.
#
# Fix: runtime-capture.sh now strips ANSI escape sequences from
# STDOUT_RAW/STDERR_RAW after collection, before storage and inference.
#
# This test asserts:
#   (a) ANSI-colored bun-test output infers PASS
#   (b) inference_basis IS the strong-pattern signal `'0 fail' line`,
#       NOT the weak `pass/ok keyword` fallback
#   (c) stored stdout_head no longer contains ESC characters

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V16-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"

# ANSI-colored bun test output — modeled on real shrnk-mono session output.
# `\e[0m`, `\e[32m`, `\e[2m`, `\e[1m` are typical SGR codes bun emits.
ansi_stdout=$'\e[1mbun test \e[0m\e[2mv1.3.10 (30e609e0)\e[0m\n\n\e[0m\e[32m 7 pass\e[0m\n\e[0m\e[2m 0 fail\e[0m\n 7 expect() calls\nRan 7 tests across 1 file. \e[0m\e[2m[\e[1m7.00ms\e[0m\e[2m]\e[0m\n'

stdin_json="$(jq -cn --arg out "$ansi_stdout" '{
  tool_name: "Bash",
  tool_input: {command: "bun test"},
  tool_response: {stdout: $out, stderr: "", interrupted: false, isImage: false, noOutputExpected: false},
  session_id: "V16-session",
  tool_use_id: "tool-use-V16"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if [ ! -f "$state_file" ]; then
  printf 'FAIL: state file not created\n'
  exit 1
fi

# (a) inferred_status MUST be PASS
inferred="$(jq -r '.inferred_status' "$state_file")"
if [ "$inferred" != "PASS" ]; then
  printf 'FAIL: inferred_status=%s, want PASS\n' "$inferred"
  printf 'inference_basis: %s\n' "$(jq -r '.inference_basis' "$state_file")"
  exit 1
fi

# (b) inference_basis MUST be the strong-pattern signal — '0 fail' line —
# NOT the weak `pass/ok keyword` fallback. This is the regression assertion.
basis="$(jq -r '.inference_basis' "$state_file")"
if ! echo "$basis" | grep -q "'0 fail' line"; then
  printf "FAIL: inference_basis=%s, want signal containing \"'0 fail' line\" (strong pattern)\n" "$basis"
  printf 'Got the weak fallback — ANSI strip likely broken.\n'
  exit 1
fi

# (c) stored stdout_head must NOT contain raw ESC characters (\x1b)
stdout_head="$(jq -r '.stdout_head' "$state_file")"
if printf '%s' "$stdout_head" | grep -q $'\e'; then
  printf 'FAIL: stdout_head still contains ESC (\\x1b) chars after strip\n'
  printf 'Head: %s\n' "$stdout_head" | head -3
  exit 1
fi

printf 'PASS\n'
exit 0
