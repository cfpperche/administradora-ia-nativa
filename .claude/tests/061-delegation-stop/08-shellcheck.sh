#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/08-shellcheck.sh
# Spec 061 — static analysis of the two delegation hooks.
#
# delegation-stop.sh (new) and delegation-gate.sh (extended with tool_use_id)
# must be lint-clean. When shellcheck is installed it runs in full; when it is
# absent the test degrades to `bash -n` syntax validation (always available)
# so the suite never silently skips the check.
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
STOP_HOOK="$AGENT0_ROOT/.claude/hooks/delegation-stop.sh"
GATE_HOOK="$AGENT0_ROOT/.claude/hooks/delegation-gate.sh"

for h in "$STOP_HOOK" "$GATE_HOOK"; do
  [ -f "$h" ] || { printf 'FAIL: hook not found: %s\n' "$h"; exit 1; }
done

if command -v shellcheck >/dev/null 2>&1; then
  sc_exit=0
  shellcheck -S warning "$STOP_HOOK" "$GATE_HOOK" || sc_exit=$?
  if [ "$sc_exit" -ne 0 ]; then
    printf 'FAIL: shellcheck reported warnings/errors (exit %d)\n' "$sc_exit"
    exit 1
  fi
  printf 'PASS: %s (shellcheck clean)\n' "$(basename "$0")"
else
  for h in "$STOP_HOOK" "$GATE_HOOK"; do
    if ! bash -n "$h"; then
      printf 'FAIL: bash -n syntax error in %s\n' "$h"
      exit 1
    fi
  done
  printf 'PASS: %s (shellcheck absent — bash -n syntax check clean)\n' "$(basename "$0")"
fi
