#!/usr/bin/env bash
# .claude/tests/validator-php/07-pint-declared-missing-advisory.sh
# Spec 047 V5 — Scenario: laravel/pint declared but vendor/bin/pint missing → advisory, no command extension.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"
TMPDIR="$(mktemp -d -t spec-047-V5b-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require-dev": { "laravel/pint": "^1.0" }
}
EOF
# No vendor/bin/pint — declared but not installed.

cd "$TMPDIR"
stdout="$(bash "$VALIDATOR" 2>"$stderr_file" || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if echo "$cmd" | grep -q 'vendor/bin/pint'; then
  printf 'FAIL: command unexpectedly includes pint\n  got: %s\n' "$cmd"
  exit 1
fi

if ! grep -q 'lint-advisory: pint declared in composer.json but not installed' "$stderr_file"; then
  printf 'FAIL: stderr missing pint lint-advisory\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

if ! grep -q 'composer install' "$stderr_file"; then
  printf 'FAIL: lint-advisory does not suggest \`composer install\`\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

printf 'PASS\n'
