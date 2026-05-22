#!/usr/bin/env bash
# .claude/tests/validator-php/05-tdd-no-warning-when-test-edited.sh
# Spec 047 V4 — Negative: prod-PHP + test-PHP edited together → no warning.
#
# Asserts:
#   (a) JSON .warnings is empty array OR field absent

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-047-V5-XXXXXX)"
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
echo '<?php' > app/Models/User.php
echo '<?php' > tests/Feature/UserTest.php
git add composer.json app/ tests/ && git commit -q -m initial

# Modify BOTH prod and test in same diff.
echo '// new method' >> app/Models/User.php
echo '// new test' >> tests/Feature/UserTest.php

stdout="$(bash "$VALIDATOR" 2>/dev/null || true)"

warnings_count="$(printf '%s' "$stdout" | jq '.warnings // [] | length' 2>/dev/null || echo 0)"
if [ "$warnings_count" != "0" ]; then
  printf 'FAIL: expected 0 warnings (test was edited), got %s\n' "$warnings_count"
  printf '  stdout: %s\n' "$stdout"
  exit 1
fi

printf 'PASS\n'
exit 0
