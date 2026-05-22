#!/usr/bin/env bash
# .claude/tests/runtime-introspect/15-cargo-skip-non-detect.sh
# V15 — Scenario H: non-verifier cargo verbs skip silently. Spec 022.
#
# Asserts that cargo invocations OUTSIDE the v1 verifier allowlist
# (cargo run / doc / publish / bench / fmt / update / install) do NOT
# produce a state-file write and the hook exits 0.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-022-V15-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

run_skip_case() {
  local label="$1"
  local cmd="$2"

  local stdin_json hook_exit
  stdin_json="$(jq -cn --arg c "$cmd" '{
    tool_name: "Bash",
    tool_input: {command: $c},
    tool_response: {stdout: "ok\n", stderr: "", interrupted: false, isImage: false, noOutputExpected: false},
    session_id: "V15-session",
    tool_use_id: "tool-use-V15"
  }')"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi

  if [ -f "$TMPDIR/.claude/.runtime-state/last-run.json" ]; then
    printf 'FAIL [%s]: last-run.json was written for non-verifier cargo command\n' "$label"
    cat "$TMPDIR/.claude/.runtime-state/last-run.json"
    exit 1
  fi
}

run_skip_case "cargo run"           "cargo run"
run_skip_case "cargo run --bin foo" "cargo run --bin foo"
run_skip_case "cargo doc"           "cargo doc --no-deps"
run_skip_case "cargo publish"       "cargo publish --dry-run"
run_skip_case "cargo bench"         "cargo bench"
run_skip_case "cargo fmt"           "cargo fmt"
run_skip_case "cargo update"        "cargo update"
run_skip_case "cargo install x"     "cargo install ripgrep"

printf 'PASS\n'
exit 0
