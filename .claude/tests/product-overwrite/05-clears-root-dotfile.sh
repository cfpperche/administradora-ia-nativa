#!/usr/bin/env bash
# Spec 069 — Scenario: non-harness root dotfiles are cleared, harness dotfiles
# survive. Guards the dotfile-enumeration risk named in plan.md (`.mcp.json` is
# a root dotfile in <remaining>; `.gitignore` is a harness dotfile).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT="$AGENT0_ROOT/.claude/skills/product/scripts/clear-target.sh"

TMPDIR="$(mktemp -d -t spec-069-05-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

OUT="$TMPDIR/out"
mkdir -p "$OUT/.claude"
touch "$OUT/.mcp.json" "$OUT/.env" "$OUT/.gitignore" "$OUT/CLAUDE.md"

bash "$SCRIPT" "$OUT" >/dev/null 2>&1

# Non-harness dotfiles must be cleared.
for e in .mcp.json .env; do
  if [ -e "$OUT/$e" ]; then
    printf 'FAIL: non-harness root dotfile %s was not cleared\n' "$e"
    exit 1
  fi
done

# Harness dotfiles / entries must survive.
for e in .gitignore CLAUDE.md .claude; do
  if [ ! -e "$OUT/$e" ]; then
    printf 'FAIL: harness entry %s was removed\n' "$e"
    exit 1
  fi
done

echo "PASS: 05-clears-root-dotfile"
