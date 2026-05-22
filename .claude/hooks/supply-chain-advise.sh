#!/usr/bin/env bash
# .claude/hooks/supply-chain-advise.sh
# PostToolUse(Edit|Write|MultiEdit) hook — supply-chain manifest-edit advisory.
#
# Sub-agent companion to .claude/hooks/supply-chain-scan.sh (the Bash preflight).
# Fires when a delegated sub-agent edits a dependency manifest or lockfile by
# basename — `package.json`, `pyproject.toml`, `Cargo.toml`, etc. The advisory
# is informational only (never blocks, never reverts the edit) and is meant to
# surface the manifest mutation in the agent's next-turn context so the diff
# is not invisible.
#
# Parent edits are exempt (actor-split via `agent_id` payload field —
# absent → exit 0 silently, same shape as secrets-advise.sh and the
# post-edit validator).
#
# Audit: one row per manifest-matching sub-agent edit, in
# `.claude/supply-chain-audit.jsonl`. No audit row for parent edits or
# non-manifest edits (the volume would be enormous and the signal-to-noise
# would tank).
#
# Decision values written by this hook:
#   "advisory"  — sub-agent edit on a recognised manifest/lockfile basename
#
# Tunables:
#   CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1  disable (matches Bash hook env var)
#
# Reference:
#   .claude/rules/supply-chain.md        — full discipline
#   .claude/hooks/supply-chain-scan.sh   — sibling Bash preflight
#   .claude/hooks/secrets-advise.sh      — shape for actor-split + opt-out
#
# Exit codes: 0 always.
# jq is a hard dependency; missing → exit 0 (fail open).
# bash 3.2-compatible.

set -uo pipefail

# Escape hatch — symmetric with the Bash preflight.
if [ "${CLAUDE_SKIP_SUPPLY_CHAIN_SCAN:-0}" = "1" ]; then
  exit 0
fi

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

# Actor split — sub-agent only.
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
[ -z "$AGENT_ID" ] && exit 0

FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -z "$FILE_PATH" ] && exit 0

BASENAME="$(basename "$FILE_PATH")"

# Manifest + lockfile allowlist (exact basename match; no glob walking).
# Order doesn't matter; first match wins.
case "$BASENAME" in
  package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lock|bun.lockb)
    ;;
  pyproject.toml|requirements.txt|uv.lock|poetry.lock|pdm.lock)
    ;;
  Cargo.toml|Cargo.lock)
    ;;
  go.mod|go.sum)
    ;;
  composer.json|composer.lock)
    ;;
  *)
    # Not a manifest — silent exit, no audit row (avoid log explosion on
    # every Edit/Write across the project).
    exit 0
    ;;
esac

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
AUDIT_LOG="$PROJECT_DIR/.claude/supply-chain-audit.jsonl"

mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || exit 0
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Emit advisory to stderr (surfaces to agent's next-turn context).
printf 'supply-chain-advisory: edit %s — manifest may have new dep\n' "$BASENAME" >&2

# Build audit row.
session_id_json="null"
[ -n "$SESSION_ID" ] && session_id_json="$(printf '%s' "$SESSION_ID" | jq -R -s -c 'rtrimstr("\n")')"
agent_id_json="$(printf '%s' "$AGENT_ID" | jq -R -s -c 'rtrimstr("\n")')"
file_json="$(printf '%s' "$BASENAME" | jq -R -s -c 'rtrimstr("\n")')"

line="$(jq -c -n \
  --arg ts "$ts" \
  --argjson session_id "$session_id_json" \
  --argjson agent_id "$agent_id_json" \
  --arg decision "advisory" \
  --arg scope "edit" \
  --argjson file "$file_json" \
  '{ts:$ts, session_id:$session_id, agent_id:$agent_id, decision:$decision, scope:$scope, file:$file}')"

# Atomic append via flock (subshell-probe pattern to avoid sticky-exec trap).
if command -v flock >/dev/null 2>&1; then
  lock_path="$AUDIT_LOG.lock"
  ( : >>"$lock_path" ) 2>/dev/null || {
    printf '%s\n' "$line" >> "$AUDIT_LOG" 2>/dev/null || true
    exit 0
  }
  exec 9>"$lock_path"
  flock 9
  printf '%s\n' "$line" >> "$AUDIT_LOG"
  flock -u 9
  exec 9>&-
else
  printf '%s\n' "$line" >> "$AUDIT_LOG" 2>/dev/null || true
fi

exit 0
