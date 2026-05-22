#!/usr/bin/env bash
# .claude/tests/secrets-scan/03-a-flag-gated.sh
# V3 — Scenario: `git commit -a` (auto-stage tracked) is gated by preflight.
#
# The preflight hook detects `-a` in `git commit -a -m "..."` as the
# git-commit-dash-a shape and rejects with exit 2 before git runs.
# This prevents the -a flag's auto-staging from bypassing the native
# pre-commit hook's staged-index scan.
#
# Asserts:
#   (a) preflight exits 2
#   (b) stderr contains the `git add -u` workaround template
#   (c) audit log gains entry: decision="reject-shape", cmd_shape="git-commit-dash-a"

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

# Write a tracked file (needs to exist in a prior commit to be auto-staged).
printf 'placeholder\n' > tracked.txt
git add tracked.txt
git commit -m "initial commit" --no-verify

# Now modify the tracked file in-place (adding the secret) — no git add.
TEST_VECTOR="AKIA""1234567890ABCDEF"  # split literal so source does not trip regex scanners; runtime concat yields the canonical test vector
printf 'aws_access_key_id = %s\n' "$TEST_VECTOR" >> tracked.txt

# The command the agent would try: git commit -a -m "..."
COMMIT_A_CMD='git commit -a -m "add key to tracked file"'

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Invoke the preflight with synthetic stdin (as Claude Code would).
stdin_json="$(printf '{"tool_input":{"command":"%s"}}' "$(printf '%s' "$COMMIT_A_CMD" | sed 's/"/\\"/g')")"

stderr_file="$TMPDIR/stderr.txt"
preflight_exit=0
printf '%s' "$stdin_json" | bash "$AGENT0_PREFLIGHT" 2>"$stderr_file" || preflight_exit=$?

# (a) Assert exit 2
if [ "$preflight_exit" -ne 2 ]; then
  printf 'FAIL: preflight exit=%d, want 2\n' "$preflight_exit"
  exit 1
fi

# (b) Assert stderr contains the git add -u workaround
stderr_content="$(cat "$stderr_file")"
if ! printf '%s' "$stderr_content" | grep -qF "git add -u"; then
  printf 'FAIL: stderr missing "git add -u"\n'
  printf 'Got: %s\n' "$stderr_content"
  exit 1
fi

# (c) Assert audit-log entry
AUDIT_LOG="$TMPDIR/.claude/secrets-audit.jsonl"
if [ ! -f "$AUDIT_LOG" ]; then
  printf 'FAIL: audit log not created at %s\n' "$AUDIT_LOG"
  exit 1
fi

matched="$(jq -c 'select(.decision == "reject-shape" and .cmd_shape == "git-commit-dash-a" and .scan_mode == "preflight")' "$AUDIT_LOG")"
if [ -z "$matched" ]; then
  printf 'FAIL: no audit line with decision=reject-shape + cmd_shape=git-commit-dash-a\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
