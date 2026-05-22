#!/usr/bin/env bash
# Spec 016 — Scenario: settings.json merge (additive, no replace).
# Asserts:
#   (a) Agent0 hook entries appended to fork's settings.json
#   (b) fork's pre-existing entries preserved
#   (c) no duplicates (dedup by matcher + hooks[].command)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-05-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Agent0 settings: 3 PreToolUse hooks
jq -cn '{
  hooks: {
    PreToolUse: [
      {matcher:"Bash", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/governance-gate.sh"}]},
      {matcher:"Bash", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/secrets-scan.sh"}]},
      {matcher:"Bash", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/supply-chain-scan.sh"}]}
    ],
    SessionStart: [
      {matcher:"*", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh"}]}
    ]
  }
}' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# Fork settings: governance-gate (matches Agent0) + a fork-only custom hook
jq -cn '{
  hooks: {
    PreToolUse: [
      {matcher:"Bash", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/governance-gate.sh"}]},
      {matcher:"Bash", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/fork-only-hook.sh"}]}
    ]
  }
}' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  exit 1
fi

# Assert: fork's PreToolUse now has 4 entries (governance dedup'd, secrets+supply added, fork-only preserved)
pre_count="$(jq -r '.hooks.PreToolUse | length' "$FORK/.claude/settings.json")"
if [ "$pre_count" -ne 4 ]; then
  printf 'FAIL: expected 4 PreToolUse entries, got %s\n' "$pre_count"
  jq . "$FORK/.claude/settings.json"
  exit 1
fi

# Assert: fork-only-hook preserved
if ! jq -e '.hooks.PreToolUse[] | select(.hooks[].command | test("fork-only-hook"))' "$FORK/.claude/settings.json" >/dev/null; then
  printf 'FAIL: fork-only-hook.sh entry was dropped\n'
  exit 1
fi

# Assert: SessionStart now exists
if ! jq -e '.hooks.SessionStart | length == 1' "$FORK/.claude/settings.json" >/dev/null; then
  printf 'FAIL: SessionStart should have 1 entry\n'
  exit 1
fi

# Assert: governance-gate NOT duplicated
gov_count="$(jq -r '.hooks.PreToolUse | map(select(.hooks[].command | test("governance-gate"))) | length' "$FORK/.claude/settings.json")"
if [ "$gov_count" -ne 1 ]; then
  printf 'FAIL: governance-gate should appear once, got %s\n' "$gov_count"
  exit 1
fi

echo "PASS: 05-settings-merge-additive"
