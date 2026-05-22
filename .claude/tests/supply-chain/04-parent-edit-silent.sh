#!/usr/bin/env bash
# .claude/tests/supply-chain/04-parent-edit-silent.sh
# V4 — Scenario: parent edit on dep manifest passes through silently.
#
# Two cases — both must produce zero stderr + zero audit rows:
#   (a) parent edit on package.json (agent_id absent → actor-split silence)
#   (b) sub-agent edit on README.md (manifest list does not contain README.md)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-advise.sh"

TMPDIR="$(mktemp -d -t spec-008-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

assert_silent() {
  local label="$1" stdin_json="$2"
  local stderr_file="$TMPDIR/stderr.txt"
  local hook_exit=0

  : > "$stderr_file"
  printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi
  if [ -s "$stderr_file" ]; then
    printf 'FAIL [%s]: expected silent, got stderr:\n%s\n' "$label" "$(cat "$stderr_file")"
    exit 1
  fi
}

# (a) parent edit on package.json — agent_id ABSENT
stdin_a="$(jq -cn '{
  tool_name:"Edit",
  tool_input:{file_path:"/some/path/package.json", old_string:"", new_string:""},
  session_id:"V4-parent"
}')"
assert_silent "parent on package.json" "$stdin_a"

# (b) sub-agent edit on README.md — agent_id PRESENT but file not in manifest list
stdin_b="$(jq -cn '{
  tool_name:"Edit",
  tool_input:{file_path:"/some/path/README.md", old_string:"", new_string:""},
  session_id:"V4-sub",
  agent_id:"V4-sub-agent"
}')"
assert_silent "sub-agent on README.md" "$stdin_b"

# Audit log MUST NOT EXIST (both cases silent → no row written → no file created)
audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ -f "$audit_log" ] && [ -s "$audit_log" ]; then
  printf 'FAIL: audit log has content but expected empty/missing:\n%s\n' "$(cat "$audit_log")"
  exit 1
fi

printf 'PASS\n'
exit 0
