---
paths:
  - ".claude/hooks/secrets-*.sh"
  - ".claude/secrets-audit.jsonl"
  - ".githooks/**"
  - ".gitleaks.toml"
---

# Secrets scan

Two layers keep credentials out of the repo, plus a soft-advisory hook on edits. Same primitives as the governance and delegation gates — stdin JSON, `# OVERRIDE:` escape, JSONL audit log.

## What fires, what advises

**Primary block — `.githooks/pre-commit` (native git hook).** Activated per-fork by `git config core.hooksPath .githooks` once after `git init`. Fires inside git's commit process *after* staging finalises — so a compound `git add ... && git commit ...` invocation still sees the real index. Runs `gitleaks git --pre-commit --staged --no-banner --report-format=json --report-path=<mktemp>` from repo root and parses the report defensively. Blocks on findings with exit 1 (NOT 2 — native pre-commit convention); passes with `decision: "override"` when `CLAUDE_SECRETS_OVERRIDE_REASON` is set; fail-open on missing gitleaks or unparseable JSON. `scan_mode: "native-pre-commit"`; `session_id` and `agent_id` are `null` (no Claude Code payload). Full decision values in § *Audit log*.

**Preflight shape-gate — `PreToolUse(Bash)` → `.claude/hooks/secrets-scan.sh`.** Broad matcher (any Bash with `git`); the script short-circuits with `skip-not-commit` unless the command is a real `git commit` (covers `git commit`, `git  commit` double-space, `git -C <path> commit`, `git commit --amend`). On a real commit it does NOT call gitleaks — that's exclusively the native layer's job. Instead: (a) parses `# OVERRIDE: <reason ≥10 chars>` (start-of-line anchored); (b) rejects compound `&& git commit` / `; git commit`, `git commit -a` / `-am` / `-ma`, `--no-verify` when no override is present, emitting the verbatim corrected stderr template (issue #24327 mitigation — see § *Gotchas*); (c) on valid override, rewrites the command to prepend `export CLAUDE_SECRETS_OVERRIDE_REASON='<reason>'; ` and outputs `{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":"<rewritten>"}}}` on stdout so the native layer inherits the env var; (d) clean shape, no marker → silent `passthrough`. All preflight rows carry `scan_mode: "preflight"` and capture `session_id` + `agent_id` (which the native layer cannot).

**Soft advisory — `PostToolUse(Edit|Write|MultiEdit)` → `.claude/hooks/secrets-advise.sh`.** Opt-in via `CLAUDE_SECRETS_ADVISE_ON_EDIT=1`. Sub-agent only — exits 0 silently for parent edits, matching the actor split in `.claude/rules/delegation.md` § *Post-edit validator loop*. On a delegated edit, runs gitleaks against the new content in a temp dir; each finding becomes one `secrets-advisory: <detector> at <file>:<line>` stderr line. Always exits 0 — never blocks, never reverts, never enters the commit audit log. Same shape as `tdd-advisory:` (see `.claude/rules/tdd.md` § *Reading the validator advisory*).

Matcher-is-broad / script-is-precise on the preflight is deliberate: false fires short-circuit cheap; missed fires would be unscanned commits.

## Override grammar

A line matching `^[[:space:]]*# OVERRIDE: <reason>` in `tool_input.command` skips shape-rejection. **Start-of-line anchored** (with optional leading whitespace) — copied from the 002-delegation fix that closed a `# OVERRIDE:` -inside-quoted-string false-positive. Inline-trailing markers on a single line are NOT accepted; they re-open the regression and were dropped. Legitimate single-shape usage is a **two-line Bash command**:

```bash
git commit -m "land auth-test fixture"
# OVERRIDE: AWS key is a documented test vector for the auth fixture suite
```

Bash treats line 2 as a no-op comment; the preflight matches it via the anchor. Compound form:

```bash
git add tests/fixtures/aws-key.txt && git commit -m "fixture"
# OVERRIDE: documentation test vector for AWS detector regression suite
```

`<reason>` must be ≥10 characters after trim — shorter values (`skip`, `n/a`) are rejected with `secrets-scan: override reason must be ≥10 characters, got "<reason>"` and the command still blocks. Same 10-char floor as the governance and delegation gates.

### Env-var bridge

The override marker lives in `tool_input.command` — visible to the preflight (stdin JSON) but invisible to the native hook (no Claude Code payload, and the shell strips `#`-comments before git runs). The bridge is `CLAUDE_SECRETS_OVERRIDE_REASON`: the preflight prepends `export CLAUDE_SECRETS_OVERRIDE_REASON='<escaped-reason>'; ` (single-quoted, with the close-escape-open `'\''` idiom against shell injection). The `export` makes the var inheritable; every chained command sees it; the native hook reads it and audits `override`.

The injection MUST be `export VAR='...'; cmd` (standalone statement + `;`), NOT the inline prefix `VAR=val cmd`. The prefix form scopes the assignment to its single command — on `VAR=val git add foo && git commit -m "..."` the var reaches `git add` but NOT the chained commit, so the native hook blocks. Latent bug, fixed in `4b47a42`; V4 test (`.claude/tests/secrets-scan/04-override-allows.sh`) asserts the rewriting starts with `export CLAUDE_SECRETS_OVERRIDE_REASON=` as a regression guard.

Override semantics are surgical: the marker skips ONLY the preflight shape rejection (compound / `-a` / `--no-verify`) AND the native block (when findings are present). The scan still runs, both audit rows are still written, `override_reason` is populated. No silent bypass.

## Allowlist mechanics

Two complementary suppression mechanisms, both honored by gitleaks at scan time:

**`.gitleaks.toml` at repo root.** The starter uses `[extend].useDefault = true` to inherit gitleaks' built-in detectors, then a singular `[allowlist]` table exposes the three suppression dimensions:

- `paths = ['''tests/fixtures/.*''', '''secrets-scan\.md''']` — regular expressions matched against each file path (NOT globs — `.*` not `**/*`). Anything matching is skipped wholesale.
- `regexes = ['''AKIA[0-9A-Z]{16}''', '''ghp_[A-Za-z0-9]{36}''']` — TOML triple-quoted regex strings; matches in any file are suppressed.
- `commits = ["abc123def456..."]` — full SHAs. Useful when a historical commit is known-clean and the scan keeps re-flagging it via amend or rebase.

Use the singular `[allowlist]` table, **not** the plural `[[allowlists]]` array-of-tables — gitleaks 8.21.x silently ignores the plural form (it parses without error but no exemption ever applies; empirically verified 2026-05-19 against gitleaks 8.21.2). The starter ships one real entry — `paths = ['''secrets-scan\.md''']` — because this rule doc itself carries synthetic fake credentials (see § *Gotchas*, the `AKIA…`-class fakes) that gitleaks would otherwise flag on a fresh fork's first commit; replace or extend that entry, do not delete it. Schema: <https://github.com/gitleaks/gitleaks/blob/master/config/allowlist.go>. Do **not** ship a `.secrets.baseline` (detect-secrets pattern); non-goal since Agent0 is a new-repo template with no legacy to freeze.

**Inline `gitleaks:allow`.** A comment containing `gitleaks:allow` on the same line as a high-entropy string suppresses that single finding without modifying `.gitleaks.toml`. Comment form is language-appropriate — `# gitleaks:allow` (shell/Python/TOML), `// gitleaks:allow` (JS/TS/Rust), `<!-- gitleaks:allow -->` (Markdown/HTML). Prefer inline for one-off lines; prefer `.gitleaks.toml` paths for whole directories.

## Escape hatch

`CLAUDE_SKIP_SECRETS_SCAN=1` makes both hooks exit 0 silently — no scan, no audit. For throwaway scratch sessions; do NOT set it in a long-lived shell config (silent permanent disable). Use the override marker for "this commit despite the finding"; the env var for "this whole session is throwaway".

Inverse-polarity twin for the advisory: `CLAUDE_SECRETS_ADVISE_ON_EDIT=1` turns it **on** (default off, so it doesn't surprise unreaders).

Missing gitleaks: both hooks fail open with `secrets-scan: gitleaks not found, scan skipped` on stderr (native audits `skip-no-engine`); preflight shape-gate still runs since it never depends on gitleaks. The template is stack-agnostic; a broken engine must never permanently lock the agent out of committing.

## Audit log

`.claude/secrets-audit.jsonl`, gitignored, append-only, `flock`-atomic. Every invocation of either commit-time layer writes exactly one line. Decision values split cleanly by layer:

| Decision | Layer | Meaning |
| --- | --- | --- |
| `skip-not-commit` | preflight | Command does not match `git commit` shape; harness passes through |
| `passthrough` | preflight | Real `git commit`, clean shape, no override — fall through to native |
| `reject-shape` | preflight | Compound / `-a` / `--no-verify` without override; exits 2 with corrected template on stderr. `cmd_shape` names which pattern matched (`compound-and`, `compound-semicolon`, `git-commit-dash-a`, `git-commit-no-verify`, `override-too-short`) |
| `override-pass-through` | preflight | Valid override marker parsed; command rewritten with `export ...;` prefix; `override_reason` populated |
| `allow` | native | gitleaks ran clean over a non-empty staged diff |
| `allow-empty` | native | `staged_files_count == 0` (e.g. `--allow-empty` commits); distinct from `allow` so the original silent-failure mode is unreproducible |
| `allow-parse-error` | native | gitleaks JSON unparseable; fail-open with forensic signal preserved (NOT collapsed into `allow`) |
| `override` | native | Findings present and `CLAUDE_SECRETS_OVERRIDE_REASON` set; reason populated |
| `block` | native | Findings present, no override, exit 1 (native pre-commit convention) |
| `skip-no-engine` | native | gitleaks missing from PATH; fail-open |

Both layers tag `scan_mode` (`"preflight"` / `"native-pre-commit"`) so a single `jq` can split or join. Preflight rows include `session_id` + `agent_id`; native rows have those `null` (git's commit process is outside Claude Code's payload reach). The advisory hook does **not** write here — advisories are a stderr stream. Read with `jq -c .` or `tail -f`.

## Gotchas

- **`.claude/.browser-state/*.json` are credential-class files.** Playwright MCP's `browser_storage_state` writes session cookies + localStorage to `.claude/.browser-state/<host>.json`; leaking one is equivalent to leaking a password. `.gitignore` is the primary defense (the sentinel `.gitkeep` is committed; state files are not). If gitleaks detects a high-entropy string inside a state file that was accidentally staged, treat it as a real credential finding — see `.claude/rules/mcp-recipes.md` § Authenticated workflow.
- **`core.hooksPath` activation is MANUAL by design — Lazarus 2025 vector.** Do NOT install via a post-clone, post-checkout, or `git init` template hook. That automation pattern is the exact mechanism used by the 2025 Lazarus Group "Contagious Interview" campaign to deliver malware via poisoned developer repos. The README per-fork checklist is the right place — the fork developer types it once after `git init`, consciously. Cost: one documented step. Benefit: a malicious downstream fork cannot silently activate hooks just by being cloned. A SessionStart hint surfaces the activation command at session start when `.githooks/` is present but `core.hooksPath` is not set — see `.claude/hooks/session-start.sh` § githooks-activation. `CLAUDE_SKIP_GITHOOKS_HINT=1` suppresses it.
- **`--no-verify` discipline.** The flag bypasses the native hook entirely. The preflight rejects it with a verbatim stderr template so the agent can pattern-match the correction. Dropping the flag is the canonical fix; the override marker is the emergency exit for deliberate bypass.
- **Global `core.hooksPath` shadowing.** Repo-local `git config core.hooksPath .githooks` wins over a `--global` setting. But a fork that *forgets* the install step inherits the global value (usually not pointing at `.githooks` in this repo), and the native hook silently does not fire. Preflight's `passthrough` audit still records the attempt — post-hoc forensics catch this, live signal does not. Verify with `git config --get core.hooksPath` returning `.githooks` as part of the install step.
- **`git commit -a` shape rejection.** The `-a` flag auto-stages tracked-file modifications, skipping explicit `git add`. The preflight rejects `-a` (and bundles `-am` / `-ma`) because the auto-stage happens inside git's pre-commit process — by then the audit trail is muddier and the override bridge is harder to reason about. Corrected form (`git add -u` + `git commit -m "..."`) is in the verbatim stderr template. `--all` (long form) is NOT rejected — only short `-a` and bundles.
- **Claude Code issue #24327: stderr ingestion on exit-2 blocks.** When a hook exits 2 with a stderr message, Claude Code's harness ingests the stderr into the agent's next-turn context as a "what went wrong" signal — agents pattern-match it to decide the next action. The shape-rejection templates therefore end with the EXACT corrected form (`git add <files>` newline `git commit -m "..."`) so the agent can copy-paste without semantic reasoning. If the templates drift in wording, the correction loop degrades from "mechanical pattern match" to "infer the intent from prose" — slower and more error-prone. Treat the stderr templates as a contract, not friendly UI text.
- **Preflight false-positive on commit messages mentioning compound syntax.** The shape detector is regex-based and does NOT parse quoting. A commit message body containing literal `&& git commit` — e.g. a heredoc'd message documenting a compound-shape bug fix — will match compound-and and reject. Mitigations: reword the body, or use the multi-line override marker form. Same caveat for `# OVERRIDE:` in prose; the start-of-line anchor protects most cases but a marker on its own line within a heredoc still matches.
- **`# OVERRIDE: ...` survives the JSON payload.** Shell strips `# ...` comments before invoking the underlying binary, but both hooks receive the raw command string — the preflight via `tool_input.command` (stdin JSON), the native via the env var the preflight injected. Neither sees a stripped command. Same upstream-of-shell mechanic as the governance and delegation gates; verify experimentally if the payload shape changes in a future Claude Code release.
- **Parse gitleaks JSON defensively.** v8.x has been stable but field renames have happened. `jq // empty` fallbacks help — but mind the `false`-vs-missing collapse (see `.claude/rules/delegation.md` § *Gotchas (for hook maintainers)*). For array length, use `if type == "array" then length else -1 end` and surface raw gitleaks output to stderr on parse failure — that's the `allow-parse-error` audit value, separate from real `allow`.
- **FP noise on test fixtures.** Sub-agents writing realistic auth/payments fixtures will trip the detectors. Layered mitigations: inline `gitleaks:allow` for one-off lines, `.gitleaks.toml` paths for whole fixture dirs, the override marker for a single commit, the env var for throwaway sessions, source-level string-splitting (e.g. `"AKIA""1234567890ABCDEF"` — adjacent strings concatenate at parse time, regex scanners see a non-matching source) when even inline allowlist comments would trip a third-party scanner. Pick the narrowest tool that fits — broad escapes accumulate as silent debt.
- **Don't dogfood the block path with `AKIAIOSFODNN7EXAMPLE` (or other gitleaks stopwords).** Gitleaks' default ruleset includes a stopword list that explicitly exempts canonical AWS documentation examples — `AKIAIOSFODNN7EXAMPLE`, `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`, and similar pass with `finding_count: 0` even though their shape matches the AWS access-key regex. Empirically confirmed 2026-05-13: a Tier-2 dogfood committed `AKIAIOSFODNN7EXAMPLE` expecting a block; preflight wrote `passthrough` and native wrote `allow` (zero findings) — gate worked exactly as designed, the test input was the bug. Revert in `f2ae87f`. When validating the block path, use a synthetic non-stopword fake like `AKIAJZTRFAKEKEYABCDE` or `AKIAQQ7777FAKEKEY999` — same regex shape, no built-in exemption. Symmetric trap exists for GitHub PATs (`ghp_0000000000000000000000000000000000` and other zero-runs) and Slack/Stripe tokens. Reference: <https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml> (search `keywords`/`stopwords` on the AWS rule).
- **gitleaks version skew across forks.** Detector set and flag names evolve. Documented floor: v8.20+ (the `gitleaks git --pre-commit --staged` invocation form requires it; the deprecated `gitleaks protect --staged` shape is gone). The hook does not gate on a version check; a fork wanting a stricter floor documents it in their own CLAUDE.md, not here.
- **Audit-log append atomicity uses `flock`.** Both layers can fire concurrently (a preflight on one Bash invocation in parallel with a native hook on another terminal's commit). JSONL one-line appends are generally safe on Linux for writes ≤ `PIPE_BUF` (typically 4096 bytes), but `flock` is the explicit guarantee against partial-line interleaving. Both hooks follow the delegation-gate pattern — and its § *Gotchas (for hook maintainers)* documents the **sticky `exec 9>file 2>/dev/null` redirect** trap that bit this codebase before.
- **The native layer is hot on first fork — IF the install step is run.** Unlike the TDD validator (inert until a stack is detected), the secrets-scan capacity activates the moment a fork runs `git config core.hooksPath .githooks`. First-time block on a fixture: read this doc top-to-bottom, don't disable `core.hooksPath` or unset it permanently. The escape hatch (`CLAUDE_SKIP_SECRETS_SCAN=1`) and override marker are designed for exactly this case.
