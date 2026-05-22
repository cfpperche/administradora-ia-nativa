#!/usr/bin/env bash
# .claude/hooks/delegation-stop.sh
# SubagentStop hook — closes the delegation audit row opened by
# delegation-gate.sh at PreToolUse(Agent) time. Appends a sibling JSONL row
# keyed by agent_id (primary) + tool_use_id (bridge to dispatch row via the
# per-sub-agent transcript sidecar .meta.json) carrying termination metadata:
# duration_ms (client-computed from dispatch_ts → close_ts), edit_count
# (counted from the per-sub-agent transcript JSONL tool_use blocks), exit
# state (ok | loop-budget-exceeded), denormalised agent_type for self-
# sufficient jq queries, and a 200-char head of the sub-agent's last
# assistant message.
#
# Fail-open everywhere: missing jq, unparseable payload, unwritable log,
# missing sidecar, missing transcript — all exit 0 silently. A broken hook
# must never block sub-agent termination or pollute the agent's next turn.
#
# Spec: docs/specs/061-subagent-stop-hook/
# Bridge mechanism: notes.md § Design decisions (2026-05-19 empirical capture)

set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
AUDIT_LOG="$PROJECT_DIR/.claude/delegation-audit.jsonl"
STATE_DIR="$PROJECT_DIR/.claude/.delegation-state/agents"
BUDGET="${CLAUDE_DELEGATION_LOOP_BUDGET:-5}"

# --- Phase 1: Extract payload fields ---
# Empirical SubagentStop payload schema (2026-05-19 probe capture):
#   { session_id, transcript_path, cwd, permission_mode, agent_id,
#     agent_type, hook_event_name, stop_hook_active, agent_transcript_path,
#     last_assistant_message }
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null || true)"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null || true)"
LAST_MSG="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)"
STOP_HOOK_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"

# Mandatory: agent_id. Without it we cannot identify the closing sub-agent.
[ -z "$AGENT_ID" ] && exit 0

# --- Phase 2: Bridge to dispatch via sidecar .meta.json ---
# The per-sub-agent transcript filename pattern is agent-<agent_id>.jsonl;
# its sidecar agent-<agent_id>.meta.json carries the toolUseId set by the
# harness at PreToolUse(Agent) time. This is the canonical correlation key.
TOOL_USE_ID=""
if [ -n "$TRANSCRIPT" ]; then
  META="${TRANSCRIPT%.jsonl}.meta.json"
  if [ -f "$META" ]; then
    TOOL_USE_ID="$(jq -r '.toolUseId // ""' "$META" 2>/dev/null || true)"
  fi
fi

# --- Phase 3: Count edits in the sub-agent's transcript ---
# Sub-agent tool_use calls live in {type: "assistant", message: [...]} entries
# where each block is {type, name, ...}. We count blocks where
# .name ∈ {Edit, Write, MultiEdit}. Fail-open on any error → null.
EDIT_COUNT="null"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # jq -s slurps all JSONL lines into an array; the filter walks every
  # assistant entry's .message array (which may be missing on minimal
  # transcripts → //[] guard) and selects tool_use blocks by name.
  count="$(jq -s '
    [.[]
      | select(.type == "assistant")
      | (.message // [])
      | (.[]?
          | select((type == "object") and (.type == "tool_use") and
                   ((.name == "Edit") or (.name == "Write") or (.name == "MultiEdit"))))
    ] | length
  ' "$TRANSCRIPT" 2>/dev/null || true)"
  case "$count" in
    ''|*[!0-9]*) : ;;  # not a clean integer → keep null
    *)           EDIT_COUNT="$count" ;;
  esac
fi

# --- Phase 4: Read loop-budget state ---
# delegation-gate's post-edit validator path stamps consecutive_failures
# under .claude/.delegation-state/agents/<agent_id>/. If present and
# ≥ budget, the sub-agent was about to be (or already was) loop-budget-
# capped. Either way, surface as termination cause.
EXIT_STATE="ok"
FAILS_FILE="$STATE_DIR/$AGENT_ID/consecutive_failures"
if [ -f "$FAILS_FILE" ]; then
  fails="$(cat "$FAILS_FILE" 2>/dev/null || echo 0)"
  case "$fails" in
    ''|*[!0-9]*) : ;;
    *) [ "$fails" -ge "$BUDGET" ] && EXIT_STATE="loop-budget-exceeded" ;;
  esac
