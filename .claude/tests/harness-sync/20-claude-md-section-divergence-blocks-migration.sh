#!/usr/bin/env bash
# Spec 058 — Scenario: no markers + fork rewrote an Agent0-region-titled section body
# → diverged-sections.md written, candidate NOT written; legacy fallback merge still runs.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-058-20-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

placeholder.

<!-- AGENT0:BEGIN -->

## TDD

canonical TDD body.

## Compact Instructions

compact.

<!-- AGENT0:END -->
EOF

# Fork has NO markers. ## TDD body differs from Agent0 region.
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork overview.

## TDD

FORK-REWRITTEN TDD body — different from canonical.

## Compact Instructions

compact.
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

err_log="$(mktemp -t spec-058-20-err-XXXXXX)"
actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err_log" || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0 (legacy merge succeeds, candidate blocked), got %d\n' "$actual_exit"
  cat "$err_log"
  exit 1
fi

# Migration BLOCKED stderr
if ! grep -q 'claude-md-migration-blocked' "$err_log"; then
  printf 'FAIL: stderr missing claude-md-migration-blocked\n'
  cat "$err_log"
  exit 1
fi

# diverged-sections.md must exist
if [ ! -f "$FORK/.claude/CLAUDE.md.diverged-sections.md" ]; then
  printf 'FAIL: diverged-sections.md not written\n'
  exit 1
fi

# Report must name ## TDD
if ! grep -q 'TDD' "$FORK/.claude/CLAUDE.md.diverged-sections.md"; then
  printf 'FAIL: diverged-sections.md does not mention TDD\n'
  cat "$FORK/.claude/CLAUDE.md.diverged-sections.md"
  exit 1
fi

# Migration candidate must NOT exist
if [ -f "$FORK/.claude/CLAUDE.md.migration-candidate.md" ]; then
  printf 'FAIL: candidate file should not exist when divergence blocked\n'
  exit 1
fi

# Fork's TDD edit must survive (legacy merge does not touch existing sections)
if ! grep -q 'FORK-REWRITTEN TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL: fork TDD edit overwritten by legacy merge\n'
  exit 1
fi

echo "PASS: 20-claude-md-section-divergence-blocks-migration"
