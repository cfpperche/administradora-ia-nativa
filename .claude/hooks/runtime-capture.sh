#!/usr/bin/env bash
# .claude/hooks/runtime-capture.sh
# PostToolUse(Bash) hook — capture last test/build/typecheck run (spec 011).
#
# Tokenises tool_input.command, matches against the v1 detector pair list
# plus CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT globs, and on a match writes
# .claude/.runtime-state/last-run.json atomically (mktemp + mv). Non-matches
# exit silently with no state write. Always exits 0 — capture failure is
# invisible to the underlying Bash; one diagnostic line goes to stderr only
# when CLAUDE_RUNTIME_INTROSPECT_DEBUG=1.
#
# Tokeniser TWIN: shares pattern with .claude/hooks/supply-chain-scan.sh's
# package-collection loop — same chain/pipe/redirect terminators and
# value-taking flag skip. See .claude/rules/runtime-introspect.md § Gotchas
# ("Tokeniser drift with supply-chain-scan").
#
# Detector pair list (v1):
#   bun test                        → bun-test
#   bun tsc                         → bun-tsc
#   bun run <script-with-keyword>   → bun-run        (test|build|typecheck|lint substring)
#   npm test                        → npm-test
#   npm run <script-with-keyword>   → npm-run
#   pnpm test                       → pnpm-test
#   pnpm run <script-with-keyword>  → pnpm-run
#   yarn test|build|typecheck|lint  → yarn-<verb>
#   pytest                          → pytest
#   python|python3 -m pytest        → python-pytest
#   python|python3 -m unittest      → python-unittest
#
# Extension: CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="<space-separated keys>"
#   where each key has the hyphen-joined `<tool>-<verb>` shape (e.g. make-test,
#   just-check). The resulting detector field is prefixed `extra:<key>` so
#   forensic queries can distinguish core vs extension matches.
#
# Reference:
#   .claude/rules/runtime-introspect.md       — full discipline
#   .claude/hooks/supply-chain-scan.sh        — tokeniser-twin (keep in sync)
#   .claude/hooks/secrets-scan.sh             — fail-open patterns
#   docs/specs/011-runtime-introspect/        — spec

set -uo pipefail

debug() {
  if [ "${CLAUDE_RUNTIME_INTROSPECT_DEBUG:-0}" = "1" ]; then
    printf 'runtime-introspect: %s\n' "$*" >&2
  fi
}

# ---------------------------------------------------------------------------
# Phase 1: User-facing escape hatch
# ---------------------------------------------------------------------------
if [ "${CLAUDE_SKIP_RUNTIME_INTROSPECT:-0}" = "1" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Stdin capture + jq availability
# ---------------------------------------------------------------------------
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  debug "jq not found — capture skipped"
  exit 0
fi

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -z "$COMMAND" ] && exit 0

# ---------------------------------------------------------------------------
# Pre-tokeniser skip: known FP shapes that contain verifier-shaped tokens
# inside non-verifier content (commit-message heredoc, grep with pattern, etc.)
# ---------------------------------------------------------------------------
# Surfaced by validation pass 2026-05-11 against spec 011 itself: a `git
# commit -m "$(cat <<'EOF' ... bun tsc ... EOF)"` invocation tokenised the
# commit body and matched "bun tsc" → false snapshot. Same family as the
# supply-chain "commit messages mentioning compound syntax" gotcha but
# higher prevalence here because verifier verbs ARE common prose. Detect
# `git commit` as a leading-segment shape and skip.
#
# Tolerates: `git commit ...`, `git -C <path> commit ...`, `git  commit`
# (double space). Whitespace + non-`#` non-newline content allowed between
# `git` and `commit` (covers -C flags etc.).
case "$COMMAND" in
  git\ commit*|git\ \ *commit*|git\ -C\ *commit*|git\ -c\ *commit*)
    exit 0 ;;
esac
# Same skip for `grep` (`grep -E 'bun test' file` would tokenise 'bun test').
case "$COMMAND" in
  grep\ *|*\ |\ grep\ *|*\ grep\ *) ;;  # let through — only skip leading grep, not piped greps
