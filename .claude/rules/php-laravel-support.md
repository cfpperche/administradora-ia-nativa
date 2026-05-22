---
paths:
  - "composer.json"
  - "composer.lock"
  - "artisan"
  - "**/composer.json"
  - "phpunit.xml"
  - "phpunit.xml.dist"
  - "Pest.php"
---

# PHP / Laravel support

This rule is an **index**, not the canonical source. Each Agent0 capacity — validator, supply-chain, runtime-introspect, TDD, lint, MCP recipes — has its own rule doc that documents the per-stack behavior in full. This page exists so a new reader on a Laravel fork can find every PHP-aware touchpoint in one place. The canonical per-capacity docs are linked under each section below; read them when you need depth, this page for orientation.

PHP detection in Agent0 is triggered by **`composer.json` at the project root** (validator + supply-chain) or **`artisan` file at the root** (Laravel canonical signal, used by mcp-recipes). The seven capacities below ship dormant in a non-PHP fork and activate the moment those signals exist — no env-var to set, no opt-in.

## 1. Validator detects PHP

`.claude/validators/run.sh` recognises `composer.json` after the rust elif (PHP slotted late in the chain so JS-leading mixed-stack monorepos route to JS via lockfile precedence). Detection chooses the test runner:

- `composer.json` declares `pestphp/pest` in `require-dev` or `require` → `command_str='vendor/bin/pest --colors=never'`
- Otherwise → `command_str='vendor/bin/phpunit --colors=never'`

`--colors=never` disables ANSI at source so inference patterns stay simple (the runtime-capture hook also strips ANSI on storage, but disabling upstream is cleaner). Canonical doc: this rule + the validator's elif chain at `.claude/validators/run.sh`.

## 2. Supply-chain knows composer

`.claude/hooks/supply-chain-scan.sh` includes `composer` as the 11th manager in the detection table (`require remove update install` verbs). `composer require <pkg>` blocks by default (exit 2 + corrective template) just like `npm install <pkg>`; the `# OVERRIDE: <reason ≥10 chars>` marker on its own line bypasses with `decision="block-override"`. Bare `composer install` with an uncommitted `composer.json` fires the `advisory-bare-install` sub-path (same shape as bare `npm install` with dirty `package.json`).

`.claude/hooks/supply-chain-advise.sh` adds `composer.json` and `composer.lock` to the manifest+lockfile basename allowlist — a delegated sub-agent's Edit/Write on either basename emits `supply-chain-advisory: edit composer.json — manifest may have new dep`.

Canonical doc: `.claude/rules/supply-chain.md` (the manager detection table + manifest+lockfile basename allowlist now include PHP).

## 3. Runtime-introspect captures PHP test runs

`.claude/hooks/runtime-capture.sh` detects:

- Single-token: `vendor/bin/phpunit` / `./vendor/bin/phpunit` → `detector="phpunit"`
- Single-token: `vendor/bin/pest` / `./vendor/bin/pest` → `detector="pest"`
- Pair-token: `artisan test` (from `php artisan test`) → `detector="artisan-test"`
- Pair-token: `composer test` (Laravel composer-script convention) → `detector="composer-test"`
- Pair-token: `composer lint` → `detector="composer-lint"`

Inference patterns: PHPUnit `OK (N tests, M assertions)` → PASS, `FAILURES!` / `ERRORS!` / `Failures: [1-9]+` / `Errors: [1-9]+` → FAIL. Pest `Tests:  N passed` → PASS, `Tests:  N failed` → FAIL. PHP fatal/parse/uncaught errors → FAIL. Lint wrappers (`composer-lint`) match `Style violations` / `errors found` / `[ERROR]` → FAIL, clean short output → PASS.

Canonical doc: `.claude/rules/runtime-introspect.md` § *Detector pair list*.

## 4. TDD patterns recognise PHP test files

