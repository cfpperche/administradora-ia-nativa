#!/usr/bin/env bash
# .claude/hooks/post-edit-validate.sh
# PostToolUse(Edit|Write|MultiEdit) hook: re-runs the project validator after
# a delegated sub-agent edits a file. Parent edits are exempt (actor detection
# via presence of `agent_id` in the payload — confirmed by probe; see
# docs/specs/002-delegation/plan.md "Approach" #2).
#
# Exit codes: 0 = allow / silent, 2 = block with stderr surfaced to the agent.
# Fail-open posture: missing/broken validator must NEVER permanently block.
#
# bash 3.2-compatible: no associative arrays, no mapfile.

set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
[ -z "$AGENT_ID" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$PROJECT_DIR/.claude/.delegation-state"
AGENTS_DIR="$STATE_DIR/agents"
LOCK_PATH="$STATE_DIR/validate.lock"
STATE_FILE="$AGENTS_DIR/$AGENT_ID"
CAP="${CLAUDE_DELEGATION_LOOP_BUDGET:-5}"

# Spec 063: worktree-aware validator scoping. Derive cwd from the git toplevel
# of the edit's file path so worktree-isolated sub-agent edits are validated
# against the worktree state, not stale parent state. Safe regardless of
# isolation declaration — parent-tree edits resolve to $PROJECT_DIR; cross-
# directory edits resolve to whatever git toplevel contains them.
# Fail-open: git failure (non-git scratch dir, etc.) falls back to $PROJECT_DIR.
EDIT_FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)"
VALIDATOR_CWD="$PROJECT_DIR"
if [ -n "$EDIT_FILE" ]; then
  edit_dir="$(dirname "$EDIT_FILE" 2>/dev/null || echo "")"
  if [ -n "$edit_dir" ] && [ -d "$edit_dir" ]; then
    toplevel="$(git -C "$edit_dir" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$toplevel" ] && VALIDATOR_CWD="$toplevel"
  fi
fi

mkdir -p "$AGENTS_DIR" 2>/dev/null || exit 0

# Validator resolution chain — first executable wins; otherwise fail-open.
VALIDATOR=""
if [ -n "${CLAUDE_DELEGATION_VALIDATOR:-}" ] && [ -x "${CLAUDE_DELEGATION_VALIDATOR:-}" ]; then
  VALIDATOR="$CLAUDE_DELEGATION_VALIDATOR"
elif [ -x "$PROJECT_DIR/.claude/validators/run.sh" ]; then
  VALIDATOR="$PROJECT_DIR/.claude/validators/run.sh"
else
  exit 0
fi

# Lock acquisition: skip-if-busy is the contract — concurrent edits must NOT
# stack validations (validator is deterministic over the working tree).
LOCK_MODE=""
LOCK_FD=""
if command -v flock >/dev/null 2>&1; then
  LOCK_MODE="flock"
  # Bare `exec 9>...` with no command applies redirections to the current
  # shell — appending `2>/dev/null` would permanently silence FD 2 for the
  # rest of the script (eats every blocking message). Guard with a subshell
  # check on writability instead.
  ( : >>"$LOCK_PATH" ) 2>/dev/null || exit 0
  exec 9>"$LOCK_PATH"
  flock -n 9 || exit 0
  LOCK_FD=9
else
  LOCK_MODE="mkdir"
  LOCKDIR="${LOCK_PATH}.d"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    exit 0
  fi
  trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT
fi

# Capture stdout (JSON contract) and stderr (advisory lines like
# `lint-advisory:` from spec 013) separately. Pre-013 the validator was silent
# on its own stderr so a `2>&1` merge did no harm; once it started emitting
# advisories that merge would prepend non-JSON text and break `jq` parsing.
VALIDATOR_STDERR_FILE="$(mktemp 2>/dev/null || mktemp -t validator-own-stderr)"
VALIDATOR_OUT="$( ( cd "$VALIDATOR_CWD" && "$VALIDATOR" ) 2>"$VALIDATOR_STDERR_FILE" || true )"
VALIDATOR_OWN_STDERR="$(cat "$VALIDATOR_STDERR_FILE" 2>/dev/null || true)"
rm -f "$VALIDATOR_STDERR_FILE"

