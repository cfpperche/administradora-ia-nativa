#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/04-pnpm-advisory-fires.sh
# V4 — Same advisory firing in the pnpm branch (manager-specific wording).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V4-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/pnpm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/pnpm"

touch "$TMPDIR/pnpm-lock.yaml"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"early-stage-pnpm"}
EOF

stderr_file="$(mktemp)"
( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true

cmd="$(jq -r '.command' "$TMPDIR/out.json")"
ok="$(jq -r '.ok' "$TMPDIR/out.json")"

if [ "$cmd" != "pnpm test" ]; then
  printf 'FAIL: command should be `pnpm test` alone, got: %s\n' "$cmd"
  rm -f "$stderr_file"
  exit 1
fi

if [ "$ok" != "true" ]; then
  printf 'FAIL: ok should be true, got: %s\n' "$ok"
  rm -f "$stderr_file"
  exit 1
fi

if ! grep -qF "typecheck-advisory:" "$stderr_file"; then
  printf 'FAIL: stderr should contain typecheck-advisory. Got: %s\n' "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

if ! grep -q 'pnpm typecheck' "$stderr_file"; then
  printf 'FAIL: pnpm-flavored advisory should mention `pnpm typecheck`. Got: %s\n' \
    "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

rm -f "$stderr_file"
printf 'PASS\n'
exit 0
