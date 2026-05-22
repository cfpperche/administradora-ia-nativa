#!/usr/bin/env bash
# .claude/hooks/rule-load-debug.sh
# Observability hook for the native CC `InstructionsLoaded` event. Logs every
# rule/CLAUDE.md load to .claude/.rule-load-debug.jsonl when
# CLAUDE_RULE_LOAD_DEBUG=1, silent otherwise. Always exit 0 — observability
# only, no decision control (the harness ignores stdout/stderr for this event).
#
# Reference:
#   .claude/rules/rule-load-debug.md  — discipline + probe usage
#   https://code.claude.com/docs/en/hooks#instructionsloaded

set -uo pipefail

# Opt-in gate: silent unless explicitly enabled.
[ "${CLAUDE_RULE_LOAD_DEBUG:-0}" = "1" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
LOG_FILE="$PROJECT_DIR/.claude/.rule-load-debug.jsonl"
LOCK_FILE="$LOG_FILE.lock"

payload="$(cat)"
[ -n "$payload" ] || exit 0

# Probe writability in subshells BEFORE the bare exec — see
# .claude/rules/delegation.md § "Gotchas (for hook maintainers)".
( : >> "$LOG_FILE" ) 2>/dev/null || exit 0
( : >> "$LOCK_FILE" ) 2>/dev/null || exit 0

file_path="$(printf '%s' "$payload" | jq -r '.file_path // ""')"
trigger_file_path="$(printf '%s' "$payload" | jq -r '.trigger_file_path // ""')"

# Relativize paths against $CLAUDE_PROJECT_DIR for readability.
rel_file="${file_path#"$PROJECT_DIR"/}"
rel_trigger="${trigger_file_path#"$PROJECT_DIR"/}"

row="$(printf '%s' "$payload" | jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg rel_file "$rel_file" \
  --arg rel_trigger "$rel_trigger" \
  '{
    ts: $ts,
    session_id: (.session_id // null),
    file: $rel_file,
    memory_type: (.memory_type // null),
    load_reason: (.load_reason // null),
    globs: (.globs // null),
    trigger_file: (if $rel_trigger == "" then null else $rel_trigger end),
    parent_file: (.parent_file_path // null)
  }')"

if [ -n "$row" ]; then
  exec 9> "$LOCK_FILE"
  flock 9
  printf '%s\n' "$row" >> "$LOG_FILE"
fi

exit 0
