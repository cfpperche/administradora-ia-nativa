#!/usr/bin/env bash
# .claude/tests/session-state-isolation/05-missing-session-id-fallback.sh
# Spec 017 V5 — Scenario: payload without session_id falls to "unknown" subdir.
#
# When the hook payload lacks .session_id (or is null/empty), the hook must
# operate against <.session-state>/unknown/ deterministically — no crash, no
# path traversal, no fallback to legacy root layout.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
START_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/session-stop.sh"

assert_unknown_subdir() {
  local tag="$1" TMPDIR="$2"
  if [ ! -f "$TMPDIR/.claude/.session-state/unknown/started-at" ]; then
    printf 'FAIL [%s]: unknown/started-at not created\n' "$tag"
    printf 'Tree:\n'
    find "$TMPDIR/.claude/.session-state" -print 2>/dev/null || true
    exit 1
  fi
  # Legacy root file must NOT be created
  if [ -f "$TMPDIR/.claude/.session-state/started-at" ]; then
    printf 'FAIL [%s]: legacy root started-at was created instead of unknown/started-at\n' "$tag"
    exit 1
  fi
}

# Variant A: payload with no session_id field at all
TMPDIR_A="$(mktemp -d -t spec-017-V5A-XXXXXX)"
export CLAUDE_PROJECT_DIR="$TMPDIR_A"
printf '{"source":"startup"}' | bash "$START_HOOK" >/dev/null 2>&1
assert_unknown_subdir "no-field" "$TMPDIR_A"
rm -rf "$TMPDIR_A"

# Variant B: payload with session_id: null
TMPDIR_B="$(mktemp -d -t spec-017-V5B-XXXXXX)"
export CLAUDE_PROJECT_DIR="$TMPDIR_B"
printf '{"source":"startup","session_id":null}' | bash "$START_HOOK" >/dev/null 2>&1
assert_unknown_subdir "null-id" "$TMPDIR_B"
rm -rf "$TMPDIR_B"

# Variant C: payload with empty-string session_id
TMPDIR_C="$(mktemp -d -t spec-017-V5C-XXXXXX)"
export CLAUDE_PROJECT_DIR="$TMPDIR_C"
printf '{"source":"startup","session_id":""}' | bash "$START_HOOK" >/dev/null 2>&1
assert_unknown_subdir "empty-string" "$TMPDIR_C"
rm -rf "$TMPDIR_C"

# Variant D: completely empty stdin
TMPDIR_D="$(mktemp -d -t spec-017-V5D-XXXXXX)"
export CLAUDE_PROJECT_DIR="$TMPDIR_D"
printf '' | bash "$START_HOOK" >/dev/null 2>&1
assert_unknown_subdir "empty-stdin" "$TMPDIR_D"
rm -rf "$TMPDIR_D"

printf 'PASS\n'
exit 0
