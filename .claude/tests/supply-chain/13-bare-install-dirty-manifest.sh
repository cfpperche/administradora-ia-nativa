#!/usr/bin/env bash
# .claude/tests/supply-chain/13-bare-install-dirty-manifest.sh
# V13 — Scenario: bare lockfile-resolve install (`npm install`, `pnpm install`,
# `bun install` with no positional args) + uncommitted manifest at hook time
# triggers a non-blocking advisory naming the dirty manifest basename.
#
# Closes the parent-edit + bare-install coverage gap surfaced via shrnk-mono
# spec 013 dogfood 2026-05-12: parent edits package.json (PostToolUse Edit
# advisory is sub-agent-only → silent for parent), then runs `bun install`
# (bare → existing skip-not-install path). Net pre-fix: zero signal despite
# new dep entering the lockfile. Post-fix: bash hook detects the dirty manifest
# via `git status --porcelain` and emits stderr advisory + audit row.
#
# Five sub-scenarios in one file (shared heavy setup justifies grouping):
#   (a) bun install + dirty package.json → advisory + audit "advisory-bare-install"
#   (b) clean manifest + bun install → skip-not-install (no false positive)
#   (c) dirty README (non-manifest) + bun install → skip-not-install (filter precise)
#   (d) dirty package.json + bun install + valid OVERRIDE → silent + audit
#       "advisory-bare-install-override" with reason preserved
#   (e) dirty package.json + bun install WITH args (`bun install elysia`) →
#       existing block path fires (bare-install detection MUST NOT short-circuit
#       the with-args path)

set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-026-V13-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Real git repo — the bare-install advisory depends on `git status --porcelain`.
( cd "$TMPDIR" && git init -q && git config user.email t@t && git config user.name t )

# Committed baseline: tracked package.json + tracked README so subsequent
# modifications show as `M ` (modified-tracked), not `?? ` (untracked).
echo '{"name":"v13"}' > "$TMPDIR/package.json"
echo '# v13' > "$TMPDIR/README.md"
( cd "$TMPDIR" && git add . && git commit -q -m baseline )

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"

cd "$TMPDIR"

# Reset audit log between sub-scenarios so each assertion sees only its own row.
reset_audit() { : > "$audit_log"; }

run_hook() {
  local cmd="$1"
  local sid="$2"
  local stderr_file="$3"
  local hook_exit=0
  local stdin_json
  stdin_json="$(jq -cn --arg c "$cmd" --arg s "$sid" '{tool_input:{command:$c}, session_id:$s}')"
  printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?
  echo "$hook_exit"
}

fail() { printf 'FAIL (%s): %s\n' "$1" "$2"; exit 1; }

# ---------------------------------------------------------------------------
# (a) Dirty package.json + bare bun install → advisory
# ---------------------------------------------------------------------------
reset_audit
echo '{"name":"v13","devDependencies":{"axios":"^1.0.0"}}' > "$TMPDIR/package.json"

stderr_file="$TMPDIR/a.err"
exit_code="$(run_hook "bun install" "scenario-a" "$stderr_file")"

[ "$exit_code" = "0" ] || fail "a" "want exit 0, got $exit_code"
grep -q '^supply-chain-advisory: bare `bun install` with uncommitted manifest(s): package.json' "$stderr_file" \
  || fail "a" "stderr advisory missing or wrong shape; got: $(cat "$stderr_file")"

decision="$(jq -r '.decision' "$audit_log")"
[ "$decision" = "advisory-bare-install" ] || fail "a" "want decision=advisory-bare-install, got $decision"

manager="$(jq -r '.manager' "$audit_log")"
[ "$manager" = "bun" ] || fail "a" "want manager=bun, got $manager"

action="$(jq -r '.action' "$audit_log")"
[ "$action" = "install" ] || fail "a" "want action=install, got $action"

pkgs="$(jq -c '.packages' "$audit_log")"
[ "$pkgs" = "[]" ] || fail "a" "want packages=[], got $pkgs"

