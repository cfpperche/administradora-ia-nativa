#!/usr/bin/env bash
# .claude/hooks/secrets-scan.sh
# PreToolUse(Bash) hook — preflight shape-gate for secrets-scan (spec 007).
#
# This script is a PURE PREFLIGHT GATE. It does NOT call gitleaks.
# The actual gitleaks scan lives in .githooks/pre-commit (the native git
# pre-commit hook, activated via `git config core.hooksPath .githooks`).
#
# Responsibilities of this preflight layer:
#   1. Short-circuit unless the command is a `git commit` invocation.
#   2. Parse the `# OVERRIDE: <reason ≥10 chars>` marker from the raw command
#      string (the marker is in the Claude Code payload; git never sees it).
#   3. Reject dangerous command shapes unless a valid override is present:
#      - compound `git add ... && git commit ...` (--no-verify bypass via compound)
#      - compound with semicolon `; git commit`
#      - `git commit -a` / `-am` / `-ma` (auto-stage skips preflight audit)
#      - `git commit --no-verify` (silently bypasses native hook)
#   4. Override pass-through: when a valid override marker is present, rewrite
#      the command to prepend CLAUDE_SECRETS_OVERRIDE_REASON='<reason>' so the
#      native hook reads it and audits correctly. Exit 0 with JSON stdout.
#   5. Append one audit line per git-commit invocation to .claude/secrets-audit.jsonl.
#
# Decision values (ONLY these; "block"/"allow"/"skip-no-engine"/"override" are
# now exclusively emitted by .githooks/pre-commit):
#   "skip-not-commit"      — command is not a git commit; no audit
#   "passthrough"          — shape clean, no override; fall through to native hook
#   "reject-shape"         — dangerous shape detected; exit 2 (with cmd_shape detail)
#   "override-pass-through"— valid override; command rewritten; exit 0 with JSON
#
# Every audit row from this script includes `scan_mode: "preflight"`.
#
# Cross-layer communication:
#   When override is parsed here, the command is rewritten to prepend:
#     CLAUDE_SECRETS_OVERRIDE_REASON='<reason>'
#   The bash subprocess → git's env → native hook reads it and audits "override".
#   If the preflight hook is missing or bypassed, no env var is set and the
#   native hook blocks normally (fail-open posture on override side).
#
# Reference:
#   .githooks/pre-commit           — native git hook (actual scan)
#   .claude/rules/secrets-scan.md  — full discipline, both layers
#   docs/specs/007-secrets-scan-timing/  — design, alternatives, risks
#   docs/specs/006-secrets-scan/   — original spec this extends
#
# Lazarus vector note: the override env-var is injected via PreToolUse
# updatedInput — NOT via a post-clone script. The install step (core.hooksPath)
# must be manual per README. See .claire/rules/secrets-scan.md § Gotchas.
#
# Exit codes: 0 = allow/pass-through, 2 = reject-shape.
# jq is a hard dependency; if missing the hook fails open (exit 0).
# bash 3.2-compatible: no associative arrays, no mapfile, no `[[ =~ ]]`.
# set -uo pipefail (NOT set -euo pipefail): `-e` would abort on intentional
# non-zero returns from grep (no match → exit 1).

set -uo pipefail

# ---------------------------------------------------------------------------
# Phase 1: User-facing escape hatch
# ---------------------------------------------------------------------------
# When CLAUDE_SKIP_SECRETS_SCAN=1, exit 0 silently — no audit row.
if [ "${CLAUDE_SKIP_SECRETS_SCAN:-0}" = "1" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Stdin capture + jq availability
# ---------------------------------------------------------------------------
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  # Fail open when jq is missing.
  exit 0
fi

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || true)"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
AUDIT_LOG="$PROJECT_DIR/.claude/secrets-audit.jsonl"

# ---------------------------------------------------------------------------
# Phase 2: Short-circuit for non-commit invocations
# ---------------------------------------------------------------------------
# Matches: `git commit`, `git  commit` (double-space/tab), `git -C <path> commit`,
# `git --git-dir=... commit`, `git commit --amend`, `&& git commit`, etc.
# The start-of-word anchor prevents matching `gitcommit` or `git-commit`.
# False negatives (pathological command shapes) are acceptable — one unscanned
# commit is cheaper than blocking valid non-commit git invocations.
is_git_commit() {
  printf '%s' "$1" | grep -qE '(^|[^A-Za-z0-9_-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+commit([[:space:]]|$)'
}

