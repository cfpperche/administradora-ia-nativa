---
name: sdd
description: Spec-driven development scaffolding. Use when starting non-trivial work (3+ files, new module, API/schema change, vague request needing decomposition). Creates and progresses docs/specs/NNN-slug/{spec,plan,tasks,notes}.md per the spec-driven workflow. Subcommands - new <slug>, refine, plan, tasks, list. See .claude/rules/spec-driven.md for when SDD applies and when to skip.
argument-hint: <new <slug> | refine [<idea> | NNN] | plan | tasks | list>
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/` conventional paths and CC-specific tools; portable to any runtime that maps a `.claude/`-analog directory and surfaces the referenced tools.
metadata:
  agent0-portability-tier: cc-native
  version: "0.2"
---

# /sdd — spec-driven development

Scaffolds and progresses spec folders for non-trivial work. Each feature gets `docs/specs/NNN-<slug>/` with four files: `spec.md` (what + why), `plan.md` (how), `tasks.md` (do), `notes.md` (in-flight design memory populated during implementation).

See `.claude/rules/spec-driven.md` for the workflow rationale and when to apply / skip SDD.

## Argument parsing

User invokes as `/sdd <subcommand> [args]`. The raw argument string is `$ARGUMENTS`. Parse it yourself: split on whitespace, first token is the subcommand (`new` / `refine` / `plan` / `tasks` / `list`), the rest are subcommand args. Do not rely on `$1` / `$2` — harness substitution for those is inconsistent across invocation paths (slash vs Skill tool); always parse `$ARGUMENTS` instead.

Raw invocation: `$ARGUMENTS`

## Subcommand: `new <slug>`

Scaffold a new spec dir. Parse `$ARGUMENTS`: first token must be `new`, second token is the slug (kebab-case, e.g. `auth-rewrite`).

1. **Validate** — refuse with a clear message if:
   - slug is empty
   - slug doesn't match `^[a-z][a-z0-9-]*$` (kebab-case starting with a letter)
   - `docs/specs/NNN-<slug>/` with that slug already exists (suggest a different slug or `/sdd list`)

2. **Find next NNN** — scan `docs/specs/` for existing `NNN-*` dirs (ignore hidden files like `.gitkeep`), take the highest NNN, increment. Start at `001` if none exist. Zero-pad to 3 digits.

3. **Create the dir and copy templates** — use the templates in `${CLAUDE_SKILL_DIR}/templates/`:
   ```
   mkdir -p docs/specs/NNN-<slug>
   cp ${CLAUDE_SKILL_DIR}/templates/spec.md.tmpl  docs/specs/NNN-<slug>/spec.md
   cp ${CLAUDE_SKILL_DIR}/templates/plan.md.tmpl  docs/specs/NNN-<slug>/plan.md
   cp ${CLAUDE_SKILL_DIR}/templates/tasks.md.tmpl docs/specs/NNN-<slug>/tasks.md
   cp ${CLAUDE_SKILL_DIR}/templates/notes.md.tmpl docs/specs/NNN-<slug>/notes.md
   ```

4. **Substitute placeholders** in each created file — replace literally:
   - `{{SLUG}}` → `<slug>`
   - `{{NNN}}` → the zero-padded number
   - `{{DATE}}` → current date in `YYYY-MM-DD` (UTC)

5. **Report** — output the four paths and tell the user the next step is to fill `spec.md`. Do NOT auto-fill it; the user owns intent. Suggest they describe the change conversationally and you can draft `spec.md` from that, but only after they say so. If the idea is still vague, suggest `/sdd refine` instead. The fourth file `notes.md` stays empty at scaffold time — its purpose is in-flight design memory populated **during** implementation (see `.claude/rules/spec-driven.md` § The four artifacts).

## Subcommand: `refine`

Discovery interview that turns a vague idea into a filled `spec.md`. Opt-in front-end to `new` — conducts a senior-engineer interview, then writes the synthesis into the `spec.md` template. **Invocable at any point** — before a spec dir exists, or to refine one that does.

**Entry shapes** (parse `$ARGUMENTS` after the `refine` token):

- `refine "<idea>"` — a quoted idea or free text → interview from scratch; a spec dir is scaffolded only if the user opts in at Step 3.
- `refine NNN` — a spec number → refine that existing spec in place.
- `refine` (no args) — target the latest `docs/specs/NNN-*/` dir, same rule as `plan` / `tasks`.

**Resumability** — if the target spec dir exists, read its `spec.md` first; you are refining, not starting fresh. If `plan.md` or `tasks.md` are already filled (no `{{` placeholders), warn — "refining intent after planning has started; re-run `/sdd plan` afterward to resync" — but do not block.

### Step 0: Context load — 🔒 Low freedom: always silent

Read project context BEFORE speaking; build an internal model, do NOT dump a summary. Read: `CLAUDE.md`, `.claude/rules/*.md`, `.claude/memory/MEMORY.md` (the lazy index — pull specific memory files only when a round needs them), the `docs/specs/` directory listing (titles, not full bodies), recent `git log`. Reference this naturally during the interview.

### Step 1: Opening — 🔓 Medium freedom: brief, grounded

In 2-3 sentences: what context you loaded, which existing specs / rules / modules overlap with the idea, and that you are ready to start. If no idea was supplied, ask what to explore.

### Step 2: Discovery — 🔓 Medium freedom: adaptive questioning

**Read `${CLAUDE_SKILL_DIR}/references/question-bank.md` before this step.**

Each round: (1) state your current understanding in 1-2 sentences; (2) ask 1-2 non-obvious questions from the bank; (3) reference actual repo context; (4) state a recommended default per question — the user confirms, corrects, or overrides, never starts from blank. If you have no opinion, say so explicitly rather than fabricating one.

Rules:

- Minimum 3 rounds, even if the idea seems clear. Maximum 6 by default — if not converging, force synthesis.
- **Deep mode** — if the user passes `--deep` or asks to "go deep", lift the 6-round cap; continue until 3 consecutive rounds surface no new in-scope decisions. Hard ceiling 20.
- **Grep before asking** — if the repo could answer a question (configs, rules, memory, specs, schemas), read first; asking is the fallback. Per `.claude/rules/research-before-proposing.md`, web research is allowed here: repo first, web second, ask last. Name the file / source you read.
- Challenge the idea at least twice (scope creep, over-engineering, vague value). Never sycophantic — "great idea" is banned.
- Cover at least 4 of the 7 question-bank categories.
- Detect convergence (answers stop adding information → synthesis) and kill signals (feature not worth building → say so directly).

Checkpoint after each round: `Round N/6 — scope converging on [summary]. Continue, or move to synthesis?`

### Step 3: Synthesis — 🔒 Low freedom: structured summary

Present for confirmation: feature name; problem (who, what pain, frequency); proposed solution (1-2 sentences); scope v1 (in / out / anti-goals); architecture fit (which existing specs / rules / modules it touches); key tradeoff; effort estimate (S/M/L/XL); top 2-3 risks.

Ask the user to confirm, adjust, or kill — and to choose the output:

1. **Write `spec.md`** — scaffold a spec dir (or refine the existing one) and fill the template. Recommended.
2. **Just the summary** — return the synthesis inline; write no file.

For option 1 on a from-scratch refine: propose a kebab-case slug derived from the feature name; the user confirms or overrides. Then scaffold exactly as `new` does (next NNN, copy templates, substitute placeholders).

### Step 4: Output — 🔒 Low freedom: use the existing template

**Read `${CLAUDE_SKILL_DIR}/templates/spec.md.tmpl` before producing.** Fill all five sections — Intent, Acceptance criteria, Non-goals, Open questions, Context / references. Every claim must trace to a discovery-round answer; invent nothing the user did not confirm. Acceptance criteria use the `Scenario: … Given/When/Then` sub-bullet shape for behavior and plain checkbox bullets for static facts (per `.claude/rules/spec-driven.md` § Acceptance scenarios) — Gherkin surfaced during discovery maps directly onto that shape.

### Step 5: Close — 🟢 High freedom: handoff

**Read `${CLAUDE_SKILL_DIR}/references/checklist.md` and self-review against it.** Then self-assess a quality score:

| Category                  | Weight | Measures                                          |
|:--------------------------|-------:|:--------------------------------------------------|
| Problem clarity           |    20% | Who, what pain, frequency, cost of inaction       |
| Scope precision           |    20% | In-scope vs out-of-scope is unambiguous           |
| Architecture fit          |    20% | References actual specs, rules, modules           |
| Acceptance completeness   |    15% | Scenarios cover happy path, edges, errors         |
| Implementation readiness  |    15% | `/sdd plan` can start from this spec alone        |
| Grounding                 |    10% | Every claim traces to a discovery answer          |

Report the score and point the user at the next step: `/sdd plan`.

## Subcommand: `plan`

Draft `plan.md` from an existing `spec.md`. No positional argument — operate on the most recent spec dir (highest NNN) unless the user has already named a specific one in conversation.

1. **Locate target** — find the latest `docs/specs/NNN-*/` dir. If multiple are in flight and ambiguous, ask which one.
2. **Read `spec.md`** — refuse if it still has unfilled template placeholders (`{{` substrings) or is essentially empty. Tell the user to fill spec first.
3. **Draft `plan.md`** — preserve the existing template section headers; fill them from `spec.md` + your understanding of the codebase. For "Alternatives considered" you MUST list at least one rejected option with reasoning — if there genuinely was no alternative, say so explicitly ("no real alternatives; only viable approach is X because Y").
4. **Cite research** — if the spec or plan involved web research or codebase exploration, link the sources in the plan. This satisfies `research-before-proposing.md`.
5. **Report** — output `plan.md` path. Tell the user to review and confirm before `/sdd tasks`.

## Subcommand: `tasks`

Generate `tasks.md` from `plan.md`. Same target-selection rule as `plan`.

1. **Locate target** — find the latest spec dir (or the one in conversation).
2. **Read `plan.md`** — refuse if it has unfilled template placeholders.
3. **Decompose into tasks** — each task should be:
   - Small enough that completion is unambiguous (passes/fails clearly)
   - Independently checkable (testable, observable, or produces a concrete artifact)
   - Ordered by dependency — earlier tasks unblock later ones
   - Numbered (`1.`, `2.`, …) with checkbox prefix (`- [ ]`)
4. **Include verification** — the last 1-2 tasks should be acceptance checks against the criteria in `spec.md` (run tests, verify behavior, sanity checks).
5. **Report** — output `tasks.md` path. Tell the user implementation is now mechanical: work the tasks top-to-bottom, check off as completed, update `plan.md` if any task reveals plan is wrong.

## Subcommand: `list`

List all specs in the repo with a one-line status each. Supports two opt-in flags: `--in-flight` (filter to active work) and `--json` (machine-readable output, agent-friendly). Both are independent; any combination is legal.

1. Scan `docs/specs/` for `NNN-*/` dirs (sorted by NNN ascending).
2. For each, emit one line (default text output): `NNN-<slug>  [status]  — <h1 of spec.md, or "(no spec)" if empty>`.
3. Resolve status using **declared truth first, derived heuristic as fallback**:
   - **Declared (preferred):** read `spec.md` for a `^\*\*Status:\*\* (draft|in-progress|shipped|superseded)` line. If present, that value is the status — overrides the derived heuristic everywhere (bare output and `--in-flight` alike).
   - **Derived (fallback when no `**Status:**` line is present):**
     - `spec` — `spec.md` has content but `plan.md` still has placeholders
     - `plan` — `plan.md` filled but `tasks.md` still has placeholders
     - `tasks` — `tasks.md` filled, some unchecked boxes remain
     - `done` — all checkboxes in `tasks.md` are checked (`- [x]`)
     - `empty` — `spec.md` still has `{{` placeholders

### Status semantics

Nine total states reachable: four declared (`draft`, `in-progress`, `shipped`, `superseded`) and five derived (`spec`, `plan`, `tasks`, `done`, `empty`). The declared set carries author intent; the derived set is the safety-net inference for specs that pre-date this convention or whose author skipped setting `**Status:**`. `superseded` is reserved for specs replaced by a later one — write `**Status:** superseded by 0NN-<slug>` so the inline slug names the replacement.

### Flag: `--in-flight`

Filter the output to active work. A spec is in flight iff:

- Declared `Status ∈ {draft, in-progress}` — OR
- Declared `Status` is absent AND derived state ∈ {`spec`, `plan`, `tasks`} AND last git activity on the dir is within the recency window

The recency window defaults to **14 days** (matches typical session-stretch length). Override with `CLAUDE_SDD_IN_FLIGHT_RECENCY_DAYS=<integer>` env var.

Specs with declared `shipped` or `superseded`, derived `done`, or derived `empty` are excluded. Derived `tasks` older than the recency window is also excluded — this is the false-positive case (`tasks.md` carries residual unchecked boxes from a long-shipped capacity).

`--in-flight` row shape, one line per spec:

```
NNN-<slug>  [status]  N/M acceptance unchecked  last activity Yd ago  — <h1>
```

Where:

- `[status]` is the resolved value (declared or derived)
- `N` = count of `- [ ]` bullets directly under `## Acceptance criteria` in `spec.md`, all nesting depths included (scenario sub-bullets AND plain static-fact bullets both count)
- `M` = total count under that section (`N` unchecked + checked)
- `last activity Yd ago` from `git log -1 --format=%ar -- docs/specs/NNN-<slug>/`

If the `## Acceptance criteria` section is missing or malformed, render `N/M` as `?/?` (text mode) and emit `null` for both counts in JSON — distinguishable from zero.

### Flag: `--json`

Emit a JSON array on stdout, one object per spec. Shape:

```json
[
  {
    "nnn": "029",
    "slug": "sdd-list-in-flight",
    "status": "in-progress",
    "acceptance_unchecked": 5,
    "acceptance_total": 8,
    "last_activity_iso": "2026-05-16T14:32:11+00:00",
    "h1": "029 — sdd-list-in-flight"
  }
]
```

Keys: `nnn` (string, zero-padded 3-digit), `slug` (string), `status` (string — one of the 9 reachable states), `acceptance_unchecked` (integer or `null`), `acceptance_total` (integer or `null`), `last_activity_iso` (string, ISO-8601 from `git log -1 --format=%aI -- <dir>`), `h1` (string — first `# ` line of `spec.md`).

`--json` is **shape-only convenience** for ad-hoc agent reads. It is **NOT a versioned wire contract** — the field set may evolve. Consumers that hard-depend on this shape do so at their own risk; no schema-version key is emitted, deliberately.

Flag combinations:

- `/sdd list` — bare text output, all specs, default behaviour (declared status now honoured)
- `/sdd list --in-flight` — text output, in-flight subset only, enriched row shape
- `/sdd list --json` — JSON array, all specs
- `/sdd list --in-flight --json` — JSON array, in-flight subset only

## Unknown subcommand

If the first token of `$ARGUMENTS` is missing or not one of `new`, `refine`, `plan`, `tasks`, `list`, refuse with a one-line usage hint:

```
/sdd <new <slug> | refine [<idea> | NNN] | plan | tasks | list>
```

## Notes

- Specs are **git-tracked** — they are project memory, not scratch. Don't gitignore them.
- The skill provides *structure*; you (Claude) provide *content*. Don't auto-fill `spec.md` — the user owns intent.
- If the user describes a change conversationally and SDD applies (per `.claude/rules/spec-driven.md`), offer to run `/sdd new <slug>` rather than diving into code.
