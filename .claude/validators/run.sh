#!/usr/bin/env bash
# .claude/validators/run.sh
# Stack auto-detect validator. Emits one JSON object on stdout per the
# documented contract (docs/specs/002-delegation/plan.md § "Validator JSON contract"
# extended by docs/specs/005-tdd/plan.md § "Validator JSON contract — additive change").
#
# Detect order (first match wins): bun → pnpm → npm → python → go → rust.
# When no marker is found, emits the no-stack-detected fallback (ok=true) so
# the consuming hook fails open.
#
# bash 3.2-compatible: no associative arrays, no mapfile.

set -uo pipefail

emit_no_stack() {
  printf '{"ok":true,"command":"no-stack-detected","exit":0,"duration_ms":0,"stdout":"","stderr":""}\n'
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  emit_no_stack
fi

command_str=""
stack=""
stack_subtype=""
typecheck_advisory_msg=""

# Manifest-as-intent typecheck dispatch (mirrors spec 013 lint-validator):
#   (a) tsconfig.json exists                 → use direct tsc invocation
#   (b) package.json `.scripts.typecheck`    → use `<runner> run typecheck`
#   (c) neither                              → omit typecheck step + advisory
# State (c) replaces the pre-fix hard-failure path where `<runner> run typecheck`
# always landed in the pipeline, breaking validators on early-stage forks
# without typecheck infrastructure (surfaced by shrnk-mono dogfood 2026-05-12).
has_typecheck_script() {
  [ -f "package.json" ] && jq -e '.scripts.typecheck // empty' package.json >/dev/null 2>&1
}

# Laravel canonical check — runs BEFORE the JS branch because Laravel 11+
# ships package.json (Vite frontend) by default, which would otherwise hijack
# detection. When BOTH `artisan` and `composer.json` declaring `laravel/framework`
# are present, the project IS a Laravel app; PHP test runner is the primary.
# Pure-PHP projects (no Laravel) still hit the late `composer.json` elif below.
# Surfaced via Acme Yard dogfood 2026-05-18: vanilla `composer create-project
# laravel/laravel` includes package.json + composer.json; pre-fix routed to npm
# and `package.json scripts.test` missing → exit 1.
if [ -f "artisan" ] && [ -f "composer.json" ] && jq -e '(.require["laravel/framework"] // .["require-dev"]["laravel/framework"]) // empty' composer.json >/dev/null 2>&1; then
  stack="php"
  if jq -e '(.["require-dev"]["pestphp/pest"] // .require["pestphp/pest"]) // empty' composer.json >/dev/null 2>&1; then
    command_str='vendor/bin/pest --colors=never'
  else
    command_str='vendor/bin/phpunit --colors=never'
  fi
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ] || [ -f "bunfig.toml" ]; then
  stack="js"
  stack_subtype="bun"
  if [ -f "tsconfig.json" ]; then
    command_str='bun test && bun tsc --noEmit'
  elif has_typecheck_script; then
    command_str='bun test && bun run typecheck'
  else
    command_str='bun test'
    typecheck_advisory_msg="typecheck-advisory: no tsconfig.json or 'typecheck' script in package.json — typecheck step skipped (add a tsconfig.json or declare \`bun run typecheck\` to enable)"
  fi
elif [ -f "pnpm-lock.yaml" ]; then
  stack="js"
  stack_subtype="pnpm"
  if [ -f "tsconfig.json" ]; then
    command_str='pnpm test && pnpm tsc --noEmit'
  elif has_typecheck_script; then
    command_str='pnpm test && pnpm typecheck'
  else
    command_str='pnpm test'
    typecheck_advisory_msg="typecheck-advisory: no tsconfig.json or 'typecheck' script in package.json — typecheck step skipped (add a tsconfig.json or declare \`pnpm typecheck\` to enable)"
  fi
