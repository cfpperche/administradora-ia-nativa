#!/usr/bin/env bash
# validate.test.sh — fixture harness for ../scripts/validate.sh
#
# Iterates every fixture directory under tests/fixtures/, runs the validator,
# compares actual exit code against the fixture's EXPECTED file. Exits 0 iff
# every fixture's actual outcome matches expectation.

set -u

# Resolve script dir → spec 033 skill dir → fixtures dir + validator path
here="$(cd "$(dirname "$0")" && pwd)"
skill_root="$(dirname "$here")"
fixtures_dir="$here/fixtures"
validator="$skill_root/scripts/validate.sh"

if [ ! -d "$fixtures_dir" ]; then
  echo "error: fixtures dir not found at $fixtures_dir" >&2
  exit 2
fi

if [ ! -x "$validator" ]; then
  echo "error: validator not executable at $validator" >&2
  exit 2
fi

pass=0
fail=0
failures=()

for fixture in "$fixtures_dir"/*/; do
  fixture="${fixture%/}"  # trim trailing slash
  name="$(basename "$fixture")"
  expected_file="$fixture/EXPECTED"

  if [ ! -f "$expected_file" ]; then
    echo "skip: $name (no EXPECTED file)" >&2
    continue
  fi

  expected_exit="$(sed -n 's/^EXIT=\([0-9]\+\)$/\1/p' "$expected_file" | head -n1)"
  if [ -z "$expected_exit" ]; then
    echo "skip: $name (EXPECTED has no EXIT=N line)" >&2
    continue
  fi

  # Run validator, suppress stderr in summary (the validator prints it; the harness
  # only cares about exit code in v1)
  set +e
  "$validator" "$fixture" >/dev/null 2>/dev/null
  actual_exit=$?
  set -e

  if [ "$actual_exit" = "$expected_exit" ]; then
    printf '  ✓ %-28s exit=%d\n' "$name" "$actual_exit"
    pass=$((pass + 1))
  else
    printf '  ✗ %-28s expected=%s actual=%d\n' "$name" "$expected_exit" "$actual_exit"
    fail=$((fail + 1))
    failures+=("$name")
  fi
done

total=$((pass + fail))
echo
echo "summary: $pass / $total passed"

if [ "$fail" -gt 0 ]; then
  echo "failed fixtures: ${failures[*]}" >&2
  exit 1
fi

exit 0
