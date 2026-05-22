#!/usr/bin/env bash
# .claude/tests/supply-chain/07-tokenizer-shape.sh
# V7 — Scenario: tokenizer stops package collection at shell separators and
# at known value-taking flags (so the `packages` field stays clean).
#
# Surfaced by the live-dogfood pass against /home/goat/pyshrnk (2026-05-11):
# `uv add requests --directory /home/goat/pyshrnk 2>&1 | tail -20` captured
# `["requests","/home/goat/pyshrnk","2>&1","|","tail"]`. After the fix:
# only `["requests"]`.
#
# Sub-cases:
#   (a) shell-separator stop: pipe / redirect / background terminate collection
#   (b) value-taking flag skip: --directory/--prefix/--manifest-path etc. eat
#       their value so paths don't leak into packages
#   (c) regression guard: `pip install -r requirements.txt` still fires (the
#       requirements-file path captured as a "package" is documented behaviour;
#       removing detection entirely would lose the supply-chain signal)
#   (d) regression guard: `cargo update --package tokio` keeps `tokio` as the
#       package (the value of --package IS the package)
#   (e) cargo --features / -F values are NOT packages (feature names, not
#       supply-chain signal) — added after the rshrnk live-dogfood pass
#       (2026-05-11) surfaced `cargo add tokio --features full` capturing
#       `["tokio","full"]`. Symmetric short form `-F derive` covered too.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-008-V7-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
export CLAUDE_SUPPLY_CHAIN_BLOCK=0  # spec 009: pin advisory mode under block-by-default default

run_case() {
  local label="$1"
  local cmd="$2"
  local want_packages_json="$3"  # JSON array literal
  local want_manager="$4"
  local want_action="$5"
  local stdin_json stderr_file hook_exit row

  stdin_json="$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}, session_id:"V7-session"}')"
  stderr_file="$TMPDIR/stderr.txt"
  : > "$stderr_file"

  hook_exit=0
  printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

  if [ "$hook_exit" -ne 0 ]; then
    printf 'FAIL [%s]: hook exit=%d, want 0\n' "$label" "$hook_exit"
    exit 1
  fi

  row="$(tail -1 "$TMPDIR/.claude/supply-chain-audit.jsonl")"
  for check in \
    ".decision == \"advisory\"" \
    ".manager == \"$want_manager\"" \
    ".action == \"$want_action\"" \
    ".packages == $want_packages_json"; do
    if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
      printf 'FAIL [%s]: audit assertion: %s\n' "$label" "$check"
      printf 'Row: %s\n' "$row"
      exit 1
    fi
  done
}

# (a) Shell separators terminate collection.
run_case "uv add with pipe and redirect" \
  "uv add requests --directory /home/goat/pyshrnk 2>&1 | tail -20" \
  '["requests"]' "uv" "add"

run_case "npm install with stdout redirect" \
  "npm install axios > /tmp/install.log" \
  '["axios"]' "npm" "install"

run_case "npm install backgrounded" \
  "npm install axios &" \
  '["axios"]' "npm" "install"

# (b) Value-taking flag values are skipped.
run_case "cargo add with --manifest-path" \
  "cargo add tokio --manifest-path /workspace/sub/Cargo.toml" \
  '["tokio"]' "cargo" "add"

run_case "pip install with --target" \
  "pip install requests --target /opt/site-packages" \
  '["requests"]' "pip" "install"

# (c) Regression guard: pip install -r requirements.txt still fires.
# `-r` is INTENTIONALLY not in the value-taking list — its value (the
# requirements file path) IS the supply-chain signal we want to surface.
run_case "pip install -r requirements.txt still fires" \
  "pip install -r requirements.txt" \
  '["requirements.txt"]' "pip" "install"

# (d) Regression guard: cargo update --package tokio keeps tokio as package.
# `--package`/`-p` is INTENTIONALLY not in the value-taking list — its value
# IS the package name being acted on.
run_case "cargo update --package keeps the package name" \
  "cargo update --package tokio" \
  '["tokio"]' "cargo" "update"

# (e) --features / -F values are feature names, NOT packages or supply-chain
# signal. The flag IS value-taking; both forms should skip their value.
run_case "cargo add with --features (long form)" \
  "cargo add tokio --features full --manifest-path /workspace/sub/Cargo.toml" \
  '["tokio"]' "cargo" "add"

run_case "cargo add with -F (short form)" \
  "cargo add serde -F derive" \
  '["serde"]' "cargo" "add"

printf 'PASS\n'
exit 0
