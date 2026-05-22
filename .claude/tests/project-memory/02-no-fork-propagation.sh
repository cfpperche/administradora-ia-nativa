#!/usr/bin/env bash
# Spec 019 — Scenario: project memory CONTENT does NOT propagate to forks,
# but the empty scaffold (.gitkeep) DOES so each fork can use its own bucket.
# INVARIANT GUARD: protects sync-harness manifest from accidental inclusion
# of memory content files.
# Asserts:
#   (a) Agent0 mock with .claude/memory/{.gitkeep, MEMORY.md, foo.md} populated
#   (b) After sync: fork has .claude/memory/.gitkeep (scaffold shipped)
#   (c) After sync: fork has NO MEMORY.md (Agent0 content) and NO foo.md

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.claude/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-019-02-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
FORK="$TMPDIR/fork"
mkdir -p "$SRC/.claude/memory" "$SRC/.claude/hooks" "$FORK/.claude"

# Mock Agent0 source — minimal but with memory content populated
printf '#!/usr/bin/env bash\necho test\n' > "$SRC/.claude/hooks/test-hook.sh"
chmod +x "$SRC/.claude/hooks/test-hook.sh"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"

# Scaffold marker + Agent0-internal content
touch "$SRC/.claude/memory/.gitkeep"
cat > "$SRC/.claude/memory/foo.md" <<'EOF'
---
name: foo
description: Agent0-only memory content that should NEVER ship to forks
metadata:
  type: project
---
foo body
EOF
cat > "$SRC/.claude/memory/MEMORY.md" <<'EOF'
- [Foo](foo.md) — Agent0-internal entry that should NOT appear in fork
EOF

# Empty fork target
printf '{"hooks":{}}\n' > "$FORK/.claude/settings.json"
printf '# Fork CLAUDE\n\n## Compact Instructions\n' > "$FORK/CLAUDE.md"

bash "$TOOL" --apply --agent0-path="$SRC" "$FORK" >/dev/null 2>&1 || true

# Assert: empty scaffold shipped (fork has its own bucket to use)
if [ ! -f "$FORK/.claude/memory/.gitkeep" ]; then
  printf 'FAIL: .gitkeep scaffold did not ship to fork\n'
  ls -la "$FORK/.claude/memory/" 2>&1
  exit 1
fi

# Assert: content files did NOT ship
if [ -f "$FORK/.claude/memory/foo.md" ]; then
  printf 'FAIL: Agent0 content file foo.md leaked to fork\n'
  exit 1
fi
if [ -f "$FORK/.claude/memory/MEMORY.md" ]; then
  printf 'FAIL: Agent0 MEMORY.md leaked to fork (each fork must have its own)\n'
  exit 1
fi

echo "PASS: 02-no-fork-propagation"
