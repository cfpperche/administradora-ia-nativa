#!/usr/bin/env bash
# .claude/tests/validator-php/02-pest-declared-uses-pest.sh
# Spec 047 V1 — Scenario: composer.json declares pestphp/pest → command uses Pest.
#
# Asserts:
#   (a) JSON .command includes 'vendor/bin/pest'
#   (b) JSON .command does NOT include 'vendor/bin/phpunit'

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-047-V2-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require": {
    "laravel/framework": "^11.0"
  },
  "require-dev": {
    "pestphp/pest": "^2.0",
    "phpunit/phpunit": "^10.0"
  }
}
EOF

cd "$TMPDIR"
stdout="$(bash "$VALIDATOR" 2>"$stderr_file" || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -q 'vendor/bin/pest'; then
  printf 'FAIL: command does not include "vendor/bin/pest"\n  got: %s\n' "$cmd"
  printf '  stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

if echo "$cmd" | grep -q 'vendor/bin/phpunit'; then
  printf 'FAIL: command unexpectedly includes "vendor/bin/phpunit" (Pest takes precedence)\n  got: %s\n' "$cmd"
  exit 1
fi

printf 'PASS\n'
exit 0
