# Routines

`.claude/routines/<slug>.md` is the project-scoped sibling of Claude Code's native `/schedule` skill. Where `/schedule` stores recurring agent runs on Anthropic's user-account cloud (the user-level memory analog), `.claude/routines/` git-tracks recurring intent at the repo level — propagating via clone, surviving fork via `.claude/tools/sync-harness.sh`, and visible in PR diff. It occupies the gap between three other state files in this project:

- **`.claude/SESSION.md`** — *in-flight* work-state (cross-session, this-machine handoff).
- **`.claude/REMINDERS.md`** — *one-shot deferred do-this-thing* items with no cadence.
- **`.claude/routines/<slug>.md`** — *cadence-driven recurring* work that the repo's contributors all benefit from.

The capacity exists because recurring project work otherwise leaks into the founder's head, a personal calendar, or `TODO` comments in code — all of which fail the "another developer cloning the repo on a fresh machine should inherit it" test. Routines pass that test by construction.

## When to use vs `/remind` vs `/schedule`

| Capacity | Cadence | Scope | Storage | Best for |
| --- | --- | --- | --- | --- |
| `/remind` | One-shot deferred | Project (git-tracked file) | `.claude/REMINDERS.md` | "Review pricing in Q3", "Circle back on caching when first user complains" — no recurring schedule. |
| `/routine` | Recurring (cron) | Project (git-tracked file) | `.claude/routines/<slug>.md` + state in `.claude/.routines-state/` | "Audit `cc-platform-hooks.md` against CC release notes every quarter", "Re-snapshot stack defaults every 90 days" — recurring work that any contributor benefits from. |
| `/schedule` (CC native) | Recurring (cron) | User (Anthropic cloud) | Anthropic backend | Personal automations tied to the user's account — cross-repo and cross-machine, but invisible to other contributors. |

Worked examples:

- "Update README after auth refactor lands" → `/remind` (one-shot, conditional on another event).
- "Weekly check that `bun test` still passes on the head of main" → `/routine` (recurring, repo-scoped, all contributors benefit from the safety net).
- "Remind me to renew the domain registration in 11 months" → `/schedule` (recurring annually, personal account, not a repo concern).

If both `/remind` and `/routine` seem to fit, the cadence question disambiguates: if it fires exactly once and is then dismissed, `/remind`; if it fires every N days/weeks/months indefinitely, `/routine`.

## Two-phase execution model

**Phase 1 (v1, ships today):** cron renders the routine prompt with fresh temporal context and writes it to `.claude/.routines-state/<slug>/queue/<unix-ts>.md`. The next interactive Claude Code session reads the queue via the `routines-readout.sh` `SessionStart` hook and surfaces a `=== ROUTINES ===` block; the human or Claude dispatches each pending routine via `/routine run <slug>`. **No Anthropic API key required.** The cron-side is purely a "render + enqueue" primitive; actual LLM execution happens in the next session.

**Phase 2 (future, when API key available):** `autonomous: true` opt-in frontmatter; cron-side invokes `claude -p` directly with the rendered prompt and writes output to PR / issue / file per the routine's `output:` declaration. Deferred per the rule-of-three demand test — built when ≥3 routines have demonstrated value in Phase 1 mode.

The Phase 1 design is deliberately human-in-loop. A routine that auto-commits without review is a foot-gun; surfacing the queue at SessionStart and requiring an explicit dispatch keeps the contract-not-promise discipline (see `.claude/rules/delegation.md` § *Why DONE_WHEN exists*) intact for every recurring action.

## Idempotency mandate (hard rule)

**Every routine MUST be idempotent.** Running the routine's prompt twice in succession MUST produce no destructive side effect — either the second run no-ops because state is already current, or it produces an identical artifact (same edit, same `no-drift-detected` log).

The `/routine validate <slug>` subcommand enforces this by rejecting any routine whose frontmatter declares `idempotent: false` (`exit 1` with `validate: idempotent: false is not allowed for routines. Use /remind for one-shot deferred work, or wrap the action in an idempotency-preserving guard (e.g. check-then-act).`). There is NO override marker for this — non-idempotent recurring work is wrong-shape for this capacity by construction.

