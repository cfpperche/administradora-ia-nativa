#!/usr/bin/env bash
# Spec 016 — Scenario: explicit --agent0-path required.
# Asserts:
#   (a) invoking without --agent0-path AND without AGENT0_HARNESS_PATH → exit 2
#   (b) stderr names both --agent0-path and AGENT0_HARNESS_PATH

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-10-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

FORK="$TMPDIR/fork"
mkdir -p "$FORK"

# Run from non-Agent0 cwd with no env var. PWD is the tmpdir.
unset AGENT0_HARNESS_PATH || true

actual_exit=0
out="$(cd "$TMPDIR" && bash "$TOOL" --apply "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 2 ]; then
  printf 'FAIL: expected exit 2 (usage), got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q '\-\-agent0-path'; then
  printf 'FAIL: stderr missing --agent0-path hint\n%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q 'AGENT0_HARNESS_PATH'; then
  printf 'FAIL: stderr missing AGENT0_HARNESS_PATH hint\n%s\n' "$out"
  exit 1
fi

echo "PASS: 10-agent0-path-explicit"
