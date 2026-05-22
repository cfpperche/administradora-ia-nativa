#!/usr/bin/env bash
# Spec 018 — Scenario: silent when no .githooks/ directory exists.
# Asserts:
#   (a) stdout does NOT contain 'githooks-activation' (capacity not installed)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-018-03-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Mock project WITHOUT .githooks/
git -C "$TMPDIR" init -q
mkdir -p "$TMPDIR/.claude"

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_GITHOOKS_HINT 2>/dev/null || true

stdin_json='{"source":"startup","session_id":"spec018-03"}'
out="$(printf '%s' "$stdin_json" | bash "$HOOK" 2>&1)" || true

if printf '%s' "$out" | grep -q 'githooks-activation'; then
  printf 'FAIL: githooks-activation should be silent without .githooks/ dir\n%s\n' "$out"
  exit 1
fi

echo "PASS: 03-silent-when-no-githooks-dir"
