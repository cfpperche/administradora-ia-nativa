#!/usr/bin/env bash
# .claude/tests/validator-php/06-pint-declared-installed-runs.sh
# Spec 047 V5 — Scenario: composer.json declares laravel/pint + binary installed → command extends with pint --test.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"
TMPDIR="$(mktemp -d -t spec-047-V5a-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require-dev": { "laravel/pint": "^1.0" }
}
EOF

# Mock executable pint binary.
mkdir -p "$TMPDIR/vendor/bin"
cat > "$TMPDIR/vendor/bin/pint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/vendor/bin/pint"

cd "$TMPDIR"
stdout="$(bash "$VALIDATOR" 2>"$stderr_file" || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -q 'vendor/bin/pint --test'; then
  printf 'FAIL: command missing "vendor/bin/pint --test"\n  got: %s\n' "$cmd"
  printf '  stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

if grep -q 'lint-advisory' "$stderr_file"; then
  printf 'FAIL: unexpected lint-advisory in stderr\n  got: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

printf 'PASS\n'
