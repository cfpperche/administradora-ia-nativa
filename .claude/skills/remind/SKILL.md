---
name: remind
description: Deferred-intent reminder list for this project. Use when the user wants to capture a future to-do that isn't urgent enough to act on now ("circle back on caching when first user complains", "review pricing in Q3", "update README after auth refactor lands"). Subcommands - add "<text>" [--due <YYYY-MM-DD>], list, dismiss <N>. State lives in .claude/REMINDERS.md (git-tracked) and is auto-injected at session start by .claude/hooks/reminders-readout.sh. See .claude/rules/reminders.md for what belongs here vs MEMORY vs SESSION.md.
argument-hint: <add "<text>" [--due <YYYY-MM-DD>] | list | dismiss <N>>
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/` conventional paths and CC-specific tools; portable to any runtime that maps a `.claude/`-analog directory and surfaces the referenced tools.
metadata:
  agent0-portability-tier: cc-native
  version: "0.1"
---

# /remind — deferred reminders

Capture, list, and dismiss action-shaped future items that aren't urgent enough to act on now but shouldn't be lost. State lives in one plain markdown file (`.claude/REMINDERS.md`, git-tracked), auto-injected into context at session start. Not a task manager, not a knowledge base, not a session work-state log — reminders are *future do-this-thing* items only.

See `.claude/rules/reminders.md` for what belongs here vs `MEMORY.md` vs `SESSION.md`, and the discipline (no auto-commit, no stable IDs, deletion-is-dismissal).

## Argument parsing

User invokes as `/remind <subcommand> [args]`. The raw argument string is `$ARGUMENTS`. Parse it yourself: split on whitespace, first token is the subcommand (`add` / `list` / `dismiss`), the rest are subcommand args. Quoted strings in `<text>` must be honored as a single argument (preserve the text between matching quotes). Do not rely on `$1` / `$2` — harness substitution for positionals differs between slash invocation and Skill tool invocation; always parse `$ARGUMENTS`.

Raw invocation: `$ARGUMENTS`

State file path used throughout: `.claude/REMINDERS.md` (resolve relative to the repo root / `$CLAUDE_PROJECT_DIR`).

## Subcommand: `add`

Append a new reminder. Parse `$ARGUMENTS`: first token must be `add`; the remainder contains the reminder text (typically quoted) and optionally `--due <YYYY-MM-DD>`.

1. **Validate input**:
   - The text must be present and non-empty after trim. Refuse with `add: text is required` and **do not write the file**.
   - Reject if the text contains a literal newline. Refuse with `add: text must be a single line` and **do not write the file**.
   - If `--due <date>` is present, validate `<date>` against the strict regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`. Refuse with `add: --due must be strict YYYY-MM-DD (got: <value>)` for any deviation, including `2026/09/01`, `2026-9-1`, `2026-09-01x`, etc. **Do not write the file** on failure.
2. **Ensure the file exists** with the canonical header. If `.claude/REMINDERS.md` is absent, create it with exactly this content (H1 followed by one blank line):
   ```
   # Reminders

   ```
3. **Append the bullet** to the end of the file. Shape:
   - Without `--due`: `- <text>`
   - With `--due`: `- <text>  ·  due: <YYYY-MM-DD>` — two spaces, middle-dot character (`·`, U+00B7), two spaces, then `due: <date>`.
   Use Read + Write (or Edit) to append. Do not introduce trailing blank lines; the bullet line is the new last line.
4. **Report**: echo `added: <bullet line>` back to the user — the exact line that was written.

## Subcommand: `list`

Print the current reminders. No arguments.

1. **If the file is absent OR contains no bullet lines** (see bullet definition below), emit a single line:
   ```
   no pending reminders
   ```
   and exit.
2. **Otherwise** output the file contents verbatim (no renumbering, no filtering, no transformation, no added headers), then a final line `<N> reminder(s)` where `<N>` is the bullet count.
3. **Bullet definition** (binding for both `list` and `dismiss`): a line whose first non-whitespace character is `-` followed by a space, occurring after the H1 header. Empty lines and the header do not count.

## Subcommand: `dismiss`

Delete the Nth reminder bullet, 1-indexed. Parse `$ARGUMENTS`: first token must be `dismiss`; second token is `N`.

1. **Validate**:
   - If `.claude/REMINDERS.md` is absent, refuse with `dismiss: no reminders to dismiss`.
   - If `N` is missing, non-numeric, or `<= 0`, refuse with `dismiss: N must be a positive integer (got: <value>)`.
   - Count bullet lines using the binding bullet definition. If `N > count`, refuse with `dismiss: only <count> reminder(s); cannot dismiss <N>`.
2. **Delete** the Nth bullet line (and only that line). Preserve the H1 header, blank lines, and every other bullet exactly in original order. Do NOT mark with a checkbox, move to an archive section, renumber, or otherwise rewrite the file.
3. **Report**: echo `dismissed: <bullet line>` back to the user — include any `  ·  due: <date>` suffix if it was present.

## Unknown subcommand

If the first token of `$ARGUMENTS` is missing or not one of `add`, `list`, `dismiss`, refuse with a one-line usage hint and stop:

```
/remind <add "<text>" [--due <YYYY-MM-DD>] | list | dismiss <N>>
```

## Notes

- **Don't auto-stage, don't auto-commit.** The founder reviews `git diff` and decides what enters history. `add` and `dismiss` leave the file dirty in the working tree.
- **Deletion IS dismissal.** Don't checkbox-mark, don't move to an archive section, don't renumber. Keeps the session-start readout short and the file lean. Audit lives in the git log of `.claude/REMINDERS.md`.
- **Position numbers are not stable IDs.** Pattern is "list, then dismiss the position you see right now". Positions shift when bullets are added or removed — re-list between multi-dismisses.
- **No history / archive section.** Reminders are pure current-state. Dismissed items are gone from the file.
- **Single file, plain markdown only.** No JSON, no sqlite, no per-item file. The session-start hook just `cat`s the file; readability and `git diff` are the contract.
- **Reminders are not knowledge.** Facts, decisions, conventions belong in `MEMORY.md` (personal) or `.claude/rules/<topic>.md` (project). See `.claude/rules/memory-placement.md`.
- **Reminders are not session work-state.** In-flight work belongs in `.claude/SESSION.md`. Reminders are *future* work that won't fit the next session's first five minutes. See `.claude/rules/session-handoff.md`.
- See `.claude/rules/reminders.md` for the full capacity description.
