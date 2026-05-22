#!/usr/bin/env bash
# .claude/tests/session-state-isolation/01-parallel-isolation.sh
# Spec 017 V1 — Scenario: parallel sessions don't reset each other's markers.
#
# Given Session A has its nagged marker in <.session-state>/session-A/, when
# SessionStart fires for Session B (parallel), Session A's nagged marker
# must remain intact AND Session B's marker lands in its own subdir.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-017-V1-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude/.session-state/session-A"
export CLAUDE_PROJECT_DIR="$TMPDIR"

# Simulate Session A: has both markers, nagged is newer than started-at
touch -d "2 minutes ago" "$TMPDIR/.claude/.session-state/session-A/started-at"
touch -d "1 minute ago" "$TMPDIR/.claude/.session-state/session-A/nagged"

# Capture A's nagged mtime BEFORE B's SessionStart
nagged_A_before="$(stat -c '%Y' "$TMPDIR/.claude/.session-state/session-A/nagged" 2>/dev/null \
  || stat -f '%m' "$TMPDIR/.claude/.session-state/session-A/nagged")"

# Run SessionStart for Session B (parallel)
stdin_json='{"source":"startup","session_id":"session-B"}'
printf '%s' "$stdin_json" | bash "$HOOK" >/dev/null 2>&1

# Assertion 1: Session A's nagged must still exist
if [ ! -f "$TMPDIR/.claude/.session-state/session-A/nagged" ]; then
  printf 'FAIL: Session A nagged marker was removed by Session B SessionStart\n'
  exit 1
fi

# Assertion 2: Session A's nagged mtime unchanged (not touched at all)
nagged_A_after="$(stat -c '%Y' "$TMPDIR/.claude/.session-state/session-A/nagged" 2>/dev/null \
  || stat -f '%m' "$TMPDIR/.claude/.session-state/session-A/nagged")"
if [ "$nagged_A_before" != "$nagged_A_after" ]; then
  printf 'FAIL: Session A nagged mtime changed (before=%s after=%s)\n' "$nagged_A_before" "$nagged_A_after"
  exit 1
fi

# Assertion 3: Session B's subdir was created with started-at
if [ ! -f "$TMPDIR/.claude/.session-state/session-B/started-at" ]; then
  printf 'FAIL: Session B started-at not created at expected per-id path\n'
  printf 'Expected: %s/.claude/.session-state/session-B/started-at\n' "$TMPDIR"
  printf 'Got tree:\n'
  find "$TMPDIR/.claude/.session-state" -print 2>/dev/null || true
  exit 1
fi

# Assertion 4: Session B should NOT have a nagged marker (fresh state)
if [ -f "$TMPDIR/.claude/.session-state/session-B/nagged" ]; then
  printf 'FAIL: Session B nagged marker exists after fresh SessionStart\n'
  exit 1
fi

printf 'PASS\n'
exit 0
