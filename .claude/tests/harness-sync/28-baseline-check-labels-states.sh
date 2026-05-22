#!/usr/bin/env bash
# Spec 068 — Scenario: --check distinguishes stale from customized.
# Asserts a drifted fork with a baseline gets each plain file labelled
# up-to-date / stale / customized / removed, --check exits 1, and --check
# performs no writes.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-068-28-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude/hooks"

# Agent0: 3 hooks.
printf 'stale-v2\n'   > "$SRC/.claude/hooks/hStale.sh"
printf 'agent0\n'     > "$SRC/.claude/hooks/hCustom.sh"
printf 'current\n'    > "$SRC/.claude/hooks/hCurrent.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC"/.claude/hooks/*.sh

# Fork: hStale untouched-but-behind, hCustom fork-edited, hCurrent in sync,
# hOrphan present but gone from Agent0.
printf 'stale-v1\n'  > "$FORK/.claude/hooks/hStale.sh"
printf 'fork-edit\n' > "$FORK/.claude/hooks/hCustom.sh"
printf 'current\n'   > "$FORK/.claude/hooks/hCurrent.sh"
printf 'orphan\n'    > "$FORK/.claude/hooks/hOrphan.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK"/.claude/hooks/*.sh

sha() { sha256sum "$1" | awk '{print $1}'; }
cat > "$FORK/.claude/harness-sync-baseline.json" <<EOF
{
  "agent0_commit": null,
  "synced_at": "2026-05-01T00:00:00Z",
  "tool_version": 1,
  "files": {
    ".claude/hooks/hStale.sh": "$(sha "$FORK/.claude/hooks/hStale.sh")",
    ".claude/hooks/hCustom.sh": "2222222222222222222222222222222222222222222222222222222222222222",
    ".claude/hooks/hCurrent.sh": "$(sha "$FORK/.claude/hooks/hCurrent.sh")",
    ".claude/hooks/hOrphan.sh": "$(sha "$FORK/.claude/hooks/hOrphan.sh")"
  }
}
EOF

pre_sha="$(find "$FORK" -type f -exec sha256sum {} \; | sort)"

actual_exit=0
out="$(bash "$TOOL" --check --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 1 ]; then
  printf 'FAIL: --check expected exit 1 (drift), got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

fail=0
printf '%s' "$out" | grep -qE '~ stale.*hStale\.sh'        || { echo "FAIL: hStale not labelled stale"; fail=1; }
printf '%s' "$out" | grep -qE '!! customized.*hCustom\.sh' || { echo "FAIL: hCustom not labelled customized"; fail=1; }
printf '%s' "$out" | grep -qE '= up to date.*hCurrent\.sh' || { echo "FAIL: hCurrent not labelled up-to-date"; fail=1; }
printf '%s' "$out" | grep -qE '^- removed.*hOrphan\.sh'    || { echo "FAIL: hOrphan not labelled removed"; fail=1; }
if [ "$fail" -ne 0 ]; then
  printf '%s\n' "$out"
  exit 1
fi

post_sha="$(find "$FORK" -type f -exec sha256sum {} \; | sort)"
if [ "$pre_sha" != "$post_sha" ]; then
  printf 'FAIL: --check modified the fork (must be read-only)\n'
  exit 1
fi

echo "PASS: 28-baseline-check-labels-states"
