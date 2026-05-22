#!/usr/bin/env bash
# .claude/tests/typecheck-advisory/08-globs-nested-workspace.sh
# V8 — Scenario: nested-workspace manifests + lockfiles must be excluded from
# TDD classification loop even when the validator runs from a populated cwd
# where bash pathname expansion finds real matches for the exclusion globs.
#
# Bug surfaced via shrnk-mono dogfood validation pass 2026-05-12, commit
# d4eada2: the `for g in $excluded_globs; do case "$f" in $g)` loop had
# unquoted variable expansion. In a populated repo, `*.json` got pathname-
# expanded to the literal root-level match (`package.json` alone), and the
# subsequent case stmt became a literal compare instead of glob match. Net:
# `apps/api/package.json` falsely surfaced in `warnings.files` despite
# `*.json` being in the exclusion list.
#
# Test 07 didn't catch the bug because its tempdir only had files matching
# the lockfile globs, plus one nested `services/api/go.sum` — for which
# pathname expansion of `*/go.sum` happened to produce the literal nested
# path, and the case literal-compare worked by accident. The bug manifests
# only when the literal-compare path DOESN'T match (multiple workspaces,
# the pattern expansion misses some of them).
#
# Fix: `set -f` around the classification loop in validators/run.sh.
# Verifies both the v6 noise filter (still active) and the v7 lockfile
# globs (still active) continue working — those are orthogonal to this fix.
#
# Asserts (single populated-monorepo scenario):
#   (a) modified nested manifests (apps/api/package.json + apps/web/package.json)
#       are excluded — they MUST NOT appear in warnings.files
#   (b) modified nested lockfile (apps/api/bun.lock) is excluded
#   (c) nested .gitignore (.gitignore being modified at apps/api/.gitignore)
#       is excluded — matches *.gitignore pattern
#   (d) the ONE legitimate prod file (apps/api/src/feature.ts untracked, no
#       corresponding test) DOES surface as the sole TDD warning entry

set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-typecheck-V8-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

( cd "$TMPDIR" && git init -q && git config user.email t@t && git config user.name t )

# Bun stack with tsconfig (drives the validator into the bun branch with
# direct tsc — keeps test independent of script-detection logic).
echo '{}' > "$TMPDIR/tsconfig.json"

# Root manifest (its presence is what makes `*.json` pathname-expand to
# literal `package.json` — the bug's predicate).
cat > "$TMPDIR/package.json" <<'EOF'
{"name":"v8-monorepo"}
EOF

# Multiple nested workspace manifests + lockfiles + .gitignore. Each one
# must be classified as excluded even though `*.json` / `*.lock` /
# `*.gitignore` only have a single root-level pathname-expansion match.
mkdir -p "$TMPDIR/apps/api/src" "$TMPDIR/apps/web/src" "$TMPDIR/services/auth"
echo '{"name":"api"}' > "$TMPDIR/apps/api/package.json"
echo '{"name":"web"}' > "$TMPDIR/apps/web/package.json"
echo '{"name":"auth"}' > "$TMPDIR/services/auth/package.json"
echo '# bun lockfile placeholder' > "$TMPDIR/apps/api/bun.lock"
echo '# api gitignore' > "$TMPDIR/apps/api/.gitignore"

cat > "$TMPDIR/.gitignore" <<'EOF'
node_modules/
*.log
bin/
EOF

# Commit baseline so subsequent edits show up via `git diff --name-only`.
( cd "$TMPDIR" && git add . && git commit -q -m baseline )

# Modify every nested manifest + lockfile + .gitignore — exactly the
# population that triggered the bug in shrnk-mono. Each modification surfaces
# in `git diff --name-only` as a nested path.
echo '{"name":"api","mod":true}' > "$TMPDIR/apps/api/package.json"
echo '{"name":"web","mod":true}' > "$TMPDIR/apps/web/package.json"
echo '{"name":"auth","mod":true}' > "$TMPDIR/services/auth/package.json"
echo '# bun lockfile mutated' > "$TMPDIR/apps/api/bun.lock"
echo '# api gitignore changed' > "$TMPDIR/apps/api/.gitignore"

# ONE genuine prod-without-test file — must surface as the sole warning.
echo "export const feature = 1;" > "$TMPDIR/apps/api/src/feature.ts"

# bun shim so `bun test && bun tsc --noEmit` exits 0 (we want to reach the
# TDD warning branch with ok=true).
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

# (a)+(b)+(c) — NONE of the excluded paths must appear in warnings.files
leaked=""
for excluded in \
    apps/api/package.json \
    apps/web/package.json \
    services/auth/package.json \
    apps/api/bun.lock \
    apps/api/.gitignore; do
  if jq -e --arg p "$excluded" '(.warnings // []) | .[].files[]? | select(. == $p)' \
       "$TMPDIR/out.json" >/dev/null 2>&1; then
    leaked="$leaked $excluded"
  fi
done

if [ -n "$leaked" ]; then
  printf 'FAIL: nested workspace paths leaked into warnings.files (pathname-expansion bug present):%s\n' "$leaked"
  jq '.warnings' "$TMPDIR/out.json"
  exit 1
fi

# (d) — apps/api/src/feature.ts MUST be the sole warning entry
warning_kind="$(jq -r '(.warnings // []) | .[0].kind // ""' "$TMPDIR/out.json")"
if [ "$warning_kind" != "no_test_change_for_prod_edit" ]; then
  printf 'FAIL: expected TDD warning for prod file, got kind=%s\n' "$warning_kind"
  jq . "$TMPDIR/out.json"
  exit 1
fi

if ! jq -e '(.warnings // []) | .[].files[]? | select(. == "apps/api/src/feature.ts")' \
     "$TMPDIR/out.json" >/dev/null 2>&1; then
  printf 'FAIL: warnings.files should include apps/api/src/feature.ts. Got:\n'
  jq '.warnings' "$TMPDIR/out.json"
  exit 1
fi

# Sanity: warnings.files should contain EXACTLY one path (the prod file).
# A higher count means leakage that the per-path check above missed.
count="$(jq -r '(.warnings // []) | .[].files[]?' "$TMPDIR/out.json" | wc -l)"
if [ "$count" -ne 1 ]; then
  printf 'FAIL: warnings.files should hold exactly 1 entry, got %d:\n' "$count"
  jq '.warnings' "$TMPDIR/out.json"
  exit 1
fi

printf 'PASS (5 nested-workspace exclusions verified; sole prod file surfaced)\n'
exit 0
