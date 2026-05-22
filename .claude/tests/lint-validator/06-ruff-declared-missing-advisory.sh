#!/usr/bin/env bash
# .claude/tests/lint-validator/06-ruff-declared-missing-advisory.sh
# Spec 013 V6 — Scenario: ruff declared but binary missing → advisory, no block.
#
# Sub-cases cover 2+ python managers (pip-default + poetry) since each yields
# a different install command. The validator detects manager via lockfile
# presence + `command -v <mgr>`.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

run_case() {
  local label="$1" lockfile="$2" mgr_bin="$3" expected_install_cmd="$4" expected_manifest="$5"

  local TMPDIR
  TMPDIR="$(mktemp -d -t "spec-013-V6-${label}-XXXXXX")"
  local stderr_file
  stderr_file="$(mktemp)"

  mkdir -p "$TMPDIR/bin"

  # python shim — fails on `-m ruff --version` (and `-m ruff check`), passes other
  cat > "$TMPDIR/bin/python" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"-m ruff --version"*) exit 1 ;;
  *"-m ruff check"*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$TMPDIR/bin/python"

  # Manager binary shim: forwards `<mgr> run python ...` to the python shim.
  # Required so the validator's `command -v <mgr>` succeeds AND the inner
  # `<mgr> run python -m pytest` actually runs (otherwise ok=false).
  if [ -n "$mgr_bin" ]; then
    cat > "$TMPDIR/bin/$mgr_bin" <<EOF
#!/usr/bin/env bash
# Forward 'run python ...' to bare python; otherwise exit 0.
if [ "\$1" = "run" ] && [ "\$2" = "python" ]; then
  shift 2
  exec "$TMPDIR/bin/python" "\$@"
fi
exit 0
EOF
    chmod +x "$TMPDIR/bin/$mgr_bin"
  fi

  if [ -n "$lockfile" ]; then
    touch "$TMPDIR/$lockfile"
  fi

  if [ "$expected_manifest" = "pyproject.toml" ]; then
    cat > "$TMPDIR/pyproject.toml" <<'EOF'
[tool.poetry.dev-dependencies]
ruff = "^0.1.0"
EOF
  else
    # requirements.txt path
    cat > "$TMPDIR/requirements.txt" <<'EOF'
requests==2.31.0
ruff>=0.1.0
EOF
  fi

  ( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true
  local stdout
  stdout="$(cat "$TMPDIR/out.json")"

  local cmd ok
  cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
  ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"

  # (a) command MUST NOT include ruff (skipped because not installed)
  if echo "$cmd" | grep -q 'ruff'; then
    printf 'FAIL[%s]: command unexpectedly includes ruff: %s\n' "$label" "$cmd"
    rm -rf "$TMPDIR" "$stderr_file"
    exit 1
  fi

  # (b) ok=true (test+mypy shims pass; lint advisory does not block)
  if [ "$ok" != "true" ]; then
    printf 'FAIL[%s]: ok != true (got %s)\n  stdout: %s\n  stderr: %s\n' \
      "$label" "$ok" "$stdout" "$(cat "$stderr_file")"
    rm -rf "$TMPDIR" "$stderr_file"
    exit 1
  fi

  # (c) advisory line with manager-specific install cmd
  local expected="lint-advisory: ruff declared in ${expected_manifest} but not installed — run \`${expected_install_cmd}\`"
  if ! grep -qF "$expected" "$stderr_file"; then
    printf 'FAIL[%s]: stderr missing expected advisory.\n  expected: %s\n  got stderr: %s\n' \
      "$label" "$expected" "$(cat "$stderr_file")"
    rm -rf "$TMPDIR" "$stderr_file"
    exit 1
  fi

  rm -rf "$TMPDIR" "$stderr_file"
}

# Case A: no lockfile → default `pip install ruff`. Manifest: pyproject.toml.
run_case "pip-default" "" "" "pip install ruff" "pyproject.toml"

# Case B: poetry.lock + poetry binary → `poetry install`.
run_case "poetry" "poetry.lock" "poetry" "poetry install" "pyproject.toml"

# Case C: requirements.txt path (no pyproject.toml) → `pip install ruff`,
# manifest in advisory must be requirements.txt.
run_case "pip-requirements" "" "" "pip install ruff" "requirements.txt"

printf 'PASS\n'
exit 0
