# Reminders

`.claude/REMINDERS.md` is a single plain-text list of *action-shaped future items* that the agent or founder doesn't want to lose but doesn't want to do now. It occupies the gap between two other state files in this project:

- **`.claude/SESSION.md`** — *in-flight* work-state (cross-session handoff).
- **`~/.claude/projects/.../memory/MEMORY.md`** — *durable knowledge* (facts, preferences, decisions).
- **`.claude/REMINDERS.md`** — *deferred do-this-thing* items, neither urgent enough to start now nor durable enough to count as knowledge.

The capacity exists because deferred intent otherwise leaks into chat scrollback (lost on `/clear` or compaction), `TODO` comments in code (rot with the file, invisible across the repo), or the founder's head (lossy).

## Flow

- **Write** — via the `/remind` skill (`.claude/skills/remind/SKILL.md`). Subcommands `add`, `list`, `dismiss`. The skill is the sanctioned way to mutate the file; hand-edits are allowed but the format (H1 header + bullet lines) must be preserved.
- **Read** — automatic at session start. The `SessionStart` hook (`.claude/hooks/reminders-readout.sh`) cats the file (or emits `(no pending reminders)` if empty) into the agent's context, alongside `SESSION.md` and the optional `COMPACT_NOTES.md` injection.

## What to write here

- Future items with an *action shape*: "circle back on caching when first user complains", "review pricing assumption in Q3", "update README after the auth refactor merges".
- Items where the right moment to act is *later than now* — too distant for the next session's WIP, too small for a tracked issue.
- Optionally a `--due <YYYY-MM-DD>` tag if the item is time-bound.

## What NOT to put here

- **Knowledge.** Facts ("the prod DB lives at host X"), conventions ("we use kebab-case for slugs"), decisions ("we picked PG over MySQL because…") belong in memory — `MEMORY.md` for personal, `.claude/rules/<topic>.md` for project-shared. See `.claude/rules/memory-placement.md`.
- **In-flight work.** Active work that needs finishing next session belongs in `.claude/SESSION.md`. See `.claude/rules/session-handoff.md`.
- **One-file fixes.** If the work fits in two lines, just do it now — don't queue a reminder.
- **Tracked issues.** Reminders are a one-machine scratchpad. Items that need collaborators or public discussion belong in the project's issue tracker, not here.

## Discipline

- **No auto-stage, no auto-commit.** `add` and `dismiss` leave the file dirty in the working tree. The founder reviews `git diff` before history is written.
- **Deletion IS dismissal.** `dismiss N` removes the Nth bullet line — no checkbox-mark, no archive section, no renumber. Keeps the file lean and the session-start injection short. Audit lives in `git log -- .claude/REMINDERS.md`.
- **Position numbers are not stable IDs.** Pattern is "list, then dismiss the position you see right now". Positions shift when bullets are added or removed — re-list between multi-dismisses.
- **One file, plain markdown.** No JSON, no sqlite, no per-item file. The hook just `cat`s it; readability and `git diff` are the contract.

## Files

- `.claude/REMINDERS.md` — the state file. Git-tracked. Created on first `/remind add`.
- `.claude/skills/remind/SKILL.md` — slash-command definition.
- `.claude/hooks/reminders-readout.sh` — session-start readout hook.

## Gotchas

- **`SessionStart` hook registration is per-session.** Adding or removing the readout from `settings.json` doesn't take effect until the next session start.
- **Bullets must be single-line.** A bullet is `^[[:space:]]*- ` after the H1. If you hand-edit, keep each bullet on one line — multi-line bullets break `list` count and `dismiss` index.
- **Empty state still emits a frame.** When there are no reminders, the readout still prints the `=== REMINDERS ===` frame with `(no pending reminders)` inside. Visible by design — the capacity is supposed to be discoverable.
