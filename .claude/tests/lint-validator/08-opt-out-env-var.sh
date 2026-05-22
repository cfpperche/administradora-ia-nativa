#!/usr/bin/env bash
# .claude/tests/lint-validator/08-opt-out-env-var.sh
# Spec 013 V8 — Scenario: CLAUDE_VALIDATOR_SKIP_LINT=1 disables lint entirely.
#
# Asserts (declared+missing fixture — would normally emit advisory):
#   (a) JSON .command does NOT include 'biome'
#   (b) no lint-advisory in stderr (opt-out wins over advisory path)
#   (c) test+typecheck still ran (ok=true)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-013-V8-XXXXXX)"
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
# biome declared (would normally trigger advisory because not installed)
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"test","devDependencies":{"@biomejs/biome":"^1.0.0"}}
EOF

cd "$TMPDIR"
stdout="$(CLAUDE_VALIDATOR_SKIP_LINT=1 PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" 2>"$stderr_file")"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if echo "$cmd" | grep -q 'biome'; then
  printf 'FAIL: command unexpectedly mentions biome under opt-out\n  got: %s\n' "$cmd"
  exit 1
fi

if grep -q 'lint-advisory' "$stderr_file"; then
  printf 'FAIL: stderr unexpectedly contains lint-advisory under opt-out: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"
if [ "$ok" != "true" ]; then
  printf 'FAIL: ok != true (test+typecheck should still run)\n  got: %s\n  stdout: %s\n' "$ok" "$stdout"
  exit 1
fi

# Verify test+typecheck pipeline still composed (sanity check)
if ! echo "$cmd" | grep -q 'bun test'; then
  printf 'FAIL: command missing base "bun test" pipeline under opt-out\n  got: %s\n' "$cmd"
  exit 1
fi

printf 'PASS\n'
exit 0
