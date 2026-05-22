#!/usr/bin/env bash
# Spec 018 — Scenario: advisory fires when .githooks/ exists but config absent.
# Asserts:
#   (a) stdout contains '=== githooks-activation ==='
#   (b) stdout contains the literal command 'git config core.hooksPath .githooks'

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-018-01-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Mock project: git repo + .githooks/pre-commit + NO core.hooksPath config
git -C "$TMPDIR" init -q
mkdir -p "$TMPDIR/.githooks" "$TMPDIR/.claude"
printf '#!/usr/bin/env bash\necho mock pre-commit\n' > "$TMPDIR/.githooks/pre-commit"
chmod +x "$TMPDIR/.githooks/pre-commit"

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_GITHOOKS_HINT 2>/dev/null || true

stdin_json='{"source":"startup","session_id":"spec018-01"}'
out="$(printf '%s' "$stdin_json" | bash "$HOOK" 2>&1)" || true

if ! printf '%s' "$out" | grep -q '=== githooks-activation ==='; then
  printf 'FAIL: expected githooks-activation block in stdout\n%s\n' "$out"
  exit 1
fi

if ! printf '%s' "$out" | grep -q 'git config core.hooksPath .githooks'; then
  printf 'FAIL: expected literal activation command in stdout\n%s\n' "$out"
  exit 1
fi

echo "PASS: 01-advisory-fires-when-inactive"