esac
case "$COMMAND" in
  grep\ *|egrep\ *|fgrep\ *|rg\ *|ag\ *)
    exit 0 ;;
esac

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || true)"
TOOL_USE_ID="$(printf '%s' "$INPUT" | jq -r '.tool_use_id // ""' 2>/dev/null || true)"
HOOK_EVENT_NAME="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || true)"

# PostToolUse tool_response shape (Claude Code, 2026-05-11):
#   {stdout, stderr, interrupted, isImage, noOutputExpected}
# Notably absent: exit_code. Live-dogfood pass 1 against /home/goat/shrnk
# confirmed Claude Code's Bash tool_response carries NO exit signal — only
# the streams. We still read exit_code defensively in case the field appears
# in a future harness release or another tool surface (tests still simulate
# it). When absent, status is inferred from runner-specific stdout patterns.
#
# PostToolUseFailure shape DIVERGES (spec 020, empirically verified
# 2026-05-11): tool_response is ABSENT. Failure body is at top-level
# `.error` as a single string; `is_interrupt` replaces
# `tool_response.interrupted`. We route `.error` → STDERR_RAW so the
# existing inference table (and tail-clamp logic) treats the failure body
# as stderr — semantically correct (it's the failing tool's error stream
# from the agent's perspective) and zero-churn for downstream code.
EXIT_CODE="$(printf '%s' "$INPUT" | jq -r '.tool_response.exit_code // empty' 2>/dev/null || true)"

# Top-level duration_ms is provided by the harness on PostToolUse (real wall
# clock). Use it when present — more accurate than diffing date-second marks
# from PreToolUse, which was the only fallback before this finding.
HARNESS_DURATION_MS="$(printf '%s' "$INPUT" | jq -r '.duration_ms // empty' 2>/dev/null || true)"

if [ "$HOOK_EVENT_NAME" = "PostToolUseFailure" ]; then
  INTERRUPTED="$(printf '%s' "$INPUT" | jq -r '.is_interrupt // false' 2>/dev/null || echo false)"
  STDOUT_RAW=""
  STDERR_RAW="$(printf '%s' "$INPUT" | jq -j '.error // ""' 2>/dev/null; printf x)"
  STDERR_RAW="${STDERR_RAW%x}"
else
  INTERRUPTED="$(printf '%s' "$INPUT" | jq -r '.tool_response.interrupted // false' 2>/dev/null || echo false)"
  # Use jq -j (no separator newline) + printf-x sentinel to preserve trailing
  # newlines in stdout/stderr. $(jq -r) strips ONE trailing \n; without this
  # trick, "foo\n" round-trips to "foo".
  STDOUT_RAW="$(printf '%s' "$INPUT" | jq -j '.tool_response.stdout // ""' 2>/dev/null; printf x)"
  STDOUT_RAW="${STDOUT_RAW%x}"
  STDERR_RAW="$(printf '%s' "$INPUT" | jq -j '.tool_response.stderr // ""' 2>/dev/null; printf x)"
  STDERR_RAW="${STDERR_RAW%x}"
fi

