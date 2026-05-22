#!/usr/bin/env bash
# .claude/tools/sync-harness.sh
# Spec 016 — one-way sync of Agent0 harness state into a fork.
# See docs/specs/016-harness-sync/ and .claude/rules/harness-sync.md (if present).

set -euo pipefail

# Capture the original invocation args before the parse loop consumes them —
# the self-rebootstrap re-exec (spec 072) forwards them verbatim.
ORIGINAL_ARGS=("$@")

# ---------------------------------------------------------------------------
# usage / arg parsing
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
sync-harness.sh — one-way Agent0 -> fork harness sync

Usage:
  sync-harness.sh [--check|--apply] [--dry-run] [--force]
                  [--force-except=GLOB[,GLOB...]]
                  [--agent0-path=PATH] <fork-path>

Modes:
  --check                read-only drift listing (default)
  --apply                write changes
  --dry-run              with --apply, emit decisions without writing
  --force                overwrite fork-customized files (warned)
  --force-except=GLOB    comma-separated globs; matching files keep their
                         customization (refused) even under --force

Source:
  --agent0-path=PATH   absolute path to Agent0 source repo
  AGENT0_HARNESS_PATH  env-var fallback

Target:
  <fork-path>          positional, required

Exit codes:
  0  clean (check: no drift; apply: success)
  1  drift detected (check) or customizations refused (apply without --force)
  2  usage error (missing source path, bad flags, etc.)
EOF
}

MODE="check"
DRY_RUN=0
FORCE=0
FORCE_EXCEPT=""
AGENT0_ARG=""
FORK_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE="check" ;;
    --apply)   MODE="apply" ;;
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --force-except=*) FORCE_EXCEPT="${1#--force-except=}" ;;
    --force-except)
      shift
      FORCE_EXCEPT="${1:-}"
      ;;
    --agent0-path=*)  AGENT0_ARG="${1#--agent0-path=}" ;;
    --agent0-path)
      shift
      AGENT0_ARG="${1:-}"
      ;;
    -h|--help) usage; exit 0 ;;
    --*)
      printf 'sync-harness: unknown flag: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -z "$FORK_ARG" ]; then
        FORK_ARG="$1"
      else
        printf 'sync-harness: unexpected extra positional arg: %s\n' "$1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$FORK_ARG" ]; then
  printf 'sync-harness: missing <fork-path>\n' >&2
  usage >&2
  exit 2
fi

# Resolve Agent0 source: explicit arg wins, then env var, then refuse.
if [ -n "$AGENT0_ARG" ]; then
  AGENT0_ROOT="$AGENT0_ARG"
elif [ -n "${AGENT0_HARNESS_PATH:-}" ]; then
  AGENT0_ROOT="$AGENT0_HARNESS_PATH"
else
  printf 'sync-harness: must specify --agent0-path=PATH or set AGENT0_HARNESS_PATH\n' >&2
  usage >&2
  exit 2
fi

FORK_ROOT="$FORK_ARG"

# Sanity: Agent0 looks like an Agent0 repo
if [ ! -d "$AGENT0_ROOT/.claude" ] || [ ! -f "$AGENT0_ROOT/CLAUDE.md" ]; then
  printf 'sync-harness: --agent0-path=%s does not look like an Agent0 repo (no .claude/ or CLAUDE.md)\n' "$AGENT0_ROOT" >&2
  exit 2
fi
if [ ! -d "$FORK_ROOT" ]; then
  printf 'sync-harness: fork path does not exist: %s\n' "$FORK_ROOT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# sync baseline (spec 068)
# ---------------------------------------------------------------------------

# The recorded sync baseline lives in the fork at
# .claude/harness-sync-baseline.json and captures Agent0's managed-file sha-set
# as of the fork's last --apply. It is the third reference point that lets the
# plain-file path tell *stale* (auto-update) apart from *customized* (refuse),
# and lets the deletion pass propagate upstream removals safely. Git-tracked in
# the fork (travels on clone); never shipped by Agent0 itself.
BASELINE_TOOL_VERSION=1
BASELINE_FILE="$FORK_ROOT/.claude/harness-sync-baseline.json"
BASELINE_PRESENT=0
BASELINE_TSV=""          # temp: sorted "relpath<TAB>sha" of the recorded baseline
MANIFEST_RAW=""          # temp: unsorted "relpath<TAB>sha" of Agent0's current set
MANIFEST_TSV=""          # temp: sorted+uniq MANIFEST_RAW
# Temp copy this process was re-exec'd from (self-rebootstrap, spec 072); empty
# in a normal run. Cleaned up here so the re-exec'd process removes its own
# source on exit — no separate trap needed.
REBOOTSTRAP_TMP="${AGENT0_SYNC_REBOOTSTRAP_TMP:-}"

_sync_cleanup() {
  rm -f "$BASELINE_TSV" "$MANIFEST_RAW" "$MANIFEST_TSV" "$REBOOTSTRAP_TMP" 2>/dev/null || true
}
trap _sync_cleanup EXIT

MANIFEST_RAW="$(mktemp -t sync-manifest-raw-XXXXXX)"
MANIFEST_TSV="$(mktemp -t sync-manifest-XXXXXX)"

# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------

# Project-local paths — MUST NOT be added to any COPY_CHECK array below.
# .claude/.browser-state/  session credentials (cookies/localStorage); project-specific,
#                           gitignored *.json, only .gitkeep sentinel travels via git.
# .claude/memory/           project knowledge; content is project-local (spec 019).
#                           The empty .gitkeep IS in COPY_CHECK_FILES — content is not.
# .claude/routines/         project-scoped routine definitions (spec 064); content is
#                           project-local. Only .gitkeep travels via git so a fresh
#                           fork has the empty directory ready for /routine new.

# Recursive globs (find -type f under base dir) — encoded as "base/**"
COPY_CHECK_RECURSIVE=(
  ".claude/skills"
  ".claude/tests"
  ".claude/agents"
)

