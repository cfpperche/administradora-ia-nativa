#!/usr/bin/env bash
# .claude/tests/validator-php/08-phpstan-declared-installed-runs.sh
# Spec 047 V5 — Scenario: composer.json declares phpstan/phpstan + binary installed → command extends.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"
TMPDIR="$(mktemp -d -t spec-047-V5c-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require-dev": { "phpstan/phpstan": "^1.10" }
}
EOF

mkdir -p "$TMPDIR/vendor/bin"
cat > "$TMPDIR/vendor/bin/phpstan" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/vendor/bin/phpstan"

cd "$TMPDIR"
stdout="$(bash "$VALIDATOR" 2>"$stderr_file" || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -q 'vendor/bin/phpstan analyse'; then
  printf 'FAIL: command missing phpstan analyse\n  got: %s\n' "$cmd"
  exit 1
fi

printf 'PASS\n'
