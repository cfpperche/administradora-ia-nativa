#!/usr/bin/env bash
# .claude/tests/supply-chain/10-block-override-too-short.sh
# V10 — Scenario: Bash dep-install in default (block) mode with too-short override.
#
# In block mode the ≥10-char reason floor is HARD-ENFORCED — too-short
# reasons (`# OVERRIDE: skip` etc.) do NOT silently degrade to advisory
# the way spec 008 handled them. Instead the hook blocks with a distinct
# corrective stderr template AND preserves the rejected reason in the
# audit row's `override_reason` field (forensics: distinguishes
# "no override at all" from "override rejected as too short").
#
# Asserts:
#   (a) hook exits 2
#   (b) stderr opens with: supply-chain-block: override reason must be ≥10 characters, got "skip"
#   (c) stderr ends with the two-line corrected form (same shape as test 08)
#   (d) audit row decision="block", manager/action/packages captured,
#       override_reason="skip" (populated — forensic preservation)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-009-V10-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

SHORT_REASON="skip"  # 4 chars — below the 10-char floor
CMD="$(printf 'npm install axios\n# OVERRIDE: %s' "$SHORT_REASON")"
stdin_json="$(jq -cn --arg c "$CMD" '{tool_input:{command:$c}, session_id:"V10-session"}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

# (a) exit 2
if [ "$hook_exit" -ne 2 ]; then
  printf 'FAIL: hook exit=%d, want 2\n' "$hook_exit"
  printf 'Stderr was:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (b) stderr opens with the short-reason block-template lead
expected_lead='supply-chain-block: override reason must be ≥10 characters, got "skip"'
if ! grep -qF "$expected_lead" "$stderr_file"; then
  printf 'FAIL: stderr missing expected short-reason lead\n'
  printf 'Expected (substring): %s\n' "$expected_lead"
  printf 'Got stderr:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (c) stderr ends with the verbatim two-line corrected form
last_two="$(grep -v '^$' "$stderr_file" | tail -2)"
if ! printf '%s\n' "$last_two" | grep -qE '^[[:space:]]*npm install axios$'; then
  printf 'FAIL: stderr does not end with original command line\n'
  printf 'Got last two lines:\n%s\n' "$last_two"
  exit 1
fi
if ! printf '%s\n' "$last_two" | grep -qF '# OVERRIDE: <reason ≥10 chars — why this dep is being added>'; then
  printf 'FAIL: stderr does not end with override-marker placeholder\n'
  printf 'Got last two lines:\n%s\n' "$last_two"
  exit 1
fi

# (d) audit row shape — override_reason MUST be populated with "skip"
audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ ! -f "$audit_log" ]; then
  printf 'FAIL: audit log not created\n'
  exit 1
fi

row=$(tail -1 "$audit_log")
for check in \
  '.decision == "block"' \
  '.scope == "bash"' \
  '.manager == "npm"' \
  '.action == "install"' \
  '.packages == ["axios"]' \
  '.override_reason == "skip"'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
