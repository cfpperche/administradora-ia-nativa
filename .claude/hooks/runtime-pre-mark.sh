#!/usr/bin/env bash
# .claude/hooks/runtime-pre-mark.sh
# PreToolUse(Bash) companion to runtime-capture.sh (spec 011).
#
# Stamps started_at (ISO-8601 UTC) for the current tool_use_id into
# .claude/.runtime-state/in-flight/<id>.t so the PostToolUse capture hook
# can compute duration_ms. Silent skip when tool_use_id is absent.
# Always exits 0.
#
# This hook intentionally does NOT do any detector matching — that work
# happens in runtime-capture.sh after the Bash result is in hand. Running
# the detector twice (here and there) would double the per-Bash latency
# for no functional gain; the trade-off is that this hook stamps a start
# time even for Bash invocations that won't end up in last-run.json.
# Acceptable: each stamp is one tiny zero-byte-ish file and the capture
# hook removes it after writing the snapshot.
#
# Reference:
#   .claude/rules/runtime-introspect.md  — full discipline
#   docs/specs/011-runtime-introspect/   — spec

set -uo pipefail

if [ "${CLAUDE_SKIP_RUNTIME_INTROSPECT:-0}" = "1" ]; then
  exit 0
fi

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_USE_ID="$(printf '%s' "$INPUT" | jq -r '.tool_use_id // ""' 2>/dev/null || true)"
[ -z "$TOOL_USE_ID" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
IN_FLIGHT_DIR="$PROJECT_DIR/.claude/.runtime-state/in-flight"

mkdir -p "$IN_FLIGHT_DIR" 2>/dev/null || exit 0

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
[ -z "$ts" ] && exit 0

# One-line file: just the ISO timestamp. Failure is silent.
printf '%s\n' "$ts" > "$IN_FLIGHT_DIR/${TOOL_USE_ID}.t" 2>/dev/null || true

exit 0
