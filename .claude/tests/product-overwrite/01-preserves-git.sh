#!/usr/bin/env bash
# Spec 069 — Scenario: overwrite preserves .git/.
# Asserts clear-target.sh leaves .git/ and its history intact while removing
# the non-harness /product artifacts.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT="$AGENT0_ROOT/.claude/skills/product/scripts/clear-target.sh"

TMPDIR="$(mktemp -d -t spec-069-01-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

OUT="$TMPDIR/out"
mkdir -p "$OUT/docs" "$OUT/app" "$OUT/.claude"
echo "prior product artifact" > "$OUT/docs/concept-brief.md"
echo "wip" > "$OUT/app/page.tsx"
echo "hook" > "$OUT/.claude/hook.sh"

git -C "$OUT" init -q >/dev/null 2>&1
git -C "$OUT" add -A >/dev/null 2>&1
git -C "$OUT" -c user.email=t@t -c user.name=t commit -q -m "checkpoint" >/dev/null 2>&1
head_before="$(git -C "$OUT" rev-parse HEAD)"

bash "$SCRIPT" "$OUT" >/dev/null 2>&1

if [ ! -d "$OUT/.git" ]; then
  printf 'FAIL: .git/ was destroyed\n'
  exit 1
fi

head_after="$(git -C "$OUT" rev-parse HEAD 2>/dev/null || echo MISSING)"
if [ "$head_after" != "$head_before" ]; then
  printf 'FAIL: git history lost (HEAD %s -> %s)\n' "$head_before" "$head_after"
  exit 1
fi

if [ -d "$OUT/docs" ] || [ -d "$OUT/app" ]; then
  printf 'FAIL: non-harness artifacts (docs/, app/) not cleared\n'
  exit 1
fi

echo "PASS: 01-preserves-git"
