#!/usr/bin/env bash
# Spec 068 — Scenario: the baseline is recorded on every --apply.
# Asserts that after --apply the fork has a valid harness-sync-baseline.json
# capturing Agent0's managed-file sha-set, with all required top-level keys.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-068-29-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude"

printf '#!/usr/bin/env bash\necho hookA\n' > "$SRC/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/hookA.sh"
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

BASELINE="$FORK/.claude/harness-sync-baseline.json"
if [ -f "$BASELINE" ]; then
  printf 'FAIL: precondition — baseline should not exist before first --apply\n'
  exit 1
fi

bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || true

if [ ! -f "$BASELINE" ]; then
  printf 'FAIL: harness-sync-baseline.json not written by --apply\n'
  exit 1
fi

if ! jq -e . "$BASELINE" >/dev/null 2>&1; then
  printf 'FAIL: harness-sync-baseline.json is not valid JSON\n'
  cat "$BASELINE"
  exit 1
fi

recorded="$(jq -r '.files[".claude/hooks/hookA.sh"] // ""' "$BASELINE")"
expected="$(sha256sum "$SRC/.claude/hooks/hookA.sh" | awk '{print $1}')"
if [ "$recorded" != "$expected" ]; then
  printf 'FAIL: baseline files-map sha mismatch for hookA.sh\n  recorded=%s\n  expected=%s\n' "$recorded" "$expected"
  exit 1
fi

for key in agent0_commit synced_at tool_version files; do
  if ! jq -e "has(\"$key\")" "$BASELINE" >/dev/null 2>&1; then
    printf 'FAIL: baseline missing top-level key: %s\n' "$key"
    exit 1
  fi
done

echo "PASS: 29-baseline-recorded-on-apply"
