#!/usr/bin/env bash
# Spec 018 — Scenario: CLAUDE_SKIP_GITHOOKS_HINT=1 suppresses the advisory.
# Asserts:
#   (a) stdout does NOT contain 'githooks-activation' even with .githooks/ present and config absent

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-018-04-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

git -C "$TMPDIR" init -q
mkdir -p "$TMPDIR/.githooks" "$TMPDIR/.claude"
printf '#!/usr/bin/env bash\necho mock pre-commit\n' > "$TMPDIR/.githooks/pre-commit"
chmod +x "$TMPDIR/.githooks/pre-commit"

# .githooks/ exists, config NOT set, but opt-out is on
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SKIP_GITHOOKS_HINT=1

stdin_json='{"source":"startup","session_id":"spec018-04"}'
out="$(printf '%s' "$stdin_json" | bash "$HOOK" 2>&1)" || true

if printf '%s' "$out" | grep -q 'githooks-activation'; then
  printf 'FAIL: githooks-activation should be silent under CLAUDE_SKIP_GITHOOKS_HINT=1\n%s\n' "$out"
  exit 1
fi

echo "PASS: 04-skip-env-var"
