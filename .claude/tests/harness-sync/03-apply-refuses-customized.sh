#!/usr/bin/env bash
# Spec 016 — Scenario: apply refuses to overwrite customized files.
# Asserts:
#   (a) customized (hash-mismatch + exists) file NOT overwritten
#   (b) stderr emits `!! customized:` for that file
#   (c) exit non-zero
#   (d) other un-customized files in same run still copy

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-03-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude/hooks"

# Source: canonical hookA + hookB
printf '#!/usr/bin/env bash\necho canonical-A\n' > "$SRC/.claude/hooks/hookA.sh"
printf '#!/usr/bin/env bash\necho canonical-B\n' > "$SRC/.claude/hooks/hookB.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh" "$SRC/.claude/hooks/hookB.sh"

# Fork: hookA customized (different bytes), hookB missing
printf '#!/usr/bin/env bash\necho FORK-CUSTOM-A\n' > "$FORK/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK/.claude/hooks/hookA.sh"

custom_sha_before="$(sha256sum "$FORK/.claude/hooks/hookA.sh" | awk '{print $1}')"

actual_exit=0
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  printf 'FAIL: expected non-zero exit (customization refused), got 0\n%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q '!! customized.*hookA.sh'; then
  printf 'FAIL: missing `!! customized` line for hookA.sh\n%s\n' "$out"
  exit 1
fi

custom_sha_after="$(sha256sum "$FORK/.claude/hooks/hookA.sh" | awk '{print $1}')"
if [ "$custom_sha_before" != "$custom_sha_after" ]; then
  printf 'FAIL: customized hookA.sh was overwritten\n'
  exit 1
fi

if [ ! -f "$FORK/.claude/hooks/hookB.sh" ]; then
  printf 'FAIL: un-customized hookB.sh should still copy\n%s\n' "$out"
  exit 1
fi

echo "PASS: 03-apply-refuses-customized"
