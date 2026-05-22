#!/usr/bin/env bash
# port-frontmatter.sh — idempotent SKILL.md frontmatter patcher (Agent0 spec 033)
#
# Adds missing required-by-spec fields (name, license, compatibility, metadata)
# for agentskills.io compliance. Detects portability tier from body content and
# fills the canonical compatibility text + metadata.agent0-portability-tier value
# accordingly.
#
# DECISIONS (spec 033 Phase C — see references/portability-tiers.md):
# - Tier metadata key is `agent0-portability-tier` (kebab-namespaced) under `metadata:`
# - `argument-hint:` stays at TOP-LEVEL (CC reads it only there per official docs);
#   port does NOT migrate it to metadata
# - Body bytes after the closing `---` are preserved byte-identical
# - Idempotent: running twice on the same file is a no-op on the second run
#
# Usage: port-frontmatter.sh <skill-dir>
# Exit:  0 on success, 1 on parse failure, 2 on usage error

set -u

usage() { echo "usage: $0 <skill-dir>" >&2; exit 2; }
[ $# -eq 1 ] || usage

skill_dir="$1"
[ -d "$skill_dir" ] || { echo "error: not a directory: $skill_dir" >&2; exit 2; }
skill_md="$skill_dir/SKILL.md"
[ -f "$skill_md" ] || { echo "error: SKILL.md not found at $skill_md" >&2; exit 1; }

dir_basename="$(basename "$(realpath "$skill_dir")")"

# Parse current frontmatter
first_line="$(head -n1 "$skill_md")"
[ "$first_line" = "---" ] || { echo "error: SKILL.md does not start with '---'" >&2; exit 1; }
close_line="$(awk 'NR>=2 && NR<=200 && /^---$/ {print NR; exit}' "$skill_md")"
[ -n "$close_line" ] || { echo "error: closing '---' not found before line 200" >&2; exit 1; }

frontmatter="$(sed -n "2,$((close_line - 1))p" "$skill_md")"
body_start=$((close_line + 1))

# Helpers
has_key()              { printf '%s\n' "$frontmatter" | grep -qE "^${1}:[[:space:]]"; }
has_bare_key()         { printf '%s\n' "$frontmatter" | grep -qE "^${1}:[[:space:]]*$"; }
has_metadata_block()   { has_bare_key metadata; }
has_tier_under_meta()  { printf '%s\n' "$frontmatter" | grep -qE "^[[:space:]]+agent0-portability-tier:[[:space:]]"; }

# Detect tier from body content — cc-native if any CC-specific signal, else portable
body="$(tail -n +"$body_start" "$skill_md")"
detected_tier="agentskills-portable"
if printf '%s\n' "$body" | grep -qE '\.claude/(rules|hooks|memory|skills|REMINDERS|SESSION)|CLAUDE_SKILL_DIR|CLAUDE_PROJECT_DIR'; then
  detected_tier="cc-native"
fi

# Canonical compatibility text per tier (single-quoted; backticks survive verbatim)
case "$detected_tier" in
  cc-native)
    compat_text='Designed for Claude Code. Body references `.claude/` conventional paths and CC-specific tools; portable to any runtime that maps a `.claude/`-analog directory and surfaces the referenced tools.'
    ;;
  agentskills-portable)
    compat_text='Compatible with any agentskills.io-compatible runtime (Claude Code, Hermes Agent, OpenAI Codex, Cursor, Goose, OpenCode, and ~35 others). Uses only universal primitives (file IO, shell, web).'
    ;;
esac

# Build new frontmatter — preserve existing keys verbatim, append missing ones
new_frontmatter="$frontmatter"

# Prepend `name:` if missing (so it leads the frontmatter — convention, not requirement)
if ! has_key name; then
  new_frontmatter="name: ${dir_basename}"$'\n'"${new_frontmatter}"
fi

# Append `license:` at end of frontmatter if missing (default MIT)
if ! has_key license; then
  new_frontmatter="${new_frontmatter}"$'\n'"license: MIT"
fi

# Append `compatibility:` at end of frontmatter if missing
if ! has_key compatibility; then
  new_frontmatter="${new_frontmatter}"$'\n'"compatibility: ${compat_text}"
fi

# Add metadata block (or insert tier inside existing one) if missing
if ! has_metadata_block && ! has_key metadata; then
  # No metadata block at all — append a fresh one
  new_frontmatter="${new_frontmatter}"$'\n'"metadata:"$'\n'"  agent0-portability-tier: ${detected_tier}"$'\n'"  version: \"0.1\""
elif ! has_tier_under_meta; then
  # Metadata block exists but no tier inside — insert tier line after `metadata:`
  new_frontmatter="$(printf '%s\n' "$new_frontmatter" | sed "/^metadata:[[:space:]]*$/a\\  agent0-portability-tier: ${detected_tier}")"
fi

# Atomic write: temp file, then rename
tmp_md="${skill_md}.port.tmp"
{
  printf '%s\n' "---"
  printf '%s\n' "$new_frontmatter"
  printf '%s\n' "---"
  tail -n +"$body_start" "$skill_md"
} > "$tmp_md"

mv "$tmp_md" "$skill_md"

echo "ported: $skill_md (tier: $detected_tier)"
