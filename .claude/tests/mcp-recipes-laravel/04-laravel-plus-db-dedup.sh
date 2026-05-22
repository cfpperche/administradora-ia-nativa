#!/usr/bin/env bash
# .claude/tests/mcp-recipes-laravel/04-laravel-plus-db-dedup.sh
# Spec 047 V6 — Scenario: Laravel + database/migrations → union (laravel-boost-mcp + playwright-mcp + dbhub).

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"
TMPDIR="$(mktemp -d -t spec-047-V6d-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

touch "$TMPDIR/artisan"
mkdir -p "$TMPDIR/database/migrations"

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_MCP_RECIPES 2>/dev/null || true

out="$TMPDIR/out.txt"
bash "$HOOK" >"$out" 2>&1

for recipe in laravel-boost-mcp playwright-mcp dbhub; do
  grep -q "$recipe" "$out" || { printf 'FAIL: missing %s\n%s\n' "$recipe" "$(cat "$out")"; exit 1; }
done

# Playwright should appear ONCE (deduped — laravel + browser would otherwise list it twice).
count_playwright=$(grep -c '^  - playwright-mcp' "$out" || true)
if [ "$count_playwright" -ne 1 ]; then
  printf 'FAIL: playwright-mcp deduped expected 1, got %d\n%s\n' "$count_playwright" "$(cat "$out")"
  exit 1
fi

printf 'PASS\n'
