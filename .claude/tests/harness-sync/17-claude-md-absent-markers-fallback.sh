#!/usr/bin/env bash
# Spec 058 — Scenario: absent markers in fork + no section divergence with Agent0 region
# → legacy merge runs (back-compat) AND migration candidate written; advisory line on stderr.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-058-17-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Source is wrapped (candidate generation prerequisite).
cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

agent0 placeholder.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

## Compact Instructions

compact.

<!-- AGENT0:END -->
EOF

# Fork has NO markers, has A from a prior sync; no body divergence (A body matches src).
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

my fork overview.

## A

body of A.

## Compact Instructions

compact.
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

stderr_log="$(mktemp -t spec-058-17-err-XXXXXX)"
actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>"$stderr_log" || actual_exit=$?
if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  cat "$stderr_log"
  exit 1
fi

# Legacy merge: ## B must be appended to fork (it was missing)
if ! grep -q '^## B$' "$FORK/CLAUDE.md"; then
  printf 'FAIL: legacy merge did not append ## B\n'
  cat "$FORK/CLAUDE.md"
  exit 1
fi

# Migration candidate file must exist
if [ ! -f "$FORK/.claude/CLAUDE.md.migration-candidate.md" ]; then
  printf 'FAIL: candidate file not written\n'
  exit 1
fi

# Advisory line must be present on stderr
if ! grep -q 'claude-md-migration-advisory: candidate written' "$stderr_log"; then
  printf 'FAIL: migration advisory not emitted on stderr\n'
  cat "$stderr_log"
  exit 1
fi

# Candidate must have BEGIN/END markers
if ! grep -q '^<!-- AGENT0:BEGIN -->$' "$FORK/.claude/CLAUDE.md.migration-candidate.md"; then
  printf 'FAIL: candidate lacks BEGIN marker\n'
  exit 1
fi
if ! grep -q '^<!-- AGENT0:END -->$' "$FORK/.claude/CLAUDE.md.migration-candidate.md"; then
  printf 'FAIL: candidate lacks END marker\n'
  exit 1
fi

# Candidate must preserve fork's project section above BEGIN
begin_line="$(grep -nE '^<!-- AGENT0:BEGIN -->$' "$FORK/.claude/CLAUDE.md.migration-candidate.md" | head -1 | cut -d: -f1)"
overview_line="$(grep -n '^## Overview$' "$FORK/.claude/CLAUDE.md.migration-candidate.md" | head -1 | cut -d: -f1)"
if [ -n "$overview_line" ] && [ "$overview_line" -ge "$begin_line" ]; then
  printf 'FAIL: fork ## Overview should be above BEGIN in candidate\n'
  exit 1
fi

echo "PASS: 17-claude-md-absent-markers-fallback"
