#!/usr/bin/env bash
# .claude/tests/session-edit-attribution/01-tracker-appends.sh
# Spec 030 — Scenario 1: tracker appends + deduplicates + fails-open.
#
# Given a fake CLAUDE_PROJECT_DIR with the tracker hook installed, when a
# PostToolUse(Edit) payload is piped in, then edited-files.txt must contain
# the file_path (relative-to-project, deduped on repeat, fail-open on bad
# payloads).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TRACK_HOOK="$AGENT0_ROOT/.claude/hooks/session-track-edits.sh"

TMPDIR="$(mktemp -d -t spec-030-01-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

SESSION_ID="test-tracker-01"
TRACK_FILE="$TMPDIR/.claude/.session-state/$SESSION_ID/edited-files.txt"

# --- Case A: simple append ---
payload_a='{"session_id":"'"$SESSION_ID"'","tool_input":{"file_path":"foo.ts"}}'
printf '%s' "$payload_a" | bash "$TRACK_HOOK"

if [ ! -f "$TRACK_FILE" ]; then
  printf 'FAIL: edited-files.txt not created at %s\n' "$TRACK_FILE"
  exit 1
fi

if ! grep -Fxq 'foo.ts' "$TRACK_FILE"; then
  printf 'FAIL: edited-files.txt missing foo.ts\n'
  printf 'content:\n'
  cat "$TRACK_FILE"
  exit 1
fi

# --- Case B: dedup on second identical call ---
printf '%s' "$payload_a" | bash "$TRACK_HOOK"
count_a="$(grep -Fxc 'foo.ts' "$TRACK_FILE" || true)"
if [ "$count_a" != "1" ]; then
  printf 'FAIL: dedup broken — foo.ts appears %s times (expected 1)\n' "$count_a"
  exit 1
fi

# --- Case C: distinct second path ---
payload_b='{"session_id":"'"$SESSION_ID"'","tool_input":{"file_path":"bar/baz.md"}}'
printf '%s' "$payload_b" | bash "$TRACK_HOOK"
if ! grep -Fxq 'bar/baz.md' "$TRACK_FILE"; then
  printf 'FAIL: second path bar/baz.md not appended\n'
  exit 1
fi

# --- Case D: empty stdin — fail open, no crash, no new lines ---
lines_before="$(wc -l <"$TRACK_FILE")"
printf '' | bash "$TRACK_HOOK"
exit_d=$?
if [ "$exit_d" -ne 0 ]; then
  printf 'FAIL: hook exit non-zero on empty stdin (expected fail-open)\n'
  exit 1
fi
lines_after="$(wc -l <"$TRACK_FILE")"
if [ "$lines_before" != "$lines_after" ]; then
  printf 'FAIL: empty stdin changed file contents (before=%s after=%s)\n' "$lines_before" "$lines_after"
  exit 1
fi

# --- Case E: missing file_path — exit 0, no append ---
payload_e='{"session_id":"'"$SESSION_ID"'"}'
printf '%s' "$payload_e" | bash "$TRACK_HOOK"
lines_e="$(wc -l <"$TRACK_FILE")"
if [ "$lines_e" != "$lines_after" ]; then
  printf 'FAIL: payload without file_path caused append (before=%s after=%s)\n' "$lines_after" "$lines_e"
  exit 1
fi

# --- Case F: malformed session_id falls to "unknown" subdir ---
payload_f='{"session_id":"../etc/passwd","tool_input":{"file_path":"x.ts"}}'
printf '%s' "$payload_f" | bash "$TRACK_HOOK"
if [ ! -f "$TMPDIR/.claude/.session-state/unknown/edited-files.txt" ]; then
  printf 'FAIL: malformed session_id did not fall to "unknown" subdir\n'
  exit 1
fi
if [ -e "$TMPDIR/.claude/.session-state/../etc/passwd" ]; then
  printf 'FAIL: path-traversal sanitization breached\n'
  exit 1
fi

printf 'PASS\n'
exit 0
