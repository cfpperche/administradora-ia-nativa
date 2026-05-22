#!/usr/bin/env bash
# .claude/tests/lint-validator/02-biome-not-declared-skips.sh
# Spec 013 V2 — Scenario: package.json without @biomejs/biome → silent skip.
#
# Asserts:
#   (a) JSON .command does NOT include 'biome'
#   (b) no lint-advisory in validator stderr (silent skip)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-013-V2-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun"

touch "$TMPDIR/bun.lock"
echo '{}' > "$TMPDIR/tsconfig.json"
# No biome in deps
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"test","devDependencies":{"typescript":"^5.0.0"}}
EOF

cd "$TMPDIR"
stdout="$(PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" 2>"$stderr_file")"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if echo "$cmd" | grep -q 'biome'; then
  printf 'FAIL: command unexpectedly mentions biome\n  got: %s\n' "$cmd"
  exit 1
fi

if grep -q 'lint-advisory' "$stderr_file"; then
  printf 'FAIL: stderr unexpectedly contains lint-advisory: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

printf 'PASS\n'
exit 0
