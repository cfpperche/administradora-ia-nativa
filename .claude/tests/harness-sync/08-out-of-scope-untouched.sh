#!/usr/bin/env bash
# Spec 016 — Scenario: out-of-scope files never touched.
# Asserts:
#   (a) src/, tests/, docs/, package.json, Cargo.toml, pyproject.toml, .mcp.json all byte-identical post-apply
#   (b) nothing under those paths appears in any decision line

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-016-08-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/hooks" "$FORK/.claude" "$FORK/src" "$FORK/tests" "$FORK/docs"

printf '#!/usr/bin/env bash\necho new\n' > "$SRC/.claude/hooks/newhook.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
chmod +x "$SRC/.claude/hooks/newhook.sh"

printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# CLAUDE fork\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

# Out-of-scope content with sentinel markers
printf 'export const main = () => "PRODUCT-CODE-MARKER";\n' > "$FORK/src/main.ts"
printf 'describe("integration", () => "FORK-TEST-MARKER");\n' > "$FORK/tests/integration.test.ts"
printf '# FORK-DOC-MARKER\n' > "$FORK/docs/README.md"
printf '{"name":"PRODUCT-PACKAGE","version":"1.0.0"}\n' > "$FORK/package.json"
printf '[package]\nname = "PRODUCT-CARGO"\n' > "$FORK/Cargo.toml"
printf '[project]\nname = "PRODUCT-PYPROJECT"\n' > "$FORK/pyproject.toml"
printf '{"mcpServers":{"local":"FORK-MCP-MARKER"}}\n' > "$FORK/.mcp.json"

pre_shas="$(find "$FORK/src" "$FORK/tests" "$FORK/docs" "$FORK/package.json" "$FORK/Cargo.toml" "$FORK/pyproject.toml" "$FORK/.mcp.json" -type f -exec sha256sum {} \; | sort)"

actual_exit=0
out="$(bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" 2>&1)" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  printf 'FAIL: --apply expected exit 0, got %d\n%s\n' "$actual_exit" "$out"
  exit 1
fi

post_shas="$(find "$FORK/src" "$FORK/tests" "$FORK/docs" "$FORK/package.json" "$FORK/Cargo.toml" "$FORK/pyproject.toml" "$FORK/.mcp.json" -type f -exec sha256sum {} \; | sort)"

if [ "$pre_shas" != "$post_shas" ]; then
  printf 'FAIL: out-of-scope files modified\n'
  diff <(printf '%s\n' "$pre_shas") <(printf '%s\n' "$post_shas") || true
  exit 1
fi

# Decision output must NOT name out-of-scope paths
if printf '%s' "$out" | grep -qE '(main\.ts|integration\.test\.ts|package\.json|Cargo\.toml|pyproject\.toml|/\.mcp\.json[^.])'; then
  printf 'FAIL: decision output mentions out-of-scope path\n%s\n' "$out"
  exit 1
fi

echo "PASS: 08-out-of-scope-untouched"
