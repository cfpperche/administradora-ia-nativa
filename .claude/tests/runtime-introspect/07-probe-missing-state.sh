#!/usr/bin/env bash
# .claude/tests/runtime-introspect/07-probe-missing-state.sh
# V7 — Scenario: probe prints friendly empty-state message when no
# snapshot exists yet; exit 0.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
PROBE="$AGENT0_ROOT/.claude/tools/probe.sh"

TMPDIR="$(mktemp -d -t spec-011-V7-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"

# No state file exists.
probe_exit=0
out_file="$TMPDIR/probe-out.txt"
bash "$PROBE" last-run >"$out_file" 2>&1 || probe_exit=$?

if [ "$probe_exit" -ne 0 ]; then
  printf 'FAIL: probe exit=%d, want 0 on missing state\n' "$probe_exit"
  cat "$out_file"
  exit 1
fi

# Friendly empty-state shape — must name at least one example invocation.
if ! grep -qE 'no-snapshot|no snapshot' "$out_file"; then
  printf 'FAIL: probe output lacks no-snapshot indicator\n'
  printf 'Got:\n'
  cat "$out_file"
  exit 1
fi

if ! grep -qE 'bun test|pytest|run a recognised' "$out_file"; then
  printf 'FAIL: empty-state message lacks example invocation hint\n'
  printf 'Got:\n'
  cat "$out_file"
  exit 1
fi

# Unknown subcommand → exit 2 with usage hint.
unknown_exit=0
unknown_out_file="$TMPDIR/unknown-out.txt"
bash "$PROBE" not-a-subcommand >"$unknown_out_file" 2>&1 || unknown_exit=$?

if [ "$unknown_exit" -ne 2 ]; then
  printf 'FAIL: unknown subcommand exit=%d, want 2\n' "$unknown_exit"
  cat "$unknown_out_file"
  exit 1
fi

if ! grep -qi 'usage' "$unknown_out_file"; then
  printf 'FAIL: unknown subcommand lacks usage hint\n'
  printf 'Got:\n'
  cat "$unknown_out_file"
  exit 1
fi

printf 'PASS\n'
exit 0
