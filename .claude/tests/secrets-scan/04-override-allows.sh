#!/usr/bin/env bash
# .claude/tests/secrets-scan/04-override-allows.sh
# V4 — Scenario: override marker preserves spec 006 semantics, end-to-end.
#
# A two-line Bash command string — line 1 is the compound invocation,
# line 2 is the override marker on its own line (start-of-line anchor).
# The preflight parses the marker, rewrites the command to prepend an
# `export CLAUDE_SECRETS_OVERRIDE_REASON='...'; ` statement, exits 0 with
# the rewritten command in hookSpecificOutput.updatedInput JSON. The harness
# then executes the rewritten command in a bash shell. Because `export` is a
# standalone statement (followed by `;`), the env var is inherited by every
# subsequent command in the chain — both `git add` AND `git commit`. The
# native hook running as git's pre-commit subprocess reads the env var and
# audits as "override".
#
# This test exercises the REAL production path: it feeds the preflight's
# rewritten command back through `bash -c` (mimicking what the harness
# does on updatedInput) instead of bypassing the rewriting and exporting
# the env var manually. If the preflight ever regresses to the prefix
# form `VAR=val cmd1 && cmd2`, this test fails because the env var would
# NOT propagate to the chained git commit and the native hook would block.
#
# Asserts:
#   (a) preflight exits 0 and emits JSON with hookSpecificOutput.updatedInput
#       whose command starts with `export CLAUDE_SECRETS_OVERRIDE_REASON='...'`
#   (b) preflight audit has decision="override-pass-through" + override_reason set
#   (c) executing the rewritten command via `bash -c` reaches the native hook
#       with the env var visible, native hook audits decision="override" +
#       finding_count>=1 + override_reason set
#   (d) git commit lands in git log (override allows it through both layers)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
AGENT0_GITHOOKS="$AGENT0_ROOT/.githooks"
AGENT0_PREFLIGHT="$AGENT0_ROOT/.claude/hooks/secrets-scan.sh"
AGENT0_GITLEAKS_TOML="$AGENT0_ROOT/.gitleaks.toml"

TMPDIR="$(mktemp -d -t spec-007-test-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
git config core.hooksPath "$AGENT0_GITHOOKS"

# Copy .gitleaks.toml so detectors apply.
cp "$AGENT0_GITLEAKS_TOML" "$TMPDIR/.gitleaks.toml"

# Fixture file with the canonical test vector.
TEST_VECTOR="AKIA""1234567890ABCDEF"  # split literal so source does not trip regex scanners; runtime concat yields the canonical test vector
printf 'aws_access_key_id = %s\n' "$TEST_VECTOR" > fixture.env

export CLAUDE_PROJECT_DIR="$TMPDIR"

# Two-line command: line 1 is the compound invocation, line 2 is the marker.
# bash treats the second line as a comment (no-op) when it actually runs the
# command; the preflight sees it as start-of-line text and matches.
REASON="documentation test vector for spec 007"
# Build a JSON string with an embedded newline. jq -Rs reads it as-is.
CMD_LINE1='git add fixture.env && git commit -m "add test vector"'
CMD_LINE2="# OVERRIDE: ${REASON}"
COMPOUND_CMD="${CMD_LINE1}
${CMD_LINE2}"

# Build the JSON payload — use jq to embed the multi-line command safely.
stdin_json="$(jq -cn --arg cmd "$COMPOUND_CMD" '{"tool_input":{"command":$cmd}}')"

# (a) Run the preflight — capture stdout (JSON) and stderr.
stdout_file="$TMPDIR/preflight_stdout.txt"
stderr_file="$TMPDIR/preflight_stderr.txt"
preflight_exit=0
printf '%s' "$stdin_json" | bash "$AGENT0_PREFLIGHT" >"$stdout_file" 2>"$stderr_file" || preflight_exit=$?

if [ "$preflight_exit" -ne 0 ]; then
  printf 'FAIL: preflight exit=%d, want 0\n' "$preflight_exit"
  printf 'Stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

# Verify preflight emitted hookSpecificOutput JSON.
rewritten_cmd="$(jq -r '.hookSpecificOutput.updatedInput.command // ""' "$stdout_file" 2>/dev/null || true)"
if [ -z "$rewritten_cmd" ]; then
  printf 'FAIL: preflight did not emit hookSpecificOutput.updatedInput.command\n'
  printf 'Preflight stdout: %s\n' "$(cat "$stdout_file")"
  exit 1
fi

# Verify the rewriting uses the STANDALONE export form (not the inline prefix).
# The prefix form `VAR=val cmd` does NOT propagate the var to `&&`-chained
# commands; the standalone form `export VAR=val; cmd` does. If the preflight
# regresses to the prefix form, this assertion catches it.
case "$rewritten_cmd" in
  "export CLAUDE_SECRETS_OVERRIDE_REASON="*)
    : # ok
    ;;
  *)
    printf 'FAIL: preflight rewriting must start with `export CLAUDE_SECRETS_OVERRIDE_REASON=` (standalone statement form), got: %s\n' "$rewritten_cmd"
    exit 1
    ;;
esac

# (b) Assert preflight audit has override-pass-through + reason.
AUDIT_LOG="$TMPDIR/.claude/secrets-audit.jsonl"
if [ ! -f "$AUDIT_LOG" ]; then
  printf 'FAIL: preflight audit log not created\n'
  exit 1
fi

preflight_matched="$(jq -c 'select(.decision == "override-pass-through" and .scan_mode == "preflight" and (.override_reason != null))' "$AUDIT_LOG")"
if [ -z "$preflight_matched" ]; then
  printf 'FAIL: no preflight audit line with decision=override-pass-through\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

# (c) Execute the rewritten command via `bash -c`, mimicking what Claude Code's
# harness does when it receives hookSpecificOutput.updatedInput. The rewriting
# itself must propagate the env var across the `&& git commit` chain — we do NOT
# pre-export the env var here. If the preflight regresses to the prefix form
# `VAR=val cmd1 && cmd2`, the second command does NOT inherit the var, the
# native hook does not see CLAUDE_SECRETS_OVERRIDE_REASON, and the commit is
# blocked. This test catches that regression.
commit_exit=0
commit_stderr_file="$TMPDIR/commit_stderr.txt"

bash -c "$rewritten_cmd" 2>"$commit_stderr_file" || commit_exit=$?

if [ "$commit_exit" -ne 0 ]; then
  printf 'FAIL: git commit exit=%d after override, want 0\n' "$commit_exit"
  printf 'Commit stderr: %s\n' "$(cat "$commit_stderr_file")"
  exit 1
fi

# Assert native audit has decision="override" + finding_count>=1.
native_matched="$(jq -c 'select(.decision == "override" and .scan_mode == "native-pre-commit" and .finding_count >= 1 and (.override_reason != null))' "$AUDIT_LOG")"
if [ -z "$native_matched" ]; then
  printf 'FAIL: no native audit line with decision=override + finding_count>=1\n'
  printf 'Audit log contents:\n'
  cat "$AUDIT_LOG"
  exit 1
fi

# (d) Assert commit landed in git log.
if ! git log --oneline | grep -q "add test vector"; then
  printf 'FAIL: commit not found in git log after override\n'
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
