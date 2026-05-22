#!/usr/bin/env bash
# validate.sh — agentskills.io frontmatter validator (Agent0 spec 033)
#
# Zero-dep bash. Defers to `skills-ref validate` when on PATH.
# Implements the hard rules from `../references/frontmatter-validation-rules.md`.
#
# Usage:
#   validate.sh <skill-dir-or-SKILL.md>
#
# Exit codes:
#   0  — every hard rule passed (soft warnings may be on stderr)
#   1  — at least one hard rule failed (stderr lists each violation by rule ID)
#   2  — usage / argument error
#
# When `skills-ref` is on PATH this script `exec`s into it — its output and
# exit code become ours verbatim (defer-to-canonical pattern). The bash rules
# below are the zero-dep fallback.

set -u

usage() {
  echo "usage: $0 <skill-dir-or-SKILL.md>" >&2
  exit 2
}

[ $# -eq 1 ] || usage

target="$1"

# Resolve to skill_dir + skill_md
if [ -d "$target" ]; then
  skill_dir="$target"
  skill_md="$target/SKILL.md"
elif [ -f "$target" ] && [ "$(basename "$target")" = "SKILL.md" ]; then
  skill_md="$target"
  skill_dir="$(dirname "$target")"
else
  echo "validate: argument must be a skill directory or a SKILL.md path; got: $target" >&2
  exit 2
fi

# Defer-to-canonical: skills-ref wins when present
if command -v skills-ref >/dev/null 2>&1; then
  exec skills-ref validate "$skill_dir"
fi

# ── Rule 1 — file present and opens with '---' ───────────────────────────────
if [ ! -f "$skill_md" ]; then
  echo "rule1-frontmatter: SKILL.md missing at $skill_md" >&2
  exit 1
fi

first_line="$(head -n1 "$skill_md" 2>/dev/null || true)"
if [ "$first_line" != "---" ]; then
  echo "rule1-frontmatter: SKILL.md missing, empty, or not opened with '---'" >&2
  exit 1
fi

# Locate closing '---' on lines 2..200
close_line="$(awk 'NR>=2 && NR<=200 && /^---$/ {print NR; exit}' "$skill_md")"
if [ -z "$close_line" ]; then
  echo "rule6-frontmatter-runaway: closing '---' not found before line 200; check YAML syntax" >&2
  exit 1
fi

# Extract frontmatter region (lines 2..close_line-1) into a variable
frontmatter="$(sed -n "2,$((close_line - 1))p" "$skill_md")"

# Simple top-level key extractor — single-line scalar values only (v1 limitation)
# Returns first match of "^key: <value>"; trims trailing whitespace and surrounding quotes.
get_field() {
  local key="$1"
  local raw
  raw="$(printf '%s\n' "$frontmatter" | sed -n "s|^${key}:[[:space:]]*\(.*\)$|\1|p" | head -n1)"
  # Trim trailing whitespace
  raw="${raw%"${raw##*[![:space:]]}"}"
  # Strip surrounding double-quotes
  if [ "${raw#\"}" != "$raw" ] && [ "${raw%\"}" != "$raw" ]; then
    raw="${raw#\"}"; raw="${raw%\"}"
  fi
  # Strip surrounding single-quotes
  if [ "${raw#\'}" != "$raw" ] && [ "${raw%\'}" != "$raw" ]; then
    raw="${raw#\'}"; raw="${raw%\'}"
  fi
  printf '%s' "$raw"
}

fail=0

# ── Rule 2 — name field present + length + regex ─────────────────────────────
name_val="$(get_field name)"
if [ -z "$name_val" ]; then
  echo "rule2-name-missing: required field 'name' absent from frontmatter" >&2
  fail=1
else
  name_len=${#name_val}
  if [ "$name_len" -lt 1 ] || [ "$name_len" -gt 64 ]; then
    echo "rule2-name-length: 'name' is $name_len chars; must be 1-64" >&2
    fail=1
  fi
  if ! printf '%s' "$name_val" | grep -Eq '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
    echo "rule2-name-regex: 'name' must match ^[a-z][a-z0-9]*(-[a-z0-9]+)*\$; got: '$name_val'" >&2
    fail=1
  fi
fi

# ── Rule 3 — name matches parent directory ───────────────────────────────────
dir_basename="$(basename "$(realpath "$skill_dir" 2>/dev/null || echo "$skill_dir")")"
if [ -n "$name_val" ] && [ "$name_val" != "$dir_basename" ]; then
  echo "rule3-name-dirname-mismatch: name '$name_val' does not match parent directory '$dir_basename'" >&2
  fail=1
fi

# ── Rule 4 — description present + length ────────────────────────────────────
desc_val="$(get_field description)"
if [ -z "$desc_val" ]; then
  echo "rule4-description-missing: required field 'description' absent from frontmatter" >&2
  fail=1
else
  desc_len=${#desc_val}
  if [ "$desc_len" -lt 1 ]; then
    echo "rule4-description-empty: 'description' is empty" >&2
    fail=1
  elif [ "$desc_len" -gt 1024 ]; then
    echo "rule4-description-length: 'description' is $desc_len chars; must be 1-1024" >&2
    fail=1
  fi
fi

# ── Rule 5 — compatibility (if present) length ───────────────────────────────
compat_val="$(get_field compatibility)"
if [ -n "$compat_val" ]; then
  compat_len=${#compat_val}
  if [ "$compat_len" -gt 500 ]; then
    echo "rule5-compatibility-length: 'compatibility' is $compat_len chars; must be 1-500" >&2
    fail=1
  fi
fi

# ── Rule 7 — body line count (SOFT warning, does not flip exit) ──────────────
# Note: variable name 'cl' (not 'close') — `close` is a reserved gawk builtin.
body_lines="$(awk -v cl="$close_line" 'NR > cl {n++} END {print n+0}' "$skill_md")"
if [ "$body_lines" -gt 500 ]; then
  echo "rule7-body-warn: body is $body_lines lines; recommended max is 500 (consider moving detail to references/)" >&2
fi

# ── Rule 8 — body token estimate (SOFT warning) ──────────────────────────────
body_bytes="$(awk -v cl="$close_line" 'NR > cl {n += length($0) + 1} END {print n+0}' "$skill_md")"
body_tokens=$(( body_bytes / 4 ))
if [ "$body_tokens" -gt 5000 ]; then
  echo "rule8-body-token-warn: body is ~${body_tokens} estimated tokens; recommended max is 5000" >&2
fi

exit "$fail"
