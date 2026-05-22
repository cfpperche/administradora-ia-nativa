#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/06-noise-dir-filter-prevents-hang.sh
# V6 — Scenario: validator's TDD warning loop must not iterate over noise
# dirs (node_modules, .venv, target, etc.) that escaped a mis-configured
# fork's .gitignore.
#
# Bug surfaced via shrnk-mono dogfood 2026-05-12: Agent0 ships a
# stack-agnostic .gitignore template with `# node_modules/` commented;
# the fork developer must uncomment per-stack. shrnk-mono didn't, so
# `git ls-files --others --exclude-standard` dumped 15,711 paths into
# the validator's per-file shell pattern-match loop, hanging beyond
# any reasonable timeout.
#
# Fix: validator now grep-filters common noise dir prefixes (node_modules/,
# .venv/, __pycache__/, target/, dist/, build/, coverage/, .next/, etc.)
# before the loop. Defends in layers — fork's .gitignore is still the
# correct primary control, but the validator no longer hangs catastrophically.
#
# Asserts:
#   (a) validator completes within a generous wall-clock budget (10s)
#       even when the fixture has 1000+ untracked node_modules files
#   (b) the changed_files visible to the loop does NOT include node_modules
#       paths (verified by ensuring no node_modules entry surfaces in the
#       warnings.files array — if filter broken, the per-file loop would
#       see them and either hang or emit them)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V6-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Real git repo — TDD warning code requires `git rev-parse --git-dir` success.
( cd "$TMPDIR" && git init -q && git config user.email t@t && git config user.name t )

# Bun stack with tsconfig (so typecheck path is direct + ok=true).
echo '{}' > "$TMPDIR/tsconfig.json"
touch "$TMPDIR/bun.lock"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"noise-test"}
EOF

# Mis-configured .gitignore — does NOT ignore node_modules.
cat > "$TMPDIR/.gitignore" <<'EOF'
# Stack-agnostic template (intentionally does NOT cover node_modules)
*.log
EOF

# Commit baseline so subsequent untracked files surface via ls-files --others.
( cd "$TMPDIR" && git add . && git commit -q -m baseline )

# Plant 1500 untracked files under node_modules — the noise filter must
# strip these before they hit the per-file loop.
mkdir -p "$TMPDIR/node_modules/.bun/some-pkg"
for i in $(seq 1 1500); do
  echo "//noise" > "$TMPDIR/node_modules/.bun/some-pkg/file-$i.js"
done

# Plant ONE legitimate prod-shaped untracked file so the loop has real work.
mkdir -p "$TMPDIR/src"
echo "export const x = 1;" > "$TMPDIR/src/feature.ts"

# bun shim so `bun test && bun tsc --noEmit` exits 0
mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun"

# Time-bound the run: 10s is generous for a 1500-file scenario when filter
# works (should complete in <1s). Without the filter, this hangs hard.
start_ts=$(date +%s)
( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" timeout 10 bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$TMPDIR/err.txt" ) && exit_code=0 || exit_code=$?
end_ts=$(date +%s)
elapsed=$(( end_ts - start_ts ))

if [ "$exit_code" = "124" ]; then
  printf 'FAIL: validator timed out (10s) — noise filter likely broken; loop iterating node_modules\n'
  printf 'elapsed=%ds\n' "$elapsed"
  exit 1
fi

if [ "$exit_code" -ne 0 ]; then
  printf 'FAIL: validator exited non-zero unexpectedly (exit=%d)\n' "$exit_code"
  cat "$TMPDIR/err.txt"
  exit 1
fi

# Sanity: validator JSON must be present
if [ ! -s "$TMPDIR/out.json" ]; then
  printf 'FAIL: validator produced empty stdout\n'
  exit 1
fi

# (b) warnings.files (if present) must NOT include any node_modules path
files_with_noise="$(jq -r '(.warnings // []) | .[].files[]?' "$TMPDIR/out.json" 2>/dev/null | grep -c '^node_modules/' || true)"
if [ "$files_with_noise" -gt 0 ]; then
  printf 'FAIL: warnings.files contains %d node_modules entries — filter broken\n' "$files_with_noise"
  jq . "$TMPDIR/out.json"
  exit 1
fi

# Bonus: with src/feature.ts (prod) + no test, TDD warning SHOULD fire for
# the legit prod file. Verify the legit signal still surfaces post-filter.
warning_kind="$(jq -r '(.warnings // []) | .[0].kind // ""' "$TMPDIR/out.json")"
if [ "$warning_kind" != "no_test_change_for_prod_edit" ]; then
  printf 'FAIL: expected TDD warning for src/feature.ts, got kind=%s\n' "$warning_kind"
  jq . "$TMPDIR/out.json"
  exit 1
fi

if ! jq -e '(.warnings // []) | .[].files[]? | select(. == "src/feature.ts")' "$TMPDIR/out.json" >/dev/null 2>&1; then
  printf 'FAIL: warning.files should include src/feature.ts. Got:\n'
  jq '.warnings' "$TMPDIR/out.json"
  exit 1
fi

printf 'PASS (elapsed=%ds with 1500 noise files filtered)\n' "$elapsed"
exit 0
