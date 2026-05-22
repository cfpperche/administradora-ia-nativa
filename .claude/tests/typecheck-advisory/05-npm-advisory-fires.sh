#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/05-npm-advisory-fires.sh
# V5 — Same advisory firing in the npm branch. Conservative npm path:
# only the script-presence check exists (no tsconfig-direct fast-path —
# `npx tsc` adds resolution surprises that the bun/pnpm runners don't have).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V5-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/npm"

touch "$TMPDIR/package-lock.json"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"early-stage-npm"}
EOF

stderr_file="$(mktemp)"
( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true

cmd="$(jq -r '.command' "$TMPDIR/out.json")"
ok="$(jq -r '.ok' "$TMPDIR/out.json")"

if [ "$cmd" != "npm test --silent" ]; then
  printf 'FAIL: command should be `npm test --silent` alone, got: %s\n' "$cmd"
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

if ! grep -q 'npm run typecheck' "$stderr_file"; then
  printf 'FAIL: npm-flavored advisory should mention `npm run typecheck`. Got: %s\n' \
    "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

rm -f "$stderr_file"
printf 'PASS\n'
exit 0
