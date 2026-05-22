#!/usr/bin/env bash
# Spec 068 — Scenario: a fork with no baseline file does not error on first --apply.
# Asserts the first sync degrades gracefully: differing files refused as
# `(no baseline)`, missing files copied, and a baseline written for next time.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-068-31-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude/hooks"

printf '#!/usr/bin/env bash\necho agent0-A\n' > "$SRC/.claude/hooks/hookA.sh"
printf '#!/usr/bin/env bash\necho agent0-B\n' > "$SRC/.claude/hooks/hookB.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh" "$SRC/.claude/hooks/hookB.sh"

# Fork: hookA differs (pre-baseline ambiguity), hookB missing, NO baseline file.
printf '#!/usr/bin/env bash\necho FORK-A\n' > "$FORK/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK/.claude/hooks/hookA.sh"

BASELINE="$FORK/.claude/harness-sync-baseline.json"
if [ -f "$BASELINE" ]; then
  printf 'FAIL: precondition — baseline must not exist\n'
  exit 1
fi

actual_exit=0
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

# exit 1 = customizations refused (NOT exit 2 = a usage/crash error).
if [ "$actual_exit" -ne 1 ]; then
  printf 'FAIL: bootstrap --apply expected exit 1 (refusal), got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -E 'hookA\.sh' | grep -q 'no baseline'; then
  printf 'FAIL: differing hookA.sh should be refused as `(no baseline)` on first sync\n%s\n' "$out"
  exit 1
fi

if [ ! -f "$FORK/.claude/hooks/hookB.sh" ]; then
  printf 'FAIL: missing hookB.sh should still be copied on first sync\n%s\n' "$out"
  exit 1
fi

if [ ! -f "$BASELINE" ]; then
  printf 'FAIL: first --apply must write the baseline for subsequent 3-way sync\n'
  exit 1
fi

echo "PASS: 31-baseline-bootstrap-no-baseline"
