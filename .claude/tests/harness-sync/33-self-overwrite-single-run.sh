#!/usr/bin/env bash
# Spec 072 — Scenario: a self the run will overwrite does not crash the run.
#
# The fork's own sync-harness.sh is stale; running it makes walk_copy_check
# overwrite that very file mid-run. Without the self-rebootstrap pre-flight,
# bash reads the orchestration tail from the replaced file at a misaligned
# byte offset and the run crashes (the 2026-05-21 mei-saas failure:
# `line 1234: src: unbound variable`). Asserts the fixed tool completes the
# sync in a single invocation — exit 0, no crash, fork copy updated.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
REAL_TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-072-33-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/tools" "$FORK/.claude/tools"

# Agent0 source ships the real sync-harness.sh + a minimal harness.
cp "$REAL_TOOL" "$SRC/.claude/tools/sync-harness.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# Fork has a STALE sync-harness.sh: the real tool with a padding block inserted
# right after `set -euo pipefail`. The insertion shifts every byte below it —
# the orchestration tail included — to a higher offset, so an in-place overwrite
# mid-run reliably misaligns bash's read position.
awk '!done && /^set -euo pipefail$/ {
       print
       for (i = 0; i < 40; i++) print "# spec-072 fixture padding line " i
       done = 1
       next
     } 1' "$REAL_TOOL" > "$FORK/.claude/tools/sync-harness.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

# Baseline records the fork's padded-copy sha → classifies `stale`, not
# `customized` → the run auto-updates (overwrites) it without --force.
fork_sha="$(sha256sum "$FORK/.claude/tools/sync-harness.sh" | awk '{print $1}')"
cat > "$FORK/.claude/harness-sync-baseline.json" <<EOF
{
  "agent0_commit": null,
  "synced_at": "2026-05-01T00:00:00Z",
  "tool_version": 1,
  "files": { ".claude/tools/sync-harness.sh": "$fork_sha" }
}
EOF

src_sha="$(sha256sum "$SRC/.claude/tools/sync-harness.sh" | awk '{print $1}')"

# Run the FORK's own copy once — this is the invocation that self-overwrites.
actual_exit=0
out="$(bash "$FORK/.claude/tools/sync-harness.sh" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: single --apply expected exit 0, got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

if printf '%s' "$out" | grep -qE 'unbound variable|syntax error|command not found'; then
  printf 'FAIL: self-overwrite corruption — crash output detected\n%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q 'synced:'; then
  printf 'FAIL: summary line absent — run did not reach completion\n%s\n' "$out"
  exit 1
fi

after_sha="$(sha256sum "$FORK/.claude/tools/sync-harness.sh" | awk '{print $1}')"
if [ "$after_sha" != "$src_sha" ]; then
  printf 'FAIL: fork sync-harness.sh not updated to Agent0 version in one run\n'
  exit 1
fi

echo "PASS: 33-self-overwrite-single-run"
