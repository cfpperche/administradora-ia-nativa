#!/usr/bin/env bash
# .claude/skills/product/scripts/clear-target.sh
# Spec 069 — selective clear of a /product --out target.
#
# Removes every top-level entry of <out> that is NOT in the Agent0 harness
# allowlist, so a /product overwrite regenerates the docs foundation WITHOUT
# destroying .git/ history or the bootstrapped harness. Replaces the blunt
# `rm -r <out>` that spec-069 "Gap F" flagged as an unrecoverable foot-gun.
# See docs/specs/069-product-overwrite-git-safety/.
#
# Usage:  clear-target.sh <out>
# Exit:   0 success · 2 usage error (missing / non-directory <out>)

set -euo pipefail

# Harness allowlist — top-level entries preserved across a /product overwrite.
# The CANONICAL list lives in .claude/skills/product/SKILL.md Phase 0 step 1;
# this is a copy, and sync-harness.sh's manifest carries a third. On a manifest
# change, audit all three (same drift caveat SKILL.md's overwrite note carries).
ALLOWLIST=(
  ".claude" ".githooks" ".gitignore" ".gitleaks.toml"
  ".mcp.json.example" "CLAUDE.md" ".git"
)

OUT="${1:-}"
if [ -z "$OUT" ]; then
  printf 'clear-target: missing <out>\nusage: clear-target.sh <out>\n' >&2
  exit 2
fi
OUT="${OUT%/}"
if [ ! -d "$OUT" ]; then
  printf 'clear-target: not a directory: %s\n' "$OUT" >&2
  exit 2
fi

in_allowlist() {
  local name="$1" entry
  for entry in "${ALLOWLIST[@]}"; do
    [ "$name" = "$entry" ] && return 0
  done
  return 1
}

removed=0
for path in "$OUT"/* "$OUT"/.*; do
  [ -e "$path" ] || continue          # unmatched glob → literal; skip
  name="$(basename "$path")"
  case "$name" in
    . | .. ) continue ;;              # the dir itself / its parent
  esac
  # Defense in depth: never remove .git or .claude, whatever the allowlist says.
  case "$name" in
    .git | .claude ) continue ;;
  esac
  if in_allowlist "$name"; then
    continue
  fi
  rm -r "$path"                        # -r only, never -rf (governance gate)
  printf 'removed %s\n' "$name"
  removed=$((removed + 1))
done

printf 'clear-target: %d non-harness top-level entr(ies) removed from %s\n' \
  "$removed" "$OUT" >&2
exit 0
