#!/usr/bin/env bash
# .claude/tests/lint-validator/03-biome-declared-missing-advisory.sh
# Spec 013 V3 — Scenario: biome declared but not installed → advisory, no block.
#
# Sub-cases cover all 3 JS managers (bun/pnpm/npm) since each yields a
# different install command in the advisory text.

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

run_case() {
  local label="$1" stack_marker="$2" expected_install_cmd="$3" runner="$4"

  local TMPDIR
  TMPDIR="$(mktemp -d -t "spec-013-V3-${label}-XXXXXX")"
  local stderr_file
  stderr_file="$(mktemp)"

  mkdir -p "$TMPDIR/bin"
  # Provide whichever runner the manager uses for `<runner> test/typecheck`
  cat > "$TMPDIR/bin/$runner" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TMPDIR/bin/$runner"

  # Stack marker
  case "$stack_marker" in
    bun.lock|bun.lockb|bunfig.toml) touch "$TMPDIR/$stack_marker" ;;
    pnpm-lock.yaml) touch "$TMPDIR/pnpm-lock.yaml" ;;
    package-lock.json) touch "$TMPDIR/package-lock.json" ;;
    package.json-only) : ;;  # no lockfile, only package.json (npm fallback path)
  esac

  echo '{}' > "$TMPDIR/tsconfig.json"
  cat > "$TMPDIR/package.json" <<'EOF'
{"name":"test","devDependencies":{"@biomejs/biome":"^1.0.0"}}
EOF
  # NO node_modules/@biomejs/biome — declared+missing state

  ( cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" >"$TMPDIR/out.json" 2>"$stderr_file" ) || true
  local stdout
  stdout="$(cat "$TMPDIR/out.json")"

  local cmd ok
  cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
  ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"

  # (a) command MUST NOT include biome (skipped because not installed)
  if echo "$cmd" | grep -q 'biome'; then
    printf 'FAIL[%s]: command unexpectedly includes biome: %s\n' "$label" "$cmd"
    rm -rf "$TMPDIR" "$stderr_file"
    exit 1
  fi

  # (b) ok=true since test+tsc shims pass and lint is skipped (advisory only)
  if [ "$ok" != "true" ]; then
    printf 'FAIL[%s]: ok != true (got %s)\n  stdout: %s\n  stderr: %s\n' \
      "$label" "$ok" "$stdout" "$(cat "$stderr_file")"
    rm -rf "$TMPDIR" "$stderr_file"
    exit 1
  fi

  # (c) stderr advisory line with manager-specific install cmd
  local expected="lint-advisory: biome declared in package.json but not installed — run \`${expected_install_cmd}\`"
  if ! grep -qF "$expected" "$stderr_file"; then
    printf 'FAIL[%s]: stderr missing expected advisory.\n  expected: %s\n  got stderr: %s\n' \
      "$label" "$expected" "$(cat "$stderr_file")"
    rm -rf "$TMPDIR" "$stderr_file"
    exit 1
  fi

  rm -rf "$TMPDIR" "$stderr_file"
}

run_case "bun"  "bun.lock"         "bun install"  "bun"
run_case "pnpm" "pnpm-lock.yaml"   "pnpm install" "pnpm"
run_case "npm"  "package-lock.json" "npm install" "npm"

printf 'PASS\n'
exit 0
