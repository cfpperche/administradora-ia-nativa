#!/usr/bin/env bash
# Spec 058 — Scenario: paired markers + region matches source → first apply = up-to-date,
# second apply = up-to-date, no mutations across runs (sha256sum stable).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-058-21-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

cat > "$SRC/CLAUDE.md" <<'EOF'
# Agent0

## Overview

placeholder.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

<!-- AGENT0:END -->
EOF

# Fork's region == source's region. Project section above BEGIN is fork-specific.
cat > "$FORK/CLAUDE.md" <<'EOF'
# MyFork

## Overview

my fork overview.

<!-- AGENT0:BEGIN -->

## A

body of A.

## B

body of B.

<!-- AGENT0:END -->
EOF

printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"

# Capture initial sha
sha_before="$(sha256sum "$FORK/CLAUDE.md" | awk '{print $1}')"

# --- Run 1 ---
out1="$(mktemp -t spec-058-21-out1-XXXXXX)"
exit1=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >"$out1" 2>/dev/null || exit1=$?
if [ "$exit1" -ne 0 ]; then
  printf 'FAIL(run1): expected exit 0, got %d\n' "$exit1"
  exit 1
fi
if ! grep -q '= up to date CLAUDE.md' "$out1"; then
  printf 'FAIL(run1): expected "= up to date CLAUDE.md" in output\n'
  cat "$out1"
  exit 1
fi
sha_after1="$(sha256sum "$FORK/CLAUDE.md" | awk '{print $1}')"
if [ "$sha_before" != "$sha_after1" ]; then
  printf 'FAIL(run1): fork CLAUDE.md mutated despite up-to-date\n'
  exit 1
fi

# --- Run 2 (idempotency) ---
out2="$(mktemp -t spec-058-21-out2-XXXXXX)"
exit2=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >"$out2" 2>/dev/null || exit2=$?
if [ "$exit2" -ne 0 ]; then
  printf 'FAIL(run2): expected exit 0, got %d\n' "$exit2"
  exit 1
fi
if ! grep -q '= up to date CLAUDE.md' "$out2"; then
  printf 'FAIL(run2): expected "= up to date CLAUDE.md" in output\n'
  cat "$out2"
  exit 1
fi
sha_after2="$(sha256sum "$FORK/CLAUDE.md" | awk '{print $1}')"
if [ "$sha_after1" != "$sha_after2" ]; then
  printf 'FAIL(run2): fork CLAUDE.md mutated on second apply\n'
  exit 1
fi

echo "PASS: 21-claude-md-idempotent-managed-block"
