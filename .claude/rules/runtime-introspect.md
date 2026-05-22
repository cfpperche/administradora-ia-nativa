---
paths:
  - ".claude/hooks/runtime-*.sh"
  - ".claude/tools/probe.sh"
  - ".claude/.runtime-state/**"
---

# Runtime introspect

A capacity that gives the agent runtime evidence about its own work so it can close edit→verify loops without depending on human ratification or static-code reading alone. A `PostToolUse(Bash)` hook captures the last test/build/typecheck command output to a single state file; a shell tool reads it back in a shape the agent can pattern-match.

The wedge is deliberately framework-agnostic and minimal — it complements mature external MCPs (Laravel boost, Playwright MCP, Chrome DevTools MCP, DBHub, next-devtools-mcp, rails-mcp-server) by filling the gap none of them covers: generic local test/build capture. Forks layer the external MCPs into their own `.mcp.json` when they need browser/DB introspection.

## What fires, what captures

**Pre-mark — `PreToolUse(Bash)` → `.claude/hooks/runtime-pre-mark.sh`.** Tiny hook. Stamps `started_at` (ISO-8601 UTC) for the current `tool_use_id` into `.claude/.runtime-state/in-flight/<id>.t` so the post hook can compute `duration_ms`. Silent skip when `tool_use_id` is absent. Always exits 0.

