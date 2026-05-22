#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/01-next-in-apps-web.sh
# V1 — Scenario: Next.js detected one level deep in apps/web/.
#
# Fixture: monorepo with apps/web/next.config.js (no root next signal).
# Asserts hint contains next-devtools-mcp + playwright-mcp AND signal label
# names the workspace path (apps/web/next.config.js).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V1-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/apps/web"
touch "$TMPDIR/apps/web/next.config.js"

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

if ! grep -qE '=== mcp-recipes ===' "$out_file"; then
  printf 'FAIL: hint block NOT emitted\n'
  printf 'Got:\n'
  cat "$out_file"
  exit 1
fi

if ! grep -q 'next-devtools-mcp' "$out_file"; then
  printf 'FAIL: hint missing next-devtools-mcp\n'
  cat "$out_file"
  exit 1
fi

if ! grep -q 'playwright-mcp' "$out_file"; then
  printf 'FAIL: hint missing playwright-mcp\n'
  cat "$out_file"
  exit 1
fi

if ! grep -q 'apps/web/next.config.js' "$out_file"; then
  printf 'FAIL: signal label missing workspace prefix (expected apps/web/next.config.js)\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
