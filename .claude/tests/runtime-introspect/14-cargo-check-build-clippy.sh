#!/usr/bin/env bash
# .claude/tests/runtime-introspect/14-cargo-check-build-clippy.sh
# V14 — Scenarios C, D, E, F, G: cargo check / build / clippy capture and
# inference. Spec 022.
#
# Asserts:
#   (C) `cargo check` clean → detector=cargo-check, status=PASS (Finished line)
#   (D) `cargo check` with error[E0xxx] → status=FAIL (compiler error)
#   (E) `cargo clippy --all-targets -- -D warnings` clean → status=PASS
#   (F) `cargo clippy --all-targets -- -D warnings` with ^error: (warnings
#       promoted) → status=FAIL
#   (G) `cargo build` clean → detector=cargo-build, status=PASS

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"

TMPDIR="$(mktemp -d -t spec-022-V14-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"

run_case() {
  local label="$1"
  local cmd="$2"
  local stderr="$3"
  local want_detector="$4"
  local want_status="$5"
  local want_basis_fragment="$6"

  rm -f "$state_file"

  local stdin_json hook_exit
  stdin_json="$(jq -cn \
    --arg c "$cmd" \
    --arg err "$stderr" \
    '{
      tool_name: "Bash",
      tool_input: {command: $c},
      tool_response: {stdout: "", stderr: $err, interrupted: false, isImage: false, noOutputExpected: false},
      session_id: "V14-session",
      tool_use_id: "tool-use-V14"
    }')"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?
  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi
  if [ ! -f "$state_file" ]; then
    printf 'FAIL [%s]: last-run.json not created\n' "$label"
    exit 1
  fi
  local detector status basis
  detector="$(jq -r '.detector' "$state_file")"
  status="$(jq -r '.inferred_status' "$state_file")"
  basis="$(jq -r '.inference_basis' "$state_file")"
  if [ "$detector" != "$want_detector" ]; then
    printf 'FAIL [%s]: detector=%s, want %s\n' "$label" "$detector" "$want_detector"
    cat "$state_file"
    exit 1
  fi
  if [ "$status" != "$want_status" ]; then
    printf 'FAIL [%s]: inferred_status=%s, want %s\n' "$label" "$status" "$want_status"
    printf 'inference_basis: %s\n' "$basis"
    cat "$state_file"
    exit 1
  fi
  if ! printf '%s' "$basis" | grep -q "$want_basis_fragment"; then
    printf 'FAIL [%s]: inference_basis missing %q fragment, got: %s\n' "$label" "$want_basis_fragment" "$basis"
    exit 1
  fi
}

# (C) cargo check clean
clean_check='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.42s
'
run_case "C cargo check clean"            "cargo check"        "$clean_check"  "cargo-check"   "PASS"  "Finished"

# (D) cargo check with rustc error[E0xxx]
fail_check='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
error[E0425]: cannot find value `foo` in this scope
  --> src/lib.rs:10:5
   |
10 |     foo
   |     ^^^ not found in this scope

error: could not compile `rshrnk` (lib) due to 1 previous error
'
run_case "D cargo check rustc error"      "cargo check"        "$fail_check"   "cargo-check"   "FAIL"  "error\[E"

# (E) cargo clippy -D warnings clean
clean_clippy='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
    Checking rshrnk v0.1.0 (/home/goat/rshrnk)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.50s
'
run_case "E cargo clippy clean"           "cargo clippy --all-targets -- -D warnings"  "$clean_clippy"  "cargo-clippy"  "PASS"  "Finished"

# (F) cargo clippy with warning promoted to error (clippy -D warnings emits ^error:)
fail_clippy='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
error: this function has too many arguments (8/7)
  --> src/lib.rs:5:1
   |
5  | / fn many_args(a: u32, b: u32, c: u32, d: u32, e: u32, f: u32, g: u32, h: u32) -> u32 {
6  | |     a + b + c + d + e + f + g + h
7  | | }
   | |_^
   |
   = note: `-D clippy::too-many-arguments` implied by `-D warnings`

error: could not compile `rshrnk` (lib) due to 1 previous error
'
run_case "F cargo clippy promoted warn"   "cargo clippy --all-targets -- -D warnings"  "$fail_clippy"   "cargo-clippy"  "FAIL"  "\^error:"

# (G) cargo build clean
clean_build='   Compiling rshrnk v0.1.0 (/home/goat/rshrnk)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.38s
'
run_case "G cargo build clean"            "cargo build"        "$clean_build"  "cargo-build"   "PASS"  "Finished"

printf 'PASS\n'
exit 0
