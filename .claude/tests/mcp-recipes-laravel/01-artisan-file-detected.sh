#!/usr/bin/env bash
# .claude/tests/mcp-recipes-laravel/01-artisan-file-detected.sh
# Spec 047 V6 — Scenario: artisan file at root → suggests laravel-boost-mcp + playwright-mcp.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"
TMPDIR="$(mktemp -d -t spec-047-V6a-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Canonical Laravel signal: artisan file at project root.
touch "$TMPDIR/artisan"

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_MCP_RECIPES 2>/dev/null || true

out="$TMPDIR/out.txt"
bash "$HOOK" >"$out" 2>&1

grep -qE '=== mcp-recipes ===' "$out" || { printf 'FAIL: hint block not emitted\n%s\n' "$(cat "$out")"; exit 1; }
grep -q 'laravel-boost-mcp' "$out" || { printf 'FAIL: missing laravel-boost-mcp\n%s\n' "$(cat "$out")"; exit 1; }
grep -q 'playwright-mcp' "$out" || { printf 'FAIL: missing playwright-mcp\n%s\n' "$(cat "$out")"; exit 1; }
grep -q 'artisan' "$out" || { printf 'FAIL: signals do not name artisan\n%s\n' "$(cat "$out")"; exit 1; }

printf 'PASS\n'
