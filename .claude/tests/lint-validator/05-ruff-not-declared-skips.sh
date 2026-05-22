#!/usr/bin/env bash
# .claude/tests/lint-validator/05-ruff-not-declared-skips.sh
# Spec 013 V5 — Scenario: Python project without ruff in manifests → silent skip.
#
# Asserts:
#   (a) JSON .command does NOT include 'ruff'
#   (b) no lint-advisory in stderr

set -euo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
VALIDATOR="$AGENT0_ROOT/.claude/validators/run.sh"

TMPDIR="$(mktemp -d -t spec-013-V5-XXXXXX)"
stderr_file="$(mktemp)"
trap 'rm -rf "$TMPDIR" "$stderr_file"' EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/python" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMPDIR/bin/python"

cat > "$TMPDIR/pyproject.toml" <<'EOF'
[project]
name = "test"
dependencies = ["requests"]
EOF
# requirements.txt also without ruff
cat > "$TMPDIR/requirements.txt" <<'EOF'
requests==2.31.0
pytest==7.4.0
EOF

cd "$TMPDIR"
stdout="$(PATH="$TMPDIR/bin:$PATH" bash "$VALIDATOR" 2>"$stderr_file")"

cmd="$(printf '%s' "$stdout" | jq -r '.command' 2>/dev/null || true)"
if echo "$cmd" | grep -q 'ruff'; then
  printf 'FAIL: command unexpectedly mentions ruff\n  got: %s\n' "$cmd"
  exit 1
fi

if grep -q 'lint-advisory' "$stderr_file"; then
  printf 'FAIL: stderr unexpectedly contains lint-advisory: %s\n' "$(cat "$stderr_file")"
  exit 1
fi

printf 'PASS\n'
exit 0
