#!/usr/bin/env bash
# .claude/tests/session-state-isolation/04-stop-reads-from-subdir.sh
# Spec 017 V4 — Scenario: Stop hook reads only from its own subdir.
#
# Block signal detected via stdout JSON pattern `{"decision":"block"`.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

TMPDIR="$(mktemp -d -t spec-017-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Git repo with uncommitted changes
git -C "$TMPDIR" init -q
git -C "$TMPDIR" config user.email "test@example.com"
git -C "$TMPDIR" config user.name "Test"
echo "initial" > "$TMPDIR/file.txt"
git -C "$TMPDIR" add file.txt
git -C "$TMPDIR" commit -q -m "init"
echo "modified" > "$TMPDIR/file.txt"

# Pre-populate <foo>/ with both markers, nagged newer (means "already nagged")
mkdir -p "$TMPDIR/.claude/.session-state/foo"
touch -d "2 minutes ago" "$TMPDIR/.claude/.session-state/foo/started-at"
touch -d "1 minute ago" "$TMPDIR/.claude/.session-state/foo/nagged"

# Stop call for foo: must silence (foo/nagged is newer than foo/started-at)
out_foo="$(printf '{"session_id":"foo"}' | bash "$STOP_HOOK" 2>&1)"
if printf '%s' "$out_foo" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop for foo emitted block JSON despite foo being already nagged\n'
  printf 'Got: %s\n' "$out_foo"
  exit 1
fi

# Pre-populate <baz>/ with just started-at (no nagged → must block on first Stop)
mkdir -p "$TMPDIR/.claude/.session-state/baz"
touch -d "2 minutes ago" "$TMPDIR/.claude/.session-state/baz/started-at"

# Stop call for baz: must block (baz never nagged, regardless of foo's state)
out_baz="$(printf '{"session_id":"baz"}' | bash "$STOP_HOOK" 2>&1)"
if ! printf '%s' "$out_baz" | grep -q '"decision":"block"'; then
  printf 'FAIL: Stop for baz did not block — foo nag was incorrectly visible to baz session\n'
  printf 'Got: %s\n' "$out_baz"
  exit 1
fi

# baz/nagged should now exist (created by the block path)
if [ ! -f "$TMPDIR/.claude/.session-state/baz/nagged" ]; then
  printf 'FAIL: baz/nagged not created after blocking Stop\n'
  exit 1
fi

# foo/nagged should be untouched
if [ ! -f "$TMPDIR/.claude/.session-state/foo/nagged" ]; then
  printf 'FAIL: foo/nagged was removed by baz Stop call\n'
  exit 1
fi

printf 'PASS\n'
exit 0
