#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/05-custom-workspace-dirs.sh
# V5 — Scenario: custom workspace layout via env var.
#
# CLAUDE_MCP_RECIPES_WORKSPACE_DIRS="modules subprojects" REPLACES the default
# set. Fixture has modules/web/next.config.js (should fire) AND a decoy
# apps/foo/next.config.js (should NOT fire because apps/ is no longer in
# the active workspace set).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V5-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/modules/web" "$TMPDIR/apps/foo"
touch "$TMPDIR/modules/web/next.config.js"
touch "$TMPDIR/apps/foo/next.config.js"

export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_MCP_RECIPES_WORKSPACE_DIRS="modules subprojects"
unset CLAUDE_SKIP_MCP_RECIPES

out_file="$TMPDIR/out.txt"
hook_exit=0
bash "$HOOK" >"$out_file" 2>&1 || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  cat "$out_file"
  exit 1
fi

if ! grep -qE '=== mcp-recipes ===' "$out_file"; then
  printf 'FAIL: hint block NOT emitted (env var should activate modules/* walk)\n'
  cat "$out_file"
  exit 1
fi

if ! grep -q 'modules/web/next.config.js' "$out_file"; then
  printf 'FAIL: signal label missing modules/web/next.config.js (env var should walk modules/*)\n'
  cat "$out_file"
  exit 1
fi

if grep -q 'apps/foo/next.config.js' "$out_file"; then
  printf 'FAIL: env var should REPLACE default set; apps/foo signal must not appear\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
