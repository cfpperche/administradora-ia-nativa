#!/usr/bin/env bash
# .claude/tests/mcp-recipes/01-next-detection.sh
# V1 — Scenario: Next.js project detection suggests next-devtools + playwright.
#
# Two sub-cases:
#   (a) next.config.js exists (file signal)
#   (b) package.json has `next` in dependencies (dep signal)
#
# Asserts the hint block contains both `next-devtools-mcp` AND `playwright-mcp`
# recipe names. Does NOT assert ordering (combined hint is set-like).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-012-V1-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

run_case() {
  local label="$1"
  local fixture_setup="$2"

  local fixture="$TMPDIR/$label"
  mkdir -p "$fixture"
  eval "$fixture_setup"

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
    printf 'Got:\n'
    cat "$out_file"
    exit 1
  fi

  if ! grep -q 'next-devtools-mcp' "$out_file"; then
    printf 'FAIL [%s]: hint missing next-devtools-mcp\n' "$label"
    cat "$out_file"
    exit 1
  fi

  if ! grep -q 'playwright-mcp' "$out_file"; then
    printf 'FAIL [%s]: hint missing playwright-mcp\n' "$label"
    cat "$out_file"
    exit 1
  fi
}

# (a) next.config.js file signal
run_case "next-config-file" "touch '$TMPDIR/next-config-file/next.config.js'"

# (b) package.json next dep signal
run_case "next-package-dep" "printf '%s\n' '{\"dependencies\":{\"next\":\"^15.0.0\",\"react\":\"^18.0.0\"}}' > '$TMPDIR/next-package-dep/package.json'"

# (c) next.config.ts variant
run_case "next-config-ts" "touch '$TMPDIR/next-config-ts/next.config.ts'"

printf 'PASS\n'
exit 0
