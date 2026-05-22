#!/usr/bin/env bash
# .claude/tests/secrets-scan/07-template-portable.sh
# V7 — Scenario: fix is template-portable.
#
# Clones the Agent0 repo fresh into a temp dir, follows the per-fork checklist
# (git config core.hooksPath .githooks — the one new step), then runs a real
# git add + git commit sequence to confirm the secrets-scan gate is operative
# in a fork without any additional hook-copying.
#
# The native pre-commit hook is the durable portability layer: it lives in
# .githooks/ which is cloned along with the rest of the repo. The single
# install step (`git config core.hooksPath .githooks`) activates it.
#
# This test exercises the NATIVE HOOK ONLY (not the preflight). The preflight
# is a Claude Code harness hook; forks may not use Claude Code. Template
# portability means the native git hook works in any environment.
#
# Asserts:
#   (a) Clone succeeds and .githooks/pre-commit exists in the fork
#   (b) After `git config core.hooksPath .githooks`, git commit with a
#       secret-containing staged file is blocked (exit 1)
#   (c) Audit log in the fork has decision="block" + scan_mode="native-pre-commit"
#   (d) git log does NOT contain the blocked commit

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
AGENT0_GITLEAKS_TOML="$AGENT0_ROOT/.gitleaks.toml"

TMPDIR="$(mktemp -d -t spec-007-test-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

FORK_DIR="$TMPDIR/agent0-fork"

# Clone the Agent0 repo (local file:// clone — no network required).
git clone "$AGENT0_ROOT" "$FORK_DIR" -q

# (a) Assert .githooks/pre-commit exists in the fork.
if [ ! -f "$FORK_DIR/.githooks/pre-commit" ]; then
  printf 'FAIL: .githooks/pre-commit not present in cloned fork\n'
  exit 1
fi
if [ ! -x "$FORK_DIR/.githooks/pre-commit" ]; then
  printf 'FAIL: .githooks/pre-commit is not executable in cloned fork\n'
  exit 1
fi

# Per-fork checklist step: activate core.hooksPath (the one manual step).
cd "$FORK_DIR"
git config user.email "fork@example.com"
git config user.name "Fork Test"
git config core.hooksPath .githooks

# Copy .gitleaks.toml so detectors apply (already present via clone, but
# confirm by checking — it's checked into the repo, so it will be there).
if [ ! -f "$FORK_DIR/.gitleaks.toml" ]; then
  cp "$AGENT0_GITLEAKS_TOML" "$FORK_DIR/.gitleaks.toml"
fi

# Stage a file with the canonical test vector.
TEST_VECTOR="AKIA""1234567890ABCDEF"  # split literal so source does not trip regex scanners; runtime concat yields the canonical test vector
printf 'aws_access_key_id = %s\n' "$TEST_VECTOR" > fork-fixture.env
git add fork-fixture.env

# Run git commit — the native hook should block it.
commit_exit=0
commit_stderr_file="$TMPDIR/fork_commit_stderr.txt"
git commit -m "add key in fork" 2>"$commit_stderr_file" || commit_exit=$?

# (b) Assert exit 1 (native hook blocked it).
if [ "$commit_exit" -ne 1 ]; then
  printf 'FAIL: git commit exit=%d in fork, want 1 (should be blocked by native hook)\n' "$commit_exit"
  printf 'Stderr: %s\n' "$(cat "$commit_stderr_file")"
  exit 1
fi

# Assert stderr contains block message.
if ! grep -qF "secrets-scan: blocked" "$commit_stderr_file"; then
  printf 'FAIL: fork commit stderr missing "secrets-scan: blocked"\n'
  printf 'Got: %s\n' "$(cat "$commit_stderr_file")"
  exit 1
fi

# (c) Assert fork audit log entry.
FORK_AUDIT="$FORK_DIR/.claude/secrets-audit.jsonl"
if [ ! -f "$FORK_AUDIT" ]; then
  printf 'FAIL: audit log not created in fork at %s\n' "$FORK_AUDIT"
  exit 1
fi

matched="$(jq -c 'select(.decision == "block" and .scan_mode == "native-pre-commit")' "$FORK_AUDIT")"
if [ -z "$matched" ]; then
  printf 'FAIL: no fork audit line with decision=block + scan_mode=native-pre-commit\n'
  printf 'Fork audit log contents:\n'
  cat "$FORK_AUDIT"
  exit 1
fi

# (d) Assert git log does NOT contain the blocked commit.
if git log --oneline 2>/dev/null | grep -q "add key in fork"; then
  printf 'FAIL: blocked commit appeared in fork git log\n'
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