# Single-level globs (find -maxdepth 1 with name pattern) — encoded as "dir|pattern"
COPY_CHECK_GLOBS=(
  ".claude/hooks|*.sh"
  ".claude/rules|*.md"
  ".claude/tools|*.sh"
  ".claude/validators|*.sh"
  ".claude/presence|*.mjs"
)

# Literal files
COPY_CHECK_FILES=(
  ".mcp.json.example"
  ".gitleaks.toml"
  ".githooks/pre-commit"
  ".claude/memory/.gitkeep"
  ".claude/.browser-state/.gitkeep"
  ".claude/routines/.gitkeep"
)

# Structured merge handled by dedicated functions below
# - .claude/settings.json
# - CLAUDE.md
# - .gitignore

# ---------------------------------------------------------------------------
# counters
# ---------------------------------------------------------------------------

COPIED=0
UP_TO_DATE=0
CUSTOMIZED_REFUSED=0
OVERWRITTEN=0
MERGED=0
DRIFT=0
STALE_UPDATED=0   # spec 068: stale plain files auto-updated (fork == baseline, Agent0 moved)
REMOVED=0         # spec 068: upstream-removed files deleted from the fork

# ---------------------------------------------------------------------------
# copy / check
# ---------------------------------------------------------------------------

sha_of() {
  if [ -f "$1" ]; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo ""
  fi
}

# Returns 0 if `rel` matches any glob in FORCE_EXCEPT (comma-separated), else 1.
matches_force_except() {
  local rel="$1"
  [ -z "$FORCE_EXCEPT" ] && return 1
  local IFS=','
  local pat
  for pat in $FORCE_EXCEPT; do
    [ -z "$pat" ] && continue
    case "$rel" in
      $pat) return 0 ;;
    esac
  done
  return 1
}

# ---------------------------------------------------------------------------
# baseline load + lookup (spec 068)
# ---------------------------------------------------------------------------

# Load the fork's recorded sync baseline (if present) into a sorted TSV temp
# file. One jq call dumps the .files map to "relpath<TAB>sha" lines; per-file
# lookup is then a Bash-3.2-safe awk scan (no declare -A). A malformed or
# unreadable baseline fails open — treated as no baseline.
load_baseline() {
  if [ ! -f "$BASELINE_FILE" ]; then
    BASELINE_PRESENT=0
    return
  fi
  BASELINE_TSV="$(mktemp -t sync-baseline-XXXXXX)"
  if jq -r '.files // {} | to_entries[] | "\(.key)\t\(.value)"' "$BASELINE_FILE" 2>/dev/null \
       | sort > "$BASELINE_TSV"; then
    BASELINE_PRESENT=1
  else
    printf '!! harness-sync-baseline.json unreadable/malformed — treating as no baseline\n' >&2
    BASELINE_PRESENT=0
  fi
}

# Echo the baseline sha recorded for a relpath, or empty string if absent.
# Exact-match the first tab-delimited field — no prefix-match footgun.
baseline_sha_for() {
  local rel="$1"
  if [ "$BASELINE_PRESENT" -ne 1 ]; then
    echo ""
    return
  fi
  awk -F'\t' -v k="$rel" '$1 == k { print $2; exit }' "$BASELINE_TSV"
}

# ---------------------------------------------------------------------------
# self-rebootstrap (spec 072)
# ---------------------------------------------------------------------------

# sync-harness.sh is itself in the propagation manifest, so an --apply against a
# fork whose copy is stale overwrites the very file bash is executing. Bash
# reads scripts incrementally; an in-place whole-file overwrite mid-run
# misaligns the read offset and corrupts execution. Guard: before any write, if
# this run WILL overwrite the fork's sync-harness.sh, re-exec from a stable temp
# copy of Agent0's current script — the re-exec'd process executes from the temp
# file, so overwriting the fork copy can no longer corrupt it. Must run after
# load_baseline (stale-vs-customized needs the baseline loaded).
_self_rebootstrap() {
  # Already re-exec'd from a stable copy — never loop.
  [ -n "${AGENT0_SYNC_REBOOTSTRAPPED:-}" ] && return 0
  # Only a real --apply writes; --check and --apply --dry-run never overwrite.
  [ "$MODE" = "apply" ] && [ "$DRY_RUN" -eq 0 ] || return 0

  local rel=".claude/tools/sync-harness.sh"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"
  # No source, or fork has no copy → no in-place self-overwrite to guard.
  [ -f "$src" ] && [ -f "$dst" ] || return 0

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  # Identical → the run leaves sync-harness.sh untouched.
  [ "$src_sha" = "$dst_sha" ] && return 0

  # Differs — will the run actually write it? stale auto-updates; customized is
  # written only under --force and not shielded by --force-except. A customized
  # self that will be refused is never overwritten, so it needs no rebootstrap.
  local baseline_sha will_overwrite=0
  baseline_sha="$(baseline_sha_for "$rel")"
  if [ -n "$baseline_sha" ] && [ "$baseline_sha" = "$dst_sha" ]; then
    will_overwrite=1
  elif [ "$FORCE" -eq 1 ] && ! matches_force_except "$rel"; then
    will_overwrite=1
  fi
  [ "$will_overwrite" -eq 1 ] || return 0

  # The run WILL overwrite our own running file — re-exec from a stable copy.
  local tmp
  tmp="$(mktemp -t sync-harness-rebootstrap-XXXXXX)" || return 0
  if ! cp "$src" "$tmp"; then
    rm -f "$tmp"
    return 0
  fi
  printf 'sync-harness: self-update detected — re-executing from a stable copy\n' >&2
  export AGENT0_SYNC_REBOOTSTRAPPED=1
  export AGENT0_SYNC_REBOOTSTRAP_TMP="$tmp"
  exec bash "$tmp" "${ORIGINAL_ARGS[@]}"
}