override="$(jq -r '.override_reason' "$audit_log")"
[ "$override" = "null" ] || fail "a" "want override_reason=null, got $override"

# ---------------------------------------------------------------------------
# (b) Clean manifest + bare bun install → skip-not-install (no false positive)
# ---------------------------------------------------------------------------
reset_audit
( cd "$TMPDIR" && git checkout -q -- package.json )

stderr_file="$TMPDIR/b.err"
exit_code="$(run_hook "bun install" "scenario-b" "$stderr_file")"

[ "$exit_code" = "0" ] || fail "b" "want exit 0, got $exit_code"
[ ! -s "$stderr_file" ] || fail "b" "stderr should be empty for clean-tree skip; got: $(cat "$stderr_file")"

decision="$(jq -r '.decision' "$audit_log")"
[ "$decision" = "skip-not-install" ] || fail "b" "want skip-not-install, got $decision"

# ---------------------------------------------------------------------------
# (c) Dirty README only (no manifest) + bun install → skip-not-install
# ---------------------------------------------------------------------------
reset_audit
echo '# v13 — modified' > "$TMPDIR/README.md"

stderr_file="$TMPDIR/c.err"
exit_code="$(run_hook "bun install" "scenario-c" "$stderr_file")"

[ "$exit_code" = "0" ] || fail "c" "want exit 0, got $exit_code"
[ ! -s "$stderr_file" ] || fail "c" "stderr should be empty when only non-manifest dirty; got: $(cat "$stderr_file")"

decision="$(jq -r '.decision' "$audit_log")"
[ "$decision" = "skip-not-install" ] || fail "c" "want skip-not-install when only README dirty, got $decision"

( cd "$TMPDIR" && git checkout -q -- README.md )

# ---------------------------------------------------------------------------
# (d) Dirty package.json + bare bun install + valid OVERRIDE → silent
# ---------------------------------------------------------------------------
reset_audit
echo '{"name":"v13","devDependencies":{"axios":"^1.0.0"}}' > "$TMPDIR/package.json"

override_reason="deliberate resolve of vetted axios dep per prior decision"
cmd="bun install
# OVERRIDE: $override_reason"

stderr_file="$TMPDIR/d.err"
exit_code="$(run_hook "$cmd" "scenario-d" "$stderr_file")"

[ "$exit_code" = "0" ] || fail "d" "want exit 0, got $exit_code"
[ ! -s "$stderr_file" ] || fail "d" "stderr should be silent under valid override; got: $(cat "$stderr_file")"

decision="$(jq -r '.decision' "$audit_log")"
[ "$decision" = "advisory-bare-install-override" ] || fail "d" "want advisory-bare-install-override, got $decision"

audit_reason="$(jq -r '.override_reason' "$audit_log")"
[ "$audit_reason" = "$override_reason" ] || fail "d" "override_reason mismatch: want='$override_reason', got='$audit_reason'"

# ---------------------------------------------------------------------------
# (e) Dirty package.json + bun install WITH args → existing block path,
#     NOT short-circuited by bare-install detection
# ---------------------------------------------------------------------------
reset_audit
# package.json still dirty from (d)

stderr_file="$TMPDIR/e.err"
exit_code="$(run_hook "bun install elysia" "scenario-e" "$stderr_file")"

[ "$exit_code" = "2" ] || fail "e" "want exit 2 (block-mode default), got $exit_code"
grep -q '^supply-chain-block: bun install detected' "$stderr_file" \
  || fail "e" "stderr should carry block template, not bare-install advisory; got: $(cat "$stderr_file")"
! grep -q 'advisory-bare-install' "$stderr_file" || fail "e" "block path leaked bare-install string into stderr"

decision="$(jq -r '.decision' "$audit_log")"
[ "$decision" = "block" ] || fail "e" "want decision=block (with-args path unaffected), got $decision"

printf 'PASS (5 sub-scenarios: a=advisory  b=clean-skip  c=non-manifest-skip  d=override-silent  e=with-args-blocks)\n'
exit 0
