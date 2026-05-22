#!/usr/bin/env bash
# Spec 018 — Scenario: silent when .githooks/ exists AND core.hooksPath is set.
# Asserts:
#   (a) stdout does NOT contain '=== githooks-activation ==='

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-018-02-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

git -C "$TMPDIR" init -q
mkdir -p "$TMPDIR/.githooks" "$TMPDIR/.claude"
printf '#!/usr/bin/env bash\necho mock pre-commit\n' > "$TMPDIR/.githooks/pre-commit"
chmod +x "$TMPDIR/.githooks/pre-commit"

# Activate
git -C "$TMPDIR" config core.hooksPath .githooks

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_GITHOOKS_HINT 2>/dev/null || true

stdin_json='{"source":"startup","session_id":"spec018-02"}'
out="$(printf '%s' "$stdin_json" | bash "$HOOK" 2>&1)" || true

if printf '%s' "$out" | grep -q 'githooks-activation'; then
  printf 'FAIL: githooks-activation should be silent when activated\n%s\n' "$out"
  exit 1
fi

echo "PASS: 02-silent-when-activated"
