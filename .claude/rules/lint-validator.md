---
paths:
  - ".claude/validators/run.sh"
  - "biome.json"
  - "**/biome.json"
  - "**/pyproject.toml"
  - "**/package.json"
  - "**/requirements*.txt"
---

# Lint validator

The post-edit validator (`.claude/validators/run.sh`) extends to lint enforcement when the fork's manifest declares the linter idiomatic to the detected stack. JS/TS uses [Biome](https://biomejs.dev) (`@biomejs/biome` in `devDependencies` or `dependencies`); Python uses [Ruff](https://docs.astral.sh/ruff) (declared in `pyproject.toml` or `requirements*.txt`). Three states keep the discipline tight without prescribing tooling Agent0 doesn't ship: (a) declared + installed → linter runs and contributes to `ok`; (b) declared + missing → actionable advisory on stderr, no block; (c) not declared → silent skip.

## What fires, what advises

The validator's existing JS / Python branches gain a lint extension that runs after the test+typecheck pipeline is composed but before it executes. State dispatch per stack:

**JS/TS.** When `package.json` exists AND `jq -e '.devDependencies["@biomejs/biome"] // .dependencies["@biomejs/biome"]'` resolves: biome is declared.
- `node_modules/@biomejs/biome/package.json` exists → append `<runner> biome check` to `command_str`. `<runner>` is `bunx` for bun, `pnpm exec` for pnpm, `npx` for npm — driven by the same lockfile match the validator already used to pick `<runner> test`.
- `node_modules/@biomejs/biome/` missing → emit `lint-advisory: biome declared in package.json but not installed — run \`<install-cmd>\`` to validator stderr; `<install-cmd>` is `bun install` / `pnpm install` / `npm install`. The pipeline runs without biome; `ok` reflects test+typecheck only.

**Python.** When `pyproject.toml` or `requirements*.txt` matches the ruff regex `(^[[:space:]]*ruff([[:space:]=<>~!]|$)|"ruff"|"ruff[<>=~!])` (case-insensitive): ruff is declared. The regex covers poetry (`ruff = "x"`), PEP 621 array (`"ruff>=x"`), requirements.txt (`ruff>=x`, `Ruff`).
- `<py_prefix> -m ruff --version` exits 0 → append `<py_prefix> -m ruff check .`.
- `<py_prefix> -m ruff --version` exits non-zero → emit `lint-advisory: ruff declared in <manifest> but not installed — run \`<install-cmd>\``. `<install-cmd>` derives from lockfile presence: `uv.lock` → `uv sync`; `poetry.lock` → `poetry install`; `pdm.lock` → `pdm install`; otherwise `pip install ruff`. Mirrors the existing `py_prefix` switch.

`<py_prefix>` is the same `python` / `uv run python` / `poetry run python` / `pdm run python` chain the validator already detected for test+typecheck.

**PHP.** When `composer.json` exists AND `jq -e '.["require-dev"]["laravel/pint"] // .require["laravel/pint"]'` resolves: Laravel Pint is declared. Pint wraps `php-cs-fixer` with Laravel-leaning defaults; it's the idiomatic formatter for Laravel projects (and works for non-Laravel PHP too).
- `vendor/bin/pint` exists and is executable → append `vendor/bin/pint --test` to `command_str` (test mode = check without fix, exits non-zero on style violations).
- `vendor/bin/pint` missing → emit `lint-advisory: pint declared in composer.json but not installed — run \`composer install\``. The pipeline runs without Pint; `ok` reflects test only.

Static analysis (Larastan / vanilla PHPStan) follows the same shape under PHP. When `composer.json` declares ONE of `phpstan/phpstan` OR `larastan/larastan` in `require-dev` (or `require`): PHPStan is declared. Larastan is a wrapper that extends PHPStan with Laravel-aware rules; both ship the `vendor/bin/phpstan` binary, so either declaration triggers the same probe.
- `vendor/bin/phpstan` exists and is executable → append `vendor/bin/phpstan analyse --no-progress`.
- `vendor/bin/phpstan` missing → emit `lint-advisory: phpstan declared in composer.json but not installed — run \`composer install\``.

PHP is the first stack where TWO lint primitives (Pint + PHPStan) can fire side-by-side in a single validator run; the existing `lint_advisory_msg` channel concatenates per-linter advisories with a newline separator so each declared+missing linter gets its own stderr line on the agent's next turn.

## Manifest-as-intent

