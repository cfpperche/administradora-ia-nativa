#!/usr/bin/env bash
# .claude/tests/validator-php/09-larastan-declared-installed-runs.sh
# Spec 047 V5 — Scenario: composer.json declares larastan/larastan (Laravel wrapper) + binary installed → command extends with phpstan analyse.

set -euo pipefail
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"
TMPDIR="$(mktemp -d -t spec-047-V5d-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

cat > "$TMPDIR/composer.json" <<'EOF'
{
  "name": "acme/test",
  "require-dev": { "larastan/larastan": "^2.0" }
}
EOF

mkdir -p "$TMPDIR/vendor/bin"
echo '#!/usr/bin/env bash' > "$TMPDIR/vendor/bin/phpstan"
echo 'exit 0' >> "$TMPDIR/vendor/bin/phpstan"
chmod +x "$TMPDIR/vendor/bin/phpstan"

cd "$TMPDIR"
stdout="$(bash "$VALIDATOR" 2>"$stderr_file" || true)"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -q 'vendor/bin/phpstan analyse'; then
  printf 'FAIL: command missing phpstan analyse (Larastan declared)\n  got: %s\n' "$cmd"
  exit 1
fi

printf 'PASS\n'