**Capture — `PostToolUse(Bash)` AND `PostToolUseFailure(Bash)` → `.claude/hooks/runtime-capture.sh`** (registered on both events). Reads stdin JSON, escape-hatches on `CLAUDE_SKIP_RUNTIME_INTROSPECT=1`, tokenises `tool_input.command` (twin to `.claude/hooks/supply-chain-scan.sh`'s tokeniser — same chain/pipe/redirect terminators and value-taking flag skip), matches against the v1 detector pair list plus `CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT` globs. On a match: reads the failure body from `tool_response.stdout`/`stderr` (PostToolUse path, success) OR from top-level `.error` (PostToolUseFailure path, failure — `tool_response` is absent, `is_interrupt` replaces `tool_response.interrupted`; payload divergence verified empirically); computes duration from the in-flight start mark (best-effort, `null` if missing) with harness `duration_ms` preferred; clamps each stream to 4 KB head + 4 KB tail with a `*_truncated` flag; writes `.claude/.runtime-state/last-run.json` atomically (`mktemp + mv`). When the event is PostToolUseFailure AND inference table missed, `inferred_status` defaults to `FAIL` — the event itself is authoritative signal of verifier failure (basis: `"PostToolUseFailure event (pattern table missed)"`). Non-matches exit silently with no state write. Always exits 0 — capture failure is invisible to the underlying Bash; one diagnostic line goes to stderr only when `CLAUDE_RUNTIME_INTROSPECT_DEBUG=1`.

**Probe — `.claude/tools/probe.sh`.** Bash + jq. Single `last-run` subcommand in v1. Reads the state file, computes status (`PASS` exit==0, `FAIL` exit!=0, `UNKNOWN` exit missing/non-numeric), computes age from `started_at` vs now, computes `stale` by comparing `started_at` against `.claude/.session-state/started-at`, emits a structured plain-text block the agent can pattern-match (status / command / exit / age / stale header, then `--- stdout (head) ---` / `--- stdout (tail) ---` / `--- stderr ---` markers). Missing state → friendly empty-state message naming an example invocation (`bun test`, `pytest`, etc.); exit 0. Unknown subcommand → exit 2 with one-line usage hint.

**SessionStart hint — `.claude/hooks/session-start.sh`.** Existing hook is extended to append one line after the SESSION.md / COMPACT_NOTES.md block, naming the probe path and example invocation, so the agent discovers the capability without reading this rule cold.

## Detector pair list (v1)

Detection is tokenisation-based, twin to `.claude/hooks/supply-chain-scan.sh`. Matches at least one non-flag positional after the verb (otherwise the command is a no-op like `bun install` without args). Pair list:

| Pair | Notes |
| --- | --- |
| `bun test` | Bun's native test runner |
| `bun tsc` | `bun tsc --noEmit` typecheck; pass-through to TypeScript compiler |
| `bun run <script>` | Only when `<script>` contains `test`, `build`, `typecheck`, or `lint` substring. `bun run dev` is NOT a verifier (long-running server) and is skipped. |
| `npm test` / `npm run test` | npm test conventions |
| `npm run build` / `npm run typecheck` / `npm run lint` | npm's verify-shaped scripts |
| `pnpm test` / `pnpm run test` / `pnpm run build` / `pnpm run typecheck` / `pnpm run lint` | pnpm equivalents |
| `yarn test` / `yarn build` / `yarn typecheck` / `yarn lint` | yarn equivalents |
| `pytest` / `python -m pytest` / `python3 -m pytest` | Python testing |
| `python -m unittest` / `python3 -m unittest` | stdlib unittest |
| `cargo test` | Rust's native test runner (cargo workspaces walk all members by default) |
| `cargo build` | Rust compile (release/dev profile) |
| `cargo check` | Rust typecheck-equivalent (no codegen, fastest verifier) |
| `cargo clippy` | Rust lint analog of biome/ruff; `cargo clippy -- -D warnings` promotes warnings to errors |
| `vendor/bin/phpunit` / `./vendor/bin/phpunit` | Single-token PHP test runner (PHPUnit) |
| `vendor/bin/pest` / `./vendor/bin/pest` | Single-token PHP test runner (Pest, wraps PHPUnit) |
| `php artisan test` | Laravel's `artisan test` command (typically wraps Pest or PHPUnit). Pair-token match on `artisan test` — the leading `php` is the shell context |
| `composer test` / `composer lint` | Composer-script wrappers — common pattern in Laravel forks where `composer.json` `scripts.test` aliases the test runner |

**Extension via env var (HUMAN-ONLY, pre-launch).** `CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="<space-separated globs>"` adds custom runners without modifying the hook. Example: `CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="make-test just-check"` accepts `make test` and `just check`. The hook normalises the matched pair to `extra:<glob>` in the `detector` field so audits stay distinguishable from core detections. **The variable must be exported in the shell BEFORE `claude` launches** — agents cannot set it mid-session via a Bash tool call. Reason: the hook is spawned by the Claude Code harness as a sibling process, inheriting the harness's env, not the Bash tool child shell's env (verified empirically by rshrnk dogfood B3, finding #6 — see § Gotchas). When a stack needs a new detector and the human can't pre-launch (or doesn't want to), the path is a follow-up spec extending the native detector list, not the env-var workaround.

The list is deliberately small. The supply-chain capacity proved that strict pair lists with env-var extension beat generous regex fallbacks — the latter consistently leaks false positives (e.g. `cat README | grep test` would match a `*test*` heuristic).

## `last-run.json` schema

Single snapshot, overwritten on every matched capture. JSON shape (post live-dogfood pass on /home/goat/shrnk, 2026-05-11):

```json
{
  "command": "bun test src/server.test.ts",
  "detector": "bun-test",
  "exit": null,
  "interrupted": false,
  "inferred_status": "PASS",
  "inference_basis": "bun-test: '0 fail' line",
  "started_at": "2026-05-11T17:14:43Z",
  "ended_at": "2026-05-11T17:14:44Z",
  "duration_ms": 118,
  "session_id": "01HZX...",
  "agent_id": null,
  "stdout_head": " 10 pass\n 0 fail\n 17 expect() calls...",
  "stdout_tail": "",
  "stdout_truncated": false,
  "stderr_head": "",
  "stderr_tail": "",
  "stderr_truncated": false
}
```

- `command` — raw `tool_input.command` (no shell rewrite).
- `detector` — pair-list key that matched. Core: `bun-test`, `bun-tsc`, `bun-run-test`, `bun-run-typecheck`, `bun-run-build`, `bun-run-lint`, `npm-test`, `npm-run-test`, `pnpm-test`, `pnpm-run-typecheck`, `yarn-test`, `yarn-typecheck`, `yarn-build`, `yarn-lint`, `pytest`, `python-pytest`, `python-unittest`, `cargo-test`, `cargo-build`, `cargo-check`, `cargo-clippy`. Extension: `extra:<key>`.
- `exit` — integer from `tool_response.exit_code` when the harness surfaces it; **`null` under Claude Code today** (the Bash tool_response carries `{stdout, stderr, interrupted, isImage, noOutputExpected}` and no exit field — confirmed by live-dogfood capture). Other harnesses may surface it; the field is read defensively.
- `interrupted` — boolean from `tool_response.interrupted`. `true` overrides everything downstream to status `INTERRUPTED`.
- `inferred_status` — `PASS` / `FAIL` / `UNKNOWN` / `INTERRUPTED`, computed from runner-specific stdout/stderr patterns (see below). Always set; the probe uses it as the canonical status when `exit` is `null`.
- `inference_basis` — short string explaining which pattern matched (e.g. `bun-test: '0 fail' line`). Auditable.
- `started_at` / `ended_at` — ISO-8601 UTC. `started_at` from the PreToolUse in-flight mark; `ended_at` is hook-write time.
- `duration_ms` — integer or `null`. **Prefer the harness's top-level `duration_ms`** when present (real millisecond wall clock); fall back to date-second diff only when absent.
- `session_id` / `agent_id` — pass-through from the hook payload (`agent_id` is `null` for parent edits).
- `stdout_head` / `stdout_tail` — first 4096 bytes / last 4096 bytes of `tool_response.stdout`. When total length ≤ 8192 bytes, `stdout_head` holds the whole stream and `stdout_tail` is `""`.
- `stdout_truncated` — `true` iff clamping engaged (`len > 8192`). Same shape for `stderr_*`.

### Inference heuristics

Per-detector pattern tables, run against combined `stdout + stderr` (since some runners emit summaries on stderr). Updated when a real-world runner output surfaces that the table misses.

- **Test runners** (`bun-test`, `npm-test`, `pnpm-test`, `yarn-test`, `*-run-test`): `^[[:space:]]*0 fail[[:space:]]*$` → PASS; `[1-9][0-9]* fail` → FAIL; `failed|✗|error` → FAIL; `pass|✓|ok` → PASS (weak).
- **pytest / unittest** (`pytest`, `python-pytest`, `python-unittest`): `[1-9][0-9]* (failed|error)` → FAIL; `[0-9]+ passed` (no `failed|error`) → PASS; `^FAILED` → FAIL; `^OK` → PASS.
- **Typecheck / build / lint** (`bun-tsc`, `yarn-typecheck|build|lint`, `*-run-typecheck|build|lint`): `error TS[0-9]+` → FAIL; output < 500 chars and no `error|fail` keyword → PASS (clean-output heuristic).
- **Cargo test** (`cargo-test`): `^test result: ok` → PASS; `^test result: FAILED` → FAIL. Canonical test-runner summary line, anchored at start-of-line. Multiple `test result:` lines under `--no-fail-fast` or workspace walks — first FAIL wins (any failure flips overall status).
- **Cargo typecheck / build / lint** (`cargo-check`, `cargo-build`, `cargo-clippy`): `error\[E[0-9]+\]` → FAIL (rustc compiler error code shape); `^error:` → FAIL (clippy `-D warnings` promoted-warning lines + rustc fatal summary "could not compile" lines); `[[:space:]]+Finished` → PASS (cargo's canonical clean-completion line). The Finished-line PASS signal is deliberately preferred over a character-count heuristic because cargo output frequently exceeds 500 chars in multi-crate projects due to per-crate `Compiling ...` lines.

`interrupted=true` trumps any inference → status `INTERRUPTED`.

## Probe output shape

`bash .claude/tools/probe.sh last-run` emits plain text:

```
status: PASS
command: cd /home/goat/shrnk && bun test
detector: bun-test
exit: null
inferred_status: PASS
inference_basis: bun-test: '0 fail' line
age: 1s
duration_ms: 118
stale: false

--- stdout (head) ---
 10 pass
 0 fail
 17 expect() calls
Ran 10 tests across 2 files. [34.00ms]

--- stderr ---
(empty)
```

The `status` header is the canonical outcome the agent reads. When `exit` is numeric (some non-Claude harness), `status` mirrors that (`0` → PASS, else FAIL). When `exit` is `null` (Claude Code today), `status` mirrors `inferred_status`. When `interrupted=true`, `status` is `INTERRUPTED` regardless. The `inference_basis` line is only emitted when inference is doing the work — it documents which pattern matched, so a failing inference can be audited and the table extended.

When the state file is missing:

```
status: no-snapshot
hint: run a recognised verifier (e.g. `bun test`, `pytest`) then re-query with `bash .claude/tools/probe.sh last-run`.
```

The shape is plain text by design — agents read stdout, not structured tool returns, in v1. JSON output is a candidate v2 if MCP promotion happens.

## Escape hatches

- **`CLAUDE_SKIP_RUNTIME_INTROSPECT=1`** — disables both hooks silently. No capture, no probe writes. For throwaway scratch sessions; do NOT set in long-lived shell config (silent permanent disable).
- **`CLAUDE_RUNTIME_INTROSPECT_DEBUG=1`** — opts INTO stderr diagnostic lines from the capture hook (default off — never pollute stderr in normal use). One line per noteworthy event: detector match, write success, tail-clamp engaged. Default is silent because PostToolUse stderr is ingested into the agent's next-turn context (issue #24327) and noise would dilute real signal.
- **`CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="<globs>"`** — adds custom pair detections (see § Detector pair list). **MUST be set in the shell before `claude` launches** — not settable mid-session by an agent (see § Gotchas).

Missing `jq`: both hooks fail open (`exit 0`, no capture). The probe tool prints a one-line "jq not found — probe disabled" message and exits 0. A broken dependency must never permanently lock the agent out.

## State file (no audit log)

`.claude/.runtime-state/last-run.json` — single file, gitignored, overwritten on every matched capture. Concurrent matched runs race on `mktemp + mv` semantics; POSIX rename atomicity guarantees no torn writes, and last-writer-wins is the design (snapshot = latest, not history).

In-flight start marks live at `.claude/.runtime-state/in-flight/<tool_use_id>.t` (touched by the pre-mark hook, removed by the capture hook). Stale marks (older than 1h) are not auto-pruned in v1 — disk impact is negligible (one zero-byte file per Bash invocation) and pruning complexity isn't paying for itself yet.

**Deliberate non-feature: no per-Bash audit JSONL.** The supply-chain capacity writes one row per Bash call (including `skip-not-install`) and the well-documented forensic noise that follows (see `.claude/rules/supply-chain.md` § Gotchas). This capacity does NOT mirror that pattern — `last-run.json` is self-sufficient for the "latest evidence" use case the agent has, and adding an audit layer would dilute the signal-to-noise ratio at the same scale. A follow-up spec adds an audit layer if forensic queries become a real need.

## Gotchas

- **Claude Code's `tool_response.exit_code` does NOT exist (live-dogfood 2026-05-11).** The Bash tool's PostToolUse `tool_response` carries `{stdout, stderr, interrupted, isImage, noOutputExpected}` only. No exit code, no error type. Status inference IS the canonical signal under Claude Code; the `exit` field is preserved in schema for forward-compat with other harnesses or future Claude Code releases. When introducing new detectors, the inference branch is mandatory. **Related:** `PostToolUse(Bash)` itself fires only on exit-zero — failing Bash commands skip this hook entirely and route to `PostToolUseFailure(Bash)` instead. The capture hook is registered on both events and teaches itself the divergent PostToolUseFailure payload shape (no `tool_response`; failure body at top-level `.error`; `is_interrupt` replaces `tool_response.interrupted`).
- **Top-level `duration_ms` IS in the payload.** Real wall-clock milliseconds, populated by Claude Code on PostToolUse. Use it; the PreToolUse in-flight mark + date-second diff is the (less accurate) fallback. The live-dogfood pass showed 118 ms harness-supplied vs 1000 ms second-rounded — order-of-magnitude noise removed.
- **`tool_response` truncation risk.** PostToolUse(Bash) carries the captured stdout/stderr in `tool_response`, BUT the harness may truncate large outputs before the hook sees them. The hook's tail clamping happens against whatever reached it — if upstream truncation engages, the snapshot reflects the pre-truncated view, not the original. Mitigation: probe with a known-noisy `bun test` invocation before relying on this; live-dogfood verified shrnk's ~150-byte test output survives end-to-end. Long-term fallback (not in v1): read the last assistant message's `tool_result` block from `transcript_path`.
- **Probe inside the SAME Bash tool call does NOT see its own capture.** PostToolUse fires AFTER the underlying Bash command returns. A command of the shape `bun test && bash .claude/tools/probe.sh last-run` will probe the PREVIOUS snapshot, not the one being produced. To read the current run's snapshot, the probe must be in the agent's *next* Bash invocation. Discovered during dogfood pass 1 — documented so the agent doesn't construct false negatives.
- **Tokeniser drift with supply-chain-scan.** Both hooks tokenise `tool_input.command` with the same separator/value-flag rules. They are currently DUPLICATED with a cross-reference comment, not extracted to `.claude/lib/`. If a third consumer arrives, extract to `tokenize.sh` then — see `.claude/rules/supply-chain.md` § Gotchas ("Package-collection terminators") for the rule set both must keep in sync.
- **`bun run <script>` keyword filter is heuristic.** Captures only when the script name contains `test` / `build` / `typecheck` / `lint`. `bun run dev` (long-running server) is correctly skipped; `bun run frontend:test` is correctly captured; `bun run preflight` (a build-shaped script with a non-keyword name) is SKIPPED. The miss is acceptable — the human can extend via `CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT` pre-launch (NOT settable mid-session by the agent; see gotcha below) or rename the script.
- **SessionStart hint is one line.** Agents may scan past it. The hint exists for discoverability, not for forced behaviour. Reinforce in `.claude/rules/tdd.md` and PR reviews that the probe is the canonical way for the agent to verify its own work; consider PostToolUse(Edit) nudge as a v2 if dogfood shows under-use.
- **Concurrent Bash capture races.** Two parallel matched commands race the state file write. POSIX rename atomicity → no torn writes; last-writer-wins by design. The in-flight directory keeps per-invocation start marks separate so durations stay accurate even under concurrency.
- **Commit-message FP.** Same shape as the supply-chain "commit messages mentioning compound syntax" gotcha. A heredoc'd commit body containing literal `bun test` would tokenise as a runner. The tokeniser only collects pair tokens at top-level command segments (after `&&` / `||` / `;` separators, not inside quoted strings); reuse of the supply-chain tokeniser shape inherits this protection. Recursive dogfood (committing 011 itself) is the canonical test of this — see `.claude/rules/supply-chain.md` § Gotchas for the precedent fix.
- **No `bun install` / `npm install` capture.** Those are dep mutations, not verifiers — they belong to the supply-chain capacity's scope, not this one. This capacity captures *the act of verifying*, not *the act of installing*. Don't add install verbs to the detector list; the FP cost (any install would dilute the "latest test result" semantics) would erase the value.
- **`bun tsc --noEmit` exit code is verifier signal.** TypeScript's `tsc` returns 0 on clean, non-zero on errors — clean PASS/FAIL maps. Don't conflate this with the lint advisory in the validator (see `.claude/validators/run.sh`); this capacity surfaces the latest run, not the validator's per-edit signal.
- **`CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT` glob shape.** Space-separated globs interpreted as `<tool>-<verb>` keys joined by hyphen (e.g. `make-test` → matches `make test`). Glob meta-chars beyond shell word-split are NOT supported in v1 — keep entries flat. If a fork needs richer matching, extend the parser; until then, prefer multiple flat entries.
- **`CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT` is NOT settable mid-session by the agent (rshrnk dogfood B3 finding #6, 2026-05-12).** Both inline-prefix form (`VAR=val cargo test`) and same-Bash-call `export VAR=val; cargo test` fail to propagate the env to the hook. Root cause: when the agent runs a Bash tool call, the harness spawns a child shell to execute the command; in parallel, the harness spawns the registered `PostToolUse(Bash)` / `PostToolUseFailure(Bash)` hooks as **its own children** (siblings to the bash child, NOT children of it). Sibling processes do not inherit each other's env mutations — the hook reads the harness's env, not the bash child's. `settings.json` has no `env` injection mechanism (`jq 'keys' settings.json` returns only `["hooks"]` + `["permissions"]` etc., no `env`). Consequence: the env-var extension path is reserved for the **human** — set in the parent shell before launching `claude`. Agents needing a new detector mid-session have no workaround; the correct fix is a follow-up spec extending the native detector pair list (the cargo case was the original trigger — closed by adding native `cargo test|build|check|clippy` detection). A theoretical mid-session injection mechanism (file-based extra-detect under `.claude/.runtime-state/`) is a candidate spec only if symmetry between human-pre-launch and agent-mid-session becomes a real need for OTHER undetected stacks (gleam, deno, etc.); until then, native-detector extension is the canonical path.
- **Cargo workspaces use the same detector, no special handling.** A workspace with `[workspace.members]` walks all members on `cargo test` / `cargo check` / etc. by default. Each member crate emits its own `test result:` summary line, and cargo emits a single `Finished` line at the workspace level on clean completion. The inference table's first-FAIL-wins behavior is correct: any single `test result: FAILED` flips the overall snapshot to FAIL even if other crates passed. A workspace member that fails compilation surfaces an `error[E0xxx]:` or `^error:` line — same FAIL path. No multi-crate awareness needed in the hook; the monorepo-stack-detect capacity is the right place for multi-stack reasoning if it ever becomes a concrete need.
- **First-fork friction.** A fresh fork that runs `bun test` for the first time will see no probe hint until session start. The capacity activates the moment the hooks are registered and `bun test` matches the allowlist — nothing in the fork's setup blocks this. The escape hatch (`CLAUDE_SKIP_RUNTIME_INTROSPECT=1`) is the per-session opt-out, not a permanent disable.
- **ANSI escape sequences in runner output stripped at storage (shrnk-mono dogfood 2026-05-12).** Bun's test runner and many other modern verifiers emit colored output (e.g. `\e[32m 0 fail\e[0m`). Pre-fix, the line-anchored regex `^[[:space:]]*0 fail[[:space:]]*$` did NOT match because color codes prefixed the line, forcing inference to fall through to the weak `pass|✓|ok` keyword heuristic. Status was still PASS (correct outcome), but `inference_basis` read `pass/ok keyword (weak heuristic)` instead of the canonical `'0 fail' line` — degrading the auditable signal. Fix: `runtime-capture.sh` strips ANSI sequences (`\x1b\[[0-9;]*[a-zA-Z]`) from `STDOUT_RAW`/`STDERR_RAW` after collection, before storage AND inference. Stored snapshots now have clean text — LLM agents reading probe output don't render colors anyway, so the codes were pure noise. Regression guarded by test 16. The `printf x` sentinel trick is reused in the strip path so trailing newlines survive command substitution (test 04 asserts byte-exact `stdout_head`).
