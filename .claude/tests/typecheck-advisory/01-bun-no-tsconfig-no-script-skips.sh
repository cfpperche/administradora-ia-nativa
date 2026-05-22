#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/01-bun-no-tsconfig-no-script-skips.sh
# V1 — Scenario: bun fork without tsconfig.json AND without typecheck script.
#
# This is the bug surfaced via shrnk-mono dogfood 2026-05-12: pre-fix the
# validator unconditionally tried `bun run typecheck`, hard-failing the
# pipeline on early-stage forks. Post-fix the validator omits the
# typecheck step entirely and emits `typecheck-advisory:` to stderr.
#
# Asserts:
#   (a) command_str is `bun test` ALONE (no `&& bun run typecheck`)
#   (b) ok=true (no broken step)
#   (c) stderr contains the canonical typecheck-advisory line

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V1-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun"

touch "$TMPDIR/bun.lock"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"early-stage-fork"}
EOF
# NO tsconfig.json, NO scripts.typecheck

stderr_file="$(mktemp)"
( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true

cmd="$(jq -r '.command' "$TMPDIR/out.json")"
ok="$(jq -r '.ok' "$TMPDIR/out.json")"

# (a) command MUST be `bun test` alone — no typecheck step
if [ "$cmd" != "bun test" ]; then
  printf 'FAIL: command should be `bun test` alone, got: %s\n' "$cmd"
  cat "$stderr_file"
  rm -f "$stderr_file"
  exit 1
fi

# (b) ok=true (no broken step in pipeline)
if [ "$ok" != "true" ]; then
  printf 'FAIL: ok should be true (only bun test ran via shim), got: %s\n' "$ok"
  cat "$TMPDIR/out.json"
  rm -f "$stderr_file"
  exit 1
fi

# (c) stderr MUST contain the typecheck-advisory line
expected="typecheck-advisory: no tsconfig.json or 'typecheck' script in package.json"
if ! grep -qF "$expected" "$stderr_file"; then
  printf 'FAIL: stderr missing typecheck advisory.\n  expected substring: %s\n  got: %s\n' \
    "$expected" "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

# Bonus: advisory should mention `bun run typecheck` (manager-specific guidance)
if ! grep -q 'bun run typecheck' "$stderr_file"; then
  printf 'FAIL: bun-flavored advisory should mention `bun run typecheck`. Got: %s\n' \
    "$(cat "$stderr_file")"
  rm -f "$stderr_file"
  exit 1
fi

rm -f "$stderr_file"
printf 'PASS\n'
exit 0
