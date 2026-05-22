#!/usr/bin/env bash
# .claude/tests/secrets-scan/06-audit-distinguishes-incomplete.sh
# V6 — Scenario: audit distinguishes incomplete-scan from real-allow.
#
# The spec-006 buggy path produced decision="allow" + finding_count=0 for
# compound commands that staged nothing before the commit ran. The spec-007
# fix distinguishes three cases:
#
#   decision="allow-empty" + staged_files_count=0  → empty diff commit
#   decision="allow"       + finding_count=0 + staged_files_count>=1  → real clean commit
#
# This test exercises both shapes in the same repo so the two are directly
# comparable side-by-side in the audit log.
#
# Asserts:
#   (a) `git commit --allow-empty` produces decision="allow-empty" + staged_files_count=0
#   (b) real commit with clean file produces decision="allow" + finding_count=0 + staged_files_count>=1
#   (c) the two entries are distinguishable by decision value (NOT both "allow")

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

# Copy .gitleaks.toml so detectors apply correctly.
cp "$AGENT0_GITLEAKS_TOML" "$TMPDIR/.gitleaks.toml"

AUDIT_LOG="$TMPDIR/.claude/secrets-audit.jsonl"

# --- Part A: allow-empty commit ---
commit_exit=0
git commit --allow-empty -m "empty commit" 2>/dev/null || commit_exit=$?

if [ "$commit_exit" -ne 0 ]; then
  printf 'FAIL: git commit --allow-empty exit=%d, want 0\n' "$commit_exit"
  exit 1
fi

# Assert audit entry for allow-empty
if [ ! -f "$AUDIT_LOG" ]; then
  printf 'FAIL: audit log not created after allow-empty commit\n'
  exit 1
fi

allow_empty_entry="$(jq -c 'select(.decision == "allow-empty" and .scan_mode == "native-pre-commit" and .staged_files_count == 0)' "$AUDIT_LOG")"
if [ -z "$allow_empty_entry" ]; then
  printf 'FAIL: no audit line with decision=allow-empty + staged_files_count=0\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

# --- Part B: real clean commit ---
printf 'clean content\n' > cleanfile.txt
git add cleanfile.txt

commit_exit=0
git commit -m "real clean commit" 2>/dev/null || commit_exit=$?

if [ "$commit_exit" -ne 0 ]; then
  printf 'FAIL: real clean commit exit=%d, want 0\n' "$commit_exit"
  exit 1
fi

real_allow_entry="$(jq -c 'select(.decision == "allow" and .scan_mode == "native-pre-commit" and .finding_count == 0 and .staged_files_count >= 1)' "$AUDIT_LOG")"
if [ -z "$real_allow_entry" ]; then
  printf 'FAIL: no audit line with decision=allow + finding_count=0 + staged_files_count>=1\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

# (c) Confirm the two are distinguishable: one "allow-empty", one "allow"
allow_empty_count="$(jq 'select(.decision == "allow-empty")' "$AUDIT_LOG" | jq -s 'length')"
real_allow_count="$(jq 'select(.decision == "allow")' "$AUDIT_LOG" | jq -s 'length')"

if [ "$allow_empty_count" -lt 1 ] || [ "$real_allow_count" -lt 1 ]; then
  printf 'FAIL: did not get both allow-empty and allow entries\n'
  printf 'allow-empty count: %s, allow count: %s\n' "$allow_empty_count" "$real_allow_count"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
