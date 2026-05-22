#!/usr/bin/env bash
# .claude/tests/parallel-edit-validation/01-worktree-isolated-no-cross-fail.sh
# Spec 067 — Scenario: worktree-isolated parallel sub-agents do not fail each
# other's validation (spec.md AC1 + the positive half of AC4).
#
# Models a parallel `Agent` fan-out where each sub-agent runs isolation:"worktree":
# two git worktrees of one repo, each sub-agent editing its own. Asserts that
# post-edit-validate.sh — which scopes the validator cwd to the edited file's
# git toplevel (spec 063, post-edit-validate.sh:30-42) — validates worktree B
# against ONLY worktree B, so a deliberate type error sitting in worktree A
# does not flip B's validation to ok=false.
#
# Non-vacuous guard: the same hook, scoped to worktree A, DOES block — proving
# the error is real and detectable, so the clean B result is genuine isolation,
# not a dead validator.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/post-edit-validate.sh"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

[ -f "$HOOK" ]      || { printf 'FAIL: hook not found: %s\n' "$HOOK"; exit 1; }
[ -x "$VALIDATOR" ] || { printf 'FAIL: validator not executable: %s\n' "$VALIDATOR"; exit 1; }

TMPDIR="$(mktemp -d -t spec-067-01-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- bun shim: `bun test` always passes; `bun tsc --noEmit` models a
# project-wide typecheck by scanning the cwd subtree for the sentinel that the
# broken fixture file carries — a type error ANYWHERE in the tree fails it,
# exactly as real `tsc --noEmit` (whole import graph) would.
SHIM="$TMPDIR/bin"
mkdir -p "$SHIM"
cat > "$SHIM/bun" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  test) exit 0 ;;
  tsc)
    if grep -rl --include='*.ts' --exclude-dir=.git 'TYPE_ERROR_SENTINEL_067' . >/dev/null 2>&1; then
      echo 'error TS2322: Type "string" is not assignable to type "number". (TYPE_ERROR_SENTINEL_067)' >&2
      exit 1
    fi
    exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$SHIM/bun"

# --- fixture: a minimal bun + TS project, committed, then two worktrees.
MAIN="$TMPDIR/main"
mkdir -p "$MAIN/src"
touch "$MAIN/bun.lock"
echo '{}' > "$MAIN/tsconfig.json"
echo '{"name":"fixture-067"}' > "$MAIN/package.json"
echo 'export const app = 1;' > "$MAIN/src/app.ts"

git -C "$MAIN" init -q
git -C "$MAIN" config user.email test@example.com
git -C "$MAIN" config user.name  test
git -C "$MAIN" add -A
git -C "$MAIN" -c commit.gpgsign=false commit -q -m fixture

WT_A="$TMPDIR/wt-a"
WT_B="$TMPDIR/wt-b"
git -C "$MAIN" worktree add --detach "$WT_A" >/dev/null
git -C "$MAIN" worktree add --detach "$WT_B" >/dev/null

# Sibling A: an in-flight edit carrying a type error.
cat > "$WT_A/src/broken.ts" <<'EOF'
// TYPE_ERROR_SENTINEL_067 — deliberate type error for the parallel-edit regression test
export const broken: number = "a string assigned to a number";
EOF
# Sibling B: a clean in-flight edit.
echo 'export const feature = 2;' > "$WT_B/src/feature.ts"

# Isolated state-home so the hook's loop-counter writes never touch Agent0.
STATE_HOME="$TMPDIR/state-home"
mkdir -p "$STATE_HOME"

run_hook() { # $1 = file_path, $2 = agent_id  → echoes the hook's exit code
  local payload rc=0
  payload="$(jq -nc --arg fp "$1" --arg aid "$2" \
    '{agent_id:$aid, tool_name:"Write", tool_input:{file_path:$fp}}')"
  printf '%s' "$payload" | \
    CLAUDE_PROJECT_DIR="$STATE_HOME" \
    CLAUDE_DELEGATION_VALIDATOR="$VALIDATOR" \
    PATH="$SHIM:$PATH" \
    bash "$HOOK" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

# Assert 1 — worktree B validates clean: sibling A's error did not leak.
rc_b="$(run_hook "$WT_B/src/feature.ts" agent-b)"
if [ "$rc_b" != "0" ]; then
  printf 'FAIL: worktree-B validation blocked (exit %s) — sibling-A error leaked across worktrees\n' "$rc_b"
  exit 1
fi

# Assert 2 (non-vacuous guard) — the same hook scoped to worktree A DOES block.
rc_a="$(run_hook "$WT_A/src/broken.ts" agent-a)"
if [ "$rc_a" != "2" ]; then
  printf 'FAIL: worktree-A validation did not block (exit %s) — validator inert, assert 1 would be vacuous\n' "$rc_a"
  exit 1
fi

printf 'PASS — worktree B exit 0 (clean), worktree A exit 2 (its own error caught); no cross-fail.\n'
exit 0
