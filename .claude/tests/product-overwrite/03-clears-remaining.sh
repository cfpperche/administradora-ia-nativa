#!/usr/bin/env bash
# Spec 069 — Scenario: a non-harness artifact is still cleared.
# Asserts every non-allowlist top-level entry is removed and named on stdout,
# while a harness entry in the same target survives.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT="$AGENT0_ROOT/.claude/skills/product/scripts/clear-target.sh"

TMPDIR="$(mktemp -d -t spec-069-03-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

OUT="$TMPDIR/out"
mkdir -p "$OUT/docs" "$OUT/app" "$OUT/lib" "$OUT/node_modules" "$OUT/.claude"
touch "$OUT/package.json"
echo state > "$OUT/docs/.state.json"

out="$(bash "$SCRIPT" "$OUT" 2>/dev/null)"

for e in docs app lib node_modules package.json; do
  if [ -e "$OUT/$e" ]; then
    printf 'FAIL: non-harness entry %s was not cleared\n' "$e"
    exit 1
  fi
done

if [ ! -d "$OUT/.claude" ]; then
  printf 'FAIL: harness entry .claude was removed\n'
  exit 1
fi

if ! printf '%s' "$out" | grep -q '^removed docs$'; then
  printf 'FAIL: stdout did not name the removed entry (expected `removed docs`)\n%s\n' "$out"
  exit 1
fi

echo "PASS: 03-clears-remaining"
