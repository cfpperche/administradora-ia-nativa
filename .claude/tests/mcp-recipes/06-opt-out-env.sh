#!/usr/bin/env bash
# .claude/tests/mcp-recipes/06-opt-out-env.sh
# V6 — Scenario: CLAUDE_SKIP_MCP_RECIPES=1 opt-out.
#
# Asserts:
#   (a) With matching stack + CLAUDE_SKIP_MCP_RECIPES=1, hint NOT emitted.
#   (b) Regression guard: same fixture without the env var → hint IS emitted.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-012-V6-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/fixture"
touch "$TMPDIR/fixture/next.config.js"
export CLAUDE_PROJECT_DIR="$TMPDIR/fixture"

# Sub-case (a): env var set → silent
export CLAUDE_SKIP_MCP_RECIPES=1
out_a="$TMPDIR/out-a.txt"
exit_a=0
bash "$HOOK" >"$out_a" 2>&1 || exit_a=$?

if [ "$exit_a" -ne 0 ]; then
  printf 'FAIL [env-set]: hook exit=%d, want 0\n' "$exit_a"
  cat "$out_a"
  exit 1
fi

if grep -qE '=== mcp-recipes ===' "$out_a"; then
  printf 'FAIL [env-set]: hint emitted despite CLAUDE_SKIP_MCP_RECIPES=1\n'
  cat "$out_a"
  exit 1
fi

# Sub-case (b): env var unset → hint emitted (regression guard)
unset CLAUDE_SKIP_MCP_RECIPES
out_b="$TMPDIR/out-b.txt"
exit_b=0
bash "$HOOK" >"$out_b" 2>&1 || exit_b=$?

if [ "$exit_b" -ne 0 ]; then
  printf 'FAIL [env-unset]: hook exit=%d, want 0\n' "$exit_b"
  cat "$out_b"
  exit 1
fi

if ! grep -qE '=== mcp-recipes ===' "$out_b"; then
  printf 'FAIL [env-unset regression]: hint NOT emitted (skip became permanent?)\n'
  cat "$out_b"
  exit 1
fi

printf 'PASS\n'
exit 0
