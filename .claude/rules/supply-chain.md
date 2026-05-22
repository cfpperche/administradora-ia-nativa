---
paths:
  - ".claude/hooks/supply-chain-*.sh"
  - ".claude/supply-chain-audit.jsonl"
  - "**/package.json"
  - "**/pyproject.toml"
  - "**/Cargo.toml"
  - "**/go.mod"
  - "**/requirements*.txt"
---

# Supply chain

A two-layer capacity that surfaces dependency-manifest mutations as a privileged action so they leave an audit trail and a friction point.

**The Bash side blocks by default; the Edit/Write side advises.** Detected dep-installs (`npm install foo`, `uv add bar`, `cargo add baz`, …) exit 2 with a corrective stderr template unless a valid `# OVERRIDE: <reason ≥10 chars>` marker is present. Edit/Write on a manifest basename is always advisory (basename match has too high an FP rate — license-header edits look identical to new-dep additions — to be a blocking gate). The opt-out is one env var: `CLAUDE_SUPPLY_CHAIN_BLOCK=0` falls back to advisory-only mode; `CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1` disables both layers entirely.

## What fires, what advises

**Bash preflight — `PreToolUse(Bash)` → `.claude/hooks/supply-chain-scan.sh`.** Tokenises `tool_input.command` and looks for `(manager, verb, packages)` triples across 10 package managers. Behaviour branches on mode (see § *Block vs advisory mode* below): in block mode (default), a detected install with no valid override emits the corrective stderr template, audits `decision: "block"`, and exits 2; a valid override silently passes with `decision: "block-override"`; a too-short override is hard-rejected with a dedicated short-reason template (the rejected reason is preserved in `override_reason` for forensics). In advisory mode (`CLAUDE_SUPPLY_CHAIN_BLOCK=0`), the advisory-only path runs unchanged: `decision: "advisory"` / `"advisory-override"`, never exit 2. On no install match → audits `decision: "skip-not-install"` for forensic completeness (mirrors `secrets-scan.sh`'s `skip-not-commit` row-per-bash discipline; gitignored, growth is acceptable). The skip path is mode-independent.

**Edit/Write advisory — `PostToolUse(Edit|Write|MultiEdit)` → `.claude/hooks/supply-chain-advise.sh`.** Sub-agent only — exits 0 silently for parent edits (the `agent_id` actor-split, mirrored from `.claude/rules/delegation.md` § *Post-edit validator loop* and `.claude/rules/secrets-scan.md` § *Soft advisory*). On a delegated edit, takes the basename of `tool_input.file_path` and compares against a fixed allowlist of manifest + lockfile names (no glob walking — exact basename match only). On match → audits `decision: "advisory"`, `scope: "edit"`, `file: "<basename>"`; emits `supply-chain-advisory: edit <basename> — manifest may have new dep` on stderr. On non-match → exits 0 silently, no audit row.

**Bare-install + dirty-manifest sub-path (Bash preflight).** Closes the parent-edit + bare-install coverage gap surfaced via the shrnk-mono dogfood: the parent edits `package.json` (silent — Edit advisory is sub-agent-only) then runs `bun install` (bare → existing `skip-not-install` path); pre-fix the dep landed in the lockfile with zero audit signal. When the Bash scan sees a manager+verb pair from `{npm,pnpm,bun}.{install,i}` but collects no packages AND `git -C "$PROJECT_DIR" status --porcelain` shows at least one of `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` modified-or-untracked, the hook emits `supply-chain-advisory: bare \`<manager> <verb>\` with uncommitted manifest(s): <basename(s)> — installing newly-declared dep(s); add \`# OVERRIDE: <reason ≥10 chars>\` on its own line to silence` and audits `decision: "advisory-bare-install"`. A valid `# OVERRIDE: <reason ≥10 chars>` marker silences the stderr line and records `decision: "advisory-bare-install-override"` with `override_reason` populated. Always non-blocking (intent was already declared via the manifest edit; blocking the lockfile resolve would be late). Mode-agnostic: fires in both block and advisory modes. Other empty manager+verb matches (`pip install --help`, `cargo install` with no positional) are NOT recorded — they're genuine no-ops, not lockfile resolves.

## Manager detection table

Each row: manager → matched verb whitelist → example command. Detection requires at least one non-flag positional argument after the verb — `npm install` (no args) is a lockfile resolve, not a mutation, so it audits as `skip-not-install`.

| Manager | Verbs detected | Example |
| --- | --- | --- |
| `npm` | `install`, `i`, `add`, `update`, `upgrade` | `npm install axios` |
| `pnpm` | `install`, `i`, `add`, `update`, `up` | `pnpm add axios` |
| `yarn` | `add` | `yarn add axios` |
| `bun` | `install`, `i`, `add`, `update` | `bun add axios` |
| `pip` | `install` | `pip install axios` |
| `uv` | `add` | `uv add axios` |
| `poetry` | `add` | `poetry add axios` |
| `pdm` | `add` | `pdm add axios` |
| `cargo` | `add`, `update`, `install` | `cargo add tokio` |
| `go` | `get` | `go get example.com/mod` |
| `composer` | `require`, `remove`, `update`, `install` | `composer require laravel/cashier` |

Detection is tokenisation-based, not regex anchored to start-of-line: `python -m pip install foo` matches (the `pip install foo` substring is found mid-command). Chained commands work too: `git push && npm install foo` triggers on the second half.

## Manifest+lockfile basename allowlist

The Edit/Write hook fires on exact basename match against:

- **JS/TS**: `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, `bun.lockb`
- **Python**: `pyproject.toml`, `requirements.txt`, `uv.lock`, `poetry.lock`, `pdm.lock`
- **Rust**: `Cargo.toml`, `Cargo.lock`
- **Go**: `go.mod`, `go.sum`
- **PHP**: `composer.json`, `composer.lock`

No glob walking — `tests/fixtures/pkg-with-bad-deps/package.json` matches because the basename is `package.json`, regardless of containing directory. This is deliberate: forks that fixture-test manifests will trip the advisory occasionally; the cost (one stderr line) is lower than the alternative (false negatives on real edits to fixture-named manifests in production paths).

## Block vs advisory mode

Mode is resolved at hook entry from `CLAUDE_SUPPLY_CHAIN_BLOCK`:

| `CLAUDE_SUPPLY_CHAIN_BLOCK` | Mode | Behaviour on detected dep-install |
| --- | --- | --- |
| unset (default) | `block` | exit 2 + corrective template; override marker bypasses |
| `0` | `advisory` | advisory-only behaviour — exit 0, stderr advisory line |
| `1` or any other value | `block` | same as unset (defensive: env-var typo can't silently disable) |

`CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1` takes precedence over both — exits 0 silently with no audit, no scan, no mode evaluation.

Decision-value matrix:

| Mode | Override state | Decision | Exit | Stderr |
| --- | --- | --- | --- | --- |
| `block` | none | `block` | 2 | no-override template |
| `block` | valid (≥10 chars) | `block-override` | 0 | silent |
| `block` | too-short (<10 chars) | `block` | 2 | short-reason template; `override_reason` populated |
| `advisory` | none | `advisory` | 0 | `supply-chain-advisory:` line |
| `advisory` | valid (≥10 chars) | `advisory-override` | 0 | silent |
| `advisory` | too-short (<10 chars) | `advisory` | 0 | `supply-chain-advisory:` line (marker silently dropped) |
| either | `skip-not-install` (no install match) | `skip-not-install` | 0 | silent |

The Edit/Write hook is mode-independent — always advisory, `decision: "advisory"`, `scope: "edit"`.

The stderr templates in block mode end with the verbatim corrected form (original command line + `# OVERRIDE: <reason ≥10 chars — why this dep is being added>` placeholder) so the agent's next-turn pattern match has unambiguous input to act on. This is the same issue-#24327 contract pattern documented in `.claude/rules/secrets-scan.md` § *Gotchas*: stderr-on-exit-2 is ingested into next-turn context, so the template wording IS the agent-facing UX, not friendly prose.

## Override grammar

A line in `tool_input.command` matching `^[[:space:]]*# OVERRIDE: <reason>` skips the advisory and records `decision: "advisory-override"` with `override_reason` populated in the audit row. **Start-of-line anchored** (with optional leading whitespace) — identical shape to the secrets-scan preflight. Inline-trailing markers on a single line are NOT accepted; that re-opens the false-positive where `# OVERRIDE:` inside a quoted string was matching. Use a **two-line Bash command** form:

```bash
npm install axios
# OVERRIDE: documented chart-library upgrade per discussion in conversation
```

Bash treats line 2 as a no-op comment when the command actually runs; the hook sees line 2 as start-of-line text and matches.

`<reason>` must be ≥10 characters after trim. **Behaviour on too-short reasons depends on mode**: block mode rejects with a dedicated short-reason stderr template AND preserves the rejected reason in the audit row's `override_reason` field for forensics (decision stays `block`, exit 2 — symmetric with secrets-scan's `override-too-short` shape). Advisory mode silently degrades to the plain advisory path (preserved exactly when `CLAUDE_SUPPLY_CHAIN_BLOCK=0`). The 10-char floor matches the governance / delegation / secrets gates for consistency.

