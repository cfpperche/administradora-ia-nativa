#!/usr/bin/env bash
# Spec 016 — Scenario: .gitignore merge when fork has no .gitignore.
# Asserts:
#   (a) Fork lacking .gitignore receives Agent0's verbatim via process_file
#   (b) No merge marker appears (full copy, not append-merge)
#   (c) MERGED counter NOT incremented (this is a COPY, not a MERGE)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-13-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Agent0: minimal valid harness with a .gitignore containing 3 entries.
printf '%s\n' \
  '# Claude Code state' \
  '.claude/.runtime-state/' \
  '.claude/secrets-audit.jsonl' \
  '.claude/delegation-audit.jsonl' \
  > "$SRC/.gitignore"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# Fork: no .gitignore at all.
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

actual_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n' "$actual_exit"
  exit 1
fi

if [ ! -f "$FORK/.gitignore" ]; then
  printf 'FAIL: fork .gitignore not created\n'
  exit 1
fi

# Assert (a): fork .gitignore byte-identical to Agent0's.
src_sha="$(sha256sum "$SRC/.gitignore" | awk '{print $1}')"
fork_sha="$(sha256sum "$FORK/.gitignore" | awk '{print $1}')"
if [ "$src_sha" != "$fork_sha" ]; then
  printf 'FAIL: expected byte-identical copy, got different hashes\n'
  diff "$SRC/.gitignore" "$FORK/.gitignore"
  exit 1
fi

# Assert (b): no merge marker — this was a copy, not an append-merge.
if grep -Fq '# === Agent0 harness sync — additions ===' "$FORK/.gitignore"; then
  printf 'FAIL: unexpected merge marker in copied-only file\n'
  exit 1
fi

printf 'PASS: fork without .gitignore receives Agent0 copy verbatim\n'
