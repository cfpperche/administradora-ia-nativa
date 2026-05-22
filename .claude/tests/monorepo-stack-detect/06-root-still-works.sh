#!/usr/bin/env bash
# .claude/tests/monorepo-stack-detect/06-root-still-works.sh
# V6 — Scenario: root signals still detected (regression guard for spec 012).
#
# Root next.config.js (no workspaces). Asserts hint fires unchanged from
# spec 012 behaviour: bare signal label (no path prefix), recipes correct.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-015-V6-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/root-only"
touch "$TMPDIR/root-only/next.config.js"

export CLAUDE_PROJECT_DIR="$TMPDIR/root-only"
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
  printf 'FAIL: hint block NOT emitted on root signal\n'
  cat "$out_file"
  exit 1
fi

if ! grep -q 'next-devtools-mcp' "$out_file"; then
  printf 'FAIL: hint missing next-devtools-mcp\n'
  cat "$out_file"
  exit 1
fi

# Bare signal label — no path prefix expected for root signal.
if ! grep -qE 'Stack signals detected: next.config.js' "$out_file"; then
  printf 'FAIL: root signal should appear bare (no path prefix)\n'
  cat "$out_file"
  exit 1
fi

# Negative regression: no spurious workspace path prefix.
if grep -qE '(apps|packages|services|workspaces)/.*next.config.js' "$out_file"; then
  printf 'FAIL: root-only fixture wrongly produced workspace-prefixed signal\n'
  cat "$out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
