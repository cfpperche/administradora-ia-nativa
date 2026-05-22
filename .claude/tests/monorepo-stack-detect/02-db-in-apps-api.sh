#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/02-db-in-apps-api.sh
# V2 — Scenario: DB detected one level deep in apps/api/.
#
# Fixture: monorepo with apps/api/schema.prisma (no root DB signal).
# Asserts hint contains dbhub AND signal label names the workspace path.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V2-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/apps/api"
touch "$TMPDIR/apps/api/schema.prisma"

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
  cat "$out_file"
  exit 1
fi

if ! grep -q 'dbhub' "$out_file"; then
  printf 'FAIL: hint missing dbhub\n'
  cat "$out_file"
  exit 1
fi

if ! grep -q 'apps/api/schema.prisma' "$out_file"; then
  printf 'FAIL: signal label missing workspace prefix (expected apps/api/schema.prisma)\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
