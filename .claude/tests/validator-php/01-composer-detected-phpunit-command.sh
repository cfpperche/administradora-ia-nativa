#!/usr/bin/env bash
# .claude/tests/validator-php/01-composer-detected-phpunit-command.sh
# Spec 047 V1 — Scenario: validator detects PHP via composer.json (PHPUnit default).
#
# Asserts:
#   (a) JSON .command includes 'vendor/bin/phpunit'
#   (b) JSON .command does NOT include 'vendor/bin/pest' (Pest not declared)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-047-V1-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

# Minimal composer.json with no Pest declaration. Validator should pick phpunit.
cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require": {
    "laravel/framework": "^11.0"
  },
  "require-dev": {
    "phpunit/phpunit": "^10.0"
  }
}
EOF

cd "$TMPDIR"
# Inner pipeline will fail (no vendor/bin/phpunit binary on PATH), but that's
# fine — we only assert the COMPOSED COMMAND, not its execution outcome.
stdout="$(bash "$VALIDATOR" 2>"$stderr_file" || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -q 'vendor/bin/phpunit'; then
  printf 'FAIL: command does not include "vendor/bin/phpunit"\n  got: %s\n' "$cmd"
  printf '  stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

if echo "$cmd" | grep -q 'vendor/bin/pest'; then
  printf 'FAIL: command unexpectedly includes "vendor/bin/pest" (Pest not declared)\n  got: %s\n' "$cmd"
  exit 1
fi

printf 'PASS\n'
exit 0
