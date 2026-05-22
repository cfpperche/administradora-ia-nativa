#!/usr/bin/env bash
# Spec 016 — Scenario: idempotent apply.
# Asserts:
#   (a) running --apply twice → second run all `= up to date` lines
#   (b) zero file modifications between first and second apply

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-09-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$SRC/.claude/rules" "$FORK/.claude"

printf '#!/usr/bin/env bash\necho hookA\n' > "$SRC/.claude/hooks/hookA.sh"
printf '# rule-A\n' > "$SRC/.claude/rules/ruleA.md"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh"

printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

# First apply: should write files
first_exit=0
bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || first_exit=$?
if [ "$first_exit" -ne 0 ]; then
  printf 'FAIL: first --apply expected exit 0, got %d\n' "$first_exit"
  exit 1
fi

mid_sha="$(find "$FORK" -type f -exec sha256sum {} \; | sort)"

# Second apply: should be no-op
second_exit=0
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || second_exit=$?
if [ "$second_exit" -ne 0 ]; then
  printf 'FAIL: second --apply expected exit 0, got %d\n%s\n' "$second_exit" "$out"
  exit 1
fi

# Decision output should show `= up to date` lines, no `+ copied`
if printf '%s' "$out" | grep -q '+ copied'; then
  printf 'FAIL: second apply produced `+ copied` lines (not idempotent)\n%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q '= up to date'; then
  printf 'FAIL: second apply missing `= up to date` lines\n%s\n' "$out"
  exit 1
fi

post_sha="$(find "$FORK" -type f -exec sha256sum {} \; | sort)"
if [ "$mid_sha" != "$post_sha" ]; then
  printf 'FAIL: second apply modified filesystem\n'
  exit 1
fi

echo "PASS: 09-idempotent-apply"
