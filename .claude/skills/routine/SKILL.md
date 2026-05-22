---
name: routine
description: Project-scoped recurring routine manager. Use when the user wants to schedule recurring work that the repo's contributors all benefit from ("every quarter audit CC platform changes", "weekly stack defaults snapshot", "monthly dependency drift check"). Distinct from /remind (one-shot deferred) and /schedule (user-account-scoped Anthropic cloud). Subcommands - new <slug>, list, run <slug>, validate <slug>, dismiss <slug>. State lives in .claude/routines/<slug>.md (git-tracked source of truth) and .claude/.routines-state/ (gitignored per-machine cache). See .claude/rules/routines.md for discipline.
argument-hint: <new <slug> | list | run <slug> | validate <slug> | dismiss <slug>>
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/` conventional paths and CC-specific tools; cron executor + bootstrap scripts are bash + POSIX utilities, portable to any runtime that maps a `.claude/`-analog directory.
metadata:
  agent0-portability-tier: cc-native
  version: "0.1"
---

# /routine — project-scoped recurring routines

Create, list, execute, validate, and dismiss recurring routines for this repo. Routine definitions live in `.claude/routines/<slug>.md` (git-tracked); cron renders them into `.claude/.routines-state/<slug>/queue/` (gitignored); the next interactive Claude Code session reads the queue and dispatches each pending routine via this skill.

See `.claude/rules/routines.md` for full discipline, frontmatter reference, cron syntax limits, leader-flag model, and the differences vs `/remind` and `/schedule`.

## Argument parsing

User invokes as `/routine <subcommand> [args]`. The raw argument string is `$ARGUMENTS`. Parse it yourself: split on whitespace, first token is the subcommand (`new` / `list` / `run` / `validate` / `dismiss`), the rest are subcommand args. Do not rely on `$1` / `$2` — harness substitution for positionals differs between slash invocation and Skill tool invocation; always parse `$ARGUMENTS`.

Raw invocation: `$ARGUMENTS`

Repo root resolution: `$CLAUDE_PROJECT_DIR` if set, else `git rev-parse --show-toplevel`, else `$PWD`.

## Subcommand: `new <slug>`

Scaffold a new routine. Parse `$ARGUMENTS`: first token must be `new`, second token is the slug (kebab-case, `^[a-z][a-z0-9-]*$`).

1. **Validate** — refuse if:
   - slug is empty or contains uppercase / non-alphanumeric (besides hyphen)
   - `.claude/routines/<slug>.md` already exists (suggest a different slug, or edit the existing file)
2. **Invoke**: `bash .claude/skills/routine/scripts/new.sh <slug>`. The script copies `templates/routine.md.tmpl` → `.claude/routines/<slug>.md`, substitutes `{{SLUG}}` and `{{DATE}}`, and runs `validate.sh` as a self-check (should pass).
3. **Report**: surface the script's stdout (`new: created <path>` + the re-install hint). Tell the user to edit the file (especially the `schedule:` field, default `0 9 * * *` is rarely what they want), then re-run `.claude/tools/install-routines.sh` to register the new routine with cron.

## Subcommand: `list`

Show the status of every routine in this repo. No arguments.

1. **Invoke**: `bash .claude/skills/routine/scripts/list.sh`. The script iterates `.claude/routines/*.md` (excluding `.gitkeep`), parses frontmatter, and emits one line per routine in the shape:
   ```
   <slug>  schedule=<cron>  leader=<yes|no|n/a>  queue=<N pending>  last-completed=<ts|never>
   ```
   - `leader` reads `~/.claude/.agent0-routines-leaders.json`: `yes` if this repo's abs path is `true`, `no` if `false`, `n/a` if missing or repo not in file.
   - `queue` counts files in `.claude/.routines-state/<slug>/queue/*.md` (0 if dir absent).
   - `last-completed` reads `.claude/.routines-state/<slug>/last-completed.json` for the `ts` field, or `never` if file absent.
2. **Footer** (script-emitted): if leader is `n/a` AND routines exist, the script appends `(no leader designated — run .claude/tools/install-routines.sh to schedule)`.
3. **Empty case** (script-emitted): if no routines exist, the script emits `(no routines defined — use /routine new <slug> to create one)`.

## Subcommand: `run <slug>`

Dispatch the oldest pending queue entry for a routine. Parse `$ARGUMENTS`: first token must be `run`, second is the slug.

1. **Validate** — refuse if:
   - `.claude/routines/<slug>.md` does not exist (suggest `/routine new <slug>` or check spelling)
   - `.claude/.routines-state/<slug>/queue/*.md` is empty (suggest `/routine run` with a different slug, or note that cron hasn't fired yet)
2. **Pop oldest queue entry** — pick the file with the lowest unix timestamp in the filename (`ls .claude/.routines-state/<slug>/queue/*.md | sort | head -1`).
3. **Read the queue file** — it contains the rendered prompt (with `{{LAST_COMPLETED_TS}}` etc. already substituted by `run-routine.sh`). The prompt body is between `# Prompt` and `# Done when` (or EOF if no done-when block).
4. **Dispatch** — execute the prompt as the next action in this session. The work itself happens here: read the prompt, do what it asks, report back. **You are the executor.** Idempotency discipline (per `.claude/rules/routines.md` § *Idempotency mandate*): re-running this prompt should produce no destructive side effect; that's the routine author's responsibility, not yours.
5. **Archive** — on dispatch completion, move the queue file:
   ```bash
   mv .claude/.routines-state/<slug>/queue/<ts>.md .claude/.routines-state/<slug>/completed/<ts>.md
   ```
   And update `.claude/.routines-state/<slug>/last-completed.json` with the current ISO-8601 UTC timestamp:
   ```json
   { "ts": "2026-05-19T18:54:00Z", "queue_file": "1747...md" }
   ```
6. **FIFO cap on `completed/`** — if `ls .claude/.routines-state/<slug>/completed/*.md | wc -l` > 50, delete oldest until count ≤ 50. Use `ls -t | tail -n +51 | xargs -r rm -f`.

## Subcommand: `validate <slug>`

Run the frontmatter + body validator against a routine file. Parse `$ARGUMENTS`: first token must be `validate`, second is the slug.

1. **Invoke**: `bash .claude/skills/routine/scripts/validate.sh <slug>`. The script checks: frontmatter shape (two `---` markers, line 1 start); required keys (`name`, `schedule`, `idempotent`); `name` matches file basename; `idempotent: true` (hard reject `false` — no override); cron expression matches the 30-line regex (per `.claude/rules/routines.md` § *Cron expression syntax*); body has `# Prompt` and `# Done when` headers.
2. **Report**: surface the script's stdout/stderr verbatim. Exit code 0 = pass; 1 = fail with explanation.

Per-check override markers (placed on their own line in the routine body):
- `# OVERRIDE: cron-syntax-extended: <reason ≥10 chars>` — bypass cron regex (use for non-standard schedulers).
- `# OVERRIDE: missing-done-block: <reason ≥10 chars>` — allow routine without `# Done when` (use for side-effect-only routines).

There is **no override** for `idempotent: false` — it's a hard rule.

## Subcommand: `dismiss <slug>`

Move ALL pending queue entries for a routine to `completed/` with `-dismissed` suffix (audit-preserving skip). Used when a routine fires during an irrelevant work window and you don't want to execute it.

Parse `$ARGUMENTS`: first token must be `dismiss`, second is the slug.

1. **Validate** — refuse if `.claude/.routines-state/<slug>/queue/*.md` is empty (`(no pending entries for <slug>)`).
2. **Move each queue file** to `completed/<original-name>-dismissed.md`. Preserve original timestamp prefix so audit ordering stays correct.
3. **Do NOT update `last-completed.json`** — dismissal is not completion. The routine will fire again on its next scheduled tick.
4. **Report**: `dismissed: <N> pending entries for <slug> (moved to completed/ with -dismissed suffix)`.

## Unknown subcommand

If the first token of `$ARGUMENTS` is missing or not one of `new`, `list`, `run`, `validate`, `dismiss`, refuse with a one-line usage hint and stop:

```
/routine <new <slug> | list | run <slug> | validate <slug> | dismiss <slug>>
```

## Notes

- **Don't auto-stage, don't auto-commit.** `new` writes the file; `git add` is the developer's call. Same discipline as `/remind`.
- **Routine definitions are git-tracked; state is NOT.** `.claude/routines/<slug>.md` ships in git; `.claude/.routines-state/` is gitignored (per-machine). This split is what makes the capacity multi-developer-safe.
- **Sync-harness propagates the capacity (rule + scripts + skill + hook), NOT instances.** A fork that adopts Agent0's harness gets `/routine` for free, but the fork's own routines are fork-local.
- **Cron registration is separate from routine definition.** `/routine new` creates the file; `.claude/tools/install-routines.sh` (re-)generates the crontab block. After `new`, the routine is NOT scheduled until install runs.
- **Idempotency is the routine author's responsibility.** The validator rejects `idempotent: false` in frontmatter, but it can't verify the prompt body is actually idempotent. The 4-layer N-fold defense (per `.claude/rules/routines.md`) catches drift; the routine author writes the guard.
- **`run` dispatches in the current session.** Unlike Phase 2 (autonomous `claude -p`), v1 `run` means "you, the current Claude Code session, do what the routine prompt asks". The session is the executor.
- See `.claude/rules/routines.md` for the full capacity description, gotchas, and cross-references.
