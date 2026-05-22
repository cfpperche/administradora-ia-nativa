#!/usr/bin/env bash
# .claude/tests/lint-validator/04-ruff-declared-installed-runs.sh
# Spec 013 V4 — Scenario: ruff declared in pyproject.toml + installed → runs.
#
# Asserts:
#   (a) JSON .command includes 'ruff check .'
#   (b) JSON .ok == true (mock python+ruff succeed)
#   (c) no lint-advisory in stderr

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-013-V4-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

mkdir -p "$TMPDIR/bin"
# python shim: handles -m pytest, -m mypy, -m ruff --version, -m ruff check (all exit 0)
cat > "$TMPDIR/bin/python" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/python"

# pyproject.toml (PEP 621 shape) declaring ruff as a dev dep
cat > "$TMPDIR/pyproject.toml" <<'EOF'
[project]
name = "test"

[project.optional-dependencies]
dev = ["ruff>=0.1.0"]
EOF

cd "$TMPDIR"
stdout="$(PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" 2>"$stderr_file")"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if ! echo "$cmd" | grep -qE 'python -m ruff check \.'; then
  printf 'FAIL: command does not include "python -m ruff check ."\n  got: %s\n' "$cmd"
  printf '  stderr: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

ok="$(printf '%s' "$stdout" | jq -r '.ok' 2>/dev/null || true)"
if [ "$ok" != "true" ]; then
  printf 'FAIL: ok != true (got %s)\n  stdout: %s\n  stderr: %s\n' "$ok" "$stdout" "$(cat "$stderr_file")"
  exit 1
fi

if grep -q 'lint-advisory' "$stderr_file"; then
  printf 'FAIL: stderr unexpectedly contains lint-advisory: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

printf 'PASS\n'
exit 0
