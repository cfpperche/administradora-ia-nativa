#!/usr/bin/env bash
# Spec 016 — Scenario: check mode lists drift.
# Asserts:
#   (a) --check exits 1 when drift exists
#   (b) stdout names each missing file
#   (c) no filesystem writes in fork target

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-01-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$SRC/.claude/rules" "$FORK/.claude/hooks" "$FORK/.claude/rules"

# Source: 2 hooks + 1 rule
printf '#!/usr/bin/env bash\necho hookA\n' > "$SRC/.claude/hooks/hookA.sh"
printf '#!/usr/bin/env bash\necho hookB\n' > "$SRC/.claude/hooks/hookB.sh"
printf '# rule-A\n' > "$SRC/.claude/rules/ruleA.md"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh" "$SRC/.claude/hooks/hookB.sh"

# Fork: only hookA present (missing hookB + ruleA)
printf '#!/usr/bin/env bash\necho hookA\n' > "$FORK/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK/.claude/hooks/hookA.sh"

pre_sha="$(find "$FORK" -type f -exec sha256sum {} \; | sort)"

actual_exit=0
out="$(bash "$TOOL" --check --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

# Assertions
if [ "$actual_exit" -ne 1 ]; then
  printf 'FAIL: expected exit=1 (drift), got exit=%d\n' "$actual_exit"
  printf '%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q 'hookB.sh'; then
  printf 'FAIL: stdout missing hookB.sh\n%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q 'ruleA.md'; then
  printf 'FAIL: stdout missing ruleA.md\n%s\n' "$out"
  exit 1
fi

post_sha="$(find "$FORK" -type f -exec sha256sum {} \; | sort)"
if [ "$pre_sha" != "$post_sha" ]; then
  printf 'FAIL: --check should not modify fork\n'
  exit 1
fi

echo "PASS: 01-check-mode-lists-drift"