process_file() {
  local rel="$1"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    # Missing in fork: copy.
    if [ "$MODE" = "check" ]; then
      printf '+ would copy %s\n' "$rel"
      DRIFT=1
    else
      if [ "$DRY_RUN" -eq 1 ]; then
        printf '+ copied %s (dry-run)\n' "$rel"
      else
        mkdir -p "$(dirname "$dst")"
        cp -p "$src" "$dst"
        printf '+ copied %s\n' "$rel"
      fi
      COPIED=$((COPIED + 1))
    fi
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"

  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Hash mismatch — 3-way reconciliation: fork vs baseline vs Agent0 (spec 068).
  local baseline_sha
  baseline_sha="$(baseline_sha_for "$rel")"

  if [ -n "$baseline_sha" ] && [ "$baseline_sha" = "$dst_sha" ]; then
    # STALE: fork never touched this file since last sync; Agent0 moved on.
    # Auto-update — no --force needed.
    if [ "$MODE" = "check" ]; then
      printf '~ stale %s (would update)\n' "$rel"
      DRIFT=1
      return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '~ stale %s -> updated (dry-run)\n' "$rel"
    else
      cp -p "$src" "$dst"
      printf '~ stale %s -> updated\n' "$rel"
    fi
    STALE_UPDATED=$((STALE_UPDATED + 1))
    return
  fi

  # CUSTOMIZED: fork edited the file (baseline present but != fork copy), OR no
  # baseline entry exists (first sync / file added to manifest after the fork's
  # last sync — the genuine pre-baseline ambiguity). Refuse; --force overrides.
  local nobaseline=""
  if [ -z "$baseline_sha" ]; then
    nobaseline=" (no baseline)"
  fi

  if [ "$MODE" = "check" ]; then
    printf '!! customized %s%s\n' "$rel" "$nobaseline"
    DRIFT=1
    return
  fi

  if [ "$FORCE" -eq 1 ] && ! matches_force_except "$rel"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '! overwritten %s (dry-run)\n' "$rel" >&2
    else
      cp -p "$src" "$dst"
      printf '! overwritten %s\n' "$rel" >&2
    fi
    OVERWRITTEN=$((OVERWRITTEN + 1))
  else
    printf '!! customized %s%s\n' "$rel" "$nobaseline" >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
  fi
}

# Append a managed file + its current Agent0 sha to the running manifest
# (spec 068). The accumulated MANIFEST_TSV is consumed by the deletion pass
# (orphan detection) and the baseline write.
record_manifest() {
  local rel="$1"
  local src="$AGENT0_ROOT/$rel"
  if [ -f "$src" ]; then
    printf '%s\t%s\n' "$rel" "$(sha_of "$src")" >> "$MANIFEST_RAW"
  fi
}

walk_copy_check() {
  local base pattern dir relfile entry
  : > "$MANIFEST_RAW"

  for base in "${COPY_CHECK_RECURSIVE[@]}"; do
    if [ -d "$AGENT0_ROOT/$base" ]; then
      while IFS= read -r relfile; do
        if [ -n "$relfile" ]; then
          record_manifest "$relfile"
          process_file "$relfile"
        fi
      done < <(cd "$AGENT0_ROOT" && find "$base" -type f 2>/dev/null | sort)
    fi
  done

  for entry in "${COPY_CHECK_GLOBS[@]}"; do
    dir="${entry%|*}"
    pattern="${entry#*|}"
    if [ -d "$AGENT0_ROOT/$dir" ]; then
      while IFS= read -r relfile; do
        if [ -n "$relfile" ]; then
          record_manifest "$relfile"
          process_file "$relfile"
        fi
      done < <(cd "$AGENT0_ROOT" && find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | sort)
    fi
  done

  for relfile in "${COPY_CHECK_FILES[@]}"; do
    record_manifest "$relfile"
    process_file "$relfile"
  done

  sort -u "$MANIFEST_RAW" > "$MANIFEST_TSV"
}

# ---------------------------------------------------------------------------
# deletion reconciliation (spec 068)
# ---------------------------------------------------------------------------

