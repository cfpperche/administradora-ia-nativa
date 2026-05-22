#!/usr/bin/env bash
# Spec 019 — Scenario: memory-placement.md documents 3 buckets.
# Asserts:
#   (a) memory-placement.md mentions all three bucket paths verbatim:
#       - ~/.claude/projects/
#       - .claude/memory/
#       - .claude/rules/

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
RULE="$AGENT0_ROOT/.claude/rules/memory-placement.md"

if [ ! -f "$RULE" ]; then
  printf 'FAIL: %s not found\n' "$RULE"
  exit 1
fi

for path in '~/.claude/projects/' '.claude/memory/' '.claude/rules/'; do
  if ! grep -qF "$path" "$RULE"; then
    printf 'FAIL: memory-placement.md missing reference to bucket path: %s\n' "$path"
    exit 1
  fi
done

echo "PASS: 07-memory-placement-3-buckets"