`.claude/validators/run.sh`'s TDD warning path adds `php) default_patterns='tests/* *Test.php *_test.php' ;;` to the per-stack pattern table. This covers PHPUnit and Pest naming conventions plus Laravel's `tests/Feature/` and `tests/Unit/` layout. A delegated sub-agent that edits prod-PHP (e.g. `app/Models/User.php`) without touching any pattern-matched test file in the same diff triggers a `tdd-advisory:` line on the next turn.

Canonical doc: `.claude/rules/tdd.md` § *From scenarios to tests* (per-language test-pattern table).

## 5. Lint validator runs Pint + PHPStan

`.claude/validators/run.sh` lint extension adds a `php` branch after the Python branch:

- `composer.json` declares `laravel/pint` in `require-dev` (or `require`) AND `vendor/bin/pint` is executable → append `vendor/bin/pint --test` (test mode — no auto-fix).
- `composer.json` declares `phpstan/phpstan` OR `larastan/larastan` (in `require-dev` or `require`) AND `vendor/bin/phpstan` is executable → append `vendor/bin/phpstan analyse --no-progress`.
- Either declared + binary missing → emit `lint-advisory: <linter> declared in composer.json but not installed — run \`composer install\`` to stderr.

PHP is the first stack where TWO lint primitives (Pint + PHPStan) can fire in a single run. Both contribute to the composed `command_str`; both can emit advisories on missing binaries; advisories are concatenated with newlines so each gets its own stderr line.

Canonical doc: `.claude/rules/lint-validator.md` § *What fires, what advises* (PHP paragraph).

## 6. MCP recipes hint laravel-boost-mcp

`.claude/hooks/mcp-recipes-hint.sh` detects Laravel via `artisan` file at root (canonical) OR `composer.json` declaring `laravel/framework` in `require` / `require-dev`. When detected, the SessionStart hint adds:

- `laravel-boost-mcp` — Laravel framework introspection (Eloquent models, DB schema, logs, docs)
- `playwright-mcp` — browser observation (Laravel apps commonly need browser-driven E2E)

DBHub is suggested separately if the existing DB signals fire (`database/migrations/` is a default in Laravel; many Laravel forks will see both Laravel + DB recipes).

`.mcp.json.example` contains the `laravel-boost` server block, commented out by default. Activation in a fork: `composer require laravel/boost --dev && php artisan boost:install` inside the Laravel project, then `cp .mcp.json.example .mcp.json` + uncomment.

Canonical doc: `.claude/rules/mcp-recipes.md` § *Laravel Boost MCP*.

## 7. CLAUDE.md capacity index

CLAUDE.md folds PHP/Laravel detection inline into the capacity sections that enumerate stacks (validator, supply-chain, runtime-introspect, lint) — it carries no dedicated PHP/Laravel chapter. This rule doc is the canonical PHP/Laravel reference; it is path-scoped (frontmatter `paths:` on `composer.json` / `artisan` / `phpunit.xml` / `Pest.php`) and auto-loads the moment a fork's PHP signals are touched, so a fork needs no CLAUDE.md pointer to discover it.

## What this does NOT add

- **No new validator stack other than PHP.** Symfony, CodeIgniter, Yii, Laminas, etc. — all out of scope for v1. A future spec can extend detection if the demand surfaces.
- **No php-cs-fixer detection separate from Pint.** Pint wraps php-cs-fixer; supporting both would duplicate signal. Pure php-cs-fixer projects (no Pint dependency) hit silent-skip on lint.
- **No PHP-aware monorepo walk.** The validator's "first lockfile wins" remains — a fork with composer.json AND package.json routes to whichever elif matches first (currently JS first, PHP late). Multi-stack monorepo PHP+JS is a future spec territory.
- **No editor-time / on-save integration.** Same posture as every other Agent0 capacity — validator runs at sub-agent edit boundaries via hooks, not in real time.
- **No managed `composer install` orchestration.** Agent0 surfaces missing binaries as advisories; the human (or agent under override) decides when to install.

## Cross-references

- `.claude/rules/supply-chain.md` — composer manager + manifest basename
- `.claude/rules/runtime-introspect.md` — PHP detector pairs + inference
- `.claude/rules/lint-validator.md` — Pint + PHPStan rules
- `.claude/rules/tdd.md` — PHP test patterns
- `.claude/rules/mcp-recipes.md` — Laravel Boost MCP recipe
- `.claude/validators/run.sh` — the validator's PHP elif
- `.claude/hooks/{supply-chain-scan,supply-chain-advise,runtime-capture,mcp-recipes-hint}.sh` — the four hooks PHP touches
- `.claude/tests/{validator-php,supply-chain-composer,runtime-capture-php,mcp-recipes-laravel}/` — the test surface that locks the behavior

## Gotchas

- **Lockfile precedence vs PHP.** The validator's elif chain is `bun → pnpm → npm → python → go → rust → php`. A monorepo with `bun.lock` at root and `composer.json` in `services/api/` routes to bun (first match wins). The PHP detection only fires when `composer.json` is at root AND no JS/Python/Go/Rust manifest precedes it. This is the documented limitation; proper multi-stack walking is a future capacity.
- **Pest detection trumps PHPUnit.** Pest declares `phpstunit/phpunit` as a transitive dep (Pest is built on PHPUnit). Both will appear in `composer.lock`. The validator's check on the *direct* declaration of `pestphp/pest` in composer.json correctly picks Pest in that case; if a fork wants the bare PHPUnit invocation despite having Pest installed, drop the Pest declaration from composer.json (the precedent: a single test runner per project).
- **`vendor/bin/*` checks are filesystem probes.** A fork that ran `composer install` but later moved its `vendor/` dir (or is using a non-standard installer like `composer-bin-plugin`) will see "declared but missing" advisories. Symlink `vendor/bin/<tool>` to the actual binary or accept the noise. Same shape as Biome's "missing under monorepo hoisting" gotcha.
- **`composer install` is a lockfile resolve.** Bare `composer install` with no packages is treated as "apply pending declarations from composer.json" — same semantics as `bun install` / `pnpm install`. It does NOT block (no packages → not a mutation), but emits the `advisory-bare-install` advisory when `composer.json` is uncommitted-modified at hook time.
- **`composer global require` is captured under `composer require`.** Global installs are still supply-chain actions — they pull third-party code from packagist and run install scripts. The verb whitelist includes `require`; the tokeniser doesn't special-case `global`. Symmetric with `npm install -g` / `pip install --user`.
- **`composer test` exit-code passthrough.** Composer wraps the script defined in `composer.json` `scripts.test`. Composer's behaviour: if the script exits non-zero, composer exits non-zero. This is well-documented upstream; the runtime-capture inference table still reads stdout patterns (PHPUnit / Pest summary lines) as the primary signal so the snapshot stays auditable even when exit codes are perfect.
- **PHP fatal-error inference.** A `PHP Fatal error:` line (script-level crash before tests run) is captured as FAIL via the dedicated regex branch. PHP fatals don't go through PHPUnit's summary path — they're raw errors. Inference table handles this case explicitly so a syntax error in `tests/Pest.php` doesn't get mis-inferred as PASS by falling through.
- **`laravel-boost` MCP requires PHP + artisan in the working dir.** The MCP launches `php artisan boost:mcp` — if the agent's working dir is outside the Laravel project, the command fails. Forks with multi-root layouts (e.g. monorepo with Laravel under `apps/api/`) must set the MCP working dir or stay inside the Laravel root when invoking boost tools.
