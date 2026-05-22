#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/08-opt-out.sh
# V8 — Scenario: opt-out still works (regression guard for spec 012's escape hatch).
#
# Monorepo with strong workspace signals + CLAUDE_SKIP_MCP_RECIPES=1.
# Asserts hint silent.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V8-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/apps/web" "$TMPDIR/apps/api"
touch "$TMPDIR/apps/web/next.config.js"
touch "$TMPDIR/apps/api/schema.prisma"

export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SKIP_MCP_RECIPES=1
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
  printf 'FAIL: opt-out env should suppress hint even with strong signals\n'
  cat "$out_file"
  exit 1
fi

if [ -s "$out_file" ]; then
  printf 'FAIL: hook produced non-empty output despite opt-out\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
