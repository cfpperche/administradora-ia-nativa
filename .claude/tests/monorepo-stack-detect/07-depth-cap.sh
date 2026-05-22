#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/07-depth-cap.sh
# V7 — Scenario: depth cap honored.
#
# Fixture: apps/web/nested/deep/next.config.js. Walk is strictly depth-1
# per workspace pattern; a file at depth-3 must NOT trigger the hint.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V7-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/apps/web/nested/deep"
touch "$TMPDIR/apps/web/nested/deep/next.config.js"

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_MCP_RECIPES
unset CLAUDE_MCP_RECIPES_WORKSPACE_DIRS

out_file="$TMPDIR/out.txt"
hook_exit=0
bash "$HOOK" >"$out_file" 2>&1 || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  cat "$out_file"
  exit 1
fi

if grep -qE '=== mcp-recipes ===' "$out_file"; then
  printf 'FAIL: depth-3 next.config.js wrongly triggered hint (depth cap broken)\n'
  cat "$out_file"
  exit 1
fi

if [ -s "$out_file" ]; then
  printf 'FAIL: hook produced non-empty output on depth-cap miss path\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
