#!/usr/bin/env bash
# .claude/tools/probe.sh
# Shell tool for the runtime-introspect capacity (spec 011). Lets the agent
# query the latest captured test/build/typecheck run via a structured
# plain-text summary.
#
# Subcommands (v1):
#   last-run  — read .claude/.runtime-state/last-run.json and emit a
#               PASS/FAIL/UNKNOWN status header, age in seconds, stale
#               flag (vs session-start), and stdout/stderr tails.
#
# Exit codes:
#   0  — normal: snapshot found (any status), or no-snapshot empty state
#   2  — unknown subcommand (with usage hint on stderr)
#
# Reference:
#   .claude/rules/runtime-introspect.md  — full discipline
#   docs/specs/011-runtime-introspect/   — spec

set -uo pipefail

usage() {
  cat <<'EOF' >&2
Usage: bash .claude/tools/probe.sh <subcommand> [flags]

Subcommands:
  last-run                Show the latest captured test/build/typecheck run.
  rule-loads [flags]      Show recent InstructionsLoaded events. Requires
                          CLAUDE_RULE_LOAD_DEBUG=1 during the session that
                          produced the loads.
    --json                Emit raw JSONL instead of human-readable table.
    --session <id>        Filter to a single session_id.
    --reason <r>          Filter by load_reason (session_start, path_glob_match,
                          nested_traversal, include, compact).

Examples:
  bash .claude/tools/probe.sh last-run
  bash .claude/tools/probe.sh rule-loads
  bash .claude/tools/probe.sh rule-loads --reason path_glob_match
  bash .claude/tools/probe.sh rule-loads --session abc123 --json
EOF
}

SUBCMD="${1:-}"

if [ -z "$SUBCMD" ]; then
  usage
  exit 2
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$PROJECT_DIR/.claude/.runtime-state/last-run.json"
SESSION_STATE_DIR="$PROJECT_DIR/.claude/.session-state"

case "$SUBCMD" in
  last-run)
    if ! command -v jq >/dev/null 2>&1; then
      printf 'probe: jq not found — runtime-introspect probe disabled\n'
      exit 0
    fi

    if [ ! -f "$STATE_FILE" ]; then
      cat <<'EOF'
