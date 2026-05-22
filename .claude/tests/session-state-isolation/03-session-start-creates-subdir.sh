#!/usr/bin/env bash
# .claude/tests/session-state-isolation/03-session-start-creates-subdir.sh
# Spec 017 V3 — Scenario: SessionStart creates only its own subdir.
#
# Running SessionStart with session_id=foo touches <.session-state>/foo/started-at
# and removes <.session-state>/foo/nagged if present. Other subdirs (bar/) are
# left untouched.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-017-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Pre-create unrelated sibling subdir bar/ — must survive intact
mkdir -p "$TMPDIR/.claude/.session-state/bar"
touch "$TMPDIR/.claude/.session-state/bar/started-at"
touch "$TMPDIR/.claude/.session-state/bar/nagged"
bar_started_before="$(stat -c '%Y' "$TMPDIR/.claude/.session-state/bar/started-at" 2>/dev/null \
  || stat -f '%m' "$TMPDIR/.claude/.session-state/bar/started-at")"
bar_nagged_before="$(stat -c '%Y' "$TMPDIR/.claude/.session-state/bar/nagged" 2>/dev/null \
  || stat -f '%m' "$TMPDIR/.claude/.session-state/bar/nagged")"

# Pre-create foo/ with a nagged marker to verify removal
mkdir -p "$TMPDIR/.claude/.session-state/foo"
touch "$TMPDIR/.claude/.session-state/foo/nagged"

# Run SessionStart for foo
printf '{"source":"startup","session_id":"foo"}' | bash "$HOOK" >/dev/null 2>&1

# Assertion 1: foo/started-at created
if [ ! -f "$TMPDIR/.claude/.session-state/foo/started-at" ]; then
  printf 'FAIL: foo/started-at not created by SessionStart\n'
  exit 1
fi

# Assertion 2: foo/nagged removed (rm -f happens on every SessionStart)
if [ -f "$TMPDIR/.claude/.session-state/foo/nagged" ]; then
  printf 'FAIL: foo/nagged not removed by SessionStart\n'
  exit 1
fi

# Assertion 3: bar/ untouched
if [ ! -f "$TMPDIR/.claude/.session-state/bar/started-at" ]; then
  printf 'FAIL: bar/started-at was deleted\n'
  exit 1
fi
if [ ! -f "$TMPDIR/.claude/.session-state/bar/nagged" ]; then
  printf 'FAIL: bar/nagged was deleted (SessionStart of foo should not touch bar)\n'
  exit 1
fi
bar_started_after="$(stat -c '%Y' "$TMPDIR/.claude/.session-state/bar/started-at" 2>/dev/null \
  || stat -f '%m' "$TMPDIR/.claude/.session-state/bar/started-at")"
bar_nagged_after="$(stat -c '%Y' "$TMPDIR/.claude/.session-state/bar/nagged" 2>/dev/null \
  || stat -f '%m' "$TMPDIR/.claude/.session-state/bar/nagged")"
if [ "$bar_started_before" != "$bar_started_after" ]; then
  printf 'FAIL: bar/started-at mtime changed (before=%s after=%s)\n' "$bar_started_before" "$bar_started_after"
  exit 1
fi
if [ "$bar_nagged_before" != "$bar_nagged_after" ]; then
  printf 'FAIL: bar/nagged mtime changed (before=%s after=%s)\n' "$bar_nagged_before" "$bar_nagged_after"
  exit 1
fi

printf 'PASS\n'
exit 0
