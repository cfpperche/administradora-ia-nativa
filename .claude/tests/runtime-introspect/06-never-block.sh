#!/usr/bin/env bash
# .claude/tests/runtime-introspect/06-never-block.sh
# V6 — Scenario: capture never blocks the underlying command.
#
# Asserts the hook exits 0 even when the runtime-state path is unwriteable,
# and no stderr noise leaks unless CLAUDE_RUNTIME_INTROSPECT_DEBUG=1.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-011-V6-XXXXXX)"
trap 'chmod -R u+rwX "$TMPDIR" 2>/dev/null; rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude/.runtime-state"
export CLAUDE_PROJECT_DIR="$TMPDIR"

# Make .claude/.runtime-state read-only so atomic-write fails.
chmod 555 "$TMPDIR/.claude/.runtime-state"

stdin_json="$(jq -cn '{
  tool_name: "Bash",
  tool_input: {command: "bun test"},
  tool_response: {stdout: "ok", stderr: "", exit_code: 0},
  session_id: "V6-session",
  tool_use_id: "tool-use-V6"
}')"

# Sub-case 1: default — should be silent on stderr.
stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0 (must never block)\n' "$hook_exit"
  exit 1
fi

if [ -s "$stderr_file" ]; then
  printf 'FAIL: stderr non-empty in default mode (must be silent)\n'
  cat "$stderr_file"
  exit 1
fi

# Sub-case 2: CLAUDE_RUNTIME_INTROSPECT_DEBUG=1 — diagnostic IS allowed.
: > "$stderr_file"
hook_exit=0
CLAUDE_RUNTIME_INTROSPECT_DEBUG=1 printf '%s' "$stdin_json" | \
  CLAUDE_RUNTIME_INTROSPECT_DEBUG=1 bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: debug-mode hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

# In debug mode, stderr should mention runtime-introspect to be useful.
if ! grep -qi 'runtime-introspect' "$stderr_file"; then
  printf 'FAIL: debug-mode stderr lacks runtime-introspect diagnostic\n'
  cat "$stderr_file"
  exit 1
fi

printf 'PASS\n'
exit 0