elif [ -f "package-lock.json" ] || [ -f "package.json" ]; then
  stack="js"
  stack_subtype="npm"
  # npm path is conservative: rely on declared `typecheck` script rather than
  # `npx tsc` (npx is a separate binary from npm and adds resolution surprises
  # when TypeScript isn't installed locally). Forks on npm declare typecheck
  # in scripts; bun/pnpm get the tsconfig fast-path because their runners
  # invoke local node_modules/.bin/tsc directly.
  if has_typecheck_script; then
    command_str='npm test --silent && npm run typecheck'
  else
    command_str='npm test --silent'
    typecheck_advisory_msg="typecheck-advisory: no 'typecheck' script in package.json — typecheck step skipped (declare \`npm run typecheck\` to enable)"
  fi
elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  stack="python"
  # Detect venv-style project managers (first lockfile match wins). Falls back
  # to bare `python` when no wrapper is found, preserving system-Python behavior.
  py_prefix="python"
  if { [ -f "uv.lock" ] || [ -d ".venv" ]; } && command -v uv >/dev/null 2>&1; then
    py_prefix="uv run python"
  elif [ -f "poetry.lock" ] && command -v poetry >/dev/null 2>&1; then
    py_prefix="poetry run python"
  elif [ -f "pdm.lock" ] && command -v pdm >/dev/null 2>&1; then
    py_prefix="pdm run python"
  fi
  # Make mypy non-blocking (advisory only) while pytest stays a real gate.
  # Brace group localises `|| true` to the mypy step; the prior shape
  # (`pytest && mypy || true`) collapsed pytest failures into exit 0.
  command_str="$py_prefix -m pytest -q && { $py_prefix -m mypy . || true; }"
elif [ -f "go.mod" ]; then
  stack="go"
  command_str='go test ./... && go vet ./...'
elif [ -f "Cargo.toml" ]; then
  stack="rust"
  command_str='cargo test --quiet && cargo clippy -q -- -D warnings'
elif [ -f "composer.json" ]; then
  stack="php"
  # Detect Pest vs PHPUnit via composer.json deps. Pest depends on PHPUnit so
  # checking pestphp/pest first is correct precedence. Default to phpunit when
  # neither is explicitly declared (Laravel ships with phpunit by default).
  # --colors=never disables ANSI at source; runtime-capture.sh strips ANSI
  # anyway, but disabling at source is cleaner and inference patterns stay
  # simpler.
  if jq -e '(.["require-dev"]["pestphp/pest"] // .require["pestphp/pest"]) // empty' composer.json >/dev/null 2>&1; then
    command_str='vendor/bin/pest --colors=never'
  else
    command_str='vendor/bin/phpunit --colors=never'
  fi
fi

if [ -z "$command_str" ]; then
  emit_no_stack
fi

