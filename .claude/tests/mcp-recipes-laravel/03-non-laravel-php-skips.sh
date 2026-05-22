#!/usr/bin/env bash
# .claude/tests/mcp-recipes-laravel/03-non-laravel-php-skips.sh
# Spec 047 V6 — Negative: composer.json without laravel/framework AND no artisan → NO laravel-boost-mcp.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"
TMPDIR="$(mktemp -d -t spec-047-V6c-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Non-Laravel PHP project (Symfony or pure composer lib).
cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/lib",
  "require": { "symfony/console": "^7.0" }
}
EOF

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_MCP_RECIPES 2>/dev/null || true

out="$TMPDIR/out.txt"
bash "$HOOK" >"$out" 2>&1

if grep -q 'laravel-boost-mcp' "$out"; then
  printf 'FAIL: laravel-boost-mcp spuriously suggested for non-Laravel project\n%s\n' "$(cat "$out")"
  exit 1
fi

printf 'PASS\n'