# Strip ANSI escape sequences (SGR colors, cursor moves, clear, etc.) from
# both streams before downstream use. Bun's test runner and many other
# modern verifiers emit colored output (e.g. `\e[32m 0 fail\e[0m`) which
# prefixes line-anchored inference patterns like `^[[:space:]]*0 fail$` and
# forces the inference to fall through to the weak `pass/ok` heuristic
# (surfaced by shrnk-mono dogfood 2026-05-12). LLM agents reading the
# snapshot don't render colors anyway, so the codes are pure noise.
# Pattern covers ESC + `[` + optional parameters + final letter; matches
# SGR (`m`), cursor positioning, clear, and most CSI sequences.
# Reuse the `printf x` sentinel trick so command substitution preserves
# any trailing newline in the original stream (test 04 asserts verbatim).
ANSI_ESC="$(printf '\033')"
STDOUT_RAW="$(printf '%s' "$STDOUT_RAW" | sed "s/${ANSI_ESC}\[[0-9;]*[a-zA-Z]//g"; printf x)"
STDOUT_RAW="${STDOUT_RAW%x}"
STDERR_RAW="$(printf '%s' "$STDERR_RAW" | sed "s/${ANSI_ESC}\[[0-9;]*[a-zA-Z]//g"; printf x)"
STDERR_RAW="${STDERR_RAW%x}"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$PROJECT_DIR/.claude/.runtime-state"
IN_FLIGHT_DIR="$STATE_DIR/in-flight"

# ---------------------------------------------------------------------------
# Phase 2: Tokenise and detect
# ---------------------------------------------------------------------------
# shellcheck disable=SC2206  # intentional word-splitting on COMMAND
tokens=( $COMMAND )
n=${#tokens[@]}

detector=""

# Helper: does token contain one of the verifier keywords?
script_has_keyword() {
  case "$1" in
    *test*|*build*|*typecheck*|*lint*) return 0 ;;
    *) return 1 ;;
  esac
}

# Parse EXTRA_DETECT into a space-separated list of `<tool>-<verb>` keys.
extra_detect="${CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT:-}"

i=0
while [ "$i" -lt "$n" ]; do
  current="${tokens[$i]}"
  next=""
  next2=""
  [ "$((i + 1))" -lt "$n" ] && next="${tokens[$((i + 1))]}"
  [ "$((i + 2))" -lt "$n" ] && next2="${tokens[$((i + 2))]}"

  # Single-token verifiers
  case "$current" in
    pytest)
      detector="pytest"
      break
      ;;
    vendor/bin/phpunit|./vendor/bin/phpunit)
      detector="phpunit"
      break
      ;;
    vendor/bin/pest|./vendor/bin/pest)
      detector="pest"
      break
      ;;
  esac

  # python|python3 -m pytest|unittest
  case "$current" in
    python|python3)
      if [ "$next" = "-m" ]; then
        case "$next2" in
          pytest)    detector="python-pytest"; break ;;
          unittest)  detector="python-unittest"; break ;;
        esac
      fi
      ;;
  esac

  # Pair-token verifiers
  case "$current $next" in
    "bun test")    detector="bun-test"; break ;;
    "bun tsc")     detector="bun-tsc"; break ;;
    "npm test")    detector="npm-test"; break ;;
    "pnpm test")   detector="pnpm-test"; break ;;
    "yarn test")   detector="yarn-test"; break ;;
    "yarn build")  detector="yarn-build"; break ;;
    "yarn typecheck") detector="yarn-typecheck"; break ;;
    "yarn lint")   detector="yarn-lint"; break ;;
    "cargo test")    detector="cargo-test"; break ;;
    "cargo build")   detector="cargo-build"; break ;;
    "cargo check")   detector="cargo-check"; break ;;
    "cargo clippy")  detector="cargo-clippy"; break ;;
    "artisan test")  detector="artisan-test"; break ;;
    "composer test") detector="composer-test"; break ;;
    "composer lint") detector="composer-lint"; break ;;
  esac

  # run-script verifiers: bun run / npm run / pnpm run + script with keyword.
  # Suffix encodes which verifier shape the script ran (test/build/typecheck/lint)
  # so inference can route to the right pattern table.
  case "$current $next" in
    "bun run"|"npm run"|"pnpm run"|"yarn run")
      if [ -n "$next2" ] && script_has_keyword "$next2"; then
        sub="run"
        case "$next2" in
          *test*)      sub="run-test" ;;
          *typecheck*) sub="run-typecheck" ;;
          *build*)     sub="run-build" ;;
          *lint*)      sub="run-lint" ;;
        esac
        detector="${current}-${sub}"
        break
      fi
      ;;
  esac

  i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Phase 3: EXTRA_DETECT extension (only when core detection missed)
# ---------------------------------------------------------------------------
if [ -z "$detector" ] && [ -n "$extra_detect" ]; then
  i=0
  while [ "$i" -lt "$((n - 1))" ]; do
    current="${tokens[$i]}"
    next="${tokens[$((i + 1))]}"
    candidate="$current-$next"
    for key in $extra_detect; do
      if [ "$candidate" = "$key" ]; then
        detector="extra:$key"
        break 2
      fi
    done
    i=$((i + 1))
  done
fi

# No detector matched → silent skip.
[ -z "$detector" ] && exit 0

