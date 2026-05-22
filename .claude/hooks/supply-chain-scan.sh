#!/usr/bin/env bash
# .claude/hooks/supply-chain-scan.sh
# PreToolUse(Bash) hook — supply-chain dep-install gate + audit (specs 008+009).
#
# Detects dep-mutating Bash commands across 10 package managers (npm, pnpm,
# yarn, bun, pip, uv, poetry, pdm, cargo, go), audits them, and either blocks
# (spec 009 default) or advises (spec 008 mode, opt-in via env var). Honors
# the `# OVERRIDE: <reason ≥10 chars>` marker (start-of-line anchored, same
# shape as .claude/hooks/secrets-scan.sh) to record intent and bypass block.
#
# Modes (resolved at hook entry):
#   block (default)  — detected dep-install + no valid override → exit 2,
#                      corrective stderr template, audit decision="block".
#                      Valid override → exit 0 silent, decision="block-override".
#                      Too-short override → exit 2 with short-reason template,
#                      decision="block" with rejected reason preserved.
#   advisory         — CLAUDE_SUPPLY_CHAIN_BLOCK=0; spec 008 behaviour exactly.
#                      Never exit 2. Decision values: "advisory" / "advisory-override".
#                      Too-short override silently degrades to plain advisory.
#
# Decision values:
#   "skip-not-install"  — not a recognised dep-install shape (both modes)
#   "advisory"          — advisory mode, no valid override; stderr advisory line
#   "advisory-override" — advisory mode + valid override; silent, reason recorded
#   "block"             — block mode, no valid override (or too-short); exit 2
#                         + corrective stderr; override_reason populated only
#                         when too-short marker was rejected (forensics)
#   "block-override"    — block mode + valid override; silent, reason recorded
#
# Override grammar: line matching `^[[:space:]]*# OVERRIDE: <reason>` in the
# raw command string, reason ≥10 chars after trim. Start-of-line anchored;
# inline trailing markers are NOT accepted (matches secrets-scan precedent;
# see .claude/rules/secrets-scan.md § Override grammar for the regression that
# the anchor closes).
#
# Escape hatches:
#   CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1  — exits 0 silently, no scan, no audit
#                                      (takes precedence over BLOCK setting)
#   CLAUDE_SUPPLY_CHAIN_BLOCK=0      — advisory mode (spec 008 behaviour)
#   default / any other BLOCK value  — block mode (spec 009 default)
#
# The defensive default-to-block-on-unset means a typo in the env var name
# (CLAUDE_SUPPLY_CHAIN_BLCOK=0) leaves the discipline ON, not silently OFF.
#
# Reference:
#   .claude/rules/supply-chain.md      — full discipline
#   .claude/hooks/secrets-scan.sh      — sibling preflight (primitives reused);
#                                        block-template-as-contract pattern
#                                        from spec 006/007 (issue #24327)
#   docs/specs/008-supply-chain-scan/  — base advisory capacity
#   docs/specs/009-supply-chain-block/ — block-by-default promotion
#
# Exit codes: 0 (pass / advisory / valid-override) or 2 (block mode reject).
# jq is a hard dependency; if missing the hook fails open (exit 0).
# bash 3.2-compatible: no associative arrays, no mapfile, no `[[ =~ ]]`.
# set -uo pipefail (NOT set -euo pipefail): `-e` would abort on intentional
# non-zero returns from grep (no match → exit 1).

set -uo pipefail

# ---------------------------------------------------------------------------
# Phase 1: User-facing escape hatch
# ---------------------------------------------------------------------------
if [ "${CLAUDE_SKIP_SUPPLY_CHAIN_SCAN:-0}" = "1" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Phase 1b: Mode resolution (spec 009)
# ---------------------------------------------------------------------------
# CLAUDE_SUPPLY_CHAIN_BLOCK=0 → advisory mode (spec 008 behaviour).
# Default OR any other value → block mode (spec 009 default).
# Defensive default-to-block: an env-var typo never silently disables block.
if [ "${CLAUDE_SUPPLY_CHAIN_BLOCK:-1}" = "0" ]; then
  MODE="advisory"
else
  MODE="block"
fi

# ---------------------------------------------------------------------------
# Stdin capture + jq availability
# ---------------------------------------------------------------------------
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || true)"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
AUDIT_LOG="$PROJECT_DIR/.claude/supply-chain-audit.jsonl"

mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || exit 0
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Empty command → no audit, exit 0
[ -z "$COMMAND" ] && exit 0

