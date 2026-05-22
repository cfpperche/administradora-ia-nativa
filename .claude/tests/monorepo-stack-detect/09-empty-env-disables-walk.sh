#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/09-empty-env-disables-walk.sh
# V9 — Scenario: empty env-var disables walk entirely.
#
# CLAUDE_MCP_RECIPES_WORKSPACE_DIRS="" (set but empty) opts out of all
# workspace walks. Root-level detection still runs (verified by adding a
# root signal); workspace signals MUST be silent.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V9-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- Sub-case A: workspace-only signals; empty env should silence the hint
mkdir -p "$TMPDIR/A/apps/web"
touch "$TMPDIR/A/apps/web/next.config.js"

export CLAUDE_PROJECT_DIR="$TMPDIR/A"
export CLAUDE_MCP_RECIPES_WORKSPACE_DIRS=""
unset CLAUDE_SKIP_MCP_RECIPES

out_a="$TMPDIR/out-a.txt"
hook_exit=0
bash "$HOOK" >"$out_a" 2>&1 || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [A]: hook exit=%d, want 0\n' "$hook_exit"
  cat "$out_a"
  exit 1
fi

if grep -qE '=== mcp-recipes ===' "$out_a"; then
  printf 'FAIL [A]: empty env should disable walk; workspace signal must not fire\n'
  cat "$out_a"
  exit 1
fi

# --- Sub-case B: root signal + workspace signal; empty env keeps root, silences workspace
mkdir -p "$TMPDIR/B/apps/api"
touch "$TMPDIR/B/next.config.js"
touch "$TMPDIR/B/apps/api/schema.prisma"

export CLAUDE_PROJECT_DIR="$TMPDIR/B"
export CLAUDE_MCP_RECIPES_WORKSPACE_DIRS=""

out_b="$TMPDIR/out-b.txt"
hook_exit=0
bash "$HOOK" >"$out_b" 2>&1 || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [B]: hook exit=%d, want 0\n' "$hook_exit"
  cat "$out_b"
  exit 1
fi

if ! grep -qE '=== mcp-recipes ===' "$out_b"; then
  printf 'FAIL [B]: root signal should still fire even with empty walk env\n'
  cat "$out_b"
  exit 1
fi

if ! grep -q 'next-devtools-mcp' "$out_b"; then
  printf 'FAIL [B]: root next signal lost\n'
  cat "$out_b"
  exit 1
fi

if grep -q 'apps/api/schema.prisma' "$out_b"; then
  printf 'FAIL [B]: workspace signal leaked through despite empty walk env\n'
  cat "$out_b"
  exit 1
fi

# Bonus: root signal label should be bare
if ! grep -qE 'Stack signals detected:.* next.config.js' "$out_b" && \
   ! grep -qE 'Stack signals detected: next.config.js' "$out_b"; then
  printf 'FAIL [B]: root signal label format unexpected\n'
  cat "$out_b"
  exit 1
fi

printf 'PASS\n'
exit 0
