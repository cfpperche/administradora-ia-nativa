#!/usr/bin/env bash
# Spec 016 — Scenario: .gitignore merge is idempotent on re-sync.
# Asserts:
#   (a) First --apply merges; file changes.
#   (b) Second --apply with no source changes reports "up to date"; file unchanged.
#   (c) Subsequent --check exits 0 (no drift).

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-15-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

printf '%s\n' \
  '# Claude Code state' \
  '.claude/.runtime-state/' \
  '.claude/secrets-audit.jsonl' \
  > "$SRC/.gitignore"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

printf '%s\n' \
  '/vendor' \
  '/node_modules' \
  > "$FORK/.gitignore"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

# First apply — should merge.
first_out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || true
sha_after_first="$(sha256sum "$FORK/.gitignore" | awk '{print $1}')"

if ! printf '%s' "$first_out" | grep -qE 'merged \.gitignore'; then
  printf 'FAIL(a): first apply did not log "merged .gitignore"\n%s\n' "$first_out"
  exit 1
fi

# Second apply — should be no-op.
second_out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || true
sha_after_second="$(sha256sum "$FORK/.gitignore" | awk '{print $1}')"

if [ "$sha_after_first" != "$sha_after_second" ]; then
  printf 'FAIL(b): second apply changed file (hash drift on idempotent re-run)\n'
  diff <(printf '%s\n' "$sha_after_first") <(printf '%s\n' "$sha_after_second")
  cat "$FORK/.gitignore"
  exit 1
fi

if ! printf '%s' "$second_out" | grep -qE 'up to date \.gitignore'; then
  printf 'FAIL(b): second apply did not log "up to date .gitignore"\n%s\n' "$second_out"
  exit 1
fi

# Third --check — should exit 0 (no drift).
check_exit=0
bash "$TOOL" --check --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || check_exit=$?
if [ "$check_exit" -ne 0 ]; then
  printf 'FAIL(c): --check after idempotent merge expected exit 0, got %d\n' "$check_exit"
  exit 1
fi

printf 'PASS: gitignore merge idempotent (first merges, second up-to-date, check exits 0)\n'
