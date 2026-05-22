#!/usr/bin/env bash
# .claude/tests/supply-chain/05-override-marker.sh
# V5+V6 — Scenarios:
#   (a) valid multi-line override → advisory-override audit, NO stderr line
#   (b) short-reason multi-line override → marker dropped, plain advisory fires
#
# Override grammar is start-of-line anchored, ≥10 chars after trim.
# Mirrors .claude/hooks/secrets-scan.sh grammar. Inline-trailing markers
# are NOT accepted (would re-open the spec-002 false-positive regression).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-008-V5-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SUPPLY_CHAIN_BLOCK=0  # spec 009: pin advisory mode under block-by-default default

# ---------------------------------------------------------------------------
# (a) Valid override marker → advisory-override, no stderr
# ---------------------------------------------------------------------------
REASON_VALID="documented chart-library upgrade per PR-123"
CMD_VALID="$(printf 'npm install axios\n# OVERRIDE: %s' "$REASON_VALID")"
stdin_valid="$(jq -cn --arg c "$CMD_VALID" '{tool_input:{command:$c}, session_id:"V5-a"}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_valid" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [valid override]: hook exit=%d\n' "$hook_exit"
  exit 1
fi
if [ -s "$stderr_file" ]; then
  printf 'FAIL [valid override]: expected silent (override suppresses stderr), got:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

row="$(tail -1 "$TMPDIR/.claude/supply-chain-audit.jsonl")"
for check in \
  '.decision == "advisory-override"' \
  '.manager == "npm"' \
  '.action == "install"' \
  '.packages == ["axios"]' \
  ".override_reason == \"$REASON_VALID\""; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL [valid override]: audit assertion failed: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# (b) Short-reason override → marker silently dropped, plain advisory fires
# ---------------------------------------------------------------------------
CMD_SHORT="$(printf 'npm install axios\n# OVERRIDE: ok')"
stdin_short="$(jq -cn --arg c "$CMD_SHORT" '{tool_input:{command:$c}, session_id:"V5-b"}')"

: > "$stderr_file"
hook_exit=0
printf '%s' "$stdin_short" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL [short override]: hook exit=%d\n' "$hook_exit"
  exit 1
fi
if ! grep -q "^supply-chain-advisory: npm install — axios$" "$stderr_file"; then
  printf 'FAIL [short override]: expected normal advisory stderr, got:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

row="$(tail -1 "$TMPDIR/.claude/supply-chain-audit.jsonl")"
for check in \
  '.decision == "advisory"' \
  '.manager == "npm"' \
  '.override_reason == null'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL [short override]: audit assertion failed: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
