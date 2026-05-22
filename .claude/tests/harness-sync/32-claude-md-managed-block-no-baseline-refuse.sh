#!/usr/bin/env bash
# Spec 071 — Scenario: paired markers, managed block differs from Agent0, but the
# fork has NO recorded baseline (a pre-071 fork's first sync). stale-vs-customized
# is unknowable with no history → refuse as `customized (no baseline)`; --force
# overrides. The one-time first-sync friction, mirroring spec 068's plain-file path.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-071-32-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

placeholder.

<!-- AGENT0:BEGIN -->

## A

agent0 body of A.

<!-- AGENT0:END -->
EOF

cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork overview.

<!-- AGENT0:BEGIN -->

## A

stale fork body of A.

<!-- AGENT0:END -->
EOF

# Deliberately NO .claude/harness-sync-baseline.json — fork never synced under
# the baseline mechanism.

# Phase 1: --apply (no --force) → refuse, customized (no baseline).
err1="$(mktemp)"
exit1=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err1" || exit1=$?
if [ "$exit1" -eq 0 ]; then
  printf 'FAIL(1): no-baseline managed block should refuse without --force\n'
  exit 1
fi
if ! grep -q 'managed block customized (no baseline)' "$err1"; then
  printf 'FAIL(1): stderr missing "managed block customized (no baseline)"\n'
  cat "$err1"
  exit 1
fi
if ! grep -q 'stale fork body of A' "$FORK/CLAUDE.md"; then
  printf 'FAIL(1): fork block changed despite refuse\n'
  exit 1
fi

# Phase 2: --apply --force → block replaced wholesale.
err2="$(mktemp)"
exit2=0
bash "$TOOL" --apply --force --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err2" || exit2=$?
if [ "$exit2" -ne 0 ]; then
  printf 'FAIL(2): --force expected exit 0, got %d\n' "$exit2"
  cat "$err2"
  exit 1
fi
if ! grep -q 'agent0 body of A' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): Agent0 block not propagated under --force\n'
  exit 1
fi
if grep -q 'stale fork body of A' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): stale fork body should be overwritten under --force\n'
  exit 1
fi
if ! grep -q 'fork overview' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): fork Overview lost\n'
  exit 1
fi

echo "PASS: 32-claude-md-managed-block-no-baseline-refuse"
