#!/usr/bin/env bash
# .claude/hooks/delegation-gate.sh
# PreToolUse(Agent) hook enforcing structured delegation handoffs.
#
# Phases (fixed order):
#   1. Override marker — `# OVERRIDE: <reason ≥10 chars>` (case-sensitive)
#   2. 5-field validation — TASK / CONTEXT / CONSTRAINTS / (DELIVERABLE | DONE_WHEN)
#   3. Audit append (allow path only) — JSONL line per plan.md schema
#   4. Escalation advisory (allow path only) — score 5 signals; advise opus if >=2
#
# Exit codes: 0 = allow, 2 = block (Claude Code re-prompts the agent with stderr).
# jq is a hard dependency; if missing, the hook fails closed (exit 2).
#
# bash 3.2-compatible: no associative arrays, no mapfile, no `[[ =~ ]]`.

set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'EOF'
delegation-gate: jq not found.
Failing closed (exit 2) — install jq to restore Agent tool usage.
EOF
  exit 2
fi

PROMPT="$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)"
if [ $? -ne 0 ]; then
  cat >&2 <<'EOF'
delegation-gate: failed to parse PreToolUse JSON.
Failing closed (exit 2).
EOF
  exit 2
fi

[ -z "$PROMPT" ] && exit 0

SUBAGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // ""')"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""')"
TOOL_USE_ID="$(printf '%s' "$INPUT" | jq -r '.tool_use_id // ""')"
MODEL_SPECIFIED="$(printf '%s' "$INPUT" | jq -r '.tool_input | has("model")')"
MODEL="$(printf '%s' "$INPUT" | jq -r '.tool_input.model // ""')"
ISOLATION="$(printf '%s' "$INPUT" | jq -r '.tool_input.isolation // ""')"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
AUDIT_LOG="$PROJECT_DIR/.claude/delegation-audit.jsonl"

# --- Phase 1: Override marker ---
override_reason=""
override_present=0
override_too_short=0

# Start-of-line anchor (with optional leading whitespace) so prose that
# *documents* the marker mid-paragraph is not treated as a bypass.
override_line="$(printf '%s' "$PROMPT" | grep -E '^[[:space:]]*# OVERRIDE: ' | head -1 | sed -e 's/^[[:space:]]*//' || true)"
if [ -n "$override_line" ]; then
  override_present=1
  reason="${override_line#'# OVERRIDE: '}"
  reason="$(printf '%s' "$reason" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [ ${#reason} -ge 10 ]; then
    override_reason="$reason"
  else
    override_too_short=1
  fi
fi

# --- Phase 2: 5-field validation (always runs; override only suppresses block) ---
# Audit `formatted` reflects the actual check, so a future analyst can
# distinguish defensive override use (formatted=true, override=set) from
# real bypass use (formatted=false, override=set).
formatted="false"
has_task=0
has_context=0
has_constraints=0
has_deliverable=0
has_done_when=0

if printf '%s' "$PROMPT" | grep -qiE '(^|[^A-Za-z])TASK:'; then has_task=1; fi
if printf '%s' "$PROMPT" | grep -qiE '(^|[^A-Za-z])CONTEXT:'; then has_context=1; fi
if printf '%s' "$PROMPT" | grep -qiE '(^|[^A-Za-z])CONSTRAINTS:'; then has_constraints=1; fi
if printf '%s' "$PROMPT" | grep -qiE '(^|[^A-Za-z])DELIVERABLE:'; then has_deliverable=1; fi
if printf '%s' "$PROMPT" | grep -qiE '(^|[^A-Za-z])DONE_WHEN:'; then has_done_when=1; fi

has_outcome=0
if [ "$has_deliverable" -eq 1 ] || [ "$has_done_when" -eq 1 ]; then
  has_outcome=1
fi

if [ "$has_task" -eq 1 ] && [ "$has_context" -eq 1 ] && [ "$has_constraints" -eq 1 ] && [ "$has_outcome" -eq 1 ]; then
  formatted="true"
fi

