#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/03-combined-dedupe.sh
# V3 — Scenario: combined signals from multiple workspaces dedupe correctly.
#
# Fixture: apps/web/next.config.js + apps/api/schema.prisma + packages/ui/
# package.json (with react dep). Recipe set should list each entry exactly
# once even though playwright-mcp would be added by both Next branch (via
# apps/web) and browser branch (via packages/ui).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/apps/web" "$TMPDIR/apps/api" "$TMPDIR/packages/ui"
touch "$TMPDIR/apps/web/next.config.js"
touch "$TMPDIR/apps/api/schema.prisma"
printf '%s\n' '{"dependencies":{"react":"^18.0.0"}}' > "$TMPDIR/packages/ui/package.json"

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

# Each recipe must appear exactly once (count occurrences of `  - <name>` lines).
for r in next-devtools-mcp playwright-mcp chrome-devtools-mcp dbhub; do
  count=$(grep -cE "^  - $r " "$out_file" || true)
  if [ "$count" -ne 1 ]; then
    printf 'FAIL: recipe %s appears %d times (want exactly 1)\n' "$r" "$count"
    cat "$out_file"
    exit 1
  fi
done

# Signal labels should include all three workspace-prefixed paths.
if ! grep -q 'apps/web/next.config.js' "$out_file"; then
  printf 'FAIL: missing apps/web/next.config.js signal\n'
  cat "$out_file"
  exit 1
fi
if ! grep -q 'apps/api/schema.prisma' "$out_file"; then
  printf 'FAIL: missing apps/api/schema.prisma signal\n'
  cat "$out_file"
  exit 1
fi
if ! grep -q 'packages/ui/package.json:react' "$out_file"; then
  printf 'FAIL: missing packages/ui/package.json:react signal\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