debug "detector matched: $detector ($COMMAND)"

# ---------------------------------------------------------------------------
# Phase 3.5: Infer status from runner-specific stdout patterns
# ---------------------------------------------------------------------------
# Heuristic-only — driven by lived runner output. Updated when a real-world
# runner output surfaces that the table misses. Tested in test 09.
inferred_status="UNKNOWN"
inference_basis=""

infer_status() {
  local det="$1"
  local out="$2"
  case "$det" in
    # Test-style runners (and run-script with `*test*` keyword).
    bun-test|npm-test|pnpm-test|yarn-test|*-run-test)
      # bun test: ` 0 fail` / ` N fail` (any N>0 = FAIL)
      # npm/pnpm/yarn test typically delegate to jest/vitest/etc. — same shape works
      if printf '%s' "$out" | grep -qE '^[[:space:]]*0 fail[[:space:]]*$'; then
        inferred_status="PASS"
        inference_basis="$det: '0 fail' line"
        return
      fi
      if printf '%s' "$out" | grep -qE '[1-9][0-9]* fail'; then
        inferred_status="FAIL"
        inference_basis="$det: 'N fail' with N>0"
        return
      fi
      # vitest-style: "Test Files  X failed"
      if printf '%s' "$out" | grep -qiE 'failed|✗|error'; then
        inferred_status="FAIL"
        inference_basis="$det: failed/error keyword"
        return
      fi
      if printf '%s' "$out" | grep -qiE 'pass|✓|ok'; then
        inferred_status="PASS"
        inference_basis="$det: pass/ok keyword (weak heuristic)"
        return
      fi
      ;;
    pytest|python-pytest|python-unittest)
      # pytest: "===== N failed" / "===== N passed"
      if printf '%s' "$out" | grep -qE '[1-9][0-9]* (failed|error)'; then
        inferred_status="FAIL"
        inference_basis="$det: 'N failed/error' in summary"
        return
      fi
      if printf '%s' "$out" | grep -qE '[0-9]+ passed' && ! printf '%s' "$out" | grep -qE 'failed|error'; then
        inferred_status="PASS"
        inference_basis="$det: 'N passed' without failed"
        return
      fi
      # unittest: "OK" / "FAILED"
      if printf '%s' "$out" | grep -qE '^FAILED'; then
        inferred_status="FAIL"
        inference_basis="$det: 'FAILED' header (unittest)"
        return
      fi
      if printf '%s' "$out" | grep -qE '^OK'; then
        inferred_status="PASS"
        inference_basis="$det: 'OK' header (unittest)"
        return
      fi
      ;;
    # Typecheck / build / lint runners (and run-script with matching keyword).
    bun-tsc|yarn-typecheck|yarn-build|yarn-lint|*-run-typecheck|*-run-build|*-run-lint)
      # tsc emits "error TSXXXX:" lines on failure; absence = clean.
      if printf '%s' "$out" | grep -qE 'error TS[0-9]+'; then
        inferred_status="FAIL"
        inference_basis="$det: TS error line"
        return
      fi
      # Heuristic: if output is empty or short and no error keyword, treat
      # as PASS. tsc --noEmit clean output is empty.
      if [ "${#out}" -lt 500 ] && ! printf '%s' "$out" | grep -qiE 'error|fail'; then
        inferred_status="PASS"
        inference_basis="$det: clean (no error TS or fail keyword)"
        return
      fi
      ;;
    # PHP test runners — PHPUnit, Pest, Laravel artisan test, composer-script wrappers.
    # PHPUnit canonical summary: "OK (5 tests, 12 assertions)" (PASS) or
    # "FAILURES!" / "ERRORS!" followed by "Tests: N, Assertions: M, Failures: K".
    # Pest similar shape — wraps PHPUnit internally, summary line "Tests:  N passed".
    # `php artisan test` and `composer test` typically wrap one of these two runners.
    phpunit|pest|artisan-test|composer-test)
      # Laravel 11+ JSON output shape (default in `vendor/bin/phpunit` from
      # composer create-project laravel/laravel — verified empirically against
      # Laravel 11.x on 2026-05-18). Shape: `{"tool":"phpunit","result":"passed",...}`
      # or `"result":"failed"`. Check this FIRST because it's the most specific
      # and the JSON line is short, often the entire output.
      if printf '%s' "$out" | grep -qE '"result"[[:space:]]*:[[:space:]]*"passed"'; then
        inferred_status="PASS"
        inference_basis="$det: JSON \"result\":\"passed\""
        return
      fi
      if printf '%s' "$out" | grep -qE '"result"[[:space:]]*:[[:space:]]*"failed"'; then
        inferred_status="FAIL"
        inference_basis="$det: JSON \"result\":\"failed\""
        return
      fi
      # PHPUnit/Pest FAIL signals — most specific first.
      if printf '%s' "$out" | grep -qE '^FAILURES!'; then
        inferred_status="FAIL"
        inference_basis="$det: 'FAILURES!' header"
        return
      fi
      if printf '%s' "$out" | grep -qE '^ERRORS!'; then
        inferred_status="FAIL"
        inference_basis="$det: 'ERRORS!' header"
        return
      fi
      # Pest summary line: "Tests:  3 failed, 7 passed (...)" — failed count wins.
      if printf '%s' "$out" | grep -qE 'Tests:[[:space:]]+[1-9][0-9]* failed'; then
        inferred_status="FAIL"
        inference_basis="$det: 'Tests: N failed' summary"
        return
      fi
      # PHPUnit summary: "Tests: 5, Assertions: 10, Failures: 2" — non-zero Failures or Errors wins.
      if printf '%s' "$out" | grep -qE '(Failures|Errors): [1-9][0-9]*'; then
        inferred_status="FAIL"
        inference_basis="$det: PHPUnit summary with non-zero Failures/Errors"
        return
      fi
      # PHPUnit PASS canonical: "OK (N tests, M assertions)"
      if printf '%s' "$out" | grep -qE '^OK \([0-9]+ test'; then
        inferred_status="PASS"
        inference_basis="$det: 'OK (N tests, ...)' PHPUnit summary"
        return
      fi
      # Pest PASS: "Tests:  N passed" without "failed" siblings.
      if printf '%s' "$out" | grep -qE 'Tests:[[:space:]]+[0-9]+ passed' && ! printf '%s' "$out" | grep -qE 'failed|FAILURES|ERRORS'; then
        inferred_status="PASS"
        inference_basis="$det: 'Tests: N passed' (Pest summary)"
        return
      fi
      # Fatal PHP error (uncaught exception during bootstrap, syntax error, etc.)
      if printf '%s' "$out" | grep -qE 'PHP Fatal error|Parse error|Uncaught'; then
        inferred_status="FAIL"
        inference_basis="$det: PHP fatal/parse/uncaught error"
        return
      fi
      ;;
    # Composer lint wrappers — Pint and PHPStan have distinct output shapes.
    # Pint test mode: exit 0 if clean, exit 1 with "Style violations found".
    # PHPStan: exit 0 clean, exit 1 with "[ERROR] N errors" or "Found N errors".
    composer-lint)
      if printf '%s' "$out" | grep -qiE 'style violation|errors found|\[ERROR\]'; then
        inferred_status="FAIL"
        inference_basis="$det: lint failure marker"
        return
      fi
      if [ "${#out}" -lt 1500 ] && ! printf '%s' "$out" | grep -qiE 'error|fail|violation'; then
        inferred_status="PASS"
        inference_basis="$det: clean (no error/fail/violation keyword)"
        return
      fi
      ;;
    # Cargo test runner — canonical "test result:" line.
    cargo-test)
      if printf '%s' "$out" | grep -qE '^test result: ok'; then
        inferred_status="PASS"
        inference_basis="$det: 'test result: ok' line"
        return
      fi
      if printf '%s' "$out" | grep -qE '^test result: FAILED'; then
        inferred_status="FAIL"
        inference_basis="$det: 'test result: FAILED' line"
        return
      fi
      ;;
    # Cargo typecheck / build / lint — rustc compiler errors + clippy
    # promoted-warning lines, with cargo's Finished line as positive PASS.
    cargo-check|cargo-build|cargo-clippy)
      # rustc compiler error codes — most specific match first.
      if printf '%s' "$out" | grep -qE 'error\[E[0-9]+\]'; then
        inferred_status="FAIL"
        inference_basis="$det: 'error[E...]' line"
        return
      fi
      # `^error:` covers clippy -D warnings (promoted warnings) and rustc
      # summary "could not compile" lines.
      if printf '%s' "$out" | grep -qE '^error:'; then
        inferred_status="FAIL"
        inference_basis="$det: '^error:' line"
        return
      fi
      # Cargo emits `    Finished ...` on clean completion; canonical PASS
      # signal that's more robust than character-count heuristics (cargo
      # output frequently exceeds 500 chars with per-crate Compiling lines).
      if printf '%s' "$out" | grep -qE '[[:space:]]+Finished'; then
        inferred_status="PASS"
        inference_basis="$det: 'Finished' line, no errors"
        return
      fi
      ;;
  esac
}

