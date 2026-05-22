#!/usr/bin/env bash
# .claude/tests/supply-chain-composer/04-edit-composer-json-advisory.sh
# Spec 047 V2 — Scenario: sub-agent Edit/Write on composer.json triggers advisory.
#
# Asserts:
#   (a) hook exit 0
#   (b) stderr contains "supply-chain-advisory: edit composer.json"
#   (c) audit row decision="advisory", scope="edit", file="composer.json"

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-advise.sh"

TMPDIR="$(mktemp -d -t spec-047-V2d-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

# Sub-agent edit (agent_id present).
stdin_json="$(jq -cn '{
  agent_id: "test-subagent-001",
  session_id: "V2d",
  tool_input: { file_path: "/path/to/project/composer.json" }
}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

if [ "$hook_exit" -ne 0 ]; then
  printf 'FAIL: hook exit=%d, want 0\n' "$hook_exit"
  exit 1
fi

if ! grep -q '^supply-chain-advisory: edit composer.json' "$stderr_file"; then
  printf 'FAIL: stderr missing edit advisory line\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
row=$(cat "$audit_log")
for check in \
  '.decision == "advisory"' \
  '.scope == "edit"' \
  '.file == "composer.json"'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed: %s\n  row: %s\n' "$check" "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
