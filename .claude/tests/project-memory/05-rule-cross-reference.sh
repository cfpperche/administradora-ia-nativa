#!/usr/bin/env bash
# Spec 019 — Scenario: cross-reference from rule docs works.
# Asserts:
#   (a) `.claude/rules/runtime-introspect.md` mentions `.claude/memory/cc-platform-hooks.md`

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
RULE="$AGENT0_ROOT/.claude/rules/runtime-introspect.md"

if [ ! -f "$RULE" ]; then
  printf 'FAIL: %s not found\n' "$RULE"
  exit 1
fi

if ! grep -q '\.claude/memory/cc-platform-hooks\.md' "$RULE"; then
  printf 'FAIL: runtime-introspect.md missing cross-reference to .claude/memory/cc-platform-hooks.md\n'
  exit 1
fi

echo "PASS: 05-rule-cross-reference"