The single signal is **manifest declaration**, not config-file presence. `biome.json` / `[tool.ruff]` are customization, not intent — a fork that has them but does not declare the linter in deps does not trigger lint. Rationale: ecosystem-native dep declaration is unambiguous and language-uniform across npm/pnpm/bun/yarn (`devDependencies`/`dependencies` is standard) and Python (`ruff` in pyproject deps array or requirements.txt is standard). Config presence is noisy (a fork can have a `biome.json` for editor integration without wanting CI lint enforcement) and would multiply detector predicates without raising precision. See spec.md § Open questions Q1-Q3 for the design pivot rationale.

The trade-off: a fork that copies a `biome.json` from another repo without adding `@biomejs/biome` to devDeps will NOT see lint until they declare. Documented surprise, mitigated by this rule doc + the § *Lint validator* mention in CLAUDE.md.

## Advisory format

Both stacks emit single stderr lines with the same shape as supply-chain's corrected-form template:

```
lint-advisory: biome declared in package.json but not installed — run `bun install`
lint-advisory: ruff declared in pyproject.toml but not installed — run `poetry install`
```

The install command is verbatim copy-paste — the agent (or the operator reading post-edit-validate stderr) runs it and the next validator firing transitions to state (a). Advisories are NEVER blocking; they NEVER increment the delegation loop budget (see `.claude/rules/delegation.md` § *Post-edit validator loop*). Mirrors `tdd-advisory:` and `secrets-advisory:` semantics.

The advisory reaches the agent's next-turn context via `post-edit-validate.sh`, which captures validator stderr separately from stdout (the JSON contract) and surfaces it to its own stderr. Before this extension the validator was silent on its own stderr so a `2>&1` merge did no harm; once it started emitting advisories the merge would prepend non-JSON text and break `jq` parsing. The hook update is additive: stdout still carries the JSON contract; stderr is now a real channel.

## Opt-out

`CLAUDE_VALIDATOR_SKIP_LINT=1` short-circuits the entire lint extension before manifest detection. Test + typecheck pipelines run unchanged; no advisory is emitted regardless of declaration state. For sessions where lint signal is noise (e.g. mid-refactor where the lint state will be addressed in a follow-up commit) — do NOT set in long-lived shell config (silent permanent disable). There is no per-tool granularity (no separate `SKIP_BIOME` / `SKIP_RUFF`); single env var is sufficient.

Missing `jq` falls through `emit_no_stack` early — the lint extension is never reached. Missing linter binary on declared+installed false-positive (the JS check is filesystem-only and could be wrong if biome is installed in a parent `node_modules/` via hoisting): the inner `bunx biome check` invocation handles missing binaries by failing — that flips `ok=false` and surfaces the failure naturally, not via advisory. The advisory path is reserved for the deterministic detection failure (manifest says declared, install probe says missing).

## Single-stack v1

The validator's existing stack-detect is monolithic — first `if/elif` match wins. A monorepo with both `bun.lock` AND `pyproject.toml` runs only the JS lint extension (bun branch wins). Multi-stack monorepo lint is a property of the validator's stack-detect, not of this extension. The monorepo-stack-detect extension extends the validator to walk multiple stacks; when it lands, this lint extension inherits multi-stack lint automatically with no re-implementation. Documented as explicit non-goal in spec.md to prevent duplicating walk logic.

## Gotchas

