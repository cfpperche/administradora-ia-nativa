#!/usr/bin/env bash
# .claude/tests/runtime-introspect/run-all.sh
# Orchestrator for spec-011 scenarios. Runs every NN-*.sh in lex order and
# prints a summary table. Exits 0 if all pass, 1 if any fail.
#
# Usage:
#   bash run-all.sh        # quiet — only summary table
#   bash run-all.sh -v     # verbose — pass through each script's output

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export AGENT0_ROOT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VERBOSE=0
if [ "${1:-}" = "-v" ]; then
  VERBOSE=1
fi

scripts=""
for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20; do
  match="$(ls "$SCRIPT_DIR/${n}"-*.sh 2>/dev/null | head -1 || true)"
  if [ -n "$match" ]; then
    scripts="$scripts $match"
  fi
done

if [ -z "$scripts" ]; then
  printf 'run-all.sh: no scenario scripts found in %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

results=""
any_fail=0
tmpout="$(mktemp -t run-all-out-XXXXXX)"
trap 'rm -f "$tmpout"' EXIT

for script in $scripts; do
  name="$(basename "$script")"
  script_exit=0

  if [ "$VERBOSE" -eq 1 ]; then
    bash "$script" || script_exit=$?
  else
    bash "$script" >"$tmpout" 2>&1 || script_exit=$?
    if [ "$script_exit" -ne 0 ]; then
      cat "$tmpout"
    fi
  fi

  if [ "$script_exit" -eq 0 ]; then
    results="$results
  $name  PASS"
  else
    results="$results
  $name  FAIL"
    any_fail=1
  fi
done

printf '\n=== runtime-introspect scenario results ===\n'
printf '%s\n' "$results"
printf '===========================================\n'

if [ "$any_fail" -eq 0 ]; then
  printf 'All scenarios PASS.\n'
  exit 0
else
  printf 'One or more scenarios FAILED.\n'
  exit 1
fi