if [ -z "$COMMAND" ] || ! is_git_commit "$COMMAND"; then
  # Not a git commit — short-circuit silently. No audit row (spec 007 §
  # skip-not-commit: audit row proves the hook ran; but for truly non-commit
  # commands, the volume would be enormous — audit only git-commit shapes).
  # NOTE: per DONE_WHEN spec T1, we DO audit skip-not-commit. So we must
  # proceed to the audit path even here. Fall through to audit below.
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || exit 0
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Helper inline for skip-not-commit path only.
  _agent_id_json="null"
  if [ -n "$AGENT_ID" ]; then
    _agent_id_json="$(printf '%s' "$AGENT_ID" | jq -R -s -c 'rtrimstr("\n")')"
  fi
  _session_id_json="null"
  if [ -n "$SESSION_ID" ]; then
    _session_id_json="$(printf '%s' "$SESSION_ID" | jq -R -s -c 'rtrimstr("\n")')"
  fi

  _line="$(jq -c -n \
    --arg ts "$ts" \
    --argjson session_id "$_session_id_json" \
    --argjson agent_id "$_agent_id_json" \
    --arg decision "skip-not-commit" \
    --arg scan_mode "preflight" \
    '{ts:$ts, session_id:$session_id, agent_id:$agent_id, decision:$decision, scan_mode:$scan_mode}')"

  if command -v flock >/dev/null 2>&1; then
    _lock_path="$AUDIT_LOG.lock"
    ( : >>"$_lock_path" ) 2>/dev/null || {
      printf '%s\n' "$_line" >> "$AUDIT_LOG" 2>/dev/null || true
      exit 0
    }
    exec 9>"$_lock_path"
    flock 9
    printf '%s\n' "$_line" >> "$AUDIT_LOG"
    flock -u 9
    exec 9>&-
  else
    printf '%s\n' "$_line" >> "$AUDIT_LOG" 2>/dev/null || true
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# From here on: we have a real `git commit` invocation.
# Every exit path must append exactly one audit line.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || exit 0
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Audit helper
# ---------------------------------------------------------------------------
# append_audit decision [cmd_shape_or_empty] [override_reason_or_empty]
append_audit() {
  local decision="$1"
  local cmd_shape="${2:-}"
  local override_reason="${3:-}"

  local session_id_json agent_id_json cmd_shape_json override_reason_json

  if [ -n "$SESSION_ID" ]; then
    session_id_json="$(printf '%s' "$SESSION_ID" | jq -R -s -c 'rtrimstr("\n")')"
  else
    session_id_json="null"
  fi

  if [ -n "$AGENT_ID" ]; then
    agent_id_json="$(printf '%s' "$AGENT_ID" | jq -R -s -c 'rtrimstr("\n")')"
  else
    agent_id_json="null"
  fi

  if [ -n "$cmd_shape" ]; then
    cmd_shape_json="$(printf '%s' "$cmd_shape" | jq -R -s -c 'rtrimstr("\n")')"
  else
    cmd_shape_json="null"
  fi

  if [ -n "$override_reason" ]; then
    override_reason_json="$(printf '%s' "$override_reason" | jq -R -s -c 'rtrimstr("\n")')"
  else
    override_reason_json="null"
  fi

  local line
  line="$(jq -c -n \
    --arg ts "$ts" \
    --argjson session_id "$session_id_json" \
    --argjson agent_id "$agent_id_json" \
    --arg decision "$decision" \
    --arg scan_mode "preflight" \
    --argjson cmd_shape "$cmd_shape_json" \
    --argjson override_reason "$override_reason_json" \
    '{ts:$ts, session_id:$session_id, agent_id:$agent_id, decision:$decision, scan_mode:$scan_mode, cmd_shape:$cmd_shape, override_reason:$override_reason}')"

  # Atomic append via flock when available; fall back to plain append otherwise.
  # Probe writability in a subshell BEFORE the bare `exec 9>...` redirect —
  # `exec 9>file 2>/dev/null` would permanently silence FD 2 for the rest of
  # the script, eating every block/reject message.
  # See .claude/rules/delegation.md § Gotchas (the sticky exec redirect trap).
  if command -v flock >/dev/null 2>&1; then
    local lock_path="$AUDIT_LOG.lock"
    ( : >>"$lock_path" ) 2>/dev/null || {
      printf '%s\n' "$line" >> "$AUDIT_LOG" 2>/dev/null || true
      return 0
    }
    exec 9>"$lock_path"
    flock 9
    printf '%s\n' "$line" >> "$AUDIT_LOG"
    flock -u 9
    exec 9>&-
  else
    printf '%s\n' "$line" >> "$AUDIT_LOG" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Phase 3: Override marker parsing
# ---------------------------------------------------------------------------
# Detection: `^[[:space:]]*# OVERRIDE: <reason>` anchored at start-of-line.
# Same regex shipped in spec 006, traceable to the spec 002 fix that closed a
# false-positive where `# OVERRIDE:` appearing INSIDE a quoted string (e.g.
# `git commit -m "see the # OVERRIDE: docs"`) was matching and bypassing the
# scan. The anchor is load-bearing — DO NOT relax it to an inline-trailing
# fallback without re-opening that regression.
#
# To use the override on a single-shape `git commit` invocation, put the
# marker on its own line of the Bash command string:
#   git commit -m "..."
#   # OVERRIDE: <reason ≥10 chars>
# The bash subprocess treats line 2 as a no-op comment; the hook sees line 2
# as start-of-line text and matches.
override_reason=""
override_valid=0
override_too_short=0
short_reason_seen=""

override_line=""
override_line="$(printf '%s' "$COMMAND" | grep -E '^[[:space:]]*# OVERRIDE: ' | head -1 | sed -e 's/^[[:space:]]*//' 2>/dev/null || true)"

if [ -n "$override_line" ]; then
  # Strip the marker prefix to isolate the reason text.
  reason="${override_line#'# OVERRIDE: '}"
  # Trim leading/trailing whitespace.
  reason="$(printf '%s' "$reason" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  if [ "${#reason}" -ge 10 ]; then
    override_reason="$reason"
    override_valid=1
  else
    override_too_short=1
    short_reason_seen="$reason"
  fi
fi

# ---------------------------------------------------------------------------
# Override-too-short path: reject with explicit stderr. No shape check needed.
# Audits as reject-shape with cmd_shape "override-too-short".
# ---------------------------------------------------------------------------
if [ "$override_too_short" -eq 1 ]; then
  printf '%s\n' "secrets-scan: override reason must be ≥10 characters, got \"$short_reason_seen\"" >&2
  append_audit "reject-shape" "override-too-short" "$short_reason_seen"
  exit 2
fi

# ---------------------------------------------------------------------------
# Phase 4: Command-shape detection
# ---------------------------------------------------------------------------
# Each shape is detected independently; the first match wins.
# When a valid override is present, shape rejection is skipped — the override
# pass-through is emitted instead.

detected_shape=""

# Shape 1: compound with && containing git commit
# Detect ` && git commit` or `&&git commit` (with any surrounding whitespace).
if printf '%s' "$COMMAND" | grep -qE '&&[[:space:]]*git[[:space:]]+commit'; then
  detected_shape="compound-and"
fi

# Shape 2: compound with semicolon containing git commit
# Detect `; git commit` or `;git commit` (with or without trailing space).
if [ -z "$detected_shape" ]; then
  if printf '%s' "$COMMAND" | grep -qE ';[[:space:]]*git[[:space:]]+commit'; then
    detected_shape="compound-semicolon"
  fi
fi

# Shape 3: git commit -a (auto-stage flag)
# Matches: -a, -am, -ma (any short-flag bundle containing 'a' after git commit).
# Does NOT match: --all (long form is not in the rejection list).
# Strategy: extract the portion after `git commit` and look for a standalone
# short-flag token that contains 'a' (but not '--all' or '--amend').
if [ -z "$detected_shape" ]; then
  # Strip everything up to and including the first `git commit` occurrence.
  after_commit="$(printf '%s' "$COMMAND" | sed -e 's/.*git[[:space:]]\{1,\}commit//')"
  # Look for a short-flag token (-x or -xy bundles) containing 'a'.
  # A short flag token starts with a single dash (not double dash) followed by
  # one or more letters. We must NOT match --amend, --all, etc.
  # grep -E: token boundary = space or start, followed by '-' (not '--'), letters
  # containing 'a'.
  if printf '%s' "$after_commit" | grep -qE '(^|[[:space:]])-[A-Za-z]*a[A-Za-z]*([[:space:]]|$)'; then
    detected_shape="git-commit-dash-a"
  fi
fi

# Shape 4: --no-verify flag (silently bypasses native pre-commit hook)
if [ -z "$detected_shape" ]; then
  if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])--no-verify([[:space:]]|$)'; then
    detected_shape="git-commit-no-verify"
  fi
