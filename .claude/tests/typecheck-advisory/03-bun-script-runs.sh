#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/03-bun-script-runs.sh
# V3 — Regression: bun + no tsconfig + scripts.typecheck declared →
# uses `bun run typecheck`, no advisory.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V3-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun"

touch "$TMPDIR/bun.lock"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"with-script","scripts":{"typecheck":"tsc --noEmit"}}
EOF
# NO tsconfig.json — must take the script branch

stderr_file="$(mktemp)"
( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true

cmd="$(jq -r '.command' "$TMPDIR/out.json")"
ok="$(jq -r '.ok' "$TMPDIR/out.json")"

if [ "$cmd" != "bun test && bun run typecheck" ]; then
  printf 'FAIL: command should use script branch, got: %s\n' "$cmd"
  rm -f "$stderr_file"
  exit 1
fi

if [ "$ok" != "true" ]; then
  printf 'FAIL: ok should be true, got: %s\n' "$ok"
  rm -f "$stderr_file"
  exit 1
fi

if grep -q "typecheck-advisory:" "$stderr_file"; then
  printf 'FAIL: typecheck-advisory should NOT fire when script declared. stderr: %s\n' \
    "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

rm -f "$stderr_file"
printf 'PASS\n'
exit 0