Why so strict: the 4-layer N-fold defense (per `spec.md` § *N-fold prevention*) — leader flag, idempotency, claim file, human-in-loop readout — relies on idempotency as the safety net when the other layers fail. If two machines accidentally elect themselves leader and both enqueue, idempotent execution means the worst case is "I see the same nag twice", not "I have two duplicate PRs to clean up".

Practical patterns for keeping routines idempotent:

- **Check-then-act:** read current state, compute desired state, write only the diff. Example: "if `cc-platform-hooks.md` already references CC vX.Y, exit; else propose edit."
- **Date-windowed:** the routine's effect is keyed on a date window (`week-of`, `month-of`); re-running within the same window is a no-op.
- **PR-as-claim:** the routine opens a PR draft with a deterministic branch name (e.g. `routines/cc-knowledge-audit-2026-Q3`); the second run sees the branch exists and exits.

## Leader-flag model

Without coordination, every developer's machine running this repo's cron would execute every routine — N-fold spam. The leader-flag model picks one machine per repo via opt-in human designation.

**File:** `~/.claude/.agent0-routines-leaders.json` (user-scope, NOT in any repo; the `.agent0-` prefix namespaces against future CC config-file conflicts). Shape:

```json
{
  "/home/goat/Agent0": true,
  "/home/goat/mei-saas": false
}
```

Keys are absolute repo paths (resolved via `git rev-parse --show-toplevel`); values are booleans (`true` = this machine is the leader for that repo). `install-routines.sh` adds entries interactively; `uninstall-routines.sh` removes them.

**Flow:**

1. Developer clones repo on machine A, runs `./.claude/tools/install-routines.sh`. Script prompts: `Designate this machine as routines leader for /home/goat/Agent0? [y/N]`. Developer answers `y` (or `Y` / yes).
2. Same developer clones same repo on machine B, runs `install-routines.sh`. Script asks the same question. Developer answers `N` (default).
3. Machine A's cron fires; `run-routine.sh` checks the file, sees `true`, proceeds. Machine B's cron fires; checks file, sees `false`, exits 0 silently.

A repo with NO leader designated anywhere is also valid — `run-routine.sh` exits silently on every machine, and `routines-readout.sh` emits a `(no leader designated)` advisory on SessionStart so the developer knows to run `install-routines.sh` somewhere.

Switching the leader between machines: run `uninstall-routines.sh` on the old leader (removes the entry), then `install-routines.sh` on the new leader (adds the entry). Both scripts are idempotent — re-running them produces the same final state.

**Per-repo, not per-routine.** v1 designation is one-knob: "is this machine the leader for this repo?". Per-routine granularity (machine A runs routine X, machine B runs routine Y) was considered and rejected — it reintroduces the exact coordination problem this rule is built to avoid. If a real team need surfaces, that's a Phase 2 problem with real data.

## Frontmatter reference

Every routine file MUST have YAML frontmatter with the following keys:

| Key | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | string | yes | Slug, must equal the basename of the file (`name: cc-knowledge-audit` ↔ `cc-knowledge-audit.md`). |
| `schedule` | string | yes | 5-field cron expression. See § *Cron expression syntax* for accepted shapes. |
| `idempotent` | bool | yes | MUST be `true`. `false` is hard-rejected by `/routine validate`. |
| `on-stale` | string | no | `warn` (default) or `silent`. Controls behavior when a queue entry sits older than `stale-after-days`. |
| `stale-after-days` | int | no | Default `7`. Queue entries older than this trigger the `on-stale` policy at SessionStart. |
| `autonomous` | bool | no | Default `false`. Reserved for Phase 2 (autonomous `claude -p` execution); declaring `true` in v1 is a hard reject. |

Body shape (markdown after frontmatter):

```markdown
# Prompt

<the prompt body, dispatched as-is to Claude Code; interpolation placeholders allowed>

# Done when

<the contract — what the dispatched session must produce for the routine to count as done>
```

Both `# Prompt` and `# Done when` headers are required; `/routine validate` rejects files missing either.

### Interpolation placeholders

`run-routine.sh` substitutes the following placeholders in the prompt body at enqueue time:

