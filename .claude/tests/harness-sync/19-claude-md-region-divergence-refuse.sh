#!/usr/bin/env bash
# Spec 071 — Scenario: paired markers, fork edited its managed block AFTER the
# baseline was recorded → CUSTOMIZED → refuse + diverged-region.md. --force
# replaces the block wholesale.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-071-19-XXXXXX)"
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

## TDD

canonical TDD body.

<!-- AGENT0:END -->
EOF

# Phase 1: fork region == Agent0 region. --apply seeds the baseline.
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork overview.

<!-- AGENT0:BEGIN -->

## TDD

canonical TDD body.

<!-- AGENT0:END -->
EOF

exit1=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || exit1=$?
if [ "$exit1" -ne 0 ]; then
  printf 'FAIL(1): seed --apply expected exit 0, got %d\n' "$exit1"
  exit 1
fi

# Phase 2: fork edits the ## TDD body INSIDE the region → customized.
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork overview.

<!-- AGENT0:BEGIN -->

## TDD

FORK-EDITED TDD body — operator changed this in-place.

<!-- AGENT0:END -->
EOF

err2="$(mktemp)"
exit2=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err2" || exit2=$?
if [ "$exit2" -eq 0 ]; then
  printf 'FAIL(2): customized managed block should refuse without --force\n'
  exit 1
fi
if ! grep -q 'managed block customized' "$err2"; then
  printf 'FAIL(2): stderr missing "managed block customized"\n'
  cat "$err2"
  exit 1
fi
if [ ! -f "$FORK/.claude/CLAUDE.md.diverged-region.md" ]; then
  printf 'FAIL(2): diverged-region.md not written\n'
  exit 1
fi
if ! grep -q 'FORK-EDITED TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL(2): fork edit overwritten despite refuse\n'
  exit 1
fi

# Phase 3: --apply --force → region replaced wholesale.
err3="$(mktemp)"
exit3=0
bash "$TOOL" --apply --force --agent0-path="$SRC" "$FORK" >/dev/null 2>"$err3" || exit3=$?
if [ "$exit3" -ne 0 ]; then
  printf 'FAIL(3): --force expected exit 0, got %d\n' "$exit3"
  cat "$err3"
  exit 1
fi
if ! grep -q 'overwritten CLAUDE.md (managed block replaced under --force)' "$err3"; then
  printf 'FAIL(3): stderr missing overwritten message\n'
  cat "$err3"
  exit 1
fi
if grep -q 'FORK-EDITED TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL(3): fork edit should be overwritten under --force\n'
  exit 1
fi
if ! grep -q 'canonical TDD body' "$FORK/CLAUDE.md"; then
  printf 'FAIL(3): canonical body not propagated under --force\n'
  exit 1
fi
if ! grep -q 'fork overview' "$FORK/CLAUDE.md"; then
  printf 'FAIL(3): fork project section (Overview body) lost\n'
  exit 1
fi

echo "PASS: 19-claude-md-region-divergence-refuse"
