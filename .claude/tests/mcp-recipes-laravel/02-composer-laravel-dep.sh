#!/usr/bin/env bash
# .claude/tests/mcp-recipes-laravel/02-composer-laravel-dep.sh
# Spec 047 V6 — Scenario: composer.json declares laravel/framework (no artisan file) → suggests laravel-boost-mcp.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"
TMPDIR="$(mktemp -d -t spec-047-V6b-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require": { "laravel/framework": "^11.0" }
}
EOF

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_MCP_RECIPES 2>/dev/null || true

out="$TMPDIR/out.txt"
bash "$HOOK" >"$out" 2>&1

grep -q 'laravel-boost-mcp' "$out" || { printf 'FAIL: missing laravel-boost-mcp\n%s\n' "$(cat "$out")"; exit 1; }
grep -q 'composer.json:laravel/framework' "$out" || { printf 'FAIL: signal label missing\n%s\n' "$(cat "$out")"; exit 1; }

printf 'PASS\n'