# Combined stream for inference (stdout + stderr).
combined_for_inference="$STDOUT_RAW
$STDERR_RAW"

infer_status "$detector" "$combined_for_inference"

# PostToolUseFailure event implies the tool failed even when pattern-table
# inference missed (e.g. failure body shape unknown to the table). Default
# to FAIL — caller-event is authoritative signal that the verifier failed.
if [ "$HOOK_EVENT_NAME" = "PostToolUseFailure" ] && [ "$inferred_status" = "UNKNOWN" ]; then
  inferred_status="FAIL"
  inference_basis="PostToolUseFailure event (pattern table missed)"
fi

# Interruption trumps inference.
if [ "$INTERRUPTED" = "true" ]; then
  inferred_status="INTERRUPTED"
  inference_basis="interrupted=true on tool_response"
fi

debug "inferred_status: $inferred_status ($inference_basis)"

# ---------------------------------------------------------------------------
# Phase 4: Compute started_at / ended_at / duration_ms
# ---------------------------------------------------------------------------
ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
[ -z "$ended_at" ] && exit 0

started_at="$ended_at"
duration_ms="null"

# Prefer the harness's own top-level duration_ms (real wall clock, milliseconds).
if [ -n "$HARNESS_DURATION_MS" ]; then
  case "$HARNESS_DURATION_MS" in
    ''|*[!0-9]*) : ;;
    *)           duration_ms="$HARNESS_DURATION_MS" ;;
  esac
