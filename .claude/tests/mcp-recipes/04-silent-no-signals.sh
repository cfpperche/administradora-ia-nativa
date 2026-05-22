#!/usr/bin/env bash
# .claude/tests/mcp-recipes/04-silent-no-signals.sh
# V4 — Scenario: no stack signals → silent.
#
# Asserts that a fixture with only README.md + LICENSE (no Next, no browser,
# no DB signals) produces NO hint block.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-012-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/no-signals"
printf '# example\n' > "$TMPDIR/no-signals/README.md"
printf 'MIT\n' > "$TMPDIR/no-signals/LICENSE"

export CLAUDE_PROJECT_DIR="$TMPDIR/no-signals"
unset CLAUDE_SKIP_MCP_RECIPES

out_file="$TMPDIR/out.txt"
hook_exit=0
bash "$HOOK" >"$out_file" 2>&1 || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  cat "$out_file"
  exit 1
fi

if grep -qE '=== mcp-recipes ===' "$out_file"; then
  printf 'FAIL: hint block emitted on bare fixture (should be silent)\n'
  cat "$out_file"
  exit 1
fi

if [ -s "$out_file" ]; then
  printf 'FAIL: hook produced non-empty output on silent path\n'
  cat "$out_file"
  exit 1
fi

# Regression guard: also assert that an empty fixture (no files at all)
# produces silent exit 0.
mkdir -p "$TMPDIR/empty"
export CLAUDE_PROJECT_DIR="$TMPDIR/empty"
empty_out="$TMPDIR/empty-out.txt"
empty_exit=0
bash "$HOOK" >"$empty_out" 2>&1 || empty_exit=$?

if [ "$empty_exit" -ne 0 ] || [ -s "$empty_out" ]; then
  printf 'FAIL: empty fixture path failed (exit=%d, out=%d bytes)\n' "$empty_exit" "$(wc -c < "$empty_out")"
  cat "$empty_out"
  exit 1
fi

printf 'PASS\n'
exit 0