# --- Lint extension (spec 013) ----------------------------------------------
# Manifest-as-intent: linter declared in the manifest is the canonical signal
# this fork wants lint enforcement. Filesystem (`node_modules/...`, `python -m
# ruff --version`) is the secondary "installed?" probe used only after
# declaration is confirmed. Three states per stack:
#   (a) declared + installed → append `<runner> <linter> check` to command_str
#   (b) declared + missing   → emit `lint-advisory:` to stderr, do NOT append
#   (c) not declared         → silent skip
# Opt-out: CLAUDE_VALIDATOR_SKIP_LINT=1 short-circuits before any detection.
lint_advisory_msg=""
if [ "${CLAUDE_VALIDATOR_SKIP_LINT:-0}" != "1" ]; then
  if [ "$stack" = "js" ]; then
    if [ -f "package.json" ] && jq -e '.devDependencies["@biomejs/biome"] // .dependencies["@biomejs/biome"] // empty' package.json >/dev/null 2>&1; then
      if [ -f "node_modules/@biomejs/biome/package.json" ]; then
        case "$stack_subtype" in
          bun)  command_str="$command_str && bunx biome check" ;;
          pnpm) command_str="$command_str && pnpm exec biome check" ;;
          npm)  command_str="$command_str && npx biome check" ;;
        esac
      else
        case "$stack_subtype" in
          bun)  install_cmd="bun install" ;;
          pnpm) install_cmd="pnpm install" ;;
          npm)  install_cmd="npm install" ;;
          *)    install_cmd="npm install" ;;
        esac
        lint_advisory_msg="lint-advisory: biome declared in package.json but not installed — run \`$install_cmd\`"
      fi
    fi
  elif [ "$stack" = "python" ]; then
    ruff_declared=0
    ruff_manifest=""
    for manifest in pyproject.toml requirements.txt; do
      [ -f "$manifest" ] || continue
      if grep -qiE '(^[[:space:]]*ruff([[:space:]=<>~!]|$)|"ruff"|"ruff[<>=~!])' "$manifest" 2>/dev/null; then
        ruff_declared=1
        ruff_manifest="$manifest"
        break
      fi
    done
    # Also scan requirements*.txt variants (dev-requirements.txt, etc.)
    if [ "$ruff_declared" -eq 0 ]; then
      for manifest in requirements*.txt; do
        [ -f "$manifest" ] || continue
        if grep -qiE '(^[[:space:]]*ruff([[:space:]=<>~!]|$)|"ruff"|"ruff[<>=~!])' "$manifest" 2>/dev/null; then
          ruff_declared=1
          ruff_manifest="$manifest"
          break
        fi
      done
    fi

    if [ "$ruff_declared" -eq 1 ]; then
      if $py_prefix -m ruff --version >/dev/null 2>&1; then
        command_str="$command_str && $py_prefix -m ruff check ."
      else
        py_install_cmd="pip install ruff"
        if [ -f "uv.lock" ] && command -v uv >/dev/null 2>&1; then
          py_install_cmd="uv sync"
        elif [ -f "poetry.lock" ] && command -v poetry >/dev/null 2>&1; then
          py_install_cmd="poetry install"
        elif [ -f "pdm.lock" ] && command -v pdm >/dev/null 2>&1; then
          py_install_cmd="pdm install"
        fi
        lint_advisory_msg="lint-advisory: ruff declared in $ruff_manifest but not installed — run \`$py_install_cmd\`"
      fi
    fi
  elif [ "$stack" = "php" ]; then
    # Pint detection (Laravel formatter wrapping php-cs-fixer).
    # Manifest-as-intent: laravel/pint in require-dev OR require. Installed
    # probe: vendor/bin/pint exists. Same shape as Biome/Ruff branches.
    if [ -f "composer.json" ] && jq -e '(.["require-dev"]["laravel/pint"] // .require["laravel/pint"]) // empty' composer.json >/dev/null 2>&1; then
      if [ -x "vendor/bin/pint" ]; then
        command_str="$command_str && vendor/bin/pint --test"
      else
        lint_advisory_msg="lint-advisory: pint declared in composer.json but not installed — run \`composer install\`"
      fi
    fi
    # PHPStan / Larastan detection. Larastan extends PHPStan with Laravel-aware
    # rules; both ship the `vendor/bin/phpstan` binary. Either declaration counts.
    if [ -f "composer.json" ] && jq -e '(.["require-dev"]["phpstan/phpstan"] // .["require-dev"]["larastan/larastan"] // .require["phpstan/phpstan"] // .require["larastan/larastan"]) // empty' composer.json >/dev/null 2>&1; then
      if [ -x "vendor/bin/phpstan" ]; then
        command_str="$command_str && vendor/bin/phpstan analyse --no-progress"
      else
        # Concatenate if Pint advisory already set; newline-separated so each
        # advisory becomes its own stderr line (the emit loop below loops once
        # per `printf` of $lint_advisory_msg — newline-embedded strings print
        # multi-line).
        phpstan_advisory="lint-advisory: phpstan declared in composer.json but not installed — run \`composer install\`"
        if [ -n "$lint_advisory_msg" ]; then
          lint_advisory_msg="$lint_advisory_msg
$phpstan_advisory"
        else
          lint_advisory_msg="$phpstan_advisory"
        fi
      fi
    fi
  fi
fi

# Surface advisories on stderr BEFORE running the pipeline. Captured by the
# post-edit hook (which redirects validator stderr separately from stdout so
# JSON parsing stays clean) and ingested into the agent's next-turn context.
# Multiple advisories can fire in the same run (e.g. lint declared+missing
# AND no typecheck primitive); each emits its own line, agent reads all.
if [ -n "$lint_advisory_msg" ]; then
  printf '%s\n' "$lint_advisory_msg" >&2
