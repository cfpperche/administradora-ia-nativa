#!/usr/bin/env bash
# .claude/tests/runtime-introspect/12-settings-registration.sh
# V12 — Scenario: settings.json registers runtime-capture.sh on
#       PostToolUseFailure(Bash) (spec 020).
#
# Static-fact verification. Reads .claude/settings.json and asserts:
#   (a) hooks.PostToolUseFailure exists and is an array
#   (b) at least one entry has matcher == "Bash"
#   (c) at least one of those entries' hooks[].command references
#       runtime-capture.sh
#
# This test is the canonical RED→GREEN flip for spec 020. Test 11
# already passes pre-020 because the hook is event-agnostic when invoked
# directly; the registration that makes it fire on production failures
# lives only in settings.json.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SETTINGS="$AGENT0_ROOT/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  printf 'FAIL: settings.json not found at %s\n' "$SETTINGS"
  exit 1
fi

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  printf 'FAIL: settings.json is not valid JSON\n'
  exit 1
fi

# (a) hooks.PostToolUseFailure exists and is an array.
if [ "$(jq -r '.hooks.PostToolUseFailure | type' "$SETTINGS")" != "array" ]; then
  printf 'FAIL: .hooks.PostToolUseFailure not present or not an array\n'
  exit 1
fi

# (b) at least one entry has matcher == "Bash".
if [ "$(jq -r '[.hooks.PostToolUseFailure[]? | select(.matcher == "Bash")] | length' "$SETTINGS")" -lt 1 ]; then
  printf 'FAIL: no .hooks.PostToolUseFailure entry with matcher=="Bash"\n'
  exit 1
fi

# (c) at least one Bash entry references runtime-capture.sh in its command.
match_count="$(jq -r '
  [.hooks.PostToolUseFailure[]?
    | select(.matcher == "Bash")
    | .hooks[]?
    | select(.command | test("runtime-capture\\.sh"))]
  | length' "$SETTINGS")"

if [ "$match_count" -lt 1 ]; then
  printf 'FAIL: no PostToolUseFailure(Bash) entry references runtime-capture.sh\n'
  exit 1
fi

printf 'PASS\n'
exit 0
