#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/02-bun-tsconfig-direct-tsc.sh
# V2 — Regression: bun + tsconfig.json → uses `bun tsc --noEmit` directly,
# no typecheck advisory, ok=true. Confirms the spec-013-era fast-path is
# preserved by the fix.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V2-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun"

touch "$TMPDIR/bun.lock"
echo '{}' > "$TMPDIR/tsconfig.json"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"with-tsconfig"}
EOF

stderr_file="$(mktemp)"
( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true

cmd="$(jq -r '.command' "$TMPDIR/out.json")"
ok="$(jq -r '.ok' "$TMPDIR/out.json")"

if [ "$cmd" != "bun test && bun tsc --noEmit" ]; then
  printf 'FAIL: command should use direct tsc, got: %s\n' "$cmd"
  rm -f "$stderr_file"
  exit 1
fi

if [ "$ok" != "true" ]; then
  printf 'FAIL: ok should be true, got: %s\n' "$ok"
  cat "$TMPDIR/out.json"
  rm -f "$stderr_file"
  exit 1
fi

if grep -q "typecheck-advisory:" "$stderr_file"; then
  printf 'FAIL: typecheck-advisory should NOT fire when tsconfig present. stderr: %s\n' \
    "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

rm -f "$stderr_file"
printf 'PASS\n'
exit 0
