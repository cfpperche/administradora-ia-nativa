#!/usr/bin/env bash
# .claude/hooks/routines-readout.sh
# SessionStart hook — surface pending routine queue entries + leader status.
#
# Emits framed === ROUTINES === block when:
#   - ≥1 queue entry pending (lists per-slug with age + count + dispatch hint), OR
#   - .claude/routines/*.md exists AND this repo has no leader entry (advisory)
# Silent when queue is empty AND leader is designated (or no routines defined).
#
# Honors CLAUDE_SKIP_ROUTINES_READOUT=1 to suppress regardless.
# POSIX-friendly: bash + grep + ls + date + stat. Falls back gracefully if jq absent.

set -uo pipefail

if [[ "${CLAUDE_SKIP_ROUTINES_READOUT:-0}" = "1" ]]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
ROUTINES_DIR="$PROJECT_DIR/.claude/routines"
STATE_DIR="$PROJECT_DIR/.claude/.routines-state"
LEADERS_FILE="$HOME/.claude/.agent0-routines-leaders.json"

# --- Step 1: enumerate routines + pending queues ------------------------------
routine_count=0
slugs_with_queue=()
declare -A queue_count=()
declare -A oldest_ts=()

if [[ -d "$ROUTINES_DIR" ]]; then
  for f in "$ROUTINES_DIR"/*.md; do
    [[ -e "$f" ]] || continue
    base=$(basename "$f" .md)
    [[ "$base" == ".gitkeep" || "$base" == ".gitkeep.md" ]] && continue
    routine_count=$((routine_count + 1))

    slug_queue_dir="$STATE_DIR/$base/queue"
    if [[ -d "$slug_queue_dir" ]]; then
      # Count *.md files; gather oldest unix-ts from filenames.
      count=$(ls -1 "$slug_queue_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$count" -gt 0 ]]; then
        slugs_with_queue+=("$base")
        queue_count["$base"]="$count"
        # Filename format: <unix-ts>.md; min by sort.
        oldest_filename=$(ls -1 "$slug_queue_dir"/*.md 2>/dev/null | sort | head -1)
        oldest_epoch=$(basename "$oldest_filename" .md)
        oldest_ts["$base"]="$oldest_epoch"
      fi
    fi
  done
fi

# --- Step 2: leader status for THIS repo --------------------------------------
leader_status="n/a"   # unset → n/a; true → yes; false → no
if [[ -f "$LEADERS_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    raw=$(jq -r --arg path "$PROJECT_DIR" '
      if has($path) then (.[$path] | tostring) else "missing" end
    ' "$LEADERS_FILE" 2>/dev/null || echo "missing")
  else
    if grep -q "\"$PROJECT_DIR\"[[:space:]]*:[[:space:]]*true" "$LEADERS_FILE" 2>/dev/null; then
      raw="true"
    elif grep -q "\"$PROJECT_DIR\"[[:space:]]*:[[:space:]]*false" "$LEADERS_FILE" 2>/dev/null; then
      raw="false"
    else
      raw="missing"
    fi
  fi
  case "$raw" in
    true)  leader_status="yes" ;;
    false) leader_status="no" ;;
    *)     leader_status="n/a" ;;
  esac
fi

# --- Step 3: decide whether to emit -------------------------------------------
# Silent when: no routines defined OR (no queue entries AND leader is designated).
has_queue=0
[[ "${#slugs_with_queue[@]}" -gt 0 ]] && has_queue=1

need_advisory=0
if [[ "$routine_count" -gt 0 && "$leader_status" == "n/a" ]]; then
  need_advisory=1
fi

if [[ "$has_queue" -eq 0 && "$need_advisory" -eq 0 ]]; then
  exit 0
fi

# --- Step 4: emit block --------------------------------------------------------
NOW_EPOCH=$(date -u +%s)

# Helper: humanize age (seconds → "Nh Mm" or "Nd Mh").
humanize_age() {
  local secs="$1"
  if [[ "$secs" -lt 3600 ]]; then
    printf '%dm' "$((secs / 60))"
  elif [[ "$secs" -lt 86400 ]]; then
    printf '%dh %dm' "$((secs / 3600))" "$(((secs % 3600) / 60))"
  else
    printf '%dd %dh' "$((secs / 86400))" "$(((secs % 86400) / 3600))"
  fi
}

printf '\n=== ROUTINES ===\n'

if [[ "$has_queue" -eq 1 ]]; then
  printf 'Pending routine executions (dispatch with /routine run <slug>):\n'
  for slug in "${slugs_with_queue[@]}"; do
    count="${queue_count[$slug]}"
    oldest="${oldest_ts[$slug]}"
    age_secs=$((NOW_EPOCH - oldest))
    age_str=$(humanize_age "$age_secs")
    printf '  - %s: %d pending (oldest: %s ago) — /routine run %s\n' "$slug" "$count" "$age_str" "$slug"
  done
fi

if [[ "$need_advisory" -eq 1 ]]; then
  if [[ "$has_queue" -eq 1 ]]; then
    printf '\n'
  fi
  printf 'Advisory: %d routine(s) defined but no leader designated for this repo.\n' "$routine_count"
  printf '  Run: bash .claude/tools/install-routines.sh\n'
fi

printf '=== end ROUTINES ===\n'

exit 0
