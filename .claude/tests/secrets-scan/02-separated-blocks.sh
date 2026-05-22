#!/usr/bin/env bash
# .claude/tests/secrets-scan/02-separated-blocks.sh
# V2 — Scenario: separate `git add` then `git commit` still blocks on secret.
#
# When the agent runs git add in one Bash call and git commit in a separate
# Bash call, the preflight passes through (shape is clean), and the native
# pre-commit hook runs gitleaks against the real staged index and finds the
# secret, blocking exit 1.
#
# Asserts:
#   (a) git commit exits 1 (blocked by native pre-commit hook)
#   (b) stderr contains "secrets-scan: blocked"
#   (c) native audit log gains entry: decision="block", finding_count=1,
#       staged_files_count=1, scan_mode="native-pre-commit"
#   (d) git log does NOT contain the new commit

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
AGENT0_GITHOOKS="$AGENT0_ROOT/.githooks"
AGENT0_GITLEAKS_TOML="$AGENT0_ROOT/.gitleaks.toml"

TMPDIR="$(mktemp -d -t spec-007-test-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
git config core.hooksPath "$AGENT0_GITHOOKS"

# Copy .gitleaks.toml so detector rules apply (tests run in /tmp, not Agent0).
cp "$AGENT0_GITLEAKS_TOML" "$TMPDIR/.gitleaks.toml"

# Write fixture with the canonical test vector.
TEST_VECTOR="AKIA""1234567890ABCDEF"  # split literal so source does not trip regex scanners; runtime concat yields the canonical test vector
printf 'aws_access_key_id = %s\n' "$TEST_VECTOR" > fixture.env

# Step 1: git add (a separate Bash invocation — this would be a different
# tool call in Claude Code; we simulate by running it directly).
git add fixture.env

# Step 2: git commit — the native pre-commit hook will run gitleaks.
commit_exit=0
stderr_file="$TMPDIR/commit_stderr.txt"
git commit -m "add fixture with key" 2>"$stderr_file" || commit_exit=$?

# (a) Assert exit 1 (native git hook convention, not exit 2)
if [ "$commit_exit" -ne 1 ]; then
  printf 'FAIL: git commit exit=%d, want 1\n' "$commit_exit"
  printf 'Stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (b) Assert stderr contains block message
stderr_content="$(cat "$stderr_file")"
if ! printf '%s' "$stderr_content" | grep -qF "secrets-scan: blocked"; then
  printf 'FAIL: stderr missing "secrets-scan: blocked"\n'
  printf 'Got: %s\n' "$stderr_content"
  exit 1
fi

# (c) Assert native audit-log entry
AUDIT_LOG="$TMPDIR/.claude/secrets-audit.jsonl"
if [ ! -f "$AUDIT_LOG" ]; then
  printf 'FAIL: audit log not created at %s\n' "$AUDIT_LOG"
  exit 1
fi

matched="$(jq -c 'select(.decision == "block" and .scan_mode == "native-pre-commit" and .finding_count >= 1 and .staged_files_count >= 1)' "$AUDIT_LOG")"
if [ -z "$matched" ]; then
  printf 'FAIL: no audit line with decision=block, scan_mode=native-pre-commit, finding_count>=1\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

# (d) Assert git log does NOT contain the commit
if git log --oneline 2>/dev/null | grep -q "add fixture with key"; then
  printf 'FAIL: commit landed in git log but should have been blocked\n'
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
