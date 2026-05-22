#!/usr/bin/env bash
# .claude/tests/supply-chain/11-advisory-opt-out.sh
# V11 — Scenario: CLAUDE_SUPPLY_CHAIN_BLOCK=0 falls back to spec-008 advisory mode.
#
# The whole spec-008 contract must remain reachable as an explicit opt-out:
# `advisory` and `advisory-override` decision values keep their exact shape,
# stderr line format is unchanged, exit codes stay 0. This test is the
# regression guard that promoting to block-by-default did NOT alter any
# observable advisory-mode behaviour.
#
# Sub-cases (two run_case invocations):
#   (a) advisory mode + dep install + no override → decision="advisory",
#       stderr "supply-chain-advisory: npm install — axios", exit 0
#   (b) advisory mode + dep install + valid override → decision="advisory-override",
#       no stderr, override_reason populated, exit 0
#
# Sub-case (a) currently passes against the spec-008 hook because the
# default is advisory. Once T8 lands the mode resolver, this test still
# passes — explicitly because CLAUDE_SUPPLY_CHAIN_BLOCK=0 selects advisory.
# That's the "regression guard works under both old and new hook" property.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-009-V11-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SUPPLY_CHAIN_BLOCK=0  # the whole point of this test

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"

# ---------------------------------------------------------------------------
# (a) Advisory mode + no override → decision="advisory", stderr advisory line
# ---------------------------------------------------------------------------
stdin_json="$(jq -cn '{tool_input:{command:"npm install axios"}, session_id:"V11a-session"}')"
stderr_a="$TMPDIR/stderr-a.txt"
exit_a=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_a" || exit_a=$?

if [ "$exit_a" -ne 0 ]; then
  printf 'FAIL [a]: hook exit=%d, want 0\n' "$exit_a"
  printf 'Stderr was:\n%s\n' "$(cat "$stderr_a")"
  exit 1
fi
if ! grep -q '^supply-chain-advisory: npm install — axios$' "$stderr_a"; then
  printf 'FAIL [a]: stderr missing advisory line\n'
  printf 'Got: %s\n' "$(cat "$stderr_a")"
  exit 1
fi

row_a="$(tail -1 "$audit_log")"
for check in \
  '.decision == "advisory"' \
  '.scope == "bash"' \
  '.manager == "npm"' \
  '.action == "install"' \
  '.packages == ["axios"]' \
  '.override_reason == null'; do
  if [ "$(printf '%s' "$row_a" | jq -r "$check")" != "true" ]; then
    printf 'FAIL [a]: audit assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row_a"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# (b) Advisory mode + valid override → decision="advisory-override", silent
# ---------------------------------------------------------------------------
REASON="documented advisory-mode opt-out for spec 009 test"
CMD_B="$(printf 'npm install axios\n# OVERRIDE: %s' "$REASON")"
stdin_json_b="$(jq -cn --arg c "$CMD_B" '{tool_input:{command:$c}, session_id:"V11b-session"}')"
stderr_b="$TMPDIR/stderr-b.txt"
exit_b=0
printf '%s' "$stdin_json_b" | bash "$HOOK" 2>"$stderr_b" || exit_b=$?

if [ "$exit_b" -ne 0 ]; then
  printf 'FAIL [b]: hook exit=%d, want 0\n' "$exit_b"
  exit 1
fi
if [ -s "$stderr_b" ]; then
  printf 'FAIL [b]: expected silent stderr, got:\n%s\n' "$(cat "$stderr_b")"
  exit 1
fi

row_b="$(tail -1 "$audit_log")"
for check in \
  '.decision == "advisory-override"' \
  '.manager == "npm"' \
  '.action == "install"' \
  '.packages == ["axios"]'; do
  if [ "$(printf '%s' "$row_b" | jq -r "$check")" != "true" ]; then
    printf 'FAIL [b]: audit assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row_b"
    exit 1
  fi
done

got_reason="$(printf '%s' "$row_b" | jq -r '.override_reason')"
if [ "$got_reason" != "$REASON" ]; then
  printf 'FAIL [b]: override_reason mismatch\n  want: %s\n  got:  %s\n' "$REASON" "$got_reason"
  exit 1
fi

# Total: two advisory-mode rows, no block rows
total=$(wc -l < "$audit_log")
if [ "$total" -ne 2 ]; then
  printf 'FAIL: audit log has %d rows, want 2\n' "$total"
  cat "$audit_log"
  exit 1
fi

printf 'PASS\n'
exit 0