status: no-snapshot
hint: run a recognised verifier (e.g. `bun test`, `pytest`) then re-query with `bash .claude/tools/probe.sh last-run`.
EOF
      exit 0
    fi

    if ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
      printf 'status: parse-error\nhint: %s is not valid JSON — capacity may be wedged.\n' "$STATE_FILE"
      exit 0
    fi

    command="$(jq -r '.command // ""' "$STATE_FILE")"
    detector="$(jq -r '.detector // ""' "$STATE_FILE")"
    exit_val="$(jq -r '.exit // "null"' "$STATE_FILE")"
    interrupted="$(jq -r '.interrupted // false' "$STATE_FILE")"
    inferred_status="$(jq -r '.inferred_status // "UNKNOWN"' "$STATE_FILE")"
    inference_basis="$(jq -r '.inference_basis // ""' "$STATE_FILE")"
    started_at="$(jq -r '.started_at // ""' "$STATE_FILE")"
    duration_ms="$(jq -r '.duration_ms // "null"' "$STATE_FILE")"
    stdout_head="$(jq -r '.stdout_head // ""' "$STATE_FILE")"
    stdout_tail="$(jq -r '.stdout_tail // ""' "$STATE_FILE")"
    stdout_truncated="$(jq -r '.stdout_truncated // false' "$STATE_FILE")"
    stderr_head="$(jq -r '.stderr_head // ""' "$STATE_FILE")"
    stderr_tail="$(jq -r '.stderr_tail // ""' "$STATE_FILE")"
    stderr_truncated="$(jq -r '.stderr_truncated // false' "$STATE_FILE")"

    # Status mapping — exit code if available (some harnesses surface it),
    # otherwise fall back to inferred_status (output-pattern heuristic).
    # interrupted=true overrides both to INTERRUPTED.
    if [ "$interrupted" = "true" ]; then
      status="INTERRUPTED"
    else
      case "$exit_val" in
        0)       status="PASS" ;;
        null|'') status="$inferred_status" ;;
        *)       status="FAIL" ;;
      esac
    fi

    # Age computation
    age="?"
    if [ -n "$started_at" ]; then
      start_epoch="$(date -u -d "$started_at" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$started_at" +%s 2>/dev/null || true)"
      now_epoch="$(date -u +%s 2>/dev/null || true)"
      if [ -n "$start_epoch" ] && [ -n "$now_epoch" ]; then
        age="$((now_epoch - start_epoch))s"
      fi
    fi

    # Stale comparison — spec 017: session-state is per-session_id, so the
    # boundary signal is the MAX mtime across all <.session-state>/<id>/started-at
    # markers. Sessão única: identical behavior to pre-017 (single subdir).
    # Sessões paralelas: stale=true may trigger earlier in the older session
    # (conservative false-positive — agent re-runs verifier, safe direction).
    stale="false"
    session_epoch=""
    for f in "$SESSION_STATE_DIR"/*/started-at; do
      [ -f "$f" ] || continue
      this_epoch="$(date -u -r "$f" +%s 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || true)"
      if [ -n "$this_epoch" ] && { [ -z "$session_epoch" ] || [ "$this_epoch" -gt "$session_epoch" ]; }; then
        session_epoch="$this_epoch"
      fi
    done
    if [ -n "$session_epoch" ] && [ -n "${start_epoch:-}" ]; then
      if [ "$start_epoch" -lt "$session_epoch" ]; then
        stale="true"
      fi
    fi

    # Emit header
    printf 'status: %s\n' "$status"
    printf 'command: %s\n' "$command"
    printf 'detector: %s\n' "$detector"
    printf 'exit: %s\n' "$exit_val"
    if [ "$exit_val" = "null" ] || [ "$exit_val" = "" ]; then
      printf 'inferred_status: %s\n' "$inferred_status"
      if [ -n "$inference_basis" ]; then
        printf 'inference_basis: %s\n' "$inference_basis"
      fi
    fi
    if [ "$interrupted" = "true" ]; then
      printf 'interrupted: true\n'
    fi
    printf 'age: %s\n' "$age"
    if [ "$duration_ms" != "null" ]; then
      printf 'duration_ms: %s\n' "$duration_ms"
    fi
    printf 'stale: %s\n' "$stale"
    printf '\n'

    # stdout block
    printf -- '--- stdout (head) ---\n'
    if [ -z "$stdout_head" ]; then
      printf '(empty)\n'
    else
      printf '%s\n' "$stdout_head"
    fi
    if [ "$stdout_truncated" = "true" ]; then
      printf -- '--- stdout (tail) ---\n'
      printf '%s\n' "$stdout_tail"
    fi

    # stderr block
    printf '\n--- stderr ---\n'
    if [ -z "$stderr_head" ] && [ -z "$stderr_tail" ]; then
      printf '(empty)\n'
    else
      printf '%s\n' "$stderr_head"
      if [ "$stderr_truncated" = "true" ]; then
        printf -- '--- stderr (tail) ---\n'
        printf '%s\n' "$stderr_tail"
      fi
    fi

    exit 0
    ;;

  rule-loads)
    LOG="$PROJECT_DIR/.claude/.rule-load-debug.jsonl"

    if ! command -v jq >/dev/null 2>&1; then
      printf 'probe: jq not found — rule-loads probe disabled\n'
      exit 0
    fi

    if [ ! -f "$LOG" ]; then
      cat <<'EOF'
status: no-snapshot
hint: enable with `export CLAUDE_RULE_LOAD_DEBUG=1` before starting a session, then re-query.
EOF
      exit 0
    fi

    fmt="text"
    filter_field=""
    filter_val=""
    shift  # past "rule-loads"
    while [ $# -gt 0 ]; do
      case "$1" in
        --json) fmt="json"; shift ;;
        --session) filter_field="session_id"; filter_val="${2:-}"; shift 2 ;;
        --reason)  filter_field="load_reason"; filter_val="${2:-}"; shift 2 ;;
        *) printf 'probe: unknown flag "%s"\n\n' "$1" >&2; usage; exit 2 ;;
      esac
    done

    if [ -n "$filter_field" ]; then
      rows="$(jq -c --arg field "$filter_field" --arg val "$filter_val" 'select(.[$field] == $val)' "$LOG")"
    else
      rows="$(cat "$LOG")"
    fi

    if [ -z "$rows" ]; then
      printf 'status: no-matches\n'
      exit 0
    fi

    if [ "$fmt" = "json" ]; then
      printf '%s\n' "$rows"
    else
      printf '%s\n' "$rows" | tail -20 | while IFS= read -r line; do
        [ -n "$line" ] || continue
        ts="$(printf '%s' "$line" | jq -r '.ts // "?"')"
        reason="$(printf '%s' "$line" | jq -r '.load_reason // "?"')"
        file="$(printf '%s' "$line" | jq -r '.file // "?"')"
        trigger="$(printf '%s' "$line" | jq -r '.trigger_file // ""')"
        if [ -n "$trigger" ] && [ "$trigger" != "null" ]; then
          printf '%s  %-18s  %s  ← %s\n' "$ts" "$reason" "$file" "$trigger"
        else
          printf '%s  %-18s  %s\n' "$ts" "$reason" "$file"
        fi
      done
    fi

    exit 0
    ;;

  *)
    printf 'probe: unknown subcommand "%s"\n\n' "$SUBCMD" >&2
    usage
    exit 2
    ;;
esac
