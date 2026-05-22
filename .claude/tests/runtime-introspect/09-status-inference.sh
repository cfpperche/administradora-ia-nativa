#!/usr/bin/env bash
# .claude/tests/runtime-introspect/09-status-inference.sh
# V9 — Scenario: status inference from runner output when tool_response
# carries no exit_code (Claude Code's actual Bash payload shape, surfaced by
# the spec-011 live-dogfood pass against /home/goat/shrnk on 2026-05-11).
#
# Asserts:
#   (a) `bun test` with " 10 pass\n 0 fail\n" → inferred_status=PASS, basis populated
#   (b) `bun test` with " 5 pass\n 3 fail\n" → inferred_status=FAIL
#   (c) `pytest` with "===== 1 failed, 4 passed" → inferred_status=FAIL
#   (d) `pytest` with "===== 5 passed in 0.12s" → inferred_status=PASS
#   (e) `bun tsc` clean (no error TS) → inferred_status=PASS
#   (f) `bun tsc` with `error TS2304: Cannot find name` → inferred_status=FAIL
#   (g) interrupted=true → inferred_status=INTERRUPTED regardless of stdout
#   (h) probe falls back to inferred_status when exit is null (no exit_code in
#       fixture); when exit is 0, probe uses PASS directly.
#   (i) probe uses INTERRUPTED status when interrupted=true.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/runtime-capture.sh"
PROBE="$AGENT0_ROOT/.claude/tools/probe.sh"

TMPDIR="$(mktemp -d -t spec-011-V9-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

state_file="$TMPDIR/.claude/.runtime-state/last-run.json"

run_case() {
  local label="$1"
  local cmd="$2"
  local stdout="$3"
  local interrupted="${4:-false}"
  local want_status="$5"

  rm -f "$state_file"

  local stdin_json hook_exit
  # Note: NO exit_code field — matches real Claude Code payload shape.
  stdin_json="$(jq -cn \
    --arg c "$cmd" \
    --arg out "$stdout" \
    --argjson it "$interrupted" \
    '{
      tool_name: "Bash",
      tool_input: {command: $c},
      tool_response: {stdout: $out, stderr: "", interrupted: $it, isImage: false, noOutputExpected: false},
      session_id: "V9-session",
      tool_use_id: "tool-use-V9"
    }')"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi

  if [ ! -f "$state_file" ]; then
    printf 'FAIL [%s]: state file not created\n' "$label"
    exit 1
  fi

  local inferred
  inferred="$(jq -r '.inferred_status' "$state_file")"
  if [ "$inferred" != "$want_status" ]; then
    printf 'FAIL [%s]: inferred_status=%s, want %s\n' "$label" "$inferred" "$want_status"
    printf 'inference_basis: %s\n' "$(jq -r '.inference_basis' "$state_file")"
    exit 1
  fi
}

# (a) bun test pass — canonical bun output
run_case "bun test 0 fail" "bun test" \
  $' 10 pass\n 0 fail\n 17 expect() calls\nRan 10 tests across 2 files. [33.00ms]' \
  "false" "PASS"

# (b) bun test fail
run_case "bun test N fail" "bun test" \
  $' 7 pass\n 3 fail\n 12 expect() calls\nRan 10 tests across 2 files. [50.00ms]' \
  "false" "FAIL"

# (c) pytest fail
run_case "pytest 1 failed" "pytest" \
  "============= 1 failed, 4 passed in 0.12s =============" \
  "false" "FAIL"

# (d) pytest pass
run_case "pytest all passed" "pytest" \
  "============= 5 passed in 0.34s =============" \
  "false" "PASS"

# (e) bun tsc clean
run_case "bun tsc clean" "bun tsc --noEmit" "" "false" "PASS"

# (f) bun tsc with TS error
run_case "bun tsc with TS error" "bun tsc --noEmit" \
  "src/foo.ts:5:10 - error TS2304: Cannot find name 'bar'." \
  "false" "FAIL"

# (g) interrupted trumps stdout — even with passing-looking output
run_case "interrupted overrides" "bun test" \
  $' 10 pass\n 0 fail\n' \
  "true" "INTERRUPTED"

# (h) Probe falls back to inferred_status when exit is null.
# Use the last state file from case (d) — pytest pass, no exit field.
run_case "probe inference fallback setup" "pytest" \
  "============= 5 passed in 0.34s =============" \
  "false" "PASS"

probe_out="$(bash "$PROBE" last-run 2>&1)"
if ! printf '%s' "$probe_out" | grep -qE '^status: PASS'; then
  printf 'FAIL: probe did not surface inferred PASS status\n'
  printf 'Got:\n%s\n' "$probe_out"
  exit 1
fi
if ! printf '%s' "$probe_out" | grep -qE '^inferred_status: PASS'; then
  printf 'FAIL: probe missing inferred_status line when exit is null\n'
  printf 'Got:\n%s\n' "$probe_out"
  exit 1
fi

# (i) Probe shows INTERRUPTED status when the snapshot has interrupted=true.
run_case "probe interrupted" "bun test" $' 10 pass\n 0 fail\n' "true" "INTERRUPTED"

probe_out="$(bash "$PROBE" last-run 2>&1)"
if ! printf '%s' "$probe_out" | grep -qE '^status: INTERRUPTED'; then
  printf 'FAIL: probe did not surface INTERRUPTED status\n'
  printf 'Got:\n%s\n' "$probe_out"
  exit 1
fi

printf 'PASS\n'
exit 0