fi

if [ -n "$TOOL_USE_ID" ] && [ -f "$IN_FLIGHT_DIR/${TOOL_USE_ID}.t" ]; then
  mark="$(cat "$IN_FLIGHT_DIR/${TOOL_USE_ID}.t" 2>/dev/null || true)"
  if [ -n "$mark" ]; then
    started_at="$mark"
    # Only fall back to date diff when the harness didn't supply duration.
    if [ "$duration_ms" = "null" ] && command -v date >/dev/null 2>&1; then
      start_epoch="$(date -u -d "$started_at" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$started_at" +%s 2>/dev/null || true)"
      end_epoch="$(date -u -d "$ended_at" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ended_at" +%s 2>/dev/null || true)"
      if [ -n "$start_epoch" ] && [ -n "$end_epoch" ]; then
        duration_ms=$(( (end_epoch - start_epoch) * 1000 ))
      fi
    fi
  fi
  rm -f "$IN_FLIGHT_DIR/${TOOL_USE_ID}.t" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Phase 5: Clamp stdout / stderr to 4 KB head + 4 KB tail
# ---------------------------------------------------------------------------
clamp_stream() {
  local raw="$1"
  local len=${#raw}
  if [ "$len" -le 8192 ]; then
    printf '%s' "$raw"
    printf '\0'
    printf ''
    printf '\0'
    printf 'false'
    return
  fi
  # head: first 4096 chars, tail: last 4096 chars
  local head_part="${raw:0:4096}"
  local tail_part="${raw: -4096}"
  printf '%s' "$head_part"
  printf '\0'
  printf '%s' "$tail_part"
  printf '\0'
  printf 'true'
}

# Use jq directly with --rawfile-equivalent via --arg for the clamping.
stdout_len=${#STDOUT_RAW}
stderr_len=${#STDERR_RAW}

if [ "$stdout_len" -le 8192 ]; then
  stdout_head="$STDOUT_RAW"
  stdout_tail=""
  stdout_truncated="false"
else
  stdout_head="${STDOUT_RAW:0:4096}"
  stdout_tail="${STDOUT_RAW: -4096}"
  stdout_truncated="true"
fi

if [ "$stderr_len" -le 8192 ]; then
  stderr_head="$STDERR_RAW"
  stderr_tail=""
  stderr_truncated="false"
else
  stderr_head="${STDERR_RAW:0:4096}"
  stderr_tail="${STDERR_RAW: -4096}"
  stderr_truncated="true"
fi

# ---------------------------------------------------------------------------
# Phase 6: Write last-run.json atomically
# ---------------------------------------------------------------------------
mkdir -p "$STATE_DIR" 2>/dev/null || { debug "could not create state dir"; exit 0; }

# Probe writability before invoking mktemp.
if ! ( : >>"$STATE_DIR/.writetest" ) 2>/dev/null; then
  debug "state dir not writeable — capture skipped"
  exit 0
fi
rm -f "$STATE_DIR/.writetest" 2>/dev/null || true

# Build JSON payload with jq for safe escaping.
session_id_json="null"
[ -n "$SESSION_ID" ] && session_id_json="$(printf '%s' "$SESSION_ID" | jq -R -s -c 'rtrimstr("\n")')"

agent_id_json="null"
[ -n "$AGENT_ID" ] && agent_id_json="$(printf '%s' "$AGENT_ID" | jq -R -s -c 'rtrimstr("\n")')"

exit_json="null"
case "$EXIT_CODE" in
  ''|*[!0-9-]*) exit_json="null" ;;
  *)            exit_json="$EXIT_CODE" ;;
esac

interrupted_json="false"
[ "$INTERRUPTED" = "true" ] && interrupted_json="true"

payload="$(jq -n \
  --arg command "$COMMAND" \
  --arg detector "$detector" \
  --argjson exit "$exit_json" \
  --argjson interrupted "$interrupted_json" \
  --arg inferred_status "$inferred_status" \
  --arg inference_basis "$inference_basis" \
  --arg started_at "$started_at" \
  --arg ended_at "$ended_at" \
  --argjson duration_ms "$duration_ms" \
  --argjson session_id "$session_id_json" \
  --argjson agent_id "$agent_id_json" \
  --arg stdout_head "$stdout_head" \
  --arg stdout_tail "$stdout_tail" \
  --argjson stdout_truncated "$stdout_truncated" \
  --arg stderr_head "$stderr_head" \
  --arg stderr_tail "$stderr_tail" \
  --argjson stderr_truncated "$stderr_truncated" \
  '{
    command: $command,
    detector: $detector,
    exit: $exit,
    interrupted: $interrupted,
    inferred_status: $inferred_status,
    inference_basis: $inference_basis,
    started_at: $started_at,
    ended_at: $ended_at,
    duration_ms: $duration_ms,
    session_id: $session_id,
    agent_id: $agent_id,
    stdout_head: $stdout_head,
    stdout_tail: $stdout_tail,
    stdout_truncated: $stdout_truncated,
    stderr_head: $stderr_head,
    stderr_tail: $stderr_tail,
    stderr_truncated: $stderr_truncated
  }' 2>/dev/null || true)"

[ -z "$payload" ] && { debug "jq payload build failed"; exit 0; }

tmpfile="$(mktemp "$STATE_DIR/last-run.XXXXXX.json" 2>/dev/null || true)"
if [ -z "$tmpfile" ]; then
  debug "mktemp failed in state dir"
  exit 0
fi

printf '%s\n' "$payload" > "$tmpfile" 2>/dev/null || {
  rm -f "$tmpfile" 2>/dev/null || true
  debug "write to tmpfile failed"
  exit 0
}

mv -f "$tmpfile" "$STATE_DIR/last-run.json" 2>/dev/null || {
  rm -f "$tmpfile" 2>/dev/null || true
  debug "atomic rename failed"
  exit 0
}

debug "wrote snapshot: $detector exit=$exit_json"
exit 0
