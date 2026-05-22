#!/usr/bin/env bash
# .claude/skills/routine/scripts/validate.sh
# Validates a routine file: frontmatter shape, required keys, cron expression,
# required body headers. Honors per-check override markers (# OVERRIDE: <check>: <reason ≥10 chars>).
#
# Usage:   bash validate.sh <slug>
# Exit:    0 on pass, 1 on fail (stderr explains).
#
# Pure bash + grep + sed; no jq, no python, no yaml lib (agentskills-portable tier).

set -uo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "validate: usage: validate.sh <slug>" >&2
  exit 1
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"
FILE="$PROJECT_DIR/.claude/routines/$SLUG.md"

if [[ ! -f "$FILE" ]]; then
  echo "validate: file not found: $FILE" >&2
  exit 1
fi

# --- Override marker discovery -------------------------------------------------
# Shape: `# OVERRIDE: <check>: <reason ≥10 chars>` on its own line in body.
# Recognized checks: cron-syntax-extended, missing-done-block.
override_check() {
  local check="$1"
  local marker_line
  marker_line=$(grep -E "^[[:space:]]*# OVERRIDE: ${check}:" "$FILE" 2>/dev/null | head -1 || true)
  if [[ -z "$marker_line" ]]; then
    return 1
  fi
  local reason
  reason=$(echo "$marker_line" | sed -E "s|^[[:space:]]*# OVERRIDE: ${check}:[[:space:]]*||")
  reason=$(echo "$reason" | sed -E 's/[[:space:]]+$//')
  if [[ ${#reason} -lt 10 ]]; then
    echo "validate: # OVERRIDE: ${check}: reason must be ≥10 chars (got: '$reason')" >&2
    return 1
  fi
  return 0
}

# --- Phase 1: frontmatter extraction ------------------------------------------
# Frontmatter is between first `---` and second `---` lines.
first_marker=$(grep -n '^---[[:space:]]*$' "$FILE" | head -1 | cut -d: -f1)
second_marker=$(grep -n '^---[[:space:]]*$' "$FILE" | sed -n '2p' | cut -d: -f1)

if [[ -z "$first_marker" || -z "$second_marker" ]]; then
  echo "validate: missing YAML frontmatter (need two '---' lines)" >&2
  exit 1
fi

if [[ "$first_marker" -ne 1 ]]; then
  echo "validate: frontmatter must start at line 1 (found '---' at line $first_marker)" >&2
  exit 1
fi

# Extract lines between markers.
frontmatter=$(sed -n "$((first_marker + 1)),$((second_marker - 1))p" "$FILE")

# --- Phase 2: required keys -----------------------------------------------------
get_key() {
  local key="$1"
  echo "$frontmatter" | grep -E "^${key}:" | head -1 | sed -E "s|^${key}:[[:space:]]*||" | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/'
}

name_val=$(get_key "name")
schedule_val=$(get_key "schedule")
idempotent_val=$(get_key "idempotent")

if [[ -z "$name_val" ]]; then
  echo "validate: frontmatter missing required key 'name'" >&2
  exit 1
fi

if [[ "$name_val" != "$SLUG" ]]; then
  echo "validate: frontmatter 'name: $name_val' does not match file basename '$SLUG'" >&2
  exit 1
fi

if [[ -z "$schedule_val" ]]; then
  echo "validate: frontmatter missing required key 'schedule'" >&2
  exit 1
fi

if [[ -z "$idempotent_val" ]]; then
  echo "validate: frontmatter missing required key 'idempotent'" >&2
  exit 1
fi

# --- Phase 3: idempotent hard rule ---------------------------------------------
if [[ "$idempotent_val" != "true" ]]; then
  echo "validate: idempotent: $idempotent_val is not allowed for routines." >&2
  echo "  Routines MUST be idempotent (running twice == no destructive side effect)." >&2
  echo "  Use /remind for one-shot deferred work, or wrap the action in an" >&2
  echo "  idempotency-preserving guard (e.g. check-then-act)." >&2
  echo "  There is NO override marker for this check — it's a hard rule." >&2
  exit 1
fi

# --- Phase 4: autonomous=true is Phase 2 territory -----------------------------
autonomous_val=$(get_key "autonomous")
if [[ -n "$autonomous_val" && "$autonomous_val" == "true" ]]; then
  echo "validate: autonomous: true is reserved for Phase 2 (claude -p execution)." >&2
  echo "  v1 only supports enqueue-for-session execution. Remove the field" >&2
  echo "  or set autonomous: false." >&2
  exit 1
fi

# --- Phase 5: cron expression validation ---------------------------------------
# 5 fields, each: (* | */N | N | N-N | N-N/N) optionally comma-joined.
validate_cron() {
  local expr="$1"
  # Count fields (space-separated).
  local field_count
  field_count=$(echo "$expr" | awk '{print NF}')
  if [[ "$field_count" -ne 5 ]]; then
    echo "validate: schedule must be 5 fields (got $field_count): '$expr'" >&2
    return 1
  fi

  # Reject special strings explicitly with helpful message.
  case "$expr" in
    *@reboot*|*@yearly*|*@annually*|*@monthly*|*@weekly*|*@daily*|*@midnight*|*@hourly*)
      echo "validate: schedule rejects special strings (@daily etc.)." >&2
      echo "  Use explicit numeric expression: e.g. @daily -> '0 0 * * *'." >&2
      return 1
      ;;
  esac

  # Reject named day/month (MON, FEB, etc.) — uppercase letters.
  if echo "$expr" | grep -qE '[A-Za-z]'; then
    echo "validate: schedule contains letters — named days/months not supported." >&2
    echo "  Use numeric: e.g. MON -> 1, JAN -> 1." >&2
    return 1
  fi

  # Reject advanced Quartz chars.
  if echo "$expr" | grep -qE '[LW#?]'; then
    echo "validate: schedule contains advanced Quartz chars (L/W/#/?) — not supported." >&2
    return 1
  fi

  # Each field matches: (*|*/N|N(-N)?(/N)?)(,(*|*/N|N(-N)?(/N)?))*
  # Field-element regex.
  local elem='(\*|\*/[0-9]+|[0-9]+(-[0-9]+)?(/[0-9]+)?)'
  local field_re="^${elem}(,${elem})*$"

  # Use read into array to avoid glob expansion on '*' in unquoted $expr.
  local -a fields
  read -ra fields <<< "$expr"

  local i=1
  local field
  for field in "${fields[@]}"; do
    if [[ ! "$field" =~ $field_re ]]; then
      echo "validate: schedule field $i ('$field') is malformed." >&2
      echo "  Accepted shapes: * | */N | N | N-N | N-N/N | comma-joined list of these." >&2
      return 1
    fi
    i=$((i + 1))
  done
  return 0
}

if ! validate_cron "$schedule_val"; then
  if override_check "cron-syntax-extended"; then
    : # accepted via override
  else
    exit 1
  fi
fi

# --- Phase 6: body headers ------------------------------------------------------
body=$(sed -n "$((second_marker + 1)),\$p" "$FILE")

if ! echo "$body" | grep -qE '^# Prompt[[:space:]]*$'; then
  echo "validate: body missing required '# Prompt' header" >&2
  exit 1
fi

if ! echo "$body" | grep -qE '^# Done when[[:space:]]*$'; then
  if override_check "missing-done-block"; then
    : # accepted via override
  else
    echo "validate: body missing required '# Done when' header" >&2
    echo "  Use '# OVERRIDE: missing-done-block: <reason ≥10 chars>' to allow." >&2
    exit 1
  fi
fi

echo "validate: $SLUG OK"
exit 0