fi

# ---------------------------------------------------------------------------
# Phase 5: Shape-gate decision
# ---------------------------------------------------------------------------

if [ -n "$detected_shape" ]; then
  if [ "$override_valid" -eq 1 ]; then
    # Valid override present AND shape is rejected — emit override pass-through.
    # (falls through to the override pass-through block below)
    :
  else
    # No valid override — reject with verbatim stderr template (spec 007 Task 4).
    case "$detected_shape" in
      compound-and|compound-semicolon)
        cat >&2 <<'EOF'
secrets-scan: compound 'git add ... && git commit ...' bypasses the native pre-commit hook. Run as two separate Bash invocations instead:
  git add <files>
  git commit -m "..."
EOF
        ;;
      git-commit-dash-a)
        cat >&2 <<'EOF'
secrets-scan: 'git commit -a' bypasses the preflight audit. Run as:
  git add -u
  git commit -m "..."
EOF
        ;;
      git-commit-no-verify)
        cat >&2 <<'EOF'
secrets-scan: '--no-verify' disables the native pre-commit hook. Remove the flag, or add an inline '# OVERRIDE: <reason ≥10 chars>' marker if the bypass is deliberate.
EOF
        ;;
    esac
    append_audit "reject-shape" "$detected_shape" ""
    exit 2
  fi
