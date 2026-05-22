#!/usr/bin/env bash
# Spec 019 — Scenario: agent discovers project memory via CLAUDE.md.
# Asserts:
#   (a) Agent0 CLAUDE.md contains a `^## Memory$` line
#   (b) that section mentions `.claude/memory/MEMORY.md` as entry point

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
CLAUDE_MD="$AGENT0_ROOT/CLAUDE.md"

if [ ! -f "$CLAUDE_MD" ]; then
  printf 'FAIL: %s not found\n' "$CLAUDE_MD"
  exit 1
fi

count="$(grep -c '^## Memory$' "$CLAUDE_MD" || true)"
if [ "$count" != "1" ]; then
  printf 'FAIL: expected exactly 1 `## Memory` heading, got %s\n' "$count"
  exit 1
fi

if ! grep -q '\.claude/memory/MEMORY\.md' "$CLAUDE_MD"; then
  printf 'FAIL: CLAUDE.md missing reference to .claude/memory/MEMORY.md\n'
  exit 1
fi

echo "PASS: 03-claude-md-has-memory-block"