# ---------------------------------------------------------------------------
# Audit helper
# ---------------------------------------------------------------------------
# append_audit decision [manager] [action] [packages_json] [override_reason]
# packages_json must be a pre-encoded JSON value (array string or the literal
# "null"). manager/action/override_reason are bare strings (encoded inline).
append_audit() {
  local decision="$1"
  local manager="${2:-}"
  local action="${3:-}"
  local packages_json="${4:-null}"
  local override_reason="${5:-}"

  local session_id_json agent_id_json manager_json action_json override_reason_json

  if [ -n "$SESSION_ID" ]; then
    session_id_json="$(printf '%s' "$SESSION_ID" | jq -R -s -c 'rtrimstr("\n")')"
  else
    session_id_json="null"
  fi

  if [ -n "$AGENT_ID" ]; then
    agent_id_json="$(printf '%s' "$AGENT_ID" | jq -R -s -c 'rtrimstr("\n")')"
  else
    agent_id_json="null"
  fi

  if [ -n "$manager" ]; then
    manager_json="$(printf '%s' "$manager" | jq -R -s -c 'rtrimstr("\n")')"
  else
    manager_json="null"
  fi

  if [ -n "$action" ]; then
    action_json="$(printf '%s' "$action" | jq -R -s -c 'rtrimstr("\n")')"
  else
    action_json="null"
  fi

  if [ -n "$override_reason" ]; then
    override_reason_json="$(printf '%s' "$override_reason" | jq -R -s -c 'rtrimstr("\n")')"
  else
    override_reason_json="null"
  fi

  local line
  line="$(jq -c -n \
    --arg ts "$ts" \
    --argjson session_id "$session_id_json" \
    --argjson agent_id "$agent_id_json" \
    --arg decision "$decision" \
    --arg scope "bash" \
    --argjson manager "$manager_json" \
    --argjson action "$action_json" \
    --argjson packages "$packages_json" \
    --argjson override_reason "$override_reason_json" \
    '{ts:$ts, session_id:$session_id, agent_id:$agent_id, decision:$decision, scope:$scope, manager:$manager, action:$action, packages:$packages, override_reason:$override_reason}')"

  # Atomic append via flock; probe writability in a subshell first to avoid
  # the sticky `exec 9>file 2>/dev/null` trap (silences all stderr).
  # See .claude/rules/delegation.md § Gotchas.
  if command -v flock >/dev/null 2>&1; then
    local lock_path="$AUDIT_LOG.lock"
    ( : >>"$lock_path" ) 2>/dev/null || {
      printf '%s\n' "$line" >> "$AUDIT_LOG" 2>/dev/null || true
      return 0
    }
    exec 9>"$lock_path"
    flock 9
    printf '%s\n' "$line" >> "$AUDIT_LOG"
    flock -u 9
    exec 9>&-
  else
    printf '%s\n' "$line" >> "$AUDIT_LOG" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Phase 3: Override marker parsing
# ---------------------------------------------------------------------------
# Same regex as secrets-scan.sh: `^[[:space:]]*# OVERRIDE: <reason>` anchored
# at start-of-line. Reason must be ≥10 chars after trim.
#
# Outcomes:
#   override_valid=1       — reason ≥10 chars; bypasses block, suppresses advisory
#   override_too_short=1   — marker present but reason <10 chars; in block mode
#                            this rejects with a short-reason template (decision
#                            "block", reason preserved in audit); in advisory
#                            mode it silently degrades to plain advisory.
# override_reason is populated in BOTH cases (forensic preservation) — empty
# only when no marker is present at all.
override_reason=""
override_valid=0
override_too_short=0

override_line="$(printf '%s' "$COMMAND" | grep -E '^[[:space:]]*# OVERRIDE: ' | head -1 | sed -e 's/^[[:space:]]*//' 2>/dev/null || true)"

if [ -n "$override_line" ]; then
  reason="${override_line#'# OVERRIDE: '}"
  reason="$(printf '%s' "$reason" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  override_reason="$reason"
  if [ "${#reason}" -ge 10 ]; then
    override_valid=1
  else
    override_too_short=1
  fi
fi

# ---------------------------------------------------------------------------
# Phase 4: Tokenize the command and detect manager+verb+packages
# ---------------------------------------------------------------------------
# We tokenize via default word splitting (whitespace + newlines). This means
# tokens from a multi-line command (with override marker on line 2) all flow
# into one stream — the `#` token starting line 2 acts as a terminator in
# the package-collection loop below.
#
# Manager set + verb whitelist per manager:
#   npm    install i add update upgrade
#   pnpm   install i add update up
#   yarn   add                                 (yarn install is no-arg resolve)
#   bun    install i add update
#   pip    install
#   uv     add
#   poetry add
#   pdm    add
#   cargo  add update install
#   go     get
#
# Loop walks tokens, looks for (manager, verb) pair, then collects subsequent
# non-flag-non-separator tokens as packages.

detected_manager=""
detected_action=""
detected_packages=""

# Bare lockfile-resolve install tracking (closes parent-edit + bare-install
# coverage gap surfaced via shrnk-mono spec 013 dogfood 2026-05-12; sibling to
# spec 008/009 detection). When a manager+verb pair matches but no packages are
# collected AND the verb is a lockfile-resolve shape (npm/pnpm/bun `install` |
# `i`), record it for the post-scan dirty-manifest advisory below. Defaults
# stay empty so the existing skip-not-install path is unchanged when no bare
# install was seen.
bare_install_manager=""
bare_install_action=""

# shellcheck disable=SC2206  # intentional word-splitting on COMMAND
tokens=( $COMMAND )
n=${#tokens[@]}

i=0
while [ "$i" -lt "$((n - 1))" ]; do
  current="${tokens[$i]}"
  next="${tokens[$((i + 1))]}"

  verbs=""
  case "$current" in
    npm)    verbs="install i add update upgrade" ;;
    pnpm)   verbs="install i add update up" ;;
    yarn)   verbs="add" ;;
    bun)    verbs="install i add update" ;;
    pip)    verbs="install" ;;
    uv)     verbs="add" ;;
    poetry) verbs="add" ;;
    pdm)    verbs="add" ;;
    cargo)  verbs="add update install" ;;
    go)     verbs="get" ;;
    composer) verbs="require remove update install" ;;
    *)      i=$((i + 1)); continue ;;
  esac

  # Is `next` one of this manager's verbs?
  verb_match=""
  for v in $verbs; do
    if [ "$next" = "$v" ]; then
      verb_match="$v"
      break
    fi
  done

  if [ -z "$verb_match" ]; then
    i=$((i + 1))
    continue
  fi

  # Found a manager+verb pair. Collect packages from tokens[i+2..].
  # Stop at any shell separator (chain / pipe / redirect / background) or
  # comment start. Skip BOTH a known value-taking flag and its value (so
  # `--directory /path` doesn't leak the path into packages). `-r` and
  # `--package` are deliberately NOT on the value-taking list — their values
  # carry the supply-chain signal (requirements file, package name).
  j=$((i + 2))
  pkgs=""
  while [ "$j" -lt "$n" ]; do
    tok="${tokens[$j]}"
    case "$tok" in
      '&&'|'||'|';'|'|'|'>'|'>>'|'<'|'&'|'2>&1'|'2>'|'&>')
                      break ;;
      '#'*)           break ;;
      --directory|--dir|--target|--target-dir|--prefix|--manifest-path|--project|--cwd|--workspace|--config|-c|--filter|--registry|--index|--index-url|--features|-F)
                      j=$((j + 2)); continue ;;
      -*)             j=$((j + 1)); continue ;;
      *)              pkgs="$pkgs $tok"; j=$((j + 1)) ;;
    esac
  done
  pkgs="${pkgs# }"  # trim leading space

  if [ -n "$pkgs" ]; then
    detected_manager="$current"
    detected_action="$verb_match"
    detected_packages="$pkgs"
    break
  fi

  # Manager+verb matched but no packages collected (e.g. `npm install` alone,
  # or `pip install --help`). Treat as not-a-mutation and keep scanning in
  # case the command chains another install later.
  #
  # Bare-install sub-path: lockfile-resolve verbs (npm/pnpm/bun install|i) with
  # no args resolve from the manifest+lockfile pair — semantically "apply
  # pending dep declarations". Record the first such match so the post-scan
  # branch can check for an uncommitted manifest and emit an advisory. Other
  # empty matches (pip install --help, cargo install with no positional) are
  # NOT recorded — they're genuine no-ops, not lockfile resolves.
  if [ -z "$bare_install_manager" ]; then
    case "$current.$verb_match" in
      npm.install|npm.i|pnpm.install|pnpm.i|bun.install|bun.i|composer.install)
        bare_install_manager="$current"
        bare_install_action="$verb_match"
        ;;
    esac
  fi

  i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Phase 5: Decision (mode-aware — spec 009)
