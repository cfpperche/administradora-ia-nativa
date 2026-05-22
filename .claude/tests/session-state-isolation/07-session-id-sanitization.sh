#!/usr/bin/env bash
# .claude/tests/session-state-isolation/07-session-id-sanitization.sh
# Spec 017 V7 — Scenario: malicious or malformed session_id values fall to
# "unknown" subdir — no path traversal, no special-char filenames.
#
# Defense for Q4 resolution: regex ^[a-zA-Z0-9_-]+$ only. Anything outside
# the allowed alphabet falls to the "unknown" subdir.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

assert_unknown() {
  local label="$1" TMPDIR="$2"
  if [ ! -f "$TMPDIR/.claude/.session-state/unknown/started-at" ]; then
    printf 'FAIL [%s]: unknown/started-at not created — sanitization fallback missing\n' "$label"
    printf 'Tree:\n'
    find "$TMPDIR/.claude/.session-state" -print 2>/dev/null || true
    exit 1
  fi
}

assert_no_escape() {
  local label="$1" TMPDIR="$2"
  # Nothing should exist OUTSIDE .claude/.session-state/ under TMPDIR that
  # the hook could have created
  if [ -e "$TMPDIR/escape-marker" ]; then
    printf 'FAIL [%s]: path traversal created file outside .session-state/\n' "$label"
    exit 1
  fi
  # The .session-state/ dir should NOT contain anything starting with "..".
  if find "$TMPDIR/.claude/.session-state" -name '..*' -mindepth 1 2>/dev/null | grep -q .; then
    printf 'FAIL [%s]: found suspicious dotdot entries under .session-state/\n' "$label"
    exit 1
  fi
}

# Variant A: path traversal attempt
TMPDIR_A="$(mktemp -d -t spec-017-V7A-XXXXXX)"
trap 'rm -rf "$TMPDIR_A"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR_A"
printf '{"source":"startup","session_id":"../escape-marker"}' | bash "$HOOK" >/dev/null 2>&1
assert_unknown "path-traversal" "$TMPDIR_A"
assert_no_escape "path-traversal" "$TMPDIR_A"
rm -rf "$TMPDIR_A"
trap - EXIT

# Variant B: slash in middle
TMPDIR_B="$(mktemp -d -t spec-017-V7B-XXXXXX)"
trap 'rm -rf "$TMPDIR_B"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR_B"
printf '{"source":"startup","session_id":"foo/bar"}' | bash "$HOOK" >/dev/null 2>&1
assert_unknown "embedded-slash" "$TMPDIR_B"
# Specifically: foo/bar must not have been created
if [ -e "$TMPDIR_B/.claude/.session-state/foo/bar/started-at" ]; then
  printf 'FAIL [embedded-slash]: foo/bar/started-at created — sanitization missing\n'
  exit 1
fi
rm -rf "$TMPDIR_B"
trap - EXIT

# Variant C: special chars
TMPDIR_C="$(mktemp -d -t spec-017-V7C-XXXXXX)"
trap 'rm -rf "$TMPDIR_C"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR_C"
printf '{"source":"startup","session_id":"abc;rm -rf;def"}' | bash "$HOOK" >/dev/null 2>&1
assert_unknown "shell-meta" "$TMPDIR_C"
rm -rf "$TMPDIR_C"
trap - EXIT

# Variant D: spaces
TMPDIR_D="$(mktemp -d -t spec-017-V7D-XXXXXX)"
trap 'rm -rf "$TMPDIR_D"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR_D"
printf '{"source":"startup","session_id":"foo bar baz"}' | bash "$HOOK" >/dev/null 2>&1
assert_unknown "spaces" "$TMPDIR_D"
rm -rf "$TMPDIR_D"
trap - EXIT

# Variant E: legitimate UUID-style id should pass through (positive control)
TMPDIR_E="$(mktemp -d -t spec-017-V7E-XXXXXX)"
trap 'rm -rf "$TMPDIR_E"' EXIT
export CLAUDE_PROJECT_DIR="$TMPDIR_E"
uuid="abc123-DEF456_ghi789"
printf '{"source":"startup","session_id":"%s"}' "$uuid" | bash "$HOOK" >/dev/null 2>&1
if [ ! -f "$TMPDIR_E/.claude/.session-state/$uuid/started-at" ]; then
  printf 'FAIL [legitimate-uuid]: started-at not created for valid id "%s"\n' "$uuid"
  exit 1
fi
if [ -f "$TMPDIR_E/.claude/.session-state/unknown/started-at" ]; then
  printf 'FAIL [legitimate-uuid]: fell to unknown despite valid id\n'
  exit 1
fi
rm -rf "$TMPDIR_E"
trap - EXIT

printf 'PASS\n'
exit 0
