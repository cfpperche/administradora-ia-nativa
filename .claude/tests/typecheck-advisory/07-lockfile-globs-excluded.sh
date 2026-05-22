#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/07-lockfile-globs-excluded.sh
# V7 — Scenario: validator's TDD warning loop must exclude supply-chain
# lockfiles from prod/test classification. A `bun install` (or any
# manager's lockfile resolve) modifies the tracked lockfile, which
# `git diff --name-only` surfaces. Without this exclusion the validator
# misclassifies the lockfile change as "prod without test" and fires a
# false-positive `no_test_change_for_prod_edit` warning.
#
# Bug surfaced via shrnk-mono spec 013 dogfood 2026-05-12.
#
# Fix: excluded_globs gains `*.lock *.lockb go.sum */go.sum`. Covers all
# 10 supported managers (bun/yarn/cargo/poetry/uv/pdm direct via *.lock;
# bun.lockb direct via *.lockb; go.sum direct; package-lock.json and
# pnpm-lock.yaml inherit from existing *.json / *.yaml).
#
# Asserts:
#   (a) modifying 10 lockfile basenames (each manager's canonical form,
#       both root and one nested workspace path for go.sum) does NOT
#       surface them in warnings.files
#   (b) the one genuine prod-without-test file (src/feature.ts) STILL
#       fires the warning — exclusion is precise, not broad

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V7-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

( cd "$TMPDIR" && git init -q && git config user.email t@t && git config user.name t )

# Bun stack with tsconfig (drives the validator into the bun branch with
# direct tsc — keeps test independent of script-detection logic).
echo '{}' > "$TMPDIR/tsconfig.json"
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"lockfile-test"}
EOF

# Seed all 10 lockfile basenames at root + one nested go.sum to exercise
# the `*/go.sum` half of the pattern pair. Content is arbitrary; only
# the basename matters to the glob match.
mkdir -p "$TMPDIR/services/api"
for lock in bun.lock bun.lockb yarn.lock package-lock.json pnpm-lock.yaml \
            Cargo.lock poetry.lock uv.lock pdm.lock go.sum; do
  printf 'initial\n' > "$TMPDIR/$lock"
done
printf 'initial\n' > "$TMPDIR/services/api/go.sum"

# Realistic .gitignore so the per-file loop only walks tracked diff,
# not untracked noise. (Independent control from V6.)
cat > "$TMPDIR/.gitignore" <<'EOF'
node_modules/
*.log
EOF

# Commit baseline so subsequent edits show up via `git diff --name-only`
# (the "modified-tracked" path that produced the false-positive in
# the shrnk-mono dogfood — distinct from the V6 untracked-noise path).
( cd "$TMPDIR" && git add . && git commit -q -m baseline )

# Modify every lockfile — simulates `<manager> install` writing through
# the lockfile basenames.
for lock in bun.lock bun.lockb yarn.lock package-lock.json pnpm-lock.yaml \
            Cargo.lock poetry.lock uv.lock pdm.lock go.sum; do
  printf 'mutated\n' > "$TMPDIR/$lock"
done
printf 'mutated\n' > "$TMPDIR/services/api/go.sum"

# One genuine prod file untracked — without an exclusion fix this would
# be the SOLE prod entry; with the bug it gets buried under 11 false
# positives. The (b) assertion proves the warning still surfaces the
# right file.
mkdir -p "$TMPDIR/src"
echo "export const x = 1;" > "$TMPDIR/src/feature.ts"

# bun shim so the inner `bun test && bun tsc --noEmit` exits 0 — we want
# to reach the TDD warning detection branch with ok=true.
mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/bun" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/bun"

( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$TMPDIR/err.txt" ) || {
  printf 'FAIL: validator exited non-zero\n'
  cat "$TMPDIR/err.txt"
  exit 1
}

if [ ! -s "$TMPDIR/out.json" ]; then
  printf 'FAIL: validator produced empty stdout\n'
  exit 1
fi

# (a) NONE of the 11 lockfile paths must appear in warnings.files
for lock in bun.lock bun.lockb yarn.lock package-lock.json pnpm-lock.yaml \
            Cargo.lock poetry.lock uv.lock pdm.lock go.sum services/api/go.sum; do
  if jq -e --arg lk "$lock" '(.warnings // []) | .[].files[]? | select(. == $lk)' \
       "$TMPDIR/out.json" >/dev/null 2>&1; then
    printf 'FAIL: lockfile %s leaked into warnings.files — excluded_globs broken\n' "$lock"
    jq '.warnings' "$TMPDIR/out.json"
    exit 1
  fi
done

# (b) src/feature.ts MUST still appear — exclusion is precise, not blanket
warning_kind="$(jq -r '(.warnings // []) | .[0].kind // ""' "$TMPDIR/out.json")"
if [ "$warning_kind" != "no_test_change_for_prod_edit" ]; then
  printf 'FAIL: expected TDD warning for src/feature.ts after exclusions, got kind=%s\n' "$warning_kind"
  jq . "$TMPDIR/out.json"
  exit 1
fi

if ! jq -e '(.warnings // []) | .[].files[]? | select(. == "src/feature.ts")' \
     "$TMPDIR/out.json" >/dev/null 2>&1; then
  printf 'FAIL: warnings.files should include src/feature.ts. Got:\n'
  jq '.warnings' "$TMPDIR/out.json"
  exit 1
fi

printf 'PASS (11 lockfile paths excluded; src/feature.ts surfaced)\n'
exit 0
