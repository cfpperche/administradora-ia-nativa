#!/usr/bin/env bash
# .claude/tests/runtime-introspect/05-stale-flag.sh
# V5 — Scenario: probe flags stale snapshot.
#
# Given a last-run.json with started_at predating the current
# .claude/.session-state/started-at, probe.sh last-run must include
# `stale: true` in its header.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
PROBE="$AGENT0_ROOT/.claude/tools/probe.sh"

TMPDIR="$(mktemp -d -t spec-011-V5-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude/.runtime-state" "$TMPDIR/.claude/.session-state/V5-test-session"
export CLAUDE_PROJECT_DIR="$TMPDIR"

# Session started "now"; snapshot from a minute ago = stale.
# Spec 017: session-state is per-session_id, so the marker lives in a subdir.
session_now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
touch -d "$session_now" "$TMPDIR/.claude/.session-state/V5-test-session/started-at"

# Snapshot started_at = 5 minutes BEFORE the session-state touch.
snapshot_started_at="$(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)"

jq -n --arg sa "$snapshot_started_at" '{
  command: "bun test",
  detector: "bun-test",
  exit: 0,
  started_at: $sa,
  ended_at: $sa,
  duration_ms: 100,
  session_id: "V5-session",
  agent_id: null,
  stdout_head: "ok",
  stdout_tail: "",
  stdout_truncated: false,
  stderr_head: "",
  stderr_tail: "",
  stderr_truncated: false
}' > "$TMPDIR/.claude/.runtime-state/last-run.json"

out="$(bash "$PROBE" last-run 2>&1)"

if ! printf '%s' "$out" | grep -qE '^stale: true'; then
  printf 'FAIL: probe output missing `stale: true` line\n'
  printf 'Got:\n%s\n' "$out"
  exit 1
fi

# Fresh snapshot (now) should be NOT stale.
fresh_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n --arg sa "$fresh_started_at" '{
  command: "bun test",
  detector: "bun-test",
  exit: 0,
  started_at: $sa,
  ended_at: $sa,
  duration_ms: 100,
  session_id: "V5-session",
  agent_id: null,
  stdout_head: "ok",
  stdout_tail: "",
  stdout_truncated: false,
  stderr_head: "",
  stderr_tail: "",
  stderr_truncated: false
}' > "$TMPDIR/.claude/.runtime-state/last-run.json"

out_fresh="$(bash "$PROBE" last-run 2>&1)"

if ! printf '%s' "$out_fresh" | grep -qE '^stale: false'; then
  printf 'FAIL: fresh snapshot reported stale\n'
  printf 'Got:\n%s\n' "$out_fresh"
  exit 1
fi

printf 'PASS\n'
exit 0
