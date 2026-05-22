#!/usr/bin/env bash
# Spec 068 — Scenario: an upstream-removed file the fork customized is NOT deleted.
# Asserts:
#   (a) a baseline file absent from Agent0's manifest whose fork copy differs
#       from baseline is preserved (fork work is never silently destroyed)
#   (b) it is reported `!! customized ... (upstream-removed)`
#   (c) --apply exits non-zero

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-068-27-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude/hooks"

printf '#!/usr/bin/env bash\necho hookA\n' > "$SRC/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh"

printf '#!/usr/bin/env bash\necho hookA\n' > "$FORK/.claude/hooks/hookA.sh"
printf '#!/usr/bin/env bash\necho FORK-EDITED-legacy\n' > "$FORK/.claude/hooks/legacyhook.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK/.claude/hooks/hookA.sh" "$FORK/.claude/hooks/legacyhook.sh"

hookA_sha="$(sha256sum "$FORK/.claude/hooks/hookA.sh" | awk '{print $1}')"
# Baseline records legacyhook with a sha the fork copy does NOT match — fork edited it.
cat > "$FORK/.claude/harness-sync-baseline.json" <<EOF
{
  "agent0_commit": null,
  "synced_at": "2026-05-01T00:00:00Z",
  "tool_version": 1,
  "files": {
    ".claude/hooks/hookA.sh": "$hookA_sha",
    ".claude/hooks/legacyhook.sh": "1111111111111111111111111111111111111111111111111111111111111111"
  }
}
EOF

actual_exit=0
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  printf 'FAIL: customized-upstream-removed --apply expected non-zero exit, got 0\n%s\n' "$out"
  exit 1
fi

if [ ! -f "$FORK/.claude/hooks/legacyhook.sh" ]; then
  printf 'FAIL: fork-customized upstream-removed file was deleted (fork work destroyed)\n'
  exit 1
fi

if ! printf '%s' "$out" | grep -qE '!! customized.*legacyhook\.sh.*upstream-removed'; then
  printf 'FAIL: expected `!! customized ... (upstream-removed)` for legacyhook.sh\n%s\n' "$out"
  exit 1
fi

echo "PASS: 27-baseline-customized-upstream-removed"