# Surface validator-emitted stderr to the agent (next-turn context) regardless
# of pass/fail. Advisory lines (`lint-advisory:`, etc.) reach the agent without
# polluting the JSON parse below.
if [ -n "$VALIDATOR_OWN_STDERR" ]; then
  printf '%s\n' "$VALIDATOR_OWN_STDERR" >&2
fi

# `.ok // empty` would collapse `false` and missing into the same empty string;
# use `has("ok")` to keep them distinguishable.
OK="$(printf '%s' "$VALIDATOR_OUT" | jq -r 'if type == "object" and has("ok") then (.ok | tostring) else "" end' 2>/dev/null || true)"

# Fail-open on broken validator output (missing/unparseable `ok`).
if [ "$OK" != "true" ] && [ "$OK" != "false" ]; then
  exit 0
fi

if [ "$OK" = "true" ]; then
  : > "$STATE_FILE" 2>/dev/null || true
  printf '0' > "$STATE_FILE" 2>/dev/null || true

  # TDD advisory surfacing (spec 005). Validator may append a `warnings` array
  # on stack-detected paths; echo each message to stderr so the agent sees it
  # on its next turn. Always exit 0 — advisories never block.
  WARNINGS_COUNT="$(printf '%s' "$VALIDATOR_OUT" | jq -r 'if type == "object" and has("warnings") then (.warnings | length) else 0 end' 2>/dev/null || true)"
  if [ "${WARNINGS_COUNT:-0}" -gt 0 ]; then
    printf '%s' "$VALIDATOR_OUT" | jq -r '.warnings[] | "tdd-advisory: " + .message' >&2
  fi

  exit 0
fi

COUNT=0
if [ -f "$STATE_FILE" ]; then
  COUNT="$(tr -cd '0-9' < "$STATE_FILE" 2>/dev/null || true)"
  [ -z "$COUNT" ] && COUNT=0
fi

# Cap-clamp: don't keep incrementing past the budget — the agent is already
# being told to stop; further increments serve no purpose.
if [ "$COUNT" -lt "$CAP" ]; then
  COUNT=$((COUNT + 1))
  printf '%s' "$COUNT" > "$STATE_FILE" 2>/dev/null || true
fi

V_CMD="$(printf '%s' "$VALIDATOR_OUT" | jq -r '.command // ""' 2>/dev/null || true)"
V_EXIT="$(printf '%s' "$VALIDATOR_OUT" | jq -r '.exit // ""' 2>/dev/null || true)"
V_STDOUT="$(printf '%s' "$VALIDATOR_OUT" | jq -r '.stdout // ""' 2>/dev/null | tail -c 1024 || true)"
V_STDERR="$(printf '%s' "$VALIDATOR_OUT" | jq -r '.stderr // ""' 2>/dev/null | tail -c 1024 || true)"

if [ "$COUNT" -ge "$CAP" ]; then
  cat >&2 <<EOF
LOOP BUDGET EXCEEDED — sub-agent $AGENT_ID has failed validation $COUNT times
(cap = $CAP).

Stop editing. Report a partial result to the parent agent describing:
  - what you accomplished
  - what failed validation
  - what remains for a human or fresh delegation to complete

Validator command: $V_CMD
Validator exit:    $V_EXIT
--- validator stdout (tail) ---
$V_STDOUT
--- validator stderr (tail) ---
$V_STDERR

Spec: docs/specs/002-delegation/spec.md
EOF
  exit 2
fi

cat >&2 <<EOF
post-edit-validate: validation failed (attempt $COUNT of $CAP)

Validator command: $V_CMD
Validator exit:    $V_EXIT
--- validator stdout (tail) ---
$V_STDOUT
--- validator stderr (tail) ---
$V_STDERR

Fix the failing checks before declaring the task done. The validator will
re-run on your next edit. After $CAP consecutive failures the loop budget
trips and you must report a partial result instead of continuing.

Spec: docs/specs/002-delegation/spec.md
EOF

exit 2
