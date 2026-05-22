#!/usr/bin/env bash
# .claude/tests/supply-chain/12-cargo-install-coverage.sh
# V12 — Scenario: `cargo install <bin>` is detected as a supply-chain action.
#
# Surfaced by the rshrnk live-dogfood pass (2026-05-11): `cargo install
# ripgrep` ran without a block because the cargo verb whitelist only covered
# `add` and `update`. Asymmetric with npm/pip/yarn/bun/pnpm whose `install`
# verb IS detected (e.g. `npm install -g foo` blocks). `cargo install` pulls
# third-party code from crates.io and runs build scripts during compilation,
# so it warrants the same gate.
#
# Asserts under default (block) mode:
#   (a) hook exits 2 — block fires
#   (b) stderr opens with `supply-chain-block: cargo install detected — packages: ripgrep`
#   (c) stderr ends with the verbatim corrected form including the OVERRIDE
#       marker placeholder
#   (d) audit row: decision="block", manager="cargo", action="install",
#       packages=["ripgrep"], override_reason=null

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOOK="$AGENT0_ROOT/.claude/hooks/supply-chain-scan.sh"

TMPDIR="$(mktemp -d -t spec-009-V12-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/.claude"
export CLAUDE_PROJECT_DIR="$TMPDIR"
unset CLAUDE_SUPPLY_CHAIN_BLOCK 2>/dev/null || true

stdin_json="$(jq -cn '{tool_input:{command:"cargo install ripgrep"}, session_id:"V12-session"}')"

stderr_file="$TMPDIR/stderr.txt"
hook_exit=0
printf '%s' "$stdin_json" | bash "$HOOK" 2>"$stderr_file" || hook_exit=$?

# (a) exit 2
if [ "$hook_exit" -ne 2 ]; then
  printf 'FAIL: hook exit=%d, want 2\n' "$hook_exit"
  printf 'Stderr was:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (b) stderr opens with the block-template lead line
if ! grep -q "^supply-chain-block: cargo install detected — packages: ripgrep$" "$stderr_file"; then
  printf 'FAIL: stderr missing expected block-template lead line\n'
  printf 'Got stderr:\n%s\n' "$(cat "$stderr_file")"
  exit 1
fi

# (c) stderr ends with the corrected form (cmd + override placeholder)
last_two="$(grep -v '^$' "$stderr_file" | tail -2)"
expected_cmd_line='cargo install ripgrep'
expected_override_line='# OVERRIDE: <reason ≥10 chars — why this dep is being added>'

if ! printf '%s\n' "$last_two" | grep -qE "^[[:space:]]*${expected_cmd_line}\$"; then
  printf 'FAIL: stderr does not end with original command line\n'
  printf 'Expected (trimmed): %s\n' "$expected_cmd_line"
  printf 'Got last two lines:\n%s\n' "$last_two"
  exit 1
fi
if ! printf '%s\n' "$last_two" | grep -qF "$expected_override_line"; then
  printf 'FAIL: stderr does not end with override-marker placeholder\n'
  printf 'Expected (substring): %s\n' "$expected_override_line"
  printf 'Got last two lines:\n%s\n' "$last_two"
  exit 1
fi

# (d) audit row shape
audit_log="$TMPDIR/.claude/supply-chain-audit.jsonl"
if [ ! -f "$audit_log" ]; then
  printf 'FAIL: audit log not created\n'
  exit 1
fi

line_count=$(wc -l < "$audit_log")
if [ "$line_count" -ne 1 ]; then
  printf 'FAIL: audit log has %d lines, want 1\n' "$line_count"
  cat "$audit_log"
  exit 1
fi

row=$(cat "$audit_log")
for check in \
  '.decision == "block"' \
  '.scope == "bash"' \
  '.manager == "cargo"' \
  '.action == "install"' \
  '.packages == ["ripgrep"]' \
  '.override_reason == null'; do
  if [ "$(printf '%s' "$row" | jq -r "$check")" != "true" ]; then
    printf 'FAIL: audit row failed assertion: %s\n' "$check"
    printf 'Row: %s\n' "$row"
    exit 1
  fi
done

printf 'PASS\n'
exit 0