if [ "$formatted" = "false" ] && [ -z "$override_reason" ]; then
  missing=""
  [ "$has_task" -eq 0 ] && missing="$missing TASK"
  [ "$has_context" -eq 0 ] && missing="$missing CONTEXT"
  [ "$has_constraints" -eq 0 ] && missing="$missing CONSTRAINTS"
  [ "$has_outcome" -eq 0 ] && missing="$missing DELIVERABLE-or-DONE_WHEN"

  cat >&2 <<EOF
delegation-gate: blocked [missing-fields]

Missing required field(s):$missing

Sub-agent dispatches in this project must use the 5-field handoff so
the delegated agent has scope, constraints, and a verifiable outcome
instead of inventing its own framing.

Canonical template (case-insensitive field names; either DELIVERABLE
or DONE_WHEN satisfies the outcome slot — both are accepted):

  TASK: <one sentence — what to do>
  CONTEXT: <files/paths/links the sub-agent should read first>
  CONSTRAINTS: <what NOT to do; budgets; style; scope guardrails>
  DELIVERABLE: <concrete artifact — file path, PR, summary shape>
  DONE_WHEN: <verifiable condition — tests pass, file exists, etc.>

Escape hatch: prepend a line "# OVERRIDE: <reason ≥10 chars>" to the
prompt to bypass the field check. The override reason is logged.
The marker is recognized only at the start of a line (optional leading
whitespace allowed) so prose that documents the marker does not trip it.
EOF

  if [ "$override_too_short" -eq 1 ]; then
    cat >&2 <<'EOF'

Note: an `# OVERRIDE:` marker was found but the reason was shorter than
10 characters after trimming. Lengthen the reason or fill the 5 fields.
EOF
  fi

  cat >&2 <<'EOF'

Spec: docs/specs/002-delegation/spec.md
EOF
  exit 2
fi

# --- Phase 3: Audit append (allow path) ---
mkdir -p "$(dirname "$AUDIT_LOG")"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# task_summary: first 120 chars of TASK: value if present, else first 120 chars of prompt.
# Newlines stripped.
task_summary=""
task_value="$(printf '%s' "$PROMPT" | grep -iE '(^|[^A-Za-z])TASK:' | head -1 || true)"
if [ -n "$task_value" ]; then
  task_summary="$(printf '%s' "$task_value" | sed -E 's/.*[Tt][Aa][Ss][Kk]:[[:space:]]*//')"
else
  task_summary="$PROMPT"
fi
task_summary="$(printf '%s' "$task_summary" | tr '\n\r' '  ' | cut -c 1-120)"

# --- Phase 4: Escalation signals (score on prompt) ---
signals_json="[]"
signals_list=""
score=0

if printf '%s' "$PROMPT" | grep -qiE '\b(10|[1-9][0-9])\+?[[:space:]]+files\b'; then
  signals_list="$signals_list large-fileset"
  score=$((score + 1))
fi

# multi-integration: 3 occurrences of integrate|integration|api in the prompt
mi_count="$(printf '%s' "$PROMPT" | grep -oiE '(integrate|integration|api)' | wc -l | tr -d ' ')"
if [ "${mi_count:-0}" -ge 3 ]; then
  signals_list="$signals_list multi-integration"
  score=$((score + 1))
fi

# cross-domain: AND of frontend-set and backend-set hits
cd_front=0
cd_back=0
if printf '%s' "$PROMPT" | grep -qiE '(frontend|ui|react|component)'; then cd_front=1; fi
if printf '%s' "$PROMPT" | grep -qiE '(backend|server|api|database)'; then cd_back=1; fi
if [ "$cd_front" -eq 1 ] && [ "$cd_back" -eq 1 ]; then
  signals_list="$signals_list cross-domain"
  score=$((score + 1))
fi

if printf '%s' "$PROMPT" | grep -qiE '\b(schema|migration|migrate|database[[:space:]]+model|er[- ]diagram)\b'; then
  signals_list="$signals_list schema-data"
  score=$((score + 1))
fi

if printf '%s' "$PROMPT" | grep -qiE '\b(auth|authentication|payment|pii|credential|secret|token|encryption)\b'; then
  signals_list="$signals_list security"
  score=$((score + 1))
