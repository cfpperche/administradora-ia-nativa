#!/usr/bin/env bash
# .claude/tests/supply-chain/09-block-override-valid.sh
# V9 — Scenario: Bash dep-install in default (block) mode WITH valid override.
#
# A line matching `^[[:space:]]*# OVERRIDE: <reason>` (≥10 chars after trim)
# in tool_input.command bypasses the block: hook exits 0 silently, no
# stderr template, audit records decision="block-override" with the
# captured reason. Same shape as spec 008's advisory-override path but
# under block mode.
#
# Asserts:
#   (a) hook exits 0 (not 2 — valid override passes block)
#   (b) stderr is empty (no advisory line, no block template)
#   (c) audit row decision="block-override", manager/action/packages
#       captured, override_reason populated with the full reason text

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-009-V9-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
# Default mode (no CLAUDE_SUPPLY_CHAIN_BLOCK set) — block mode under spec 009.
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

REASON="documented chart-library upgrade per spec-009 verification"
CMD="$(printf 'npm install axios\n# OVERRIDE: %s' "$REASON")"
stdin_json="$(jq -cn --arg c "$CMD" '{tool_input:{command:$c}, session_id:"V9-session"}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

# (a) exit 0
if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  printf 'Stderr was:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (b) stderr empty
if [ -s "$stderr_file" ]; then
  printf 'FAIL: expected silent stderr, got:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (c) audit row shape
audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ ! -f "$audit_log" ]; then
  printf 'FAIL: audit log not created\n'
  exit 1
fi

line_count=$(wc -l < "$audit_log")
if [ "$line_count" -ne 1 ]; then
  printf 'FAIL: audit log has %d lines, want 1\n' "$line_count"
  cat "$audit_log"
  exit 1
fi

row=$(cat "$audit_log")
for check in \
  '.decision == "block-override"' \
  '.scope == "bash"' \
  '.manager == "npm"' \
  '.action == "install"' \
  '.packages == ["axios"]'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

# Override reason match is a separate equality check (string with spaces).
got_reason="$(printf '%s' "$row" | jq -r '.override_reason')"
if [ "$got_reason" != "$REASON" ]; then
  printf 'FAIL: override_reason mismatch\n  want: %s\n  got:  %s\n' "$REASON" "$got_reason"
  exit 1
fi

printf 'PASS\n'
exit 0