There is no env-var bridge for this hook (unlike `CLAUDE_SECRETS_OVERRIDE_REASON`): the override marker affects ONLY the audit row's decision value and block-bypass. No downstream layer needs to read it.

## Escape hatch

Two env vars with distinct intents — pick the smallest hammer:

- **`CLAUDE_SUPPLY_CHAIN_BLOCK=0`** — falls the Bash preflight back to advisory-only mode for the session. Edit/Write side unchanged. Use when block-mode friction is the wrong default for the work at hand (e.g. a session devoted to ratifying a previously-vetted dep set into the lockfile) but the audit signal is still useful.
- **`CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1`** — disables BOTH layers (Bash + Edit/Write) silently. No scan, no audit. Use for throwaway scratch sessions where the audit log itself adds no value. Takes precedence over `CLAUDE_SUPPLY_CHAIN_BLOCK` (skip wins).

Setting either in a long-lived shell config disables the discipline permanently and silently — wrong escape. The override marker is the right tool for "this one install needs to land deliberately"; the env vars are session-scoped opt-outs.

There is no separate env var for the Edit/Write side (unlike the secrets-scan family's `CLAUDE_SECRETS_ADVISE_ON_EDIT`). The Edit advisory is ON whenever the capacity is active; the friction is low (one stderr line + one audit row per match), and the only off-switch is `CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1`.

## Audit log

`.claude/supply-chain-audit.jsonl`, gitignored, append-only, `flock`-atomic. Every Bash hook invocation writes exactly one line (even `skip-not-install` cases — forensic completeness). Every Edit/Write hook invocation that matches the manifest list writes one line; non-matches and parent-edits write nothing.

| Decision | Scope | Meaning |
| --- | --- | --- |
| `skip-not-install` | `bash` | Bash command does not contain a recognised `<manager> <verb> <packages>` triple |
| `block` | `bash` | Block mode + (no override OR too-short override); exit 2; `override_reason` is `null` for the no-marker case OR populated with the rejected short string for the too-short case (forensic discriminator) |
| `block-override` | `bash` | Block mode + valid override marker; exit 0; `override_reason` populated |
| `advisory` | `bash` | Advisory mode (or too-short override under advisory), no block; stderr line emitted; exit 0 |
| `advisory-override` | `bash` | Advisory mode + valid override marker; no stderr; `override_reason` populated; exit 0 |
| `advisory` | `edit` | Sub-agent Edit/Write/MultiEdit on a manifest-or-lockfile basename; `file` field names the basename; always advisory regardless of Bash mode |
| `advisory-bare-install` | `bash` | Bare `{npm,pnpm,bun}.{install,i}` (no packages) + uncommitted manifest (`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`); `manager` + `action` populated, `packages: []`, stderr advisory emitted; exit 0 |
| `advisory-bare-install-override` | `bash` | Same predicate + valid override marker; silent stderr; `override_reason` populated; exit 0 |

Common fields across all rows: `ts` (ISO 8601 UTC), `session_id` (or `null`), `agent_id` (or `null`). Bash rows additionally carry `manager`, `action`, `packages` (array, possibly null on skip rows), `override_reason` (string or null). Edit rows carry `scope: "edit"` and `file: "<basename>"`. Read with `jq -c .` or `tail -f`. Forensic discriminator for `block` rows: `jq -c 'select(.decision == "block" and (.override_reason | length // 0) > 0)'` finds too-short-rejected ones; the inverse finds no-marker blocks.

## Gotchas

- **`npm install` with no args is NOT a package-add mutation, but IS a lockfile-resolve checkpoint.** Detection requires at least one non-flag positional argument after the verb to fire the block/advisory mutation path. `npm install` / `pnpm install` / `bun install` alone falls through to either: (a) `skip-not-install` when the working tree has no dirty manifest (the historical default), or (b) `advisory-bare-install` when `git -C "$PROJECT_DIR" status --porcelain` shows `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` modified-or-untracked — the latter closes the parent-edit + bare-install gap (sub-path documented in § *What fires, what advises*). Other managers' bare commands (`pdm install`, `poetry install`, `yarn install`) don't reach the bare-install detection because their verb whitelists don't include `install` at all — they fall through to `skip-not-install` unconditionally.
- **Flag-only commands are also skipped.** `pip install --help` collects no packages → falls through to `skip-not-install`. Acceptable — those aren't real installs. NOT routed through the `advisory-bare-install` path: the bare-install detection is restricted to lockfile-resolve verbs (`{npm,pnpm,bun}.{install,i}`), and only the lockfile-resolve managers' bare invocations carry the "apply pending manifest declarations" semantic.
- **Bare-install detection is basename-only — monorepo path is lost.** When a monorepo with `apps/web/package.json` AND `apps/api/package.json` has both dirty, the stderr advisory reports `package.json` once (deduped by basename). The advisory tells the agent "*some* `package.json` is dirty" but not *which workspace*. Acceptable for v1 — the agent already knows which manifest it just edited via tool-call history; the advisory is signal, not full forensics. Audit row keeps `manager`+`action` but does NOT enumerate the dirty paths; `git status --porcelain` is the canonical query if forensics need them post-hoc.
- **Bare-install honors `--git-dir` discipline.** The dirty-manifest probe is `git -C "$PROJECT_DIR" rev-parse --git-dir` + `git -C "$PROJECT_DIR" status --porcelain`. Anchoring at `$CLAUDE_PROJECT_DIR` (not the inherited CWD) means: (a) tests setting `CLAUDE_PROJECT_DIR=<TMPDIR>` see TMPDIR's git tree (or fail-open when TMPDIR has no `.git`), regardless of where the test runner invoked the hook from; (b) sub-shell `cd subdir && bun install` from inside the project still probes the project's root state correctly. A `bun install` invoked from a non-git CWD with `CLAUDE_PROJECT_DIR` pointing at a real git repo will still detect dirty manifests in that repo — correct semantic (the project's intent is what matters).
- **`pip install -r requirements.txt` records `requirements.txt` as a package name.** False positive on the package extraction (it's a file, not a package), but the advisory still fires correctly and forensics can disambiguate by reading the `packages` field. `-r` / `--requirements` are deliberately NOT on the value-taking-flag skip list (see below) — the file path IS the supply-chain signal; skipping it would lose the advisory entirely.
- **Override marker must NOT trail inline.** Single-line `npm install foo  # OVERRIDE: ...` does NOT match the start-of-line anchor; the marker is missed and the standard advisory fires. Use the two-line shape (`npm install foo\n# OVERRIDE: ...`). The exact same trap was documented for secrets-scan; the rationale (false-positive on quoted strings containing `# OVERRIDE:`) carries over.
- **Edit/Write hook does NOT parse the actual diff.** A sub-agent that edits the licence header of `package.json` triggers the advisory the same as one that adds a new dep. False positives are accepted because the alternative (lockfile-diff parsing per hook firing) is expensive and brittle across manager versions.
- **Audit-log volume on the Bash side is HIGH.** Every Bash invocation writes a `skip-not-install` row when no install pattern matches. A session that runs hundreds of `ls`/`cat`/`git status` calls produces hundreds of rows. The log is gitignored and one-line JSONL appends are cheap, but if forensics becomes painful, the `jq -c '. | select(.decision != "skip-not-install")'` filter strips the noise.
- **Hook latency adds up.** Two more hooks fire on every Bash + every Edit/Write/MultiEdit. Each adds ~10-30ms. For agents iterating quickly, cumulative cost matters. If friction surfaces, `CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1` is the per-session disable.
- **Tokenisation does NOT respect quoting.** `pip install "foo[extras]"` would split `"foo[extras]"` as the package (string preserved by the shell, but the hook sees the token before shell processing). Edge case for iter 1; advisory fires correctly with the quoted string in the packages array, which is forensically usable.
- **Package-collection terminators (live-dogfood pass 2026-05-11).** Collection stops at any of: chain separators (`&&`, `||`, `;`), pipes (`|`), redirects (`>`, `>>`, `<`, `2>&1`, `2>`, `&>`), background (`&`), comment start (`#*`). Tokens like `2>>file` (fused redirect with no whitespace) are NOT split by bash's word-split and therefore not recognised as separators — they'd be captured as packages with shell metacharacters. Acceptable noise; rewrite the command with `2>> file` to disambiguate. Initial implementation only handled `&&`/`||`/`;`/`#*`; the broader set landed after `uv add requests --directory /home/goat/pyshrnk 2>&1 | tail -20` captured `/home/goat/pyshrnk`, `2>&1`, `|`, and `tail` as packages.
- **Value-taking flags eat their next token (same pass).** When a flag is on the small allowlist (`--directory`, `--dir`, `--target`, `--target-dir`, `--prefix`, `--manifest-path`, `--project`, `--cwd`, `--workspace`, `--config`, `-c`, `--filter`, `--registry`, `--index`, `--index-url`, `--features`, `-F`), the tokeniser skips BOTH the flag and its value so paths/URLs/feature-names don't leak into the packages array. The list is deliberately small: `-r` / `--requirements` and `--package` / `-p` are NOT on it — their values ARE the supply-chain signal (requirements file, package being acted on). Equals-form (`--directory=/path`) is one token starting with `-` and is handled by the generic flag-skip branch. Other value-taking flags not on the list (e.g. `--registry-mirror`, manager-specific options) will leak their value as a package — acceptable noise; extend the allowlist if a specific noise pattern becomes annoying. The `--features` / `-F` pair landed after the rshrnk live-dogfood pass (2026-05-11) surfaced `cargo add tokio --features full` capturing `["tokio","full"]`; feature names configure a package but aren't themselves supply-chain signal.
- **`#`-starting tokens terminate the package list.** Useful: the override-marker line (line 2 of a multi-line command) gets tokenised but `#` ends package collection. Risk: a package legitimately starting with `#` (none in any manager's namespace) would be cut off; not a real-world concern.
- **stderr advisory is a deferred signal, not inline (live-dogfood pass 2026-05-11).** Claude Code surfaces PreToolUse hook stderr to the agent's *next-turn context*, not as part of the triggering Bash tool's return output. The `supply-chain-advisory:` line therefore appears in the agent's view on its next turn, but does NOT show up in the immediate stdout/stderr of the Bash call that triggered it. To watch advisories in real time during a debug session, tail the audit log: `tail -f .claude/supply-chain-audit.jsonl | jq -c 'select(.decision != "skip-not-install")'`. Same applies to the PostToolUse Edit/Write advisory.
- **First-fork friction in block mode.** A fresh fork of Agent0 will hit `supply-chain-block:` on its first `npm install <pkg>` — surprise, the install rejected. The stderr template itself names both opt-outs verbatim; the README per-fork checklist names the env var; CLAUDE.md § *Supply chain* names it again. Three points of documentation density mean a fork that reads any one of them gets the escape. If first-fork sessions report friction at higher rates than the secrets-scan first-fork (where the `# OVERRIDE:` shape is the same), revisit and consider opt-in via env var; until that signal arrives, block-on-default is the right shape.
- **`block` audit row's `override_reason` is multi-modal — read carefully.** A `block` row can mean (a) no marker was present at all (`override_reason: null`), or (b) a marker was present but the reason was <10 chars after trim (`override_reason: <the rejected short string>`). The audit table above documents the discriminator. Forensic queries that count "blocked because user didn't try to override at all" must filter `select(.override_reason == null)`, NOT `select(.override_reason | length == 0)` — the latter would also match an empty-after-trim marker reason, which is technically the too-short case.
- **Block-template length inflates next-turn context.** A blocked dep-install emits ~10 lines of stderr (template + corrected form). Each blocked call adds those lines to the agent's next-turn context (issue #24327 ingestion). A sub-agent stuck in a fix-then-retry loop trying to install something blocked could accumulate context noise; the `.claude/rules/delegation.md` loop-budget cap (default 5) limits the worst case to ~50 lines of repeated template — annoying but not fatal. If real sessions surface this as a problem, the template can be shortened in a follow-up; for now the explicit corrected-form lines pay off via faster agent recovery.
- **`uv pip install <pkg>` is treated as a `pip` install, not a `uv` action.** The tokeniser sees `uv pip install foo`: at index 0 `uv` matches the manager set but its verb whitelist is `add` only — `pip` is not in `uv`'s verbs, so the manager+verb check fails. Continuing, at index 1 `pip` matches and its verb `install` follows. Result: detected as `pip install foo`. Acceptable; the audit shows `manager: "pip"` rather than `manager: "uv"` but the user intent is preserved.
- **`cargo install <bin>` is a supply-chain action even though it doesn't mutate the project's Cargo.toml.** It pulls third-party code from crates.io and runs build scripts during compilation; the block-mode gate applies. Symmetric with npm/pip/yarn/bun/pnpm — their `install` verb is detected too, including global installs (`npm install -g foo`, `pip install --user foo`). The `install` verb on cargo landed after the rshrnk live-dogfood pass (2026-05-11) surfaced the asymmetry — the original cargo verb whitelist was `add update` only, leaving `cargo install ripgrep` invisible to the gate.
- **Preflight false-positive on commit messages mentioning supply-chain command shapes.** Same shape as secrets-scan's "commit messages mentioning compound syntax" trap. The hook reads the raw `tool_input.command`; a commit message body containing literal `cargo install <bin>` or `npm install <pkg>` matches the manager+verb pair just like a real install would. Mitigations: (a) reword the body, or (b) append a multi-line OVERRIDE marker on its own line *outside* the heredoc — `git commit -m "$(cat <<'EOF' ... EOF\n)"\n# OVERRIDE: <reason ≥10 chars>`. The marker line is a no-op bash comment but the hook sees it via the start-of-line anchor. Caught when committing the cargo-install verb-list fix itself (2026-05-11) — recursive dogfood.