# ---------------------------------------------------------------------------
if [ -z "$detected_manager" ]; then
  # Bare lockfile-resolve install + uncommitted manifest → advisory.
  # Closes the parent-edit + bare-install coverage gap caught via shrnk-mono
  # spec 013 dogfood 2026-05-12 (parent edits package.json, runs `bun install`,
  # both layers silent; dep enters lockfile with zero audit signal). Extends
  # spec 008/009 detection; not a separate capacity.
  #
  # Predicate: a manager+verb pair like `bun install` matched WITHOUT packages
  # AND a recognised manifest basename (package.json / pyproject.toml /
  # Cargo.toml / go.mod) is modified-uncommitted at hook time. Honors the
  # OVERRIDE marker (silences stderr, records reason). Mode-agnostic — always
  # advisory, never block; the intent was already declared via the manifest
  # edit, blocking the resolve would be late.
  if [ -n "$bare_install_manager" ] && git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    manifests_dirty=""
    while IFS= read -r line; do
      # Porcelain format: `XY<space>path` (2-char status + space + path).
      # For renames `XY old -> new` take the destination name.
      path="${line:3}"
      case "$path" in
        *' -> '*) path="${path##* -> }" ;;
      esac
      base="$(basename "$path")"
      case "$base" in
        package.json|pyproject.toml|Cargo.toml|go.mod|composer.json)
          # Dedup across multiple matches (monorepo with both apps/web/package.json
          # and apps/api/package.json dirty → list `package.json` once).
          case " $manifests_dirty " in
            *" $base "*) ;;
            *)
              if [ -z "$manifests_dirty" ]; then
                manifests_dirty="$base"
              else
                manifests_dirty="$manifests_dirty $base"
              fi
              ;;
          esac
          ;;
      esac
    done < <(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)

    if [ -n "$manifests_dirty" ]; then
      if [ "$override_valid" -eq 1 ]; then
        append_audit "advisory-bare-install-override" \
          "$bare_install_manager" "$bare_install_action" "[]" "$override_reason"
      else
        printf 'supply-chain-advisory: bare `%s %s` with uncommitted manifest(s): %s — installing newly-declared dep(s); add `# OVERRIDE: <reason ≥10 chars>` on its own line to silence\n' \
          "$bare_install_manager" "$bare_install_action" "$manifests_dirty" >&2
        append_audit "advisory-bare-install" \
          "$bare_install_manager" "$bare_install_action" "[]" ""
      fi
      exit 0
    fi
  fi

  # No install pattern matched (or bare-install without dirty manifest) →
  # skip-not-install audit + silent exit. Same in both modes.
  append_audit "skip-not-install"
  exit 0
