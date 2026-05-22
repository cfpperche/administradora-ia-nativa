#!/usr/bin/env bash
# Spec 016 — Scenario: CLAUDE.md capacity-section append before Compact Instructions.
# Asserts:
#   (a) missing capacity sections appended
#   (b) fork-authored sections preserved
#   (c) `## Compact Instructions` remains LAST

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-06-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Agent0 CLAUDE.md: Overview, Spec-driven development, Supply chain, Runtime introspect, Compact Instructions
cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

base.

## Spec-driven development

sdd.

## Supply chain

supply-chain content.

## Runtime introspect

runtime-introspect content.

## Compact Instructions

compact.
EOF

# Fork CLAUDE.md: Overview, FORK-CUSTOM (fork-authored), Spec-driven development, Compact Instructions
cat > "$FORK/CLAUDE.md" <<'EOF'
# Fork

## Overview

fork overview.

## FORK-CUSTOM

fork-authored section.

## Spec-driven development

sdd.

## Compact Instructions

compact.
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  exit 1
fi

# Supply chain section must now exist
if ! grep -q '^## Supply chain' "$FORK/CLAUDE.md"; then
  printf 'FAIL: ## Supply chain not appended\n'
  cat "$FORK/CLAUDE.md"
  exit 1
fi

# Runtime introspect section must now exist
if ! grep -q '^## Runtime introspect' "$FORK/CLAUDE.md"; then
  printf 'FAIL: ## Runtime introspect not appended\n'
  exit 1
fi

# FORK-CUSTOM preserved
if ! grep -q '^## FORK-CUSTOM' "$FORK/CLAUDE.md"; then
  printf 'FAIL: fork-authored ## FORK-CUSTOM dropped\n'
  exit 1
fi

# Compact Instructions still last
last_h2="$(grep '^## ' "$FORK/CLAUDE.md" | tail -1)"
if [ "$last_h2" != "## Compact Instructions" ]; then
  printf 'FAIL: ## Compact Instructions not last (got: %s)\n' "$last_h2"
  exit 1
fi

echo "PASS: 06-claude-md-section-append"
