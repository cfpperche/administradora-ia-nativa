#!/usr/bin/env bash
# .claude/tests/mcp-recipes/05-co-exists-with-011.sh
# V5 — Scenario: hint co-exists with spec 011's probe hint.
#
# When a fork has BOTH a stack signal (e.g. next.config.js) AND spec 011
# installed (`.claude/tools/probe.sh` exists), the SessionStart context
# should contain BOTH `=== runtime-introspect ===` AND `=== mcp-recipes ===`
# blocks.
#
# Test invokes both hooks (session-start.sh + mcp-recipes-hint.sh) and
# concatenates output — the real harness fires both on SessionStart per
# settings.json registration; here we simulate by running both and asserting
# the combined output has both framing lines.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SESSION_HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"
MCP_HOOK="$AGENT0_ROOT/.claude/hooks/mcp-recipes-hint.sh"

TMPDIR="$(mktemp -d -t spec-012-V5-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude/tools" "$TMPDIR/.claude/.session-state/V5-test-session"
# Stack signal: next.config.js
touch "$TMPDIR/next.config.js"
# Fake probe.sh (executable) so the runtime-introspect hint fires
printf '#!/usr/bin/env bash\necho probe-stub\n' > "$TMPDIR/.claude/tools/probe.sh"
chmod +x "$TMPDIR/.claude/tools/probe.sh"
# Spec 017: session-state is per-session_id, so the marker lives in a subdir.
touch "$TMPDIR/.claude/.session-state/V5-test-session/started-at"

export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SKIP_MCP_RECIPES

combined="$TMPDIR/combined.txt"
: > "$combined"

# session-start.sh reads stdin (looks for source field) — give it startup
printf '%s' '{"source":"startup"}' | bash "$SESSION_HOOK" >>"$combined" 2>&1 || {
  printf 'FAIL: session-start.sh exited non-zero\n'
  cat "$combined"
  exit 1
}

bash "$MCP_HOOK" >>"$combined" 2>&1 || {
  printf 'FAIL: mcp-recipes-hint.sh exited non-zero\n'
  cat "$combined"
  exit 1
}

if ! grep -qE '=== runtime-introspect ===' "$combined"; then
  printf 'FAIL: runtime-introspect block missing in combined output\n'
  cat "$combined"
  exit 1
fi

if ! grep -qE '=== mcp-recipes ===' "$combined"; then
  printf 'FAIL: mcp-recipes block missing in combined output\n'
  cat "$combined"
  exit 1
fi

printf 'PASS\n'
exit 0
