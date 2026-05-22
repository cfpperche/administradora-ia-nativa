#!/usr/bin/env bash
# .claude/tests/validator-php/04-tdd-prod-php-without-test.sh
# Spec 047 V4 — Scenario: TDD advisory fires when prod-PHP edits land without test edits.
#
# Asserts:
#   (a) JSON .warnings array contains one no_test_change_for_prod_edit entry
#   (b) The .warnings[0].files array names the prod file (e.g. "app/Models/User.php")

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-047-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"
git init -q
git config user.email "test@test.local"
git config user.name "test"

cat > composer.json <<'EOF'
{
  "name": "acme/test",
  "require": { "laravel/framework": "^11.0" }
}
EOF

mkdir -p app/Models tests/Feature

# Initial commit so git diff has a baseline.
echo '<?php' > app/Models/User.php
echo '<?php' > tests/Feature/UserTest.php
git add composer.json app/ tests/ && git commit -q -m initial

# Now modify only the prod file (no test edit).
echo '// new method' >> app/Models/User.php

# Run validator. Inner pipeline will fail (no vendor/bin/phpunit) but the
# warnings field is computed before the pipeline runs.
stdout="$(bash "$VALIDATOR" 2>/dev/null || true)"

warnings_count="$(printf '%s' "$stdout" | jq '.warnings // [] | length' 2>/dev/null || echo 0)"
if [ "$warnings_count" != "1" ]; then
  printf 'FAIL: expected 1 warning, got %s\n' "$warnings_count"
  printf '  stdout: %s\n' "$stdout"
  exit 1
fi

kind="$(printf '%s' "$stdout" | jq -r '.warnings[0].kind' 2>/dev/null || true)"
if [ "$kind" != "no_test_change_for_prod_edit" ]; then
  printf 'FAIL: expected warning kind no_test_change_for_prod_edit, got %s\n' "$kind"
  exit 1
fi

files="$(printf '%s' "$stdout" | jq -r '.warnings[0].files[]' 2>/dev/null || true)"
if ! echo "$files" | grep -q 'app/Models/User.php'; then
  printf 'FAIL: warnings.files does not include app/Models/User.php\n  got: %s\n' "$files"
  exit 1
fi

printf 'PASS\n'
exit 0
