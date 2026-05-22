#!/usr/bin/env bash
# .claude/tests/runtime-introspect/04-tail-size-cap.sh
# V4 — Scenario: 64 KB stdout collapses to 4 KB head + 4 KB tail with
# truncation marker.
#
# Asserts:
#   (a) stdout_head is exactly 4096 bytes
#   (b) stdout_tail is exactly 4096 bytes
#   (c) stdout_truncated == true
#   (d) when total stdout <= 8192 bytes, head holds whole stream and
#       stdout_truncated == false

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

# Build a 64 KB string of `A`s (predictable, easy to verify byte lengths).
big_stdout="$(printf 'A%.0s' {1..65536})"

stdin_json="$(jq -cn --arg out "$big_stdout" '{
  tool_name: "Bash",
  tool_input: {command: "bun test"},
  tool_response: {stdout: $out, stderr: "", exit_code: 0},
  session_id: "V4-session",
  tool_use_id: "tool-use-V4"
}')"

hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"
if [ ! -f "$state_file" ]; then
  printf 'FAIL: last-run.json not created\n'
  exit 1
fi

head_len=$(jq -r '.stdout_head | length' "$state_file")
tail_len=$(jq -r '.stdout_tail | length' "$state_file")
truncated=$(jq -r '.stdout_truncated' "$state_file")

if [ "$head_len" != "4096" ]; then
  printf 'FAIL: stdout_head length=%s, want 4096\n' "$head_len"
  exit 1
fi
if [ "$tail_len" != "4096" ]; then
  printf 'FAIL: stdout_tail length=%s, want 4096\n' "$tail_len"
  exit 1
fi
if [ "$truncated" != "true" ]; then
  printf 'FAIL: stdout_truncated=%s, want true\n' "$truncated"
  exit 1
fi

# Now verify the small-stream path: total <= 8192 bytes → head holds whole
# stream, tail is empty, truncated is false.
rm -f "$state_file"

small_stdout="bun test v1.2.0
2 pass, 0 fail
"

stdin_json_small="$(jq -cn --arg out "$small_stdout" '{
  tool_name: "Bash",
  tool_input: {command: "bun test"},
  tool_response: {stdout: $out, stderr: "", exit_code: 0},
  session_id: "V4-session",
  tool_use_id: "tool-use-V4b"
}')"

hook_exit=0
printf '%s' "$stdin_json_small" | bash "$HOOK" || hook_exit=$?

if [ "$hook_exit" -ne 0 ] || [ ! -f "$state_file" ]; then
  printf 'FAIL: small-stream capture failed\n'
  exit 1
fi

small_truncated=$(jq -r '.stdout_truncated' "$state_file")

if [ "$small_truncated" != "false" ]; then
  printf 'FAIL: small-stream stdout_truncated=%s, want false\n' "$small_truncated"
  exit 1
fi

# Compare via jq (not bash command-sub, which strips trailing newlines).
if [ "$(jq --arg expected "$small_stdout" -r '.stdout_head == $expected' "$state_file")" != "true" ]; then
  printf 'FAIL: small-stream head should hold whole stream verbatim\n'
  printf 'Got: %s\n' "$(jq -r '.stdout_head' "$state_file" | head -5)"
  exit 1
fi

if [ "$(jq -r '.stdout_tail == ""' "$state_file")" != "true" ]; then
  printf 'FAIL: small-stream tail should be empty\n'
  exit 1
fi

printf 'PASS\n'
exit 0
