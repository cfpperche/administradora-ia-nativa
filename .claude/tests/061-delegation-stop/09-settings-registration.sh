#!/usr/bin/env bash
# .claude/tests/061-delegation-stop/09-settings-registration.sh
# Spec 061 — .claude/settings.json registers the SubagentStop hook.
#
# Asserts the settings file round-trips through jq (valid JSON after the edit)
# and that a SubagentStop hook command pointing at delegation-stop.sh exists.
set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SETTINGS="$AGENT0_ROOT/.claude/settings.json"

[ -f "$SETTINGS" ] || { printf 'FAIL: %s not found\n' "$SETTINGS"; exit 1; }

if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  printf 'FAIL: settings.json is not valid JSON\n'
  exit 1
fi

if ! jq -e '
  [ .hooks.SubagentStop[]?.hooks[]?.command ]
  | any(. != null and contains("delegation-stop.sh"))
' "$SETTINGS" >/dev/null 2>&1; then
  printf 'FAIL: no SubagentStop hook registered for delegation-stop.sh\n'
  exit 1
fi

printf 'PASS: %s\n' "$(basename "$0")"
