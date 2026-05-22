#!/usr/bin/env bash
# Spec 019 — Scenario: migration moves substantive memories.
# Asserts:
#   (a) .claude/memory/agent0-purpose.md exists with frontmatter (name, description, type)
#   (b) .claude/memory/visibility-intent.md exists with frontmatter (name, description, type)
#   (c) ~/.claude/projects/-home-goat-Agent0/memory/user_language.md STILL exists (preference stays)
#   (d) The two migrated source files in CC per-user are GONE

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
CC_PERUSER="$HOME/.claude/projects/-home-goat-Agent0/memory"

check_frontmatter() {
  local f="$1"
  if [ ! -f "$f" ]; then
    printf 'FAIL: missing file %s\n' "$f"
    return 1
  fi
  for field in 'name:' 'description:' 'type:'; do
    if ! head -n 10 "$f" | grep -q "$field"; then
      printf 'FAIL: %s missing `%s` field in frontmatter\n' "$f" "$field"
      return 1
    fi
  done
  return 0
}

check_frontmatter "$AGENT0_ROOT/.claude/memory/agent0-purpose.md" || exit 1
check_frontmatter "$AGENT0_ROOT/.claude/memory/visibility-intent.md" || exit 1

if [ ! -f "$CC_PERUSER/user_language.md" ]; then
  printf 'FAIL: per-user user_language.md was deleted (should have stayed — it is a preference)\n'
  exit 1
fi

for orphan in project_agent0_purpose.md project_visibility_intent.md; do
  if [ -f "$CC_PERUSER/$orphan" ]; then
    printf 'FAIL: per-user %s still exists after migration\n' "$orphan"
    exit 1
  fi
done

echo "PASS: 06-migration-shape"