# Remove now-empty parent directories of a just-deleted file, bottom-up,
# stopping at the first non-empty dir. Never ascends past the fork root.
prune_empty_parents() {
  local rel="$1"
  local dir
  dir="$(dirname "$rel")"
  while [ -n "$dir" ] && [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    if [ -d "$FORK_ROOT/$dir" ] && [ -z "$(ls -A "$FORK_ROOT/$dir" 2>/dev/null)" ]; then
      rmdir "$FORK_ROOT/$dir" 2>/dev/null || break
      dir="$(dirname "$dir")"
    else
      break
    fi
  done
}

# For every path in the recorded baseline NOT in Agent0's current manifest,
# propagate the upstream removal: delete clean orphans (fork copy still matches
# baseline), refuse fork-customized ones (unless --force). Requires a baseline;
# first-sync forks (no baseline) skip this pass entirely.
reconcile_deletions() {
  if [ "$BASELINE_PRESENT" -ne 1 ]; then
    return
  fi

  local manifest_paths
  manifest_paths="$(mktemp -t sync-mpaths-XXXXXX)"
  cut -f1 "$MANIFEST_TSV" | sort -u > "$manifest_paths"

  local rel baseline_sha dst dst_sha
  while IFS=$'\t' read -r rel baseline_sha; do
    if [ -z "$rel" ]; then
      continue
    fi
    # Still in Agent0's current manifest — not an orphan, handled by the walk.
    if grep -Fxq "$rel" "$manifest_paths"; then
      continue
    fi
    dst="$FORK_ROOT/$rel"
    # Fork no longer has it — nothing to delete.
    if [ ! -f "$dst" ]; then
      continue
    fi
    dst_sha="$(sha_of "$dst")"

    if [ "$dst_sha" = "$baseline_sha" ]; then
      # Clean orphan: fork copy untouched since sync — safe to remove.
      if [ "$MODE" = "check" ]; then
        printf -- '- removed %s (would delete)\n' "$rel"
        DRIFT=1
      elif [ "$DRY_RUN" -eq 1 ]; then
        printf -- '- removed %s (dry-run)\n' "$rel"
        REMOVED=$((REMOVED + 1))
      else
        rm -f "$dst"
        prune_empty_parents "$rel"
        printf -- '- removed %s\n' "$rel"
        REMOVED=$((REMOVED + 1))
      fi
      continue
    fi

    # Fork customized a file Agent0 has since removed — never silently delete
    # fork work. Refuse and advise manual resolution; --force overrides.
    if [ "$MODE" = "check" ]; then
      printf '!! customized %s (upstream-removed)\n' "$rel"
      DRIFT=1
    elif [ "$FORCE" -eq 1 ] && ! matches_force_except "$rel"; then
      if [ "$DRY_RUN" -eq 1 ]; then
        printf -- '! removed %s (customized, upstream-removed, --force, dry-run)\n' "$rel" >&2
      else
        rm -f "$dst"
        prune_empty_parents "$rel"
        printf -- '! removed %s (customized, upstream-removed, --force)\n' "$rel" >&2
      fi
      REMOVED=$((REMOVED + 1))
    else
      printf '!! customized %s (upstream-removed — resolve manually)\n' "$rel" >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    fi
  done < "$BASELINE_TSV"

  rm -f "$manifest_paths"
}

# ---------------------------------------------------------------------------
# baseline write (spec 068)
# ---------------------------------------------------------------------------

# Record Agent0's current managed-file sha-set as the fork's new sync baseline.
# Runs only on --apply (not --check, not --dry-run). Skipped when the resulting
# files-map is byte-identical to the existing baseline's — a no-op re-sync must
# leave the file untouched (idempotency), so synced_at is not churned. Atomic
# write via mktemp + mv, mirroring merge_settings_json.
write_baseline() {
  if [ "$MODE" != "apply" ] || [ "$DRY_RUN" -eq 1 ]; then
    return
  fi
  if [ ! -f "$MANIFEST_TSV" ]; then
    return
  fi

  local files_obj
  files_obj="$(jq -R -s -c '
    split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}
  ' "$MANIFEST_TSV" 2>/dev/null || echo '{}')"

  # Idempotency: if the existing baseline already records this exact files-map,
  # leave the file untouched (a rewrite would only bump synced_at).
  if [ -f "$BASELINE_FILE" ]; then
    local old_files new_files
    old_files="$(jq -S -c '.files // {}' "$BASELINE_FILE" 2>/dev/null || echo '')"
    new_files="$(printf '%s' "$files_obj" | jq -S -c '.' 2>/dev/null || echo '')"
    if [ -n "$old_files" ] && [ "$old_files" = "$new_files" ]; then
      printf '= baseline up-to-date .claude/harness-sync-baseline.json\n' >&2
      return
    fi
  fi

  local agent0_commit synced_at tmp
  agent0_commit="$(cd "$AGENT0_ROOT" 2>/dev/null && git rev-parse HEAD 2>/dev/null || true)"
  synced_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp="$(mktemp -t sync-baseline-write-XXXXXX)"

  if jq -n \
       --argjson files "$files_obj" \
       --arg commit "$agent0_commit" \
       --arg synced "$synced_at" \
       --argjson ver "$BASELINE_TOOL_VERSION" \
       '{
          agent0_commit: (if $commit == "" then null else $commit end),
          synced_at: $synced,
          tool_version: $ver,
          files: $files
        }' > "$tmp" 2>/dev/null; then
    mkdir -p "$(dirname "$BASELINE_FILE")"
    mv "$tmp" "$BASELINE_FILE"
    printf '~ baseline recorded .claude/harness-sync-baseline.json\n' >&2
  else
    rm -f "$tmp"
    printf '!! failed to write .claude/harness-sync-baseline.json (jq error)\n' >&2
  fi
}

# ---------------------------------------------------------------------------
# settings.json structured merge
# ---------------------------------------------------------------------------