fi
if [ -n "$typecheck_advisory_msg" ]; then
  printf '%s\n' "$typecheck_advisory_msg" >&2
fi

stdout_file="$(mktemp 2>/dev/null || mktemp -t validator-stdout)"
stderr_file="$(mktemp 2>/dev/null || mktemp -t validator-stderr)"
trap 'rm -f "$stdout_file" "$stderr_file"' EXIT

# Portable millisecond clock. Computes (seconds * 1000) + (nanoseconds / 1_000_000).
# Avoids `date +%s%3N` because the `%3N` precision specifier is silently dropped
# on some platforms (observed on WSL2 GNU coreutils 2026-05) leaving full 9-digit
# nanoseconds appended — the regex `^[0-9]+$` cannot distinguish the two shapes.
# Using `%s` + `%N` separately and reducing in shell arithmetic is unambiguous.
# On BSD/macOS `%N` returns the literal `%N`; the regex check falls back to ms=0.
now_ms() {
  local secs nanos ms
  secs=$(date +%s)
  nanos=$(date +%N 2>/dev/null)
  if [[ "$nanos" =~ ^[0-9]+$ ]]; then
    # `10#` forces base-10 to avoid octal-parse on leading-zero nanos (e.g. "045123456").
    ms=$((10#$nanos / 1000000))
  else
    ms=0
  fi
  echo $((secs * 1000 + ms))
}

start_ms="$(now_ms)"
bash -c "$command_str" >"$stdout_file" 2>"$stderr_file"
exit_code=$?
end_ms="$(now_ms)"
duration_ms=$(( end_ms - start_ms ))

# Truncate to last ~4096 bytes; tail -c is in POSIX coreutils on Linux and macOS.
stdout_tail="$(tail -c 4096 "$stdout_file" 2>/dev/null || true)"
stderr_tail="$(tail -c 4096 "$stderr_file" 2>/dev/null || true)"

ok_value="false"
[ "$exit_code" -eq 0 ] && ok_value="true"

# --- TDD warning detection (spec 005) ---------------------------------------
# Skip entirely when not in a git repo: git diff is the signal source, and
# emitting an empty/misleading warnings field outside a repo is worse than
# omitting it. Hook treats missing `warnings` as "no advisory".
warnings_json=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  case "$stack" in
    js)       default_patterns='*.test.ts *.test.tsx *.test.js *.test.jsx *.spec.ts *.spec.tsx *.spec.js *.spec.jsx __tests__/* tests/* test/*' ;;
    python)   default_patterns='*_test.py test_*.py tests/* test/*' ;;
    go)       default_patterns='*_test.go' ;;
    rust)     default_patterns='tests/* *_test.rs *_tests.rs' ;;
    php)      default_patterns='tests/* *Test.php *_test.php' ;;
    *)        default_patterns='' ;;
  esac

  if [ -n "${CLAUDE_TDD_TEST_PATTERNS:-}" ]; then
    patterns_str="$CLAUDE_TDD_TEST_PATTERNS"
  else
    patterns_str="$default_patterns"
  fi

  # Modified-tracked + untracked-not-ignored, deduped. A sub-agent that uses
  # the Write tool to create a new test file leaves it untracked, so plain
  # `git diff` would miss it and the warning would falsely fire. Including
  # `ls-files --others --exclude-standard` closes that gap.
  #
  # Belt-and-suspenders noise filter — defends against forks with
  # mis-configured .gitignore (e.g. Agent0 ships a stack-agnostic gitignore
  # template with `# node_modules/` commented; forks must uncomment per
  # stack). Without this filter, an un-ignored node_modules can dump 15k+
  # paths into the per-file shell loop, hanging the validator for minutes.
  # Surfaced via shrnk-mono dogfood 2026-05-12.
  changed_files="$(
    ( git diff --name-only 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null
    ) | grep -vE '^(node_modules/|\.venv/|venv/|__pycache__/|\.pytest_cache/|\.mypy_cache/|\.ruff_cache/|target/|dist/|build/|out/|coverage/|\.next/|\.nuxt/|\.svelte-kit/|\.cache/|\.turbo/)' \
      | sort -u || true
  )"

  prod_files=""
  test_count=0
  # *.lock / *.lockb / go.sum cover supply-chain lockfiles across all 10 managers
  # (bun.lock, bun.lockb, yarn.lock, Cargo.lock, poetry.lock, uv.lock, pdm.lock,
  # go.sum; package-lock.json + pnpm-lock.yaml fall through *.json / *.yaml).
  # Surfaced via shrnk-mono spec 013 dogfood 2026-05-12: `bun install` modified
  # bun.lock, validator misclassified it as prod-without-test → false-positive.
  excluded_globs='*.md *.txt *.json *.yml *.yaml *.toml *.lock *.lockb LICENSE *.gitignore .gitkeep go.sum */go.sum'

  old_ifs="$IFS"
  IFS='
