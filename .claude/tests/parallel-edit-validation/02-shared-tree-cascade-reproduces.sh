#!/usr/bin/env bash
# .claude/tests/parallel-edit-validation/02-shared-tree-cascade-reproduces.sh
# Spec 067 — Negative control: two concurrent edits in ONE shared working tree
# DO cascade (spec.md AC4, negative half). This proves the property scenario 01
# tests is real — without worktree isolation, a clean edit is failed by a
# sibling's in-flight error, because the project-wide validator sees the whole
# shared tree. If this scenario did NOT block, scenario 01 would be vacuous.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/post-edit-validate.sh"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

[ -f "$HOOK" ]      || { printf 'FAIL: hook not found: %s\n' "$HOOK"; exit 1; }
[ -x "$VALIDATOR" ] || { printf 'FAIL: validator not executable: %s\n' "$VALIDATOR"; exit 1; }

TMPDIR="$(mktemp -d -t spec-067-02-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# --- bun shim: identical to scenario 01 — `bun tsc` models a project-wide
# typecheck by scanning the cwd subtree for the broken fixture's sentinel.
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

# --- fixture: ONE shared tree (no worktree isolation).
SHARED="$TMPDIR/shared"
mkdir -p "$SHARED/src"
touch "$SHARED/bun.lock"
echo '{}' > "$SHARED/tsconfig.json"
echo '{"name":"fixture-067"}' > "$SHARED/package.json"
echo 'export const app = 1;' > "$SHARED/src/app.ts"

git -C "$SHARED" init -q
git -C "$SHARED" config user.email test@example.com
git -C "$SHARED" config user.name  test
git -C "$SHARED" add -A
git -C "$SHARED" -c commit.gpgsign=false commit -q -m fixture

# Sibling A: an in-flight edit carrying a type error — into the SAME tree.
cat > "$SHARED/src/broken.ts" <<'EOF'
// TYPE_ERROR_SENTINEL_067 — deliberate type error for the parallel-edit regression test
export const broken: number = "a string assigned to a number";
EOF
# Sibling B: a clean in-flight edit — into the SAME tree.
echo 'export const feature = 2;' > "$SHARED/src/feature.ts"

STATE_HOME="$TMPDIR/state-home"
mkdir -p "$STATE_HOME"

# Validate sibling B's clean edit. Because A and B share one tree, the
# project-wide `bun tsc --noEmit` sees broken.ts and flips ok=false.
payload="$(jq -nc --arg fp "$SHARED/src/feature.ts" \
  '{agent_id:"agent-b", tool_name:"Write", tool_input:{file_path:$fp}}')"
rc=0
printf '%s' "$payload" | \
  CLAUDE_PROJECT_DIR="$STATE_HOME" \
  CLAUDE_DELEGATION_VALIDATOR="$VALIDATOR" \
  PATH="$SHIM:$PATH" \
  bash "$HOOK" >/dev/null 2>&1 || rc=$?

if [ "$rc" != "2" ]; then
  printf 'FAIL: shared-tree validation of the clean edit did not block (exit %s) — the cascade did not reproduce; scenario 01 cannot be trusted as a real isolation result.\n' "$rc"
  exit 1
fi

printf 'PASS — shared-tree clean edit blocked (exit 2): the validator-cascade reproduces, confirming worktree isolation (scenario 01) is what prevents it.\n'
exit 0
