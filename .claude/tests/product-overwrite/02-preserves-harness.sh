#!/usr/bin/env bash
# Spec 069 — Scenario: overwrite preserves the Agent0 harness.
# Asserts every harness-allowlist entry survives clear-target.sh, so no
# post-overwrite sync-harness re-bootstrap is needed.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT="$AGENT0_ROOT/.claude/skills/product/scripts/clear-target.sh"

TMPDIR="$(mktemp -d -t spec-069-02-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

OUT="$TMPDIR/out"
mkdir -p "$OUT/.claude" "$OUT/.githooks" "$OUT/.git" "$OUT/docs"
touch "$OUT/.gitignore" "$OUT/.gitleaks.toml" "$OUT/.mcp.json.example" "$OUT/CLAUDE.md"
echo marker > "$OUT/.git/SENTINEL"
echo doc > "$OUT/docs/x.md"

bash "$SCRIPT" "$OUT" >/dev/null 2>&1

for e in .claude .githooks .git .gitignore .gitleaks.toml .mcp.json.example CLAUDE.md; do
  if [ ! -e "$OUT/$e" ]; then
    printf 'FAIL: harness entry %s was removed\n' "$e"
    exit 1
  fi
done

if [ ! -f "$OUT/.git/SENTINEL" ]; then
  printf 'FAIL: .git/ contents were lost\n'
  exit 1
fi

if [ -d "$OUT/docs" ]; then
  printf 'FAIL: non-harness docs/ not cleared\n'
  exit 1
fi

echo "PASS: 02-preserves-harness"
