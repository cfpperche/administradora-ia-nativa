#!/usr/bin/env bash
# Spec 019 — Scenario: SessionStart does NOT auto-load memory.
# INVARIANT GUARD: protects against future regression where someone wires
# SessionStart to inject memory content (re-introduces the scaling problem).
# Asserts:
#   (a) Even with 5+ memory files present, session-start.sh emits NO `project-memory` block
#   (b) No body content from any memory file appears in stdout

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/session-start.sh"

TMPDIR="$(mktemp -d -t spec-019-04-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude/memory"

# Populate with 5 memories — each with a unique sentinel string
for letter in a b c d e; do
  cat > "$TMPDIR/.claude/memory/${letter}.md" <<EOF
---
name: ${letter}
description: test memory
metadata:
  type: project
---
SENTINEL-MEMORY-BODY-${letter}: this string should NEVER appear in SessionStart output
EOF
done

export CLAUDE_PROJECT_DIR="$TMPDIR"

stdin_json='{"source":"startup","session_id":"spec019-04"}'
out="$(printf '%s' "$stdin_json" | bash "$HOOK" 2>&1)" || true

if printf '%s' "$out" | grep -qi 'project-memory'; then
  printf 'FAIL: SessionStart emitted a project-memory block\n%s\n' "$out"
  exit 1
fi

for letter in a b c d e; do
  if printf '%s' "$out" | grep -q "SENTINEL-MEMORY-BODY-${letter}"; then
    printf 'FAIL: memory file %s.md body leaked into SessionStart output\n' "$letter"
    exit 1
  fi
done

echo "PASS: 04-sessionstart-no-memory-block"
