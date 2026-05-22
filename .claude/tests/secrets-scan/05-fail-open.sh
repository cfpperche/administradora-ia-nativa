#!/usr/bin/env bash
# .claude/tests/secrets-scan/05-fail-open.sh
# V5 — Scenario: fail-open behavior when gitleaks is absent.
#
# APPROACH: The gitleaks binary must be invisible to the native pre-commit
# hook WITHOUT deleting the user's actual binary. We achieve this by running
# the commit inside a subshell launched with a stripped PATH that contains
# only the system basics (/usr/bin:/bin) — no ~/.local/bin or any other
# directory where the real gitleaks lives. The native hook's `command -v
# gitleaks` then fails, triggering the skip-no-engine path.
#
# The preflight hook (invoked via synthetic stdin) receives the same stripped
# PATH context — but shape-detection is path-independent, so it passes through.
# Then git commit runs under the stripped PATH (no gitleaks), the native hook
# exits 0 with a stderr warning, and the commit proceeds.
#
# Asserts:
#   (a) git commit exits 0 (fail-open: commit proceeds when gitleaks absent)
#   (b) native hook emits one stderr warning mentioning gitleaks not found
#   (c) audit log gains entry: decision="skip-no-engine", scan_mode="native-pre-commit"

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

# Copy .gitleaks.toml (not strictly needed since gitleaks won't run, but keeps env realistic).
cp "$AGENT0_GITLEAKS_TOML" "$TMPDIR/.gitleaks.toml"

# Stage a clean file (no secret needed — this test is about gitleaks absence,
# not about finding detection).
printf 'clean content\n' > cleanfile.txt
git add cleanfile.txt

# Run git commit inside a subshell with a minimal PATH that excludes gitleaks.
# HOME is preserved so git can read user config; TMPDIR is the repo dir.
# jq must remain available for the native hook's audit helper — keep its dir.
JQ_DIR="$(dirname "$(command -v jq)")"

# Build a PATH that has basic tools + jq but NOT gitleaks.
# We exclude ~/.local/bin (where gitleaks is installed per `which gitleaks`).
BARE_PATH="/usr/bin:/bin"
if [ "$JQ_DIR" != "/usr/bin" ] && [ "$JQ_DIR" != "/bin" ]; then
  BARE_PATH="$JQ_DIR:$BARE_PATH"
fi

commit_exit=0
commit_output_file="$TMPDIR/commit_output.txt"

# Run git commit via env -i to strip the env, then rebuild minimal vars.
# We pass through HOME (git user config), TMPDIR is already set, and the
# git repo is our cwd. The hook reads AUDIT_LOG from the git toplevel.
env -i \
  PATH="$BARE_PATH" \
  HOME="$HOME" \
  GIT_AUTHOR_NAME="Test" \
  GIT_AUTHOR_EMAIL="test@example.com" \
  GIT_COMMITTER_NAME="Test" \
  GIT_COMMITTER_EMAIL="test@example.com" \
  bash -c "cd '$TMPDIR' && git commit -m 'clean commit without gitleaks'" \
  >"$commit_output_file" 2>&1 || commit_exit=$?

output_content="$(cat "$commit_output_file")"

# (a) Assert exit 0 (fail-open)
if [ "$commit_exit" -ne 0 ]; then
  printf 'FAIL: git commit exit=%d, want 0 (fail-open on missing gitleaks)\n' "$commit_exit"
  printf 'Output: %s\n' "$output_content"
  exit 1
fi

# (b) Assert stderr warning about gitleaks not found
if ! printf '%s' "$output_content" | grep -qF "gitleaks not found"; then
  printf 'FAIL: output missing "gitleaks not found" warning\n'
  printf 'Got: %s\n' "$output_content"
  exit 1
fi

# (c) Assert audit-log entry
AUDIT_LOG="$TMPDIR/.claude/secrets-audit.jsonl"
if [ ! -f "$AUDIT_LOG" ]; then
  printf 'FAIL: audit log not created at %s\n' "$AUDIT_LOG"
  exit 1
fi

matched="$(jq -c 'select(.decision == "skip-no-engine" and .scan_mode == "native-pre-commit")' "$AUDIT_LOG")"
if [ -z "$matched" ]; then
  printf 'FAIL: no audit line with decision=skip-no-engine, scan_mode=native-pre-commit\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
