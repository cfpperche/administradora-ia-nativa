#!/usr/bin/env bash
# .claude/tests/secrets-scan/01-compound-gated.sh
# V1 — Scenario: compound `git add && git commit` is gated correctly.
#
# The preflight hook (PreToolUse/Bash layer) receives the raw command string
# BEFORE bash executes it. When it sees `git add ... && git commit ...`, it
# recognises a compound-and shape and rejects with exit 2, so the commit
# never reaches git. This test exercises the preflight directly via synthetic
# stdin (no real git commit needed — the preflight short-circuits before the
# native hook runs).
#
# Asserts:
#   (a) preflight exits 2
#   (b) stderr contains the corrected separated-form template
#   (c) audit log gains one entry: decision="reject-shape", cmd_shape="compound-and"

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
AGENT0_GITHOOKS="$AGENT0_ROOT/.githooks"
AGENT0_PREFLIGHT="$AGENT0_ROOT/.claude/hooks/secrets-scan.sh"

TMPDIR="$(mktemp -d -t spec-007-test-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
git config core.hooksPath "$AGENT0_GITHOOKS"

# Fixture file containing the canonical test vector — written via variable
# so the literal string appears only in the fixture file, not in grep-visible
# strings inside this script.
TEST_VECTOR="AKIA""1234567890ABCDEF"  # split literal so source does not trip regex scanners; runtime concat yields the canonical test vector
printf 'aws_access_key_id = %s\n' "$TEST_VECTOR" > fixture.env

# The compound command the agent would have run (single Bash invocation).
COMPOUND_CMD='git add fixture.env && git commit -m "add fixture"'

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Invoke the preflight via synthetic stdin JSON (as Claude Code would).
stdin_json="$(printf '{"tool_input":{"command":"%s"}}' "$(printf '%s' "$COMPOUND_CMD" | sed 's/"/\\"/g')")"

stderr_file="$TMPDIR/stderr.txt"
preflight_exit=0
printf '%s' "$stdin_json" | bash "$AGENT0_PREFLIGHT" 2>"$stderr_file" || preflight_exit=$?

# (a) Assert exit code 2
if [ "$preflight_exit" -ne 2 ]; then
  printf 'FAIL: preflight exit=%d, want 2\n' "$preflight_exit"
  exit 1
fi

# (b) Assert stderr contains the corrected separated-form template
stderr_content="$(cat "$stderr_file")"
if ! printf '%s' "$stderr_content" | grep -qF "Run as two separate Bash invocations instead:"; then
  printf 'FAIL: stderr missing "Run as two separate Bash invocations instead:"\n'
  printf 'Got: %s\n' "$stderr_content"
  exit 1
fi

# (c) Assert audit-log entry
AUDIT_LOG="$TMPDIR/.claude/secrets-audit.jsonl"
if [ ! -f "$AUDIT_LOG" ]; then
  printf 'FAIL: audit log not created at %s\n' "$AUDIT_LOG"
  exit 1
fi

matched="$(jq -c 'select(.decision == "reject-shape" and .cmd_shape == "compound-and" and .scan_mode == "preflight")' "$AUDIT_LOG")"
if [ -z "$matched" ]; then
  printf 'FAIL: no audit line with decision=reject-shape + cmd_shape=compound-and\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
