#!/usr/bin/env bash
# .claude/tests/mcp-recipes/03-db-detection.sh
# V3 — Scenario: DB-shaped project detection suggests DBHub.
#
# Three sub-cases:
#   (a) schema.prisma at repo root
#   (b) drizzle.config.ts at repo root
#   (c) .env.example with DATABASE_URL= line
#
# Asserts the hint contains `dbhub` for each.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-012-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

run_case() {
  local label="$1"
  local setup_cmd="$2"

  local fixture="$TMPDIR/$label"
  mkdir -p "$fixture"
  eval "$setup_cmd"

  export CLAUDE_PROJECT_DIR="$fixture"
  unset CLAUDE_SKIP_MCP_RECIPES

  local out_file="$TMPDIR/out-$label.txt"
  local hook_exit=0
  bash "$HOOK" >"$out_file" 2>&1 || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    cat "$out_file"
    exit 1
  fi

  if ! grep -qE '=== mcp-recipes ===' "$out_file"; then
    printf 'FAIL [%s]: hint block NOT emitted\n' "$label"
    cat "$out_file"
    exit 1
  fi

  if ! grep -q 'dbhub' "$out_file"; then
    printf 'FAIL [%s]: hint missing dbhub recipe\n' "$label"
    cat "$out_file"
    exit 1
  fi
}

run_case "prisma"   "touch '$TMPDIR/prisma/schema.prisma'"
run_case "drizzle"  "touch '$TMPDIR/drizzle/drizzle.config.ts'"
run_case "env"      "printf 'DATABASE_URL=postgres://example\n' > '$TMPDIR/env/.env.example'"
run_case "alembic"  "touch '$TMPDIR/alembic/alembic.ini'"

printf 'PASS\n'
exit 0