fi

# --- Phase 5: Look up dispatch row, compute duration_ms ---
# Bridge: prefer tool_use_id (exact); fall back to (session_id,
# subagent_type) heuristic — last matching row wins (LIFO under parallel).
# On miss → correlation: "unmatched", duration_ms: null.
DISPATCH_TS=""
CORRELATION="unmatched"
if [ -f "$AUDIT_LOG" ]; then
  if [ -n "$TOOL_USE_ID" ]; then
    # Exact match via tool_use_id.
    DISPATCH_TS="$(jq -r --arg tu "$TOOL_USE_ID" '
      select(.tool_use_id == $tu and (.event // "") == "") | .ts
    ' "$AUDIT_LOG" 2>/dev/null | tail -1 || true)"
    [ -n "$DISPATCH_TS" ] && CORRELATION="tool_use_id"
  fi
  if [ -z "$DISPATCH_TS" ] && [ -n "$SESSION_ID" ] && [ -n "$AGENT_TYPE" ]; then
    # Heuristic fallback: same session + same subagent_type, last open dispatch.
    DISPATCH_TS="$(jq -r --arg sid "$SESSION_ID" --arg at "$AGENT_TYPE" '
      select(.session_id == $sid and .subagent_type == $at and (.event // "") == "") | .ts
    ' "$AUDIT_LOG" 2>/dev/null | tail -1 || true)"
    [ -n "$DISPATCH_TS" ] && CORRELATION="heuristic-session-type"
  fi
fi

CLOSE_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
[ -z "$CLOSE_TS" ] && exit 0

DURATION_MS="null"
if [ -n "$DISPATCH_TS" ]; then
  start_epoch="$(date -u -d "$DISPATCH_TS" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$DISPATCH_TS" +%s 2>/dev/null || true)"
  end_epoch="$(date -u -d "$CLOSE_TS" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$CLOSE_TS" +%s 2>/dev/null || true)"
  if [ -n "$start_epoch" ] && [ -n "$end_epoch" ]; then
    DURATION_MS=$(( (end_epoch - start_epoch) * 1000 ))
  fi
fi

# --- Phase 6: Truncate last_assistant_message head to 200 chars ---
LAST_MSG_HEAD="$(printf '%s' "$LAST_MSG" | tr '\n\r' '  ' | cut -c 1-200)"

# --- Phase 7: Build + append close row under flock ---
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || exit 0

# Probe writability before invoking flock (avoid the sticky-redirect gotcha
# in delegation.md § Gotchas about bare `exec` with 2>/dev/null).
if ! ( : >>"$AUDIT_LOG" ) 2>/dev/null; then
  exit 0
fi

close_row="$(jq -c -n \
  --arg ts "$CLOSE_TS" \
  --arg event "subagent-stop" \
  --arg session_id "$SESSION_ID" \
  --arg agent_id "$AGENT_ID" \
  --arg tool_use_id "$TOOL_USE_ID" \
  --arg agent_type "$AGENT_TYPE" \
  --arg exit "$EXIT_STATE" \
  --argjson duration_ms "$DURATION_MS" \
  --argjson edit_count "$EDIT_COUNT" \
  --arg last_assistant_message_head "$LAST_MSG_HEAD" \
  --arg agent_transcript_path "$TRANSCRIPT" \
  --arg correlation "$CORRELATION" \
  --argjson stop_hook_active "$STOP_HOOK_ACTIVE" \
  '{ts:$ts, event:$event, session_id:$session_id, agent_id:$agent_id,
    tool_use_id:(if $tool_use_id == "" then null else $tool_use_id end),
    agent_type:$agent_type, exit:$exit,
    duration_ms:$duration_ms, edit_count:$edit_count,
    last_assistant_message_head:$last_assistant_message_head,
    agent_transcript_path:$agent_transcript_path,
    correlation:$correlation, stop_hook_active:$stop_hook_active}' 2>/dev/null || true)"

[ -z "$close_row" ] && exit 0

# Atomic append via flock (mirror runtime-capture.sh pattern).
(
  flock 9
  printf '%s\n' "$close_row" >>"$AUDIT_LOG"
) 9>"$AUDIT_LOG.lock" 2>/dev/null || true

exit 0