fi

# Build packages JSON array from space-separated string.
# shellcheck disable=SC2086  # intentional word splitting
packages_json="$(printf '%s\n' $detected_packages | jq -R . | jq -s -c .)"
packages_display="$(printf '%s' "$packages_json" | jq -r 'join(", ")')"

# Extract first non-empty, non-OVERRIDE line of the command for the corrective
# stderr template. Multi-line commands carry the marker on line 2; only line 1
# is the actual install shape worth echoing back in the "corrected form" hint.
first_cmd_line="$(printf '%s' "$COMMAND" | grep -v '^[[:space:]]*# OVERRIDE: ' | grep -v '^[[:space:]]*$' | head -1)"

# --- Block mode (spec 009 default) -----------------------------------------
if [ "$MODE" = "block" ]; then
  if [ "$override_valid" -eq 1 ]; then
    append_audit "block-override" "$detected_manager" "$detected_action" "$packages_json" "$override_reason"
    exit 0
  fi

  if [ "$override_too_short" -eq 1 ]; then
    # Short-reason rejection — block with the dedicated template.
    # Audit row keeps override_reason populated for forensics.
    cat >&2 <<EOF
supply-chain-block: override reason must be ≥10 characters, got "$override_reason"

Corrected form:
  $first_cmd_line
  # OVERRIDE: <reason ≥10 chars — why this dep is being added>
EOF
    append_audit "block" "$detected_manager" "$detected_action" "$packages_json" "$override_reason"
    exit 2
  fi

  # No marker at all — block with the no-override template.
  cat >&2 <<EOF
supply-chain-block: $detected_manager $detected_action detected — packages: $packages_display

Dep installs require documented intent in block mode. Either re-run with an
override marker (reason ≥10 chars on its own line), or opt out of block mode
for this session: CLAUDE_SUPPLY_CHAIN_BLOCK=0 (advisory only) or
CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1 (full disable).

Corrected form:
  $first_cmd_line
  # OVERRIDE: <reason ≥10 chars — why this dep is being added>
EOF
  append_audit "block" "$detected_manager" "$detected_action" "$packages_json" ""
  exit 2
fi

# --- Advisory mode (spec 008 behaviour, preserved exactly) -----------------
if [ "$override_valid" -eq 1 ]; then
  append_audit "advisory-override" "$detected_manager" "$detected_action" "$packages_json" "$override_reason"
  exit 0
fi

# No valid override (including too-short, which silently degrades in advisory
# mode per spec 008) — emit stderr advisory and audit `advisory`.
printf 'supply-chain-advisory: %s %s — %s\n' "$detected_manager" "$detected_action" "$packages_display" >&2
append_audit "advisory" "$detected_manager" "$detected_action" "$packages_json" ""
exit 0