merge_settings_json() {
  local rel=".claude/settings.json"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Compute merged JSON.
  # Fork (dst) is the BASE — preserves permissions/env/model/fork-only top-level keys.
  # Agent0-owned top-level keys ($schema, statusLine) overwrite when Agent0 has them.
  # hooks: union per-event, dedup by (matcher, ordered list of inner commands).
  local tmp merged
  tmp="$(mktemp -t sync-settings-XXXXXX)"
  if ! jq -s '
    def dedup_key:
      (.matcher // "") + "|" + ((.hooks // []) | map(.command // "") | join("##"));

    . as $arr |
    ($arr[0] // {}) as $fork |
    ($arr[1] // {}) as $agent0 |
    $fork
    | (if ($agent0 | has("$schema"))    then .["$schema"]  = $agent0["$schema"]  else . end)
    | (if ($agent0 | has("statusLine")) then .statusLine   = $agent0.statusLine  else . end)
    | .hooks = (
        ((($fork.hooks // {}) | keys) + (($agent0.hooks // {}) | keys))
        | unique
        | map(. as $k | {
            ($k): ((($fork.hooks[$k]) // []) + (($agent0.hooks[$k]) // []) | unique_by(dedup_key))
          })
        | add // {}
      )
  ' "$dst" "$src" > "$tmp" 2>/dev/null; then
    printf '!! settings.json merge failed (jq error)\n' >&2
    rm -f "$tmp"
    DRIFT=1
    return
  fi

  # Compare merged result with current fork content
  local merged_sha
  merged_sha="$(sha_of "$tmp")"
  if [ "$merged_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    rm -f "$tmp"
    return
  fi

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s\n' "$rel"
    DRIFT=1
    rm -f "$tmp"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '~ merged %s (dry-run)\n' "$rel"
    rm -f "$tmp"
  else
    mv "$tmp" "$dst"
    printf '~ merged %s\n' "$rel"
  fi
  MERGED=$((MERGED + 1))
}

# ---------------------------------------------------------------------------
# CLAUDE.md capacity-section append
# ---------------------------------------------------------------------------

# Extract section headings ("^## <Title>") from a file, one per line.
extract_h2() {
  grep -E '^## ' "$1" || true
}

# Extract the body of a specific section (from "## Title" through to next "## " or EOF).
extract_section() {
  local file="$1"
  local title="$2"
  awk -v t="$title" '
    BEGIN { in_sec = 0 }
    /^## / {
      if (in_sec) exit
      if ($0 == t) in_sec = 1
    }
    { if (in_sec) print }
  ' "$file"
}

# ---------------------------------------------------------------------------
# CLAUDE.md managed-block helpers (spec 058)
# ---------------------------------------------------------------------------

# Detect marker state in a file. Outputs: absent | paired | mismatched | nested-invalid
detect_marker_state() {
  local file="$1"
  local begin_count end_count begin_line end_line
  if [ ! -f "$file" ]; then
    echo "absent"
    return
  fi
  begin_count="$(grep -cE '^<!-- AGENT0:BEGIN -->$' "$file" 2>/dev/null || true)"
  end_count="$(grep -cE '^<!-- AGENT0:END -->$' "$file" 2>/dev/null || true)"
  [ -z "$begin_count" ] && begin_count=0
  [ -z "$end_count" ] && end_count=0

  if [ "$begin_count" -eq 0 ] && [ "$end_count" -eq 0 ]; then
    echo "absent"
    return
  fi

  if [ "$begin_count" -eq 0 ] || [ "$end_count" -eq 0 ]; then
    echo "mismatched"
    return
  fi

  if [ "$begin_count" -gt 1 ] || [ "$end_count" -gt 1 ]; then
    echo "nested-invalid"
    return
  fi

  # Exactly 1 of each — check order
  begin_line="$(grep -nE '^<!-- AGENT0:BEGIN -->$' "$file" | head -1 | cut -d: -f1)"
  end_line="$(grep -nE '^<!-- AGENT0:END -->$' "$file" | head -1 | cut -d: -f1)"
  if [ "$begin_line" -ge "$end_line" ]; then
    echo "nested-invalid"
    return
  fi
  echo "paired"
}

# Extract content between AGENT0:BEGIN and AGENT0:END markers (exclusive).
_extract_region() {
  local file="$1"
  awk '
    /^<!-- AGENT0:END -->$/ { in_region=0 }
    in_region { print }
    /^<!-- AGENT0:BEGIN -->$/ { in_region=1 }
  ' "$file"
}

# sha256 of an in-memory region string. Consistent newline handling so the
# managed-block baseline record and the 3-way check compute the SAME digest.
_region_sha() {
  printf '%s\n' "$1" | sha256sum | awk '{print $1}'
}

# Record CLAUDE.md's Agent0-managed block (between AGENT0:BEGIN/END) as a
# baseline-tracked unit under the synthetic key "CLAUDE.md#managed-block" — `#`
# cannot appear in a real managed relpath, so no collision. Appended to the
# running manifest so write_baseline persists it and reconcile_deletions, which
# only acts on baseline entries ABSENT from the manifest, never orphans it.
record_managed_block_manifest() {
  local src="$AGENT0_ROOT/CLAUDE.md"
  # return 0 on the skip paths — a bare `return` propagates the failed test's
  # exit code, which under `set -e` would abort main mid-run.
  [ -f "$src" ] || return 0
  [ "$(detect_marker_state "$src")" = "paired" ] || return 0
  printf '%s\t%s\n' "CLAUDE.md#managed-block" "$(_region_sha "$(_extract_region "$src")")" >> "$MANIFEST_RAW"
  sort -u "$MANIFEST_RAW" > "$MANIFEST_TSV"
}

# For each H2 heading in BOTH files (intersection), compare section bodies.
# Outputs diverged section titles, one per line.
_check_section_divergence() {
  local src="$1"
  local dst="$2"
  local src_h2 dst_h2 src_sorted dst_sorted common title src_body dst_body
  src_h2="$(extract_h2 "$src")"
  dst_h2="$(extract_h2 "$dst")"
  src_sorted="$(mktemp -t sync-srch2-XXXXXX)"
  dst_sorted="$(mktemp -t sync-dsth2-XXXXXX)"
  printf '%s\n' "$src_h2" | sort -u > "$src_sorted"
  printf '%s\n' "$dst_h2" | sort -u > "$dst_sorted"
  common="$(comm -12 "$src_sorted" "$dst_sorted")"
  rm -f "$src_sorted" "$dst_sorted"

  while IFS= read -r title; do
    [ -z "$title" ] && continue
    src_body="$(extract_section "$src" "$title")"
    dst_body="$(extract_section "$dst" "$title")"
    if [ "$src_body" != "$dst_body" ]; then
      printf '%s\n' "$title"
    fi
  done <<EOF
$common
EOF
}

# Section divergence scoped to the AGENT0 region (between markers) in both files.
_check_region_divergence() {
  local src="$1"
  local dst="$2"
  local src_tmp dst_tmp out
  src_tmp="$(mktemp -t sync-srcrgn-XXXXXX)"
  dst_tmp="$(mktemp -t sync-dstrgn-XXXXXX)"
  _extract_region "$src" > "$src_tmp"
  _extract_region "$dst" > "$dst_tmp"
  out="$(_check_section_divergence "$src_tmp" "$dst_tmp")"
  rm -f "$src_tmp" "$dst_tmp"
  printf '%s' "$out"
}

# Write a unified diff of fork region vs Agent0 region to .claude/CLAUDE.md.diverged-region.md.
_write_region_divergence_report() {
  local src="$1"
  local dst="$2"
  local diverged_titles="$3"
  local out="$FORK_ROOT/.claude/CLAUDE.md.diverged-region.md"
  local title
  mkdir -p "$(dirname "$out")"
  {
    printf '# CLAUDE.md managed region divergence\n\n'
    printf '_Generated by sync-harness.sh on %s — fork region differs from Agent0 source._\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'Body of one or more Agent0-titled sections in the managed region differs\n'
    printf 'between fork and Agent0 source. Resolve by either:\n\n'
    printf '1. Moving project customizations OUTSIDE the markers (above `<!-- AGENT0:BEGIN -->`).\n'
    printf '2. Accepting Agent0 replacement via `--force` (fork region overwritten wholesale).\n\n'
    if [ -n "$diverged_titles" ]; then
      printf '## Diverged sections\n\n'
      while IFS= read -r title; do
        [ -z "$title" ] && continue
        printf -- '- `%s`\n' "$title"
      done <<EOF
$diverged_titles
EOF
      printf '\n'
    fi
    printf '## Unified diff (fork → Agent0)\n\n'
    printf '```diff\n'
    diff -u <(_extract_region "$dst") <(_extract_region "$src") || true
    printf '```\n'
  } > "$out"
}

# Generate `.claude/CLAUDE.md.migration-candidate.md` showing the wrapped layout,
# OR `.claude/CLAUDE.md.diverged-sections.md` if section bodies diverged.
# No-op when Agent0 source is not wrapped (markers are the "Agent0-managed namespace"
# delimiter — without them, we can't tell project-narrative from capacity sections).
# Respects MODE=check (no writes) and DRY_RUN=1 (no writes, advisory only).
_generate_migration_candidate() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"
  local src_state diverged_titles count title

  # Candidate generation requires Agent0 source to be wrapped — the markers
  # define what's Agent0-managed vs project-narrative. Without them, every
  # H2 in src would be treated as Agent0-owned and project headings like
  # `## Overview` would falsely trip the divergence check.
  src_state="$(detect_marker_state "$src")"
  if [ "$src_state" != "paired" ]; then
    return
  fi

  # Compare fork sections against Agent0's REGION (managed namespace only).
  local src_region_tmp
  src_region_tmp="$(mktemp -t sync-srcrgn-XXXXXX)"
  _extract_region "$src" > "$src_region_tmp"
  diverged_titles="$(_check_section_divergence "$src_region_tmp" "$dst")"

  if [ -n "$diverged_titles" ]; then
    count="$(printf '%s\n' "$diverged_titles" | grep -c . || true)"
    if [ "$MODE" = "check" ] || [ "$DRY_RUN" -eq 1 ]; then
      printf 'claude-md-migration-blocked: %s sections diverged (drift only, --check/--dry-run: no report written)\n' "$count" >&2
      rm -f "$src_region_tmp"
      DRIFT=1
      return
    fi

    local report="$FORK_ROOT/.claude/CLAUDE.md.diverged-sections.md"
    mkdir -p "$(dirname "$report")"
    {
      printf '# CLAUDE.md section divergence — migration blocked\n\n'
      printf '_Generated by sync-harness.sh on %s._\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'The fork rewrote the body of one or more Agent0-titled sections. Migration\n'
      printf 'to managed-block layout is blocked until these are resolved.\n\n'
      printf '## Diverged sections\n\n'
      while IFS= read -r title; do
        [ -z "$title" ] && continue
        printf -- '- `%s`\n' "$title"
      done <<EOF
$diverged_titles
EOF
      printf '\n## Resolution\n\n'
      printf '1. Per section: keep the fork edit (rename heading so it is no longer Agent0-titled),\n'
      printf '   OR accept the Agent0 body (overwrite fork edit).\n'
      printf '2. Apply the decisions in `CLAUDE.md` directly.\n'
      printf '3. Re-run sync; a fresh migration candidate is generated once divergences are gone.\n'
    } > "$report"
    printf 'claude-md-migration-blocked: %s sections diverged — see .claude/CLAUDE.md.diverged-sections.md\n' "$count" >&2
    rm -f "$src_region_tmp"
    return
  fi

  # No body divergence — generate candidate (or report-would in check/dry-run).
  if [ "$MODE" = "check" ] || [ "$DRY_RUN" -eq 1 ]; then
    printf 'claude-md-migration-advisory: would write candidate to .claude/CLAUDE.md.migration-candidate.md (--check/--dry-run: no file written)\n' >&2
    rm -f "$src_region_tmp"
    DRIFT=1
    return
  fi

  local candidate="$FORK_ROOT/.claude/CLAUDE.md.migration-candidate.md"
  mkdir -p "$(dirname "$candidate")"

  local src_region_h2 dst_h2 project_only_titles src_sha_short
  src_region_h2="$(extract_h2 "$src_region_tmp")"
  dst_h2="$(extract_h2 "$dst")"
  # Project-only sections = headings in dst NOT in Agent0's region, preserving dst order.
  if [ -z "$src_region_h2" ]; then
    project_only_titles="$dst_h2"
  else
    project_only_titles="$(printf '%s\n' "$dst_h2" | grep -Fxv -f <(printf '%s\n' "$src_region_h2") || true)"
  fi
  src_sha_short="$(sha_of "$src" | cut -c1-12)"

  {
    printf '%s\n' '<!--'
    printf 'Migration candidate generated by sync-harness.sh on %s.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'Source: Agent0 CLAUDE.md (sha %s)\n' "$src_sha_short"
    printf '\n'
    printf 'Review this layout. If it matches your intent, run:\n'
    printf '  mv .claude/CLAUDE.md.migration-candidate.md CLAUDE.md\n'
    printf '\n'
    printf 'After ratification, subsequent syncs use the managed-block merge path: the\n'
    printf 'region between AGENT0:BEGIN and AGENT0:END is replaced wholesale on each\n'
    printf 'sync, propagating Agent0 ADDs and REMOVALs symmetrically.\n'
    printf '%s\n\n' '-->'

    # Preamble: lines before the first ## heading in fork (file H1, intro paragraphs).
    awk '/^## / {exit} {print}' "$dst"

    # Project-only sections from fork (preserving fork's order).
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      extract_section "$dst" "$title"
      printf '\n'
    done <<EOF
$project_only_titles
EOF

    # AGENT0 region (sourced from Agent0's wrapped CLAUDE.md).
    printf '%s\n' '<!-- AGENT0:BEGIN -->'
    cat "$src_region_tmp"
    printf '%s\n' '<!-- AGENT0:END -->'
  } > "$candidate"

  rm -f "$src_region_tmp"
  printf 'claude-md-migration-advisory: candidate written to .claude/CLAUDE.md.migration-candidate.md — review and `mv` to ratify\n' >&2
}

# Handle paired-marker state: replace region wholesale, refuse on body divergence.
_merge_claude_md_managed_block() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if matches_force_except "$rel"; then
    printf '!! force-except %s (merge skipped)\n' "$rel" >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    return
  fi

  # Source must also be wrapped — fallback to legacy if not.
  local src_state
  src_state="$(detect_marker_state "$src")"
  if [ "$src_state" != "paired" ]; then
    printf '!! claude-md: Agent0 source CLAUDE.md is not wrapped (state=%s) — falling back to legacy merge\n' "$src_state" >&2
    _merge_claude_md_legacy
    return
  fi

  local src_region dst_region
  src_region="$(_extract_region "$src")"
  dst_region="$(_extract_region "$dst")"

  if [ "$src_region" = "$dst_region" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Region differs — 3-way reconciliation of the managed block as a single
  # baseline-tracked unit (spec 071, reusing the spec-068 baseline machinery).
  # The AGENT0:BEGIN/END contract makes the whole block Agent0-owned, so any
  # edit inside it is customization — no per-section granularity is needed.
  local region_baseline_sha dst_region_sha is_stale=0
  region_baseline_sha="$(baseline_sha_for "CLAUDE.md#managed-block")"
  dst_region_sha="$(_region_sha "$dst_region")"
  if [ -n "$region_baseline_sha" ] && [ "$region_baseline_sha" = "$dst_region_sha" ]; then
    is_stale=1
  fi

  if [ "$is_stale" -ne 1 ] && { [ "$FORCE" -ne 1 ] || matches_force_except "$rel"; }; then
    # CUSTOMIZED: fork edited its managed block (baseline present but != fork
    # region), OR no baseline entry yet (a pre-071 fork's first sync — the
    # genuine pre-baseline ambiguity). Refuse; --force overrides.
    local nobaseline=""
    [ -z "$region_baseline_sha" ] && nobaseline=" (no baseline)"
    if [ "$MODE" = "check" ]; then
      printf '!! customized %s (managed block%s)\n' "$rel" "$nobaseline"
      DRIFT=1
      return
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '!! claude-md: managed block customized%s — refused (dry-run: no report written)\n' "$nobaseline" >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
      return
    fi
    _write_region_divergence_report "$src" "$dst" "$(_check_region_divergence "$src" "$dst")"
    printf '!! claude-md: managed block customized%s — refused (see .claude/CLAUDE.md.diverged-region.md)\n' "$nobaseline" >&2
    printf '   Move project customizations OUTSIDE the markers, or accept Agent0 replacement via --force\n' >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    return
  fi

  if [ "$MODE" = "check" ]; then
    if [ "$is_stale" -eq 1 ]; then
      printf '~ stale %s (managed block — would update)\n' "$rel"
    else
      printf '~ would merge %s (managed block)\n' "$rel"
    fi
    DRIFT=1
    return
  fi

  # Build new content: (pre-BEGIN incl marker) + src_region + (END marker onwards).
  local tmp begin_line end_line
  tmp="$(mktemp -t sync-claude-md-XXXXXX)"
  begin_line="$(grep -nE '^<!-- AGENT0:BEGIN -->$' "$dst" | head -1 | cut -d: -f1)"
  end_line="$(grep -nE '^<!-- AGENT0:END -->$' "$dst" | head -1 | cut -d: -f1)"

  head -n "$begin_line" "$dst" > "$tmp"
  if [ -n "$src_region" ]; then
    printf '%s\n' "$src_region" >> "$tmp"
  fi
  tail -n +"$end_line" "$dst" >> "$tmp"

  if [ "$DRY_RUN" -eq 1 ]; then
    rm -f "$tmp"
    if [ "$is_stale" -eq 1 ]; then
      printf '~ stale %s (managed block -> updated, dry-run)\n' "$rel"
      STALE_UPDATED=$((STALE_UPDATED + 1))
    else
      printf '! overwritten %s (managed block replaced under --force, dry-run)\n' "$rel" >&2
      OVERWRITTEN=$((OVERWRITTEN + 1))
    fi
    return
  fi

  mv "$tmp" "$dst"
  if [ "$is_stale" -eq 1 ]; then
    printf '~ stale %s (managed block -> updated)\n' "$rel"
    STALE_UPDATED=$((STALE_UPDATED + 1))
  else
    printf '! overwritten %s (managed block replaced under --force)\n' "$rel" >&2
    OVERWRITTEN=$((OVERWRITTEN + 1))
  fi
}

# Legacy heading-set append merge (spec 016). Fallback for unmigrated forks.
_merge_claude_md_legacy() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  local src_headings dst_headings missing_titles
  src_headings="$(extract_h2 "$src")"
  dst_headings="$(extract_h2 "$dst")"
  # Lines in src not in dst — preserve src ordering (don't sort), so inserted
  # sections appear in the same order as Agent0's CLAUDE.md.
  if [ -z "$dst_headings" ]; then
    missing_titles="$src_headings"
  else
    missing_titles="$(printf '%s\n' "$src_headings" | grep -Fxv -f <(printf '%s\n' "$dst_headings") || true)"
  fi

  if [ -z "$missing_titles" ]; then
    # CLAUDE.md is expected to diverge in fork-authored content (Overview, Stack, etc).
    # The sync's only job is to ensure capacity sections from Agent0 are present.
    # If all Agent0 sections are present, treat as up-to-date regardless of other-body drift.
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # We have missing sections to append. Build the new content.
  local tmp anchor anchor_line
  tmp="$(mktemp -t sync-claude-md-XXXXXX)"
  anchor="## Compact Instructions"
  anchor_line="$(grep -nF "$anchor" "$dst" | head -1 | cut -d: -f1 || true)"

  if [ -z "$anchor_line" ]; then
    printf '!! claude-md: missing "%s" anchor — appending at EOF\n' "$anchor" >&2
    cp "$dst" "$tmp"
    # Append each missing section
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      printf '\n' >> "$tmp"
      extract_section "$src" "$title" >> "$tmp"
    done <<EOF
$missing_titles
EOF
  else
    # Split fork file: pre-anchor + anchor-onwards
    head -n $((anchor_line - 1)) "$dst" > "$tmp"
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      extract_section "$src" "$title" >> "$tmp"
      printf '\n' >> "$tmp"
    done <<EOF
$missing_titles
EOF
    tail -n +$anchor_line "$dst" >> "$tmp"
  fi

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s\n' "$rel"
    DRIFT=1
    rm -f "$tmp"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '~ merged %s (dry-run)\n' "$rel"
    rm -f "$tmp"
  else
    mv "$tmp" "$dst"
    printf '~ merged %s\n' "$rel"
  fi
  MERGED=$((MERGED + 1))
}

# Dispatcher: routes by marker state in fork's CLAUDE.md.
merge_claude_md() {
  local rel="CLAUDE.md"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"

  if [ ! -f "$src" ]; then
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  local state
  state="$(detect_marker_state "$dst")"
  case "$state" in
    paired)
      _merge_claude_md_managed_block
      ;;
    mismatched)
      printf '!! claude-md: markers mismatched — both BEGIN and END must be paired, or both absent\n' >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
      ;;
    nested-invalid)
      printf '!! claude-md: nested or out-of-order markers — exactly one BEGIN before exactly one END required\n' >&2
      CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
      ;;
    absent|*)
      _merge_claude_md_legacy
      _generate_migration_candidate
      ;;
  esac
}

# ---------------------------------------------------------------------------
# .gitignore additive merge
# ---------------------------------------------------------------------------

# Agent0's .gitignore carries harness-runtime entries (audit logs, state dirs,
# lock files) that MUST exist in any fork for the harness to run cleanly. Fork's
# .gitignore is typically stack-canonical (Laravel's vendor/, Next's node_modules/,
# etc.) and conflicts with Agent0's stack-agnostic template if overwritten. This
# function appends Agent0 entries the fork is missing, preserving fork-specific
# lines untouched. Idempotent: re-runs add nothing once the fork has all Agent0
# entries. Comments and blank lines are NOT membership-keyed (entries are the
# semantic unit).

merge_gitignore() {
  local rel=".gitignore"
  local src="$AGENT0_ROOT/$rel"
  local dst="$FORK_ROOT/$rel"
  local marker="# === Agent0 harness sync — additions ==="

  if [ ! -f "$src" ]; then
    return
  fi

  # Honor --force-except for the canonical .gitignore case (documented in
  # harness-sync.md). Even though merge is additive, the operator's intent in
  # passing --force-except='.gitignore' is "do not touch the fork's .gitignore".
  if matches_force_except "$rel"; then
    printf '!! force-except %s (merge skipped)\n' "$rel" >&2
    CUSTOMIZED_REFUSED=$((CUSTOMIZED_REFUSED + 1))
    return
  fi

  if [ ! -f "$dst" ]; then
    process_file "$rel"
    return
  fi

  local src_sha dst_sha
  src_sha="$(sha_of "$src")"
  dst_sha="$(sha_of "$dst")"
  if [ "$src_sha" = "$dst_sha" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    return
  fi

  # Extract entries: non-comment, non-empty, trimmed. Sort for comm.
  local tmp_src_entries tmp_fork_entries tmp_missing
  tmp_src_entries="$(mktemp -t sync-gi-src-XXXXXX)"
  tmp_fork_entries="$(mktemp -t sync-gi-fork-XXXXXX)"
  tmp_missing="$(mktemp -t sync-gi-miss-XXXXXX)"

  grep -v '^[[:space:]]*#' "$src" | grep -v '^[[:space:]]*$' | awk '{$1=$1;print}' | sort -u > "$tmp_src_entries"
  grep -v '^[[:space:]]*#' "$dst" | grep -v '^[[:space:]]*$' | awk '{$1=$1;print}' | sort -u > "$tmp_fork_entries"

  # Lines in src but not in dst — these are the additions.
  comm -23 "$tmp_src_entries" "$tmp_fork_entries" > "$tmp_missing"

  if [ ! -s "$tmp_missing" ]; then
    printf '= up to date %s\n' "$rel"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing"
    return
  fi

  local missing_count
  missing_count="$(wc -l < "$tmp_missing" | awk '{print $1}')"

  if [ "$MODE" = "check" ]; then
    printf '~ would merge %s (%d entries to add)\n' "$rel" "$missing_count"
    DRIFT=1
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing"
    return
  fi

  # Build merged content: fork's current content + marker (if new) + missing entries.
  local tmp_merged
  tmp_merged="$(mktemp -t sync-gi-merged-XXXXXX)"
  cat "$dst" > "$tmp_merged"

  if ! grep -Fq "$marker" "$tmp_merged"; then
    {
      printf '\n%s\n' "$marker"
    } >> "$tmp_merged"
  else
    printf '\n' >> "$tmp_merged"
  fi

  while IFS= read -r line; do
    printf '%s\n' "$line" >> "$tmp_merged"
  done < "$tmp_missing"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '~ merged %s (%d entries, dry-run)\n' "$rel" "$missing_count"
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing" "$tmp_merged"
  else
    mv "$tmp_merged" "$dst"
    printf '~ merged %s (%d entries appended)\n' "$rel" "$missing_count"
    rm -f "$tmp_src_entries" "$tmp_fork_entries" "$tmp_missing"
  fi
  MERGED=$((MERGED + 1))
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

load_baseline
_self_rebootstrap
walk_copy_check
record_managed_block_manifest
reconcile_deletions
merge_settings_json
merge_claude_md
merge_gitignore
write_baseline

# Summary on stderr so stdout stays parseable per-file decisions.
{
  printf '\n'
  printf 'synced: %d copied, %d stale-updated, %d removed, %d merged, %d up-to-date, %d customized-refused, %d overwritten\n' \
    "$COPIED" "$STALE_UPDATED" "$REMOVED" "$MERGED" "$UP_TO_DATE" "$CUSTOMIZED_REFUSED" "$OVERWRITTEN"
} >&2

# Exit code policy
if [ "$MODE" = "check" ]; then
  if [ "$DRIFT" -ne 0 ]; then
    exit 1
  fi
  exit 0
fi

# apply mode
if [ "$CUSTOMIZED_REFUSED" -gt 0 ]; then
  exit 1
fi

exit 0
