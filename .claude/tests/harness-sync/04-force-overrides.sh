#!/usr/bin/env bash
# Spec 016 — Scenario: --force overrides customization protection.
# Asserts:
#   (a) customized file IS overwritten under --force
#   (b) stderr emits `! overwritten:` warning
#   (c) exit 0

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-04-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude/hooks"

printf '#!/usr/bin/env bash\necho canonical-A\n' > "$SRC/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh"

printf '#!/usr/bin/env bash\necho FORK-CUSTOM-A\n' > "$FORK/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK/.claude/hooks/hookA.sh"

canonical_sha="$(sha256sum "$SRC/.claude/hooks/hookA.sh" | awk '{print $1}')"

actual_exit=0
out="$(bash "$TOOL" --apply --force --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --force expected exit 0, got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q '! overwritten.*hookA.sh'; then
  printf 'FAIL: missing `! overwritten` warning for hookA.sh\n%s\n' "$out"
  exit 1
fi

after_sha="$(sha256sum "$FORK/.claude/hooks/hookA.sh" | awk '{print $1}')"
if [ "$canonical_sha" != "$after_sha" ]; then
  printf 'FAIL: hookA.sh hash does not match canonical after --force\n'
  exit 1
fi

echo "PASS: 04-force-overrides"
