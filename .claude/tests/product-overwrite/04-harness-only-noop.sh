#!/usr/bin/env bash
# Spec 069 — Scenario: a harness-only or empty target is a no-op.
# Asserts clear-target.sh removes nothing when there is nothing non-harness
# to remove, and exits 0 on an empty directory.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT="$AGENT0_ROOT/.claude/skills/product/scripts/clear-target.sh"

TMPDIR="$(mktemp -d -t spec-069-04-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Harness-only target.
OUT="$TMPDIR/harness-only"
mkdir -p "$OUT/.claude" "$OUT/.git"
touch "$OUT/CLAUDE.md" "$OUT/.gitignore"

out="$(bash "$SCRIPT" "$OUT" 2>&1)"

if printf '%s' "$out" | grep -q '^removed '; then
  printf 'FAIL: removed something from a harness-only target\n%s\n' "$out"
  exit 1
fi

for e in .claude .git CLAUDE.md .gitignore; do
  if [ ! -e "$OUT/$e" ]; then
    printf 'FAIL: harness-only entry %s did not survive\n' "$e"
    exit 1
  fi
done

# Empty target — must exit 0, remove nothing.
EMPTY="$TMPDIR/empty"
mkdir -p "$EMPTY"
ec=0
bash "$SCRIPT" "$EMPTY" >/dev/null 2>&1 || ec=$?
if [ "$ec" -ne 0 ]; then
  printf 'FAIL: non-zero exit (%d) on an empty directory\n' "$ec"
  exit 1
fi

echo "PASS: 04-harness-only-noop"
