#!/usr/bin/env bash
# Spec 016 — Scenario: --force-except keeps matching files customized.
# Asserts:
#   (a) --force --force-except=.gitignore overwrites OTHER customized files
#   (b) .gitignore (matching the except glob) stays customized-refused
#   (c) exit non-zero (because at least one file remains refused)

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-12-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude/hooks"

# Source: canonical hookA + .gitignore
printf '#!/usr/bin/env bash\necho canonical-A\n' > "$SRC/.claude/hooks/hookA.sh"
printf 'AGENT0_GITIGNORE_LINE\n' > "$SRC/.gitignore"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh"

# Fork: both customized
printf '#!/usr/bin/env bash\necho FORK-CUSTOM-A\n' > "$FORK/.claude/hooks/hookA.sh"
printf 'FORK_GITIGNORE_LINE\n' > "$FORK/.gitignore"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"
chmod +x "$FORK/.claude/hooks/hookA.sh"

canonical_hook_sha="$(sha256sum "$SRC/.claude/hooks/hookA.sh" | awk '{print $1}')"
fork_gitignore_sha_before="$(sha256sum "$FORK/.gitignore" | awk '{print $1}')"

actual_exit=0
out="$(bash "$TOOL" --apply --force --force-except='.gitignore' --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

# hookA.sh should be overwritten
if ! printf '%s' "$out" | grep -q '! overwritten.*hookA.sh'; then
  printf 'FAIL: hookA.sh should be overwritten under --force\n%s\n' "$out"
  exit 1
fi

after_hook_sha="$(sha256sum "$FORK/.claude/hooks/hookA.sh" | awk '{print $1}')"
if [ "$canonical_hook_sha" != "$after_hook_sha" ]; then
  printf 'FAIL: hookA.sh hash does not match canonical after --force\n'
  exit 1
fi

# .gitignore should be force-except-skipped (merge handler honors --force-except too)
if ! printf '%s' "$out" | grep -qE '(!! customized.*gitignore|!! force-except .gitignore)'; then
  printf 'FAIL: .gitignore should be force-except-skipped under --force-except\n%s\n' "$out"
  exit 1
fi

after_gi_sha="$(sha256sum "$FORK/.gitignore" | awk '{print $1}')"
if [ "$fork_gitignore_sha_before" != "$after_gi_sha" ]; then
  printf 'FAIL: .gitignore was modified despite --force-except\n'
  exit 1
fi

# Exit non-zero because .gitignore was refused
if [ "$actual_exit" -eq 0 ]; then
  printf 'FAIL: expected non-zero exit (one file refused), got 0\n%s\n' "$out"
  exit 1
fi

echo "PASS: 12-force-except"