fi

# ---------------------------------------------------------------------------
# Phase 6: Override pass-through (valid override marker present)
# ---------------------------------------------------------------------------
# Fires when: (a) override valid + shape was rejected, OR
#             (b) override valid + shape is clean.
# In both cases: rewrite command to prepend the env-var assignment.
if [ "$override_valid" -eq 1 ]; then
  # Single-quote-escape the reason against shell injection.
  # Canonical close-escape-open idiom: replace each ' with '\'' in the reason.
  # NOT printf %q (bash-only, non-portable per constraints).
  escaped_reason="$(printf '%s' "$override_reason" | sed "s/'/'\\\\''/g")"

  # Build the rewritten command: prepend env-var assignment as a STANDALONE
  # statement followed by `;`. The `export` makes the var inheritable; the `;`
  # separates the assignment from the original command so the chain that
  # follows sees the var.
  #
  # DO NOT use the `VAR=val cmd` prefix form here — in bash, that form scopes
  # the assignment to the single command it prefixes, so the env var is NOT
  # inherited by anything chained with `&&` or `;`. The override use case is
  # explicitly about compound `git add ... && git commit ...` shapes (V4),
  # which would otherwise lose the env var on the `git commit` half and
  # block in the native hook.
  rewritten_cmd="export CLAUDE_SECRETS_OVERRIDE_REASON='${escaped_reason}'; ${COMMAND}"

  # Emit JSON stdout for hookSpecificOutput.updatedInput.
  # Use jq to build the JSON safely (no manual quoting of the command string).
  rewritten_json="$(jq -c -n \
    --arg cmd "$rewritten_cmd" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":$cmd}}}')"

  printf '%s\n' "$rewritten_json"

  append_audit "override-pass-through" "${detected_shape:-}" "$override_reason"
  exit 0
fi

# ---------------------------------------------------------------------------
# Phase 7: Passthrough — shape clean, no override
# ---------------------------------------------------------------------------
# Exit 0 silently; the harness will run the command unchanged.
# The native pre-commit hook does the actual scan.
append_audit "passthrough" "" ""
exit 0
