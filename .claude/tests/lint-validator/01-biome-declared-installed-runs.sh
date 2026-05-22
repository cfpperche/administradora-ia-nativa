#!/usr/bin/env bash
# .claude/tests/lint-validator/01-biome-declared-installed-runs.sh
# Spec 013 V1 — Scenario: biome declared in package.json + installed → runs.
#
# Asserts:
#   (a) JSON .command includes 'bunx biome check' (composed pipeline)
#   (b) JSON .ok == true (mock shims succeed)
#   (c) no lint-advisory in validator stderr

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-013-V1-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

mkdir -p "$TMPDIR/bin" "$TMPDIR/node_modules/@biomejs/biome"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TMPDIR/bin/bunx" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun" "$TMPDIR/bin/bunx"

# Bun stack marker + tsconfig drives `bun test && bun tsc --noEmit` pipeline
touch "$TMPDIR/bun.lock"
echo '{}' > "$TMPDIR/tsconfig.json"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"test","devDependencies":{"@biomejs/biome":"^1.0.0"}}
EOF
echo '{"name":"@biomejs/biome","version":"1.0.0"}' > "$TMPDIR/node_modules/@biomejs/biome/package.json"

cd "$TMPDIR"
stdout="$(PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" 2>"$stderr_file")"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -q 'bunx biome check'; then
  printf 'FAIL: command does not include "bunx biome check"\n  got: %s\n' "$cmd"
  printf '  stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"
if [ "$ok" != "true" ]; then
  printf 'FAIL: ok != true (got %s)\n  stdout: %s\n  stderr: %s\n' "$ok" "$stdout" "$(cat "$stderr_file")"
  exit 1
fi

if grep -q 'lint-advisory' "$stderr_file"; then
  printf 'FAIL: stderr unexpectedly contains lint-advisory: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

printf 'PASS\n'
exit 0
