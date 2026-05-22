#!/usr/bin/env bash
# .claude/tests/lint-validator/07-lint-failure-blocks.sh
# Spec 013 V7 — Scenario: lint failure (when running) blocks sub-agent.
#
# Asserts:
#   (a) JSON .ok == false
#   (b) JSON .exit != 0
#   (c) JSON .stdout or .stderr tail carries linter output

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-013-V7-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

mkdir -p "$TMPDIR/bin" "$TMPDIR/node_modules/@biomejs/biome"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
# bunx shim simulates biome failure
cat > "$TMPDIR/bin/bunx" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"biome check"*)
    echo "src/foo.ts:3:5 lint/correctness/noUnusedVariables: unused variable" >&2
    exit 1
    ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMPDIR/bin/bun" "$TMPDIR/bin/bunx"

touch "$TMPDIR/bun.lock"
echo '{}' > "$TMPDIR/tsconfig.json"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"test","devDependencies":{"@biomejs/biome":"^1.0.0"}}
EOF
echo '{"name":"@biomejs/biome","version":"1.0.0"}' > "$TMPDIR/node_modules/@biomejs/biome/package.json"

cd "$TMPDIR"
stdout="$(PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" 2>"$stderr_file")"

ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"
if [ "$ok" != "false" ]; then
  printf 'FAIL: ok != false (got %s)\n  stdout: %s\n  stderr: %s\n' "$ok" "$stdout" "$(cat "$stderr_file")"
  exit 1
fi

exit_code="$(printf '%s' "$stdout" | jq -r '.exit' 2>/dev/null || true)"
if [ "$exit_code" = "0" ] || [ -z "$exit_code" ]; then
  printf 'FAIL: exit field unexpectedly 0 or empty (got "%s")\n  stdout: %s\n' "$exit_code" "$stdout"
  exit 1
fi

# Linter output is on the inner command's stderr → captured in JSON .stderr field
linter_stderr="$(printf '%s' "$stdout" | jq -r '.stderr' 2>/dev/null || true)"
if ! echo "$linter_stderr" | grep -q 'lint/correctness/noUnusedVariables'; then
  printf 'FAIL: JSON .stderr does not carry linter output\n  got: %s\n' "$linter_stderr"
  exit 1
fi

printf 'PASS\n'
exit 0
