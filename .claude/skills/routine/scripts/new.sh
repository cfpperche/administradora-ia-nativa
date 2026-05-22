#!/usr/bin/env bash
# .claude/skills/routine/scripts/new.sh
# Scaffold a new routine: copy template, substitute placeholders, run validator.
#
# Usage:   bash new.sh <slug>
# Exit:    0 on success, 1 on validation fail or pre-existing file.

set -uo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "new: usage: new.sh <slug>" >&2
  exit 1
fi

if [[ ! "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "new: slug must be kebab-case starting with a letter (got: $SLUG)" >&2
  exit 1
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"

ROUTINES_DIR="$PROJECT_DIR/.claude/routines"
TEMPLATE="$PROJECT_DIR/.claude/skills/routine/templates/routine.md.tmpl"
DEST="$ROUTINES_DIR/$SLUG.md"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "new: template not found: $TEMPLATE" >&2
  exit 1
fi

if [[ -f "$DEST" ]]; then
  echo "new: routine already exists: $DEST" >&2
  echo "  Pick a different slug, or edit the existing file directly." >&2
  exit 1
fi

mkdir -p "$ROUTINES_DIR"

DATE=$(date -u +%Y-%m-%d)

# Substitute placeholders. Use a marker to protect runtime placeholders
# ({{LAST_COMPLETED_TS}} etc.) from being replaced at scaffold time.
sed -e "s|{{SLUG}}|$SLUG|g" -e "s|{{DATE}}|$DATE|g" "$TEMPLATE" > "$DEST"

# Validate the scaffold (it should pass own validator).
VALIDATOR="$PROJECT_DIR/.claude/skills/routine/scripts/validate.sh"
if [[ -x "$VALIDATOR" ]] || [[ -f "$VALIDATOR" ]]; then
  if ! bash "$VALIDATOR" "$SLUG"; then
    echo "new: scaffold failed self-validation — template bug, please report" >&2
    exit 1
  fi
fi

echo "new: created $DEST"
echo "  Edit the file, then re-run 'install-routines.sh' to schedule it."
exit 0