| Placeholder | Value |
| --- | --- |
| `{{LAST_COMPLETED_TS}}` | ISO-8601 UTC timestamp of the last successful run (from `.claude/.routines-state/<slug>/last-completed.json`), or `"never"` if no prior run. |
| `{{GIT_HEAD}}` | Output of `git rev-parse HEAD` at enqueue time. |
| `{{REPO_ROOT}}` | Absolute path to repo root (`git rev-parse --show-toplevel`). |
| `{{NOW}}` | ISO-8601 UTC timestamp at enqueue time. |

Placeholders NOT listed above are left unsubstituted (no error, no warning) — additions require a code change to `run-routine.sh`.

## Cron expression syntax (and its limits)

`schedule:` accepts standard **5-field cron expressions** interpreted in the machine's local timezone (matching `crontab -e` defaults). Field order: `minute hour day-of-month month day-of-week`.

Each field accepts:

- `*` — match all values
- `N` — exact integer match
- `N-N` — inclusive range
- `N/N` — step (e.g. `*/15` in minutes = every 15 minutes)
- `N,N,N` — comma-separated list

**Not supported** (rejected by `/routine validate` with explicit error):

- Special strings: `@reboot`, `@yearly`, `@annually`, `@monthly`, `@weekly`, `@daily`, `@hourly`, `@midnight`. Use explicit numeric expressions instead (`0 0 * * *` for `@daily`).
- Named day-of-week: `MON`, `TUE`, etc. Use numeric (`0`-`6`, where `0` = Sunday).
- Named month: `JAN`, `FEB`, etc. Use numeric (`1`-`12`).
- 6/7-field Quartz extensions (seconds, year).
- Advanced Quartz characters: `L` (last), `W` (weekday), `#` (nth-of-month), `?` (no-specific-value).

These limits are by design — the validator stays as a 30-line bash regex with zero deps (per `agentskills-portable` tier; see `.claude/skills/skill/references/portability-tiers.md`). The accepted shapes cover ~95% of real cron use; for the long tail, author the routine with a verbose explicit expression (`0 0 1 1 *` instead of `@yearly`).

## Override marker

Mirroring the delegation, governance, secrets-scan, and supply-chain gates: a line `# OVERRIDE: <reason ≥10 chars>` (case-sensitive, terminated by end-of-line) anywhere in the routine file body skips ONE specific validate check.

The reason text is mandatory and is the audit trail — write something a future maintainer can grep. `# OVERRIDE: skip` / `bypass` / `n/a` are rejected (under 10 chars).

The marker is scoped — it skips the named check, not all validation:

- `# OVERRIDE: cron-syntax-extended: <reason>` — bypass the cron-expression validator (use when the routine targets a non-standard scheduler, e.g. Quartz on a Jenkins host).
- `# OVERRIDE: missing-done-block: <reason>` — allow a routine without a `# Done when` block (use for routines whose entire point is `no-output, just-side-effect`, e.g. log rotation).

**There is NO override for `idempotent: false`.** That's a hard rule (see § *Idempotency mandate*).

## Files

- `.claude/routines/<slug>.md` — routine definitions. Git-tracked. Created via `/routine new <slug>`.
- `.claude/routines/.gitkeep` — empty sentinel so the directory exists in fresh clones.
- `.claude/.routines-state/<slug>/queue/<ts>.md` — pending render. Gitignored, per-machine.
- `.claude/.routines-state/<slug>/completed/<ts>.md` — archived render. Gitignored. FIFO-capped at 50.
- `.claude/.routines-state/<slug>/last-completed.json` — last successful execution metadata. Gitignored.
- `.claude/.routines-state/<slug>/last-queue.json` — last enqueue metadata. Gitignored.
- `.claude/.routines-state/cron.log` — cron stdout/stderr capture. Gitignored.
- `~/.claude/.agent0-routines-leaders.json` — per-user leader designations. NOT in any repo.
- `.claude/tools/install-routines.sh` — interactive bootstrap (leader prompt + crontab block install + WSL2 advisory).
- `.claude/tools/uninstall-routines.sh` — symmetric removal.
- `.claude/tools/run-routine.sh` — invoked by cron; leader check + interpolate + enqueue + rotation.
- `.claude/hooks/routines-readout.sh` — `SessionStart` hook; surfaces pending queue.
- `.claude/skills/routine/SKILL.md` — `/routine` slash command (new / list / run / validate / dismiss).
- `.claude/skills/routine/scripts/validate.sh` — frontmatter + cron + body validator.
- `.claude/skills/routine/scripts/new.sh` — template instantiation.
- `.claude/skills/routine/templates/routine.md.tmpl` — scaffold template.

