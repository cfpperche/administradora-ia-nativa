#!/usr/bin/env bash
# SessionStart hook: inject context appropriate to the start source.
#
# - startup / resume / clear → SESSION.md (cross-session handoff)
# - compact                  → COMPACT_NOTES.md (in-session WIP at moment of compact)
#
# State is isolated per-session_id (spec 017): markers live at
# `<.session-state>/<session_id>/{started-at,nagged}`. Parallel Claude Code
# sessions in the same project don't interfere with each other's nag state.
# Sanitization (regex `^[a-zA-Z0-9_-]+$`) defends against path traversal in
# malformed/malicious payloads; failures fall to the literal `unknown` subdir.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_STATE_ROOT="$PROJECT_DIR/.claude/.session-state"
SESSION_FILE="$PROJECT_DIR/.claude/SESSION.md"
NOTES_FILE="$PROJECT_DIR/.claude/COMPACT_NOTES.md"

# Read stdin payload FIRST so we can extract session_id before any state ops.
INPUT="$(cat 2>/dev/null || true)"

SOURCE="startup"
SESSION_ID_RAW=""
if [[ -n "$INPUT" ]] && command -v jq >/dev/null 2>&1; then
  SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo startup)"
  SESSION_ID_RAW="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi

# Sanitize session_id: only [a-zA-Z0-9_-]+; anything else falls to "unknown".
if [[ -n "$SESSION_ID_RAW" && "$SESSION_ID_RAW" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  SESSION_ID="$SESSION_ID_RAW"
else
  SESSION_ID="unknown"
fi

STATE_DIR="$SESSION_STATE_ROOT/$SESSION_ID"
mkdir -p "$STATE_DIR"
touch "$STATE_DIR/started-at"
rm -f "$STATE_DIR/nagged"

# Spec 030: create an empty edited-files.txt marker so Stop can distinguish
# "tracker is installed and this session edited nothing" (bystander → exit 0)
# from "tracker is not installed at all" (legacy session → fall to spec 023).
# The tracker hook only fires on Edit/Write/MultiEdit, so without this seed a
# real bystander session would have no file and fall to the legacy path.
touch "$STATE_DIR/edited-files.txt"

# Spec 023: snapshot `git status --porcelain` so Stop can discriminate
# "this session changed nothing" (carryover or no-op) from "this session
# has uncommitted WIP that needs a SESSION.md handoff". Best-effort —
# absence triggers Stop's fallback to today's mtime-only logic.
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$PROJECT_DIR" status --porcelain >"$STATE_DIR/start-porcelain.txt" 2>/dev/null || true
fi

if [[ "$SOURCE" == "compact" && -f "$NOTES_FILE" ]]; then
  printf '=== COMPACT_NOTES.md (pre-compact snapshot — raw signal /compact would have lost) ===\n'
  cat "$NOTES_FILE"
  printf '\n=== end COMPACT_NOTES.md ===\n'
elif [[ -f "$SESSION_FILE" ]]; then
  printf '=== SESSION.md (handoff from prior session) ===\n'
  cat "$SESSION_FILE"
  printf '\n=== end SESSION.md ===\n'
fi

# Runtime-introspect (spec 011): point the agent at the probe tool so it can
# verify its own edits via cached test/build snapshots. Silent when the tool
# is absent — the capacity isn't installed in every fork.
PROBE_TOOL="$PROJECT_DIR/.claude/tools/probe.sh"
if [[ -x "$PROBE_TOOL" ]]; then
  printf '\n=== runtime-introspect ===\n'
  printf 'Probe the latest captured test/build run with: bash .claude/tools/probe.sh last-run\n'
  printf '=== end runtime-introspect ===\n'
fi

# githooks-activation (spec 018): surface the manual core.hooksPath activation
# command when .githooks/ is present but config doesn't point at it.
# Auto-activation is refused on purpose (Lazarus vector — see
# .claude/rules/secrets-scan.md § Gotchas); the passive advisory closes the
# discoverability gap without crossing into automation.
if [[ -d "$PROJECT_DIR/.githooks" && "${CLAUDE_SKIP_GITHOOKS_HINT:-0}" != "1" ]]; then
  current_hookspath="$(git -C "$PROJECT_DIR" config --get core.hooksPath 2>/dev/null || true)"
  if [[ "$current_hookspath" != ".githooks" ]]; then
    printf '\n=== githooks-activation ===\n'
    printf 'Native git hooks NOT activated (gitleaks pre-commit inert).\n'
    printf 'Run once: git config core.hooksPath .githooks\n'
    printf '=== end githooks-activation ===\n'
  fi
fi

# Cleanup (spec 017): best-effort removal of session-state subdirs older than
# 7 days. Failure NEVER blocks the hook — silenced with 2>/dev/null || true.
find "$SESSION_STATE_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
