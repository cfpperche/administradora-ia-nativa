#!/usr/bin/env bash
# .claude/tests/mcp-recipes/02-browser-non-next.sh
# V2 — Scenario: non-Next browser-stack detection suggests playwright + chrome-devtools.
#
# Asserts that a fixture with react/vue/svelte/vite/astro (no `next`) triggers
# the browser-non-next branch and the hint contains playwright-mcp AND
# chrome-devtools-mcp, but NOT next-devtools-mcp.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-012-V2-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

run_case() {
  local label="$1"
  local pkg_json="$2"

  local fixture="$TMPDIR/$label"
  mkdir -p "$fixture"
  printf '%s\n' "$pkg_json" > "$fixture/package.json"

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

  if ! grep -q 'playwright-mcp' "$out_file"; then
    printf 'FAIL [%s]: missing playwright-mcp\n' "$label"
    cat "$out_file"
    exit 1
  fi

  if ! grep -q 'chrome-devtools-mcp' "$out_file"; then
    printf 'FAIL [%s]: missing chrome-devtools-mcp\n' "$label"
    cat "$out_file"
    exit 1
  fi

  if grep -q 'next-devtools-mcp' "$out_file"; then
    printf 'FAIL [%s]: non-Next fixture wrongly suggested next-devtools-mcp\n' "$label"
    cat "$out_file"
    exit 1
  fi
}

run_case "react-only"  '{"dependencies":{"react":"^18.0.0","react-dom":"^18.0.0"}}'
run_case "vue-only"    '{"dependencies":{"vue":"^3.4.0"}}'
run_case "svelte-only" '{"devDependencies":{"svelte":"^5.0.0"}}'
run_case "vite-only"   '{"devDependencies":{"vite":"^5.0.0"}}'
run_case "astro-only"  '{"dependencies":{"astro":"^4.0.0"}}'

printf 'PASS\n'
exit 0
