#!/usr/bin/env bash
# Spec 016 — Scenario: settings.json merge preserves top-level keys beyond .hooks.
# Regression test for the bug where merge_settings_json only emitted {hooks: ...},
# dropping $schema / statusLine / permissions / env / model from both sides.
#
# Asserts:
#   (a) Agent0's $schema propagates when fork lacks it
#   (b) Agent0's statusLine propagates when fork lacks it
#   (c) fork's permissions preserved (Agent0 owns $schema + statusLine + hooks only)
#   (d) fork-only top-level key (`env`) preserved
#   (e) hooks merge still works (regression check on the original mechanism)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-21-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Agent0 settings: $schema + statusLine + hooks (no permissions, no env)
jq -cn '{
  "$schema": "https://example.com/schema.json",
  statusLine: {type:"command", command:"node $CLAUDE_PROJECT_DIR/.claude/presence/statusline.mjs"},
  hooks: {
    SessionStart: [
      {matcher:"*", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh"}]}
    ]
  }
}' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# Fork settings: permissions (fork-owned) + env (fork-only) + a hook
jq -cn '{
  permissions: {defaultMode:"acceptEdits", allow:["Bash(npm test)"], deny:[]},
  env: {FORK_ONLY_VAR: "value"},
  hooks: {
    PreToolUse: [
      {matcher:"Bash", hooks:[{type:"command", command:"bash $CLAUDE_PROJECT_DIR/.claude/hooks/fork-hook.sh"}]}
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

# (a) Agent0's $schema propagated
schema="$(jq -r '."$schema" // empty' "$FORK/.claude/settings.json")"
if [ "$schema" != "https://example.com/schema.json" ]; then
  printf 'FAIL: $schema not propagated (got %q)\n' "$schema"
  jq . "$FORK/.claude/settings.json"
  exit 1
fi

# (b) Agent0's statusLine propagated
statusline_cmd="$(jq -r '.statusLine.command // empty' "$FORK/.claude/settings.json")"
if [ -z "$statusline_cmd" ]; then
  printf 'FAIL: statusLine not propagated\n'
  jq . "$FORK/.claude/settings.json"
  exit 1
fi

# (c) Fork's permissions preserved (NOT overwritten by Agent0 — Agent0 has none)
perms_mode="$(jq -r '.permissions.defaultMode // empty' "$FORK/.claude/settings.json")"
if [ "$perms_mode" != "acceptEdits" ]; then
  printf 'FAIL: fork permissions.defaultMode not preserved (got %q)\n' "$perms_mode"
  exit 1
fi
perms_allow="$(jq -r '.permissions.allow[0] // empty' "$FORK/.claude/settings.json")"
if [ "$perms_allow" != "Bash(npm test)" ]; then
  printf 'FAIL: fork permissions.allow not preserved (got %q)\n' "$perms_allow"
  exit 1
fi

# (d) Fork-only top-level key (env) preserved
env_val="$(jq -r '.env.FORK_ONLY_VAR // empty' "$FORK/.claude/settings.json")"
if [ "$env_val" != "value" ]; then
  printf 'FAIL: fork.env.FORK_ONLY_VAR not preserved (got %q)\n' "$env_val"
  exit 1
fi

# (e) Hooks merged correctly (fork's PreToolUse retained, Agent0's SessionStart added)
pre_count="$(jq -r '.hooks.PreToolUse | length' "$FORK/.claude/settings.json")"
ss_count="$(jq -r '.hooks.SessionStart | length' "$FORK/.claude/settings.json")"
if [ "$pre_count" -ne 1 ] || [ "$ss_count" -ne 1 ]; then
  printf 'FAIL: hooks merge wrong — PreToolUse=%s SessionStart=%s\n' "$pre_count" "$ss_count"
  jq . "$FORK/.claude/settings.json"
  exit 1
fi

echo "PASS: 21-settings-merge-toplevel-keys"