## Discipline

- **No auto-stage, no auto-commit.** `/routine new` writes the file; `git add` is the developer's call.
- **Sync-harness propagates the capacity, NOT instances.** The `.claude/routines/` directory ships as `.gitkeep`-only via sync; individual routines a fork creates are fork-local by design.
- **Leader-flag mutation requires explicit script invocation.** `install-routines.sh` and `uninstall-routines.sh` are the only sanctioned ways to mutate `~/.claude/.agent0-routines-leaders.json`. Hand-editing the file is allowed but the JSON shape must be preserved.
- **Queue file accumulation is informative.** Multiple unactioned queue entries for the same slug (e.g. "3 pending since 10 days ago") is the signal that either the routine is firing too often, or no one's been opening sessions in this repo. Both are real signals — the readout surfaces them rather than collapsing them silently.
- **Bash regex validation has gaps.** The 30-line cron validator catches obvious malformation but doesn't verify semantic plausibility (`0 25 * * *` is malformed AND rejected; `0 0 31 2 *` is semantically impossible — Feb 31 — but syntactically valid and accepted). Operator's responsibility to author plausible schedules.

## Gotchas

- **`SessionStart` hook registration is per-session.** Adding `routines-readout.sh` to `settings.json` doesn't activate until the next session boot. Same as `reminders-readout.sh`.
- **WSL2 cron is opt-in.** `service cron status` often reports inactive on fresh WSL2 distros. `install-routines.sh` detects WSL2 via `grep -qi microsoft /proc/version` and emits `wsl-advisory:` to stderr if cron isn't running. Document the `sudo service cron start` + `.profile` persistence pattern.
- **Crontab marker block is the only safe edit surface.** `install-routines.sh` rewrites the block between `# AGENT0-ROUTINES-START` and `# AGENT0-ROUTINES-END` on every run; manual edits inside the block are clobbered. Edit outside the block freely.
- **Renaming a routine slug requires re-running install.** The crontab block is generated from `.claude/routines/*.md` at install time; a `.md → different .md` rename leaves the old crontab entry referencing a now-missing file. Re-run `install-routines.sh` after any rename or addition.
- **`.claude/.routines-state/` is per-machine.** State doesn't sync between dev machines; that's by design (leader is one machine). If you switch leader, the new leader starts with empty state (`last-completed=never`), which is correct.
- **Queue file timestamps are unix epoch.** `<unix-ts>.md` not `<iso-8601>.md` because filenames sorted lexicographically by epoch == sorted chronologically; ISO-8601 requires `sort -V`. Lexicographic sort is portable across `ls`, `find`, `glob`.
- **`completed/` rotation is best-effort.** FIFO cap at 50 via `ls -t | tail -n +51 | xargs rm -f` — under high-concurrency edge cases (two routines complete simultaneously) the count can briefly drift; the soft cap is intentional, not a quota.
- **No global routine disable env var.** Unlike `CLAUDE_SKIP_MCP_RECIPES` etc., there is no `CLAUDE_SKIP_ROUTINES` — disabling routines means running `uninstall-routines.sh`, which is the sanctioned audit-leaving path. Throwaway sessions just don't hit the routines surface (no readout if queue is empty).

## Cross-references

- `.claude/rules/reminders.md` — sibling capacity (one-shot deferred); shares the user/project/shipped 3-bucket model.
- `.claude/rules/memory-placement.md` — the 3-bucket model this rule extends to routines.
- `.claude/rules/harness-sync.md` — how the capacity propagates to forks (`.claude/{tools,hooks,rules,skills}/` glob coverage).
- `.claude/rules/delegation.md` § *Why DONE_WHEN exists* — the contract-not-promise discipline that motivates the human-in-loop dispatch.
- `.claude/skills/skill/references/portability-tiers.md` — the tier definitions; `/routine` targets `cc-native` (depends on CC's slash-command surface for dispatch).
