#!/usr/bin/env bash
# .claude/tests/runtime-introspect/13-cargo-test-capture.sh
# V13 — Scenarios A + B: cargo test capture under PostToolUse (success)
# and PostToolUseFailure (failure). Spec 022.
#
# Asserts:
#   (A) `cargo test` with `test result: ok` in output → detector=cargo-test,
#       inferred_status=PASS, inference_basis names the 'test result: ok' line.
#   (B) `cargo test --test spec022_dogfood` under PostToolUseFailure shape,
#       with `test result: FAILED` in error body → detector=cargo-test,
#       inferred_status=FAIL, inference_basis names the FAILED line,
#       stderr_head contains the failure body.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-022-V13-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"

# ----- Sub-case A: passing cargo test under PostToolUse -----
stdout_a='
running 4 tests
test tests::shorten_resolve_roundtrip ... ok
test tests::idempotent_shorten ... ok
test tests::missing_resolve_returns_none ... ok
test tests::all_chars_safe ... ok

test result: ok. 4 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

'
stderr_a='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 0.12s
     Running unittests src/lib.rs (target/debug/deps/rshrnk-abc)
     Running tests/shortener.rs (target/debug/deps/shortener-def)
'

stdin_a="$(jq -cn \
  --arg c "cargo test" \
  --arg out "$stdout_a" \
  --arg err "$stderr_a" \
  '{
    tool_name: "Bash",
    tool_input: {command: $c},
    tool_response: {stdout: $out, stderr: $err, interrupted: false, isImage: false, noOutputExpected: false},
    session_id: "V13-session",
    tool_use_id: "tool-use-V13-A"
  }')"

hook_exit=0
printf '%s' "$stdin_a" | bash "$HOOK" || hook_exit=$?
if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [A passing cargo test]: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi
if [ ! -f "$state_file" ]; then
  printf 'FAIL [A passing cargo test]: last-run.json not created\n'
  exit 1
fi
detector="$(jq -r '.detector' "$state_file")"
status="$(jq -r '.inferred_status' "$state_file")"
basis="$(jq -r '.inference_basis' "$state_file")"
if [ "$detector" != "cargo-test" ]; then
  printf 'FAIL [A]: detector=%s, want cargo-test\n' "$detector"
  cat "$state_file"
  exit 1
fi
if [ "$status" != "PASS" ]; then
  printf 'FAIL [A]: inferred_status=%s, want PASS\n' "$status"
  printf 'inference_basis: %s\n' "$basis"
  cat "$state_file"
  exit 1
fi
if ! printf '%s' "$basis" | grep -q "test result: ok"; then
  printf 'FAIL [A]: inference_basis missing 'test result: ok' fragment, got: %s\n' "$basis"
  exit 1
fi

rm -f "$state_file"

# ----- Sub-case B: failing cargo test under PostToolUseFailure -----
error_b='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 0.18s
     Running tests/spec022_dogfood.rs (target/debug/deps/spec022_dogfood-xyz)

running 1 test
test deliberate_failure ... FAILED

failures:

---- deliberate_failure stdout ----
thread '\''deliberate_failure'\'' panicked at tests/spec022_dogfood.rs:3:5:
assertion `left == right` failed
  left: 1
 right: 2
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace

failures:
    deliberate_failure

test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

error: test failed, to rerun pass `--test spec022_dogfood`
'

stdin_b="$(jq -cn \
  --arg c "cargo test --test spec022_dogfood" \
  --arg e "$error_b" \
  '{
    session_id: "V13-session",
    transcript_path: "/dev/null",
    cwd: ".",
    hook_event_name: "PostToolUseFailure",
    tool_name: "Bash",
    tool_input: {command: $c, description: "deliberate failure for spec 022 test"},
    tool_use_id: "tool-use-V13-B",
    error: $e,
    is_interrupt: false,
    duration_ms: 184
  }')"

hook_exit=0
printf '%s' "$stdin_b" | bash "$HOOK" || hook_exit=$?
if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [B failing cargo test]: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi
if [ ! -f "$state_file" ]; then
  printf 'FAIL [B failing cargo test]: last-run.json not created\n'
  exit 1
fi
for check in \
  '.command == "cargo test --test spec022_dogfood"' \
  '.detector == "cargo-test"' \
  '.inferred_status == "FAIL"' \
  '(.inference_basis | test("test result: FAILED"))' \
  '(.stderr_head | test("1 failed"))'; do
  if [ "$(jq -r "$check" "$state_file")" != "true" ]; then
    printf 'FAIL [B]: assertion %s\n' "$check"
    cat "$state_file"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
