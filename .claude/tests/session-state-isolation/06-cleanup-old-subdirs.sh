#!/usr/bin/env bash
# .claude/tests/session-state-isolation/06-cleanup-old-subdirs.sh
# Spec 017 V6 — Scenario: SessionStart cleans up subdirs older than TTL.
#
# Subdirs whose started-at (or the dir itself) is older than 7 days are
# removed best-effort. Failure to clean (e.g. permissions) MUST NOT block
# the hook — it always exits 0.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-017-V6-XXXXXX)"
trap 'chmod -R u+rwx "$TMPDIR" 2>/dev/null || true; rm -rf "$TMPDIR"' EXIT

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Create 3 sibling subdirs:
#   ancient-1: mtime 10 days ago — should be cleaned
#   ancient-2: mtime 30 days ago — should be cleaned
#   recent:    mtime 2 days ago  — should be preserved
mkdir -p "$TMPDIR/.claude/.session-state/ancient-1"
mkdir -p "$TMPDIR/.claude/.session-state/ancient-2"
mkdir -p "$TMPDIR/.claude/.session-state/recent"
touch -d "10 days ago" "$TMPDIR/.claude/.session-state/ancient-1/started-at"
touch -d "30 days ago" "$TMPDIR/.claude/.session-state/ancient-2/started-at"
touch -d "2 days ago"  "$TMPDIR/.claude/.session-state/recent/started-at"

# Also touch the dirs themselves to match (find -mtime applies to whichever
# of the two `find` is configured to check; subdirs are usually checked by
# their own dir mtime). Touch the dirs to the same age.
touch -d "10 days ago" "$TMPDIR/.claude/.session-state/ancient-1"
touch -d "30 days ago" "$TMPDIR/.claude/.session-state/ancient-2"
touch -d "2 days ago"  "$TMPDIR/.claude/.session-state/recent"

# Run SessionStart with a new session_id
exit_code=0
printf '{"source":"startup","session_id":"fresh-session"}' | bash "$HOOK" >/dev/null 2>&1 || exit_code=$?

# Hook must succeed
if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: SessionStart exited %s (expected 0)\n' "$exit_code"
  exit 1
fi

# Ancient subdirs must be gone
if [ -e "$TMPDIR/.claude/.session-state/ancient-1" ]; then
  printf 'FAIL: ancient-1 (10d old) was not cleaned up\n'
  exit 1
fi
if [ -e "$TMPDIR/.claude/.session-state/ancient-2" ]; then
  printf 'FAIL: ancient-2 (30d old) was not cleaned up\n'
  exit 1
fi

# Recent subdir must survive
if [ ! -e "$TMPDIR/.claude/.session-state/recent" ]; then
  printf 'FAIL: recent (2d old) was incorrectly removed\n'
  exit 1
fi

# Fresh session subdir must be created
if [ ! -e "$TMPDIR/.claude/.session-state/fresh-session" ]; then
  printf 'FAIL: fresh-session subdir was not created\n'
  exit 1
fi

# Now test fail-open: make cleanup impossible (chmod 000 on the parent),
# verify hook still exits 0.
TMPDIR2="$(mktemp -d -t spec-017-V6b-XXXXXX)"
trap 'chmod -R u+rwx "$TMPDIR" "$TMPDIR2" 2>/dev/null || true; rm -rf "$TMPDIR" "$TMPDIR2"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR2"
mkdir -p "$TMPDIR2/.claude/.session-state/locked"
touch -d "10 days ago" "$TMPDIR2/.claude/.session-state/locked/started-at"
touch -d "10 days ago" "$TMPDIR2/.claude/.session-state/locked"
chmod 000 "$TMPDIR2/.claude/.session-state/locked" 2>/dev/null || true

exit_code2=0
printf '{"source":"startup","session_id":"sess-X"}' | bash "$HOOK" >/dev/null 2>&1 || exit_code2=$?

# Restore perms for trap cleanup
chmod 700 "$TMPDIR2/.claude/.session-state/locked" 2>/dev/null || true

if [ "$exit_code2" -ne 0 ]; then
  printf 'FAIL: SessionStart blocked due to cleanup failure (exit=%s) — expected fail-open\n' "$exit_code2"
  exit 1
fi

printf 'PASS\n'
exit 0
