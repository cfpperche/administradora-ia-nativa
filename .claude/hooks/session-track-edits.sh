#!/usr/bin/env bash
# Spec 030: PostToolUse(Edit|Write|MultiEdit) tracker that appends each edited
# file_path to `.claude/.session-state/<session_id>/edited-files.txt`. The Stop
# hook reads this as the primary signal for "did THIS session edit anything?",
# replacing spec 023's worktree-delta-compare on the primary path (spec 023
# stays live as fallback for legacy sessions; Bash-driven edits in tracker-
# enabled sessions become a documented silent miss).
#
# Escape hatch: `CLAUDE_SKIP_SESSION_HOOKS=1` short-circuits like the rest of
# the session-state machinery. Fails OPEN on every error path — a broken
# tracker must never block a tool call.
#
# Measured latency (2026-05-16, Linux/WSL2): ~30-50ms per invocation; bash
# startup + 2× jq + realpath dominate. Acceptable next to PostToolUse(Edit)
# siblings like post-edit-validate.sh which run multi-second validator suites.

set -euo pipefail

[[ "${CLAUDE_SKIP_SESSION_HOOKS:-0}" == "1" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
SESSION_STATE_ROOT="$PROJECT_DIR/.claude/.session-state"

INPUT="$(cat 2>/dev/null || true)"
[[ -n "$INPUT" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

SESSION_ID_RAW="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
if [[ -n "$SESSION_ID_RAW" && "$SESSION_ID_RAW" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  SESSION_ID="$SESSION_ID_RAW"
else
  SESSION_ID="unknown"
fi

FILE_PATH_RAW="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[[ -n "$FILE_PATH_RAW" ]] || exit 0

# Normalize to project-relative.
#
# Absolute path → use realpath to make it project-relative (handles symlinks
# and embedded `..`). Relative path → assume it's already project-relative.
# (Calling realpath on a relative path would resolve it against $PWD, which
# is not guaranteed to be $PROJECT_DIR — e.g. test harnesses that invoke the
# hook from a sibling cwd.)
NORM_PATH=""
if [[ "$FILE_PATH_RAW" = /* ]]; then
  if command -v realpath >/dev/null 2>&1; then
    NORM_PATH="$(realpath --relative-to="$PROJECT_DIR" "$FILE_PATH_RAW" 2>/dev/null || true)"
  fi
fi
[[ -n "$NORM_PATH" ]] || NORM_PATH="$FILE_PATH_RAW"

STATE_DIR="$SESSION_STATE_ROOT/$SESSION_ID"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
TRACK_FILE="$STATE_DIR/edited-files.txt"

# Dedup-and-append under flock. The lock guards against parallel sub-agent
# tool calls in the same session writing interleaved lines.
(
  flock 9
  if [[ ! -f "$TRACK_FILE" ]] || ! grep -Fxq -- "$NORM_PATH" "$TRACK_FILE" 2>/dev/null; then
    printf '%s\n' "$NORM_PATH" >>"$TRACK_FILE"
  fi
) 9>"$TRACK_FILE.lock" 2>/dev/null || true

exit 0