'
  # Disable pathname (glob) expansion for the classification loop. Without
  # `set -f`, the unquoted `$excluded_globs` / `$patterns_str` expansions
  # below get pathname-expanded against cwd: e.g. in a populated repo `*.json`
  # expands to the literal root-level matches (`package.json` alone), and the
  # subsequent `case "$f" in $g)` becomes a literal compare that misses
  # nested workspace manifests (`apps/api/package.json`) entirely. The case
  # pattern matcher correctly handles globs against `/`-containing paths once
  # the unexpanded pattern reaches it. Surfaced via shrnk-mono dogfood
  # validation pass 2026-05-12, commit `d4eada2`.
  case "$-" in *f*) prev_f_set=1 ;; *) prev_f_set=0 ;; esac
  set -f
  for f in $changed_files; do
    [ -z "$f" ] && continue

    is_excluded=0
    IFS=' '
    for g in $excluded_globs; do
      case "$f" in
        $g) is_excluded=1; break ;;
      esac
    done
    IFS='
'
    [ "$is_excluded" -eq 1 ] && continue

    is_test=0
    IFS=' '
    for g in $patterns_str; do
      case "$f" in
        $g) is_test=1; break ;;
      esac
    done
    IFS='
'
    if [ "$is_test" -eq 1 ]; then
      test_count=$(( test_count + 1 ))
    else
      if [ -z "$prod_files" ]; then
        prod_files="$f"
      else
        prod_files="$prod_files
$f"
      fi
    fi
  done
  [ "$prev_f_set" = "0" ] && set +f
  IFS="$old_ifs"

  if [ -n "$prod_files" ] && [ "$test_count" -eq 0 ]; then
    files_json="$(printf '%s\n' "$prod_files" | jq -R . | jq -s .)"
    msg='Production files changed without any test changes in this session diff. If the change is genuinely test-exempt (rename, comment, refactor without behavior change), no action needed; otherwise, consider adding a test. See .claude/rules/tdd.md.'
    warnings_json="$(jq -n --argjson files "$files_json" --arg msg "$msg" \
      '[{kind:"no_test_change_for_prod_edit",files:$files,message:$msg}]')"
  else
    warnings_json='[]'
  fi
fi

if [ -n "$warnings_json" ]; then
  jq -n \
    --argjson ok "$ok_value" \
    --arg command "$command_str" \
    --argjson exit "$exit_code" \
    --argjson duration_ms "$duration_ms" \
    --arg stdout "$stdout_tail" \
    --arg stderr "$stderr_tail" \
    --argjson warnings "$warnings_json" \
    '{ok:$ok,command:$command,exit:$exit,duration_ms:$duration_ms,stdout:$stdout,stderr:$stderr,warnings:$warnings}'
else
  jq -n \
    --argjson ok "$ok_value" \
    --arg command "$command_str" \
    --argjson exit "$exit_code" \
    --argjson duration_ms "$duration_ms" \
    --arg stdout "$stdout_tail" \
    --arg stderr "$stderr_tail" \
    '{ok:$ok,command:$command,exit:$exit,duration_ms:$duration_ms,stdout:$stdout,stderr:$stderr}'
fi

exit 0
