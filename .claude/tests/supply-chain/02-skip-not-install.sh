#!/usr/bin/env bash
# .claude/tests/supply-chain/02-skip-not-install.sh
# V2 — Scenario: non-dep Bash command audits skip and falls through silently.
#
# Asserts (across three sub-cases: "npm test", "npm install" no-args, "ls"):
#   (a) hook exits 0
#   (b) no stderr output
#   (c) audit log row decision="skip-not-install", manager=null, packages=null

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-008-V2-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SUPPLY_CHAIN_BLOCK=0  # spec 009: pin advisory mode under block-by-default default

run_case() {
  local label="$1"
  local cmd="$2"
  local stdin_json stderr_file hook_exit row

  stdin_json="$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}, session_id:"V2-session"}')"
  stderr_file="$TMPDIR/stderr.txt"
  : > "$stderr_file"  # truncate per case

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi
  if [ -s "$stderr_file" ]; then
    printf 'FAIL [%s]: expected silent (no stderr), got:\n%s\n' "$label" "$(cat "$stderr_file")"
    exit 1
  fi

  row="$(tail -1 "$TMPDIR/.claude/supply-chain-audit.jsonl")"
  for check in \
    '.decision == "skip-not-install"' \
    '.scope == "bash"' \
    '.manager == null' \
    '.action == null' \
    '.packages == null'; do
    if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
      printf 'FAIL [%s]: audit row failed: %s\n' "$label" "$check"
      printf 'Row: %s\n' "$row"
      exit 1
    fi
  done
}

run_case "npm test"        "npm test"
run_case "npm install"     "npm install"
run_case "npm install -h"  "npm install --help"
run_case "ls"              "ls -la"

# All four cases should have produced one audit row each.
line_count=$(wc -l < "$TMPDIR/.claude/supply-chain-audit.jsonl")
if [ "$line_count" -ne 4 ]; then
  printf 'FAIL: expected 4 audit rows, got %d\n' "$line_count"
  exit 1
fi

printf 'PASS\n'
exit 0
