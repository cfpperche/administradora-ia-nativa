#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/04-default-layouts.sh
# V4 — Scenario: standard layouts auto-recognised.
#
# Cycle through the 4 default workspace dirs (apps, packages, services,
# workspaces). Each fixture has next.config.js in a single child of one
# workspace dir; assert detection fires for each.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

run_case() {
  local layout="$1"
  local fixture="$TMPDIR/$layout"
  mkdir -p "$fixture/$layout/web"
  touch "$fixture/$layout/web/next.config.js"

  export CLAUDE_PROJECT_DIR="$fixture"
  unset CLAUDE_SKIP_MCP_RECIPES
  unset CLAUDE_MCP_RECIPES_WORKSPACE_DIRS

  local out_file="$TMPDIR/out-$layout.txt"
  local hook_exit=0
  bash "$HOOK" >"$out_file" 2>&1 || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$layout" "$hook_exit"
    cat "$out_file"
    exit 1
  fi

  if ! grep -qE '=== mcp-recipes ===' "$out_file"; then
    printf 'FAIL [%s]: hint block NOT emitted\n' "$layout"
    cat "$out_file"
    exit 1
  fi

  if ! grep -q "$layout/web/next.config.js" "$out_file"; then
    printf 'FAIL [%s]: signal label missing %s/web/next.config.js\n' "$layout" "$layout"
    cat "$out_file"
    exit 1
  fi
}

for layout in apps packages services workspaces; do
  run_case "$layout"
done

printf 'PASS\n'
exit 0