- **`peerDependencies` is NOT scanned.** Linters in peerDeps is an antipattern (linters are dev tooling, not runtime contracts). The `jq -e` query checks `.devDependencies // .dependencies` only. A fork that declares biome in peerDeps will hit silent-skip. Acceptable; documented to avoid the surprise.
- **Python regex is pragmatic, not exhaustive.** The grep covers poetry, PEP 621, `[tool.uv]`, requirements.txt. Edge cases NOT covered: `[tool.hatch.envs.<name>.dependencies]` (hatch nested-env shape), `[tool.poetry.group.*.dependencies]` (poetry group syntax — the regex matches the `ruff = "x"` line itself even inside a group section, so this MAY work depending on the indent; verify if a fork hits a false negative). False positive in a comment line (`# ruff is great but we removed it`) is acceptable — only triggers an advisory, never a block. Extend the regex if a real-world fork hits a gap.
- **`requirements*.txt` glob.** The validator scans `requirements.txt` AND `requirements*.txt` (covers `dev-requirements.txt`, `requirements-dev.txt`, etc.). Glob expansion in bash with no match returns the literal pattern; `[ -f "$f" ]` skips it.
- **`uv tool install ruff` (global) is invisible.** A fork that installs ruff globally via uv but does NOT declare it in pyproject deps will hit silent-skip (manifest-as-intent → no declaration → no advisory). Acceptable since the alternative (filesystem-only probe) re-introduces the config-file noise the design pivoted away from.
- **`node_modules/@biomejs/biome/` hoisting in monorepos.** A workspace setup may hoist biome to a parent `node_modules/`. The validator's filesystem check is at the cwd's `node_modules/`, which can miss hoisted installs. False negative manifests as a spurious advisory; the agent can either install biome into the workspace's local `node_modules/` or set `CLAUDE_VALIDATOR_SKIP_LINT=1` for that session. The monorepo-stack-detect extension may revisit.
- **Validator stderr is now a real channel.** Before this extension: validator emitted nothing to its own stderr; the inner pipeline's stderr was captured into the JSON `.stderr` field. After it: validator may emit `lint-advisory:` lines to its own stderr (see § Advisory format). Anyone consuming the validator outside `post-edit-validate.sh` (custom hooks, manual invocations) needs to be aware of this — `2>&1` will merge advisories into stdout and break JSON parsing.
- **No audit log.** Coherent with runtime-introspect's "snapshot-as-truth, no per-call audit". The advisory IS the signal; volume of supply-chain's per-Bash audit log is the cautionary tale (`.claude/rules/supply-chain.md` § Gotchas). If forensic queries on lint-advisory frequency become a real need, add in a follow-up spec.
- **`bunx biome check` / `pnpm exec biome check` / `npx biome check` semantics.** All three runners invoke the local `node_modules/.bin/biome`. `npx` and `pnpm exec` will fall back to a global install if the local is missing — but the filesystem check above gates on local presence, so that fallback shouldn't fire. `bunx` checks local-first too. If a fork moves binaries via custom `.bin/` paths, this may break; document in fork's CLAUDE.md.
- **`CLAUDE_VALIDATOR_SKIP_LINT` is the only opt-out.** No `CLAUDE_LINT_ADVISORY_OFF=1` (advisory is the whole point); no `CLAUDE_LINT_BLOCK_ON_MISSING=1` (advisory-not-block is by design). One env var, one knob.
- **Agent0 base ships zero linter config.** `git ls-files | grep -E '(biome\.json|ruff\.toml)'` returns empty. Forks own their config. The detection is intent-via-manifest; rule customization is the fork's responsibility.
- **`uv run` auto-sync collapses state-b for uv-managed projects.** When `<py_prefix> = "uv run python"`, the probe `uv run python -m ruff --version` triggers uv's auto-resolve from `pyproject.toml` before invoking python — meaning declaring ruff in `[dependency-groups]` causes uv to install it transparently on the next probe, bypassing the state-b "declared+missing" advisory entirely. Caught in 2026-05-12 pyshrnk dogfood. Mitigation: under default `uv run` usage the advisory rarely fires (state-b → state-a happens in one step from the agent's view), which is *desirable* for adoption ergonomics. The advisory still fires for non-uv Python flows (poetry, pdm, pip-only, or PATH-isolated CI). If a fork wants to verify "ruff actually installed", `uv run python -m ruff --version` is the canonical manual probe.
- **`.claude/` should be linter-ignored.** Biome's default scan walks the entire repo (excluding only `.git/`, `node_modules/`, `dist/`, `build/`). `.claude/` files (especially `.mjs` scripts like `presence/statusline.mjs` and `settings.json`) WILL get reformatted by `biome check --write` — and the next `sync-harness.sh` will flag those as customized hash drift, refusing updates without `--force-except`. Forks adopting biome must ship a `biome.json` ignoring `.claude/**`:
  ```json
  { "files": { "ignore": [".claude/**", "node_modules/**", "dist/**", "build/**", "coverage/**"] } }
  ```
  Symmetric advice for ruff is usually unnecessary — `.claude/` rarely contains `.py` files in any current fork; ruff's `extend-exclude` defaults already cover `.venv/`, `__pycache__/`, etc. Caught in 2026-05-12 shrnk dogfood.
- **Biome's defaults are opinionated.** Biome 1.x uses tabs and its own style ruleset by default. A fork adopting biome with zero config commits to biome's worldview wholesale — the first `biome check --write` may reformat many files. To preserve existing conventions, ship a `biome.json` with explicit `formatter.indentStyle` / `indentWidth` and any rule overrides. Not a concern here, but worth knowing before the first `bun install && bunx biome check --write`.
- **State-a transition needs a supply-chain OVERRIDE marker.** The advisory message ends with `run \`bun install\`` (or equivalent). Acting on that advisory hits the supply-chain block on dep-mutating commands. The operator (or agent) must add a multi-line `# OVERRIDE: <reason ≥10 chars>` on its own line — the supply-chain start-of-line anchor rejects inline trailing markers. Documented behavior; no fix needed here.
