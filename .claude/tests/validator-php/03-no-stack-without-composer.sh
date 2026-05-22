#!/usr/bin/env bash
# .claude/tests/validator-php/03-no-stack-without-composer.sh
# Spec 047 V1 — Regression: empty dir → no-stack-detected (PHP branch doesn't fire spuriously).
#
# Asserts:
#   (a) JSON .command == "no-stack-detected"
#   (b) JSON .ok == true

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-047-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
stdout="$(bash "$VALIDATOR" 2>/dev/null || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if [ "$cmd" != "no-stack-detected" ]; then
  printf 'FAIL: expected command="no-stack-detected", got: %s\n' "$cmd"
  printf '  stdout: %s\n' "$stdout"
  exit 1
fi

ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"
if [ "$ok" != "true" ]; then
  printf 'FAIL: expected ok=true, got: %s\n' "$ok"
  exit 1
fi

printf 'PASS\n'
exit 0
