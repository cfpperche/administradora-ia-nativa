#!/usr/bin/env bash
# Spec 058 — Scenario: mismatched markers (one BEGIN no END, or vice versa) → refuse.
# Also: nested-invalid (multiple BEGIN or END) → refuse.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

setup_src() {
  local dir="$1"
  mkdir -p "$dir/.claude"
  cat > "$dir/CLAUDE.md" <<'EOF'
# Agent0

## Overview

placeholder.

<!-- AGENT0:BEGIN -->

## A

body of A.

<!-- AGENT0:END -->
EOF
  printf '{"hooks":{}}\n' > "$dir/.claude/settings.json"
}

# --- Case (a): only BEGIN, no END ---
TMP_A="$(mktemp -d -t spec-058-18a-XXXXXX)"
trap 'rm -rf "$TMP_A" ${TMP_B:-} ${TMP_C:-}' EXIT

SRC_A="$TMP_A/agent0"
FORK_A="$TMP_A/fork"
setup_src "$SRC_A"
mkdir -p "$FORK_A/.claude"
cat > "$FORK_A/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork.

<!-- AGENT0:BEGIN -->

## A

body of A.
EOF
printf '{"hooks":{}}\n' > "$FORK_A/.claude/settings.json"

err_a="$(mktemp -t spec-058-18-erra-XXXXXX)"
exit_a=0
bash "$TOOL" --apply --agent0-path="$SRC_A" "$FORK_A" >/dev/null 2>"$err_a" || exit_a=$?
if [ "$exit_a" -eq 0 ]; then
  printf 'FAIL(a): only-BEGIN should refuse (exit non-zero), got 0\n'
  exit 1
fi
if ! grep -q 'markers mismatched' "$err_a"; then
  printf 'FAIL(a): stderr missing "markers mismatched"\n'
  cat "$err_a"
  exit 1
fi

# --- Case (b): only END, no BEGIN ---
TMP_B="$(mktemp -d -t spec-058-18b-XXXXXX)"
SRC_B="$TMP_B/agent0"
FORK_B="$TMP_B/fork"
setup_src "$SRC_B"
mkdir -p "$FORK_B/.claude"
cat > "$FORK_B/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork.

## A

body of A.

<!-- AGENT0:END -->
EOF
printf '{"hooks":{}}\n' > "$FORK_B/.claude/settings.json"

err_b="$(mktemp -t spec-058-18-errb-XXXXXX)"
exit_b=0
bash "$TOOL" --apply --agent0-path="$SRC_B" "$FORK_B" >/dev/null 2>"$err_b" || exit_b=$?
if [ "$exit_b" -eq 0 ]; then
  printf 'FAIL(b): only-END should refuse, got 0\n'
  exit 1
fi
if ! grep -q 'markers mismatched' "$err_b"; then
  printf 'FAIL(b): stderr missing "markers mismatched"\n'
  cat "$err_b"
  exit 1
fi

# --- Case (c): nested-invalid (2 BEGIN markers) ---
TMP_C="$(mktemp -d -t spec-058-18c-XXXXXX)"
SRC_C="$TMP_C/agent0"
FORK_C="$TMP_C/fork"
setup_src "$SRC_C"
mkdir -p "$FORK_C/.claude"
cat > "$FORK_C/CLAUDE.md" <<'EOF'
# MyFork

## Overview

fork.

<!-- AGENT0:BEGIN -->

## A

<!-- AGENT0:BEGIN -->

## B

<!-- AGENT0:END -->
EOF
printf '{"hooks":{}}\n' > "$FORK_C/.claude/settings.json"

err_c="$(mktemp -t spec-058-18-errc-XXXXXX)"
exit_c=0
bash "$TOOL" --apply --agent0-path="$SRC_C" "$FORK_C" >/dev/null 2>"$err_c" || exit_c=$?
if [ "$exit_c" -eq 0 ]; then
  printf 'FAIL(c): nested-invalid should refuse, got 0\n'
  exit 1
fi
if ! grep -q 'nested or out-of-order markers' "$err_c"; then
  printf 'FAIL(c): stderr missing "nested or out-of-order markers"\n'
  cat "$err_c"
  exit 1
fi

echo "PASS: 18-claude-md-mismatched-markers-refuse"
