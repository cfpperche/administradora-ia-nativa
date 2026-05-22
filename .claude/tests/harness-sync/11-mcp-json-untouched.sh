#!/usr/bin/env bash
# Spec 016 — Scenario: .mcp.json.example synced; .mcp.json never touched.
# Asserts:
#   (a) .mcp.json.example copied from Agent0 to fork
#   (b) fork's .mcp.json (with sensitive content) untouched

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-11-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude" "$FORK/.claude"

# Agent0 ships .mcp.json.example
cat > "$SRC/.mcp.json.example" <<'EOF'
// Copy to .mcp.json and uncomment desired blocks.
{
  "mcpServers": {
//    "playwright": {"command":"npx", "args":["@playwright/mcp@latest"]}
  }
}
EOF
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# Fork has a populated .mcp.json with a secret-adjacent marker; NO .mcp.json.example
cat > "$FORK/.mcp.json" <<'EOF'
{"mcpServers":{"dbhub":{"command":"npx","args":["@bytebase/dbhub@latest"],"env":{"DATABASE_URL":"FORK-SECRET-MARKER"}}}}
EOF
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

mcp_json_sha_before="$(sha256sum "$FORK/.mcp.json" | awk '{print $1}')"

actual_exit=0
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

if [ ! -f "$FORK/.mcp.json.example" ]; then
  printf 'FAIL: .mcp.json.example not copied\n%s\n' "$out"
  exit 1
fi

mcp_json_sha_after="$(sha256sum "$FORK/.mcp.json" | awk '{print $1}')"
if [ "$mcp_json_sha_before" != "$mcp_json_sha_after" ]; then
  printf 'FAIL: .mcp.json was modified by sync\n'
  exit 1
fi

# Sanity: marker still present
if ! grep -q 'FORK-SECRET-MARKER' "$FORK/.mcp.json"; then
  printf 'FAIL: .mcp.json content corrupted\n'
  exit 1
fi

echo "PASS: 11-mcp-json-untouched"