fi

if [ -n "$signals_list" ]; then
  signals_json="$(printf '%s' "$signals_list" | tr ' ' '\n' | grep -v '^$' | jq -R . | jq -s -c .)"
fi

# Two distinct advisories share the same advisory_emitted=true exit:
#   "model-discipline" — model_specified=false AND any signal fires.
#     Different from "escalation": the parent never made a conscious model
#     choice, so the first step is to declare one (via the task-fit table)
#     before deciding whether that choice was opus-worthy.
#   "escalation" — score>=2 AND model_specified=true AND model!=opus.
#     The parent picked a non-opus model for a task with multiple complexity
#     signals; nudge toward opus.
# The "unspecified" branch wins when both could fire — declaring a model is
# the prerequisite to recommending opus.
advisory_emitted="false"
advisory_kind="null"
if [ "$MODEL_SPECIFIED" = "false" ] && [ "$score" -ge 1 ]; then
  advisory_emitted="true"
  advisory_kind="\"model-discipline\""
elif [ "$score" -ge 2 ] && [ "$MODEL" != "opus" ]; then
  advisory_emitted="true"
  advisory_kind="\"escalation\""
fi

# Build override JSON value (string or null)
if [ -n "$override_reason" ]; then
  override_field="$(printf '%s' "$override_reason" | jq -R -s -c 'rtrimstr("\n")')"
else
  override_field="null"
fi

# model field: emit string if specified, else null. model_specified reflects has("model").
if [ "$MODEL_SPECIFIED" = "true" ]; then
  model_field="$(printf '%s' "$MODEL" | jq -R -s -c 'rtrimstr("\n")')"
else
  model_field="null"
fi

audit_line="$(jq -c -n \
  --arg ts "$ts" \
  --arg session_id "$SESSION_ID" \
  --arg tool_use_id "$TOOL_USE_ID" \
  --arg subagent_type "$SUBAGENT_TYPE" \
  --argjson model "$model_field" \
  --argjson model_specified "$MODEL_SPECIFIED" \
  --arg isolation "$ISOLATION" \
  --argjson formatted "$formatted" \
  --argjson override "$override_field" \
  --argjson advisory_emitted "$advisory_emitted" \
  --argjson advisory_kind "$advisory_kind" \
  --argjson escalation_signals "$signals_json" \
  --arg task_summary "$task_summary" \
  '{ts:$ts, session_id:$session_id, tool_use_id:$tool_use_id, subagent_type:$subagent_type, model:$model, model_specified:$model_specified, isolation:$isolation, formatted:$formatted, override:$override, advisory_emitted:$advisory_emitted, advisory_kind:$advisory_kind, escalation_signals:$escalation_signals, task_summary:$task_summary}')"

printf '%s\n' "$audit_line" >> "$AUDIT_LOG"

if [ "$advisory_emitted" = "true" ]; then
  signal_csv="$(printf '%s' "$signals_list" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\+/, /g')"
  if [ "$advisory_kind" = "\"model-discipline\"" ]; then
    advisory_text="Delegation has no explicit \`model\` field. With complexity signal(s) firing (${signal_csv}), declare a model explicitly using the task-fit table:

  Mechanical implementation (detailed brief, patterns to copy)        -> sonnet
  Schema/protocol lookup, short research with an obvious source       -> haiku or sonnet
  Multi-source comparative research with opinionated recommendation   -> opus if >=2 signals (cross-domain + security/schema), else sonnet
  Architecture review, subtle trade-offs                              -> opus
  Exploratory debugging without clear hypothesis                      -> opus

Without an explicit model, the harness default for this subagent type runs — which may not match the task's actual reasoning needs. This is advisory only; the call has been allowed."
  else
    advisory_text="Delegation appears complex (signals: $signal_csv). Consider re-issuing with model: \"opus\" for stronger reasoning. This is advisory only — the call has been allowed."
  fi
  jq -c -n \
    --arg msg "$advisory_text" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", additionalContext:$msg}}'
fi

exit 0
