# Self-review checklist — `/sdd refine`

Run before delivering the synthesis (Step 3) and again before writing `spec.md` (Step 4). Used by `/sdd refine` (see `../SKILL.md` § Subcommand: refine).

## Context

- [ ] Read available project context before speaking — CLAUDE.md, `.claude/rules/*.md`, `.claude/memory/MEMORY.md`, the `docs/specs/` listing, recent `git log`
- [ ] Identified existing specs, rules, modules, or memory entries that overlap with the idea
- [ ] Told the user which context was loaded and what is relevant — concisely, not a dump

## Discovery quality

- [ ] Conducted minimum 3 rounds, even if the idea seemed clear
- [ ] Challenged the idea at least twice (scope creep, over-engineering, vague value)
- [ ] Referenced actual repo files, specs, rules, or modules in suggestions — not generic advice
- [ ] Checked the idea against existing decisions in `docs/specs/` and conventions in `.claude/rules/`
- [ ] Covered at least 4 of the 7 question-bank categories
- [ ] Grepped/read the repo before asking anything that the repo could answer
- [ ] Asked about v1 scope explicitly — what is IN and what is OUT
- [ ] Stated a recommended default for each question; said "no strong default" rather than fabricating one

## Synthesis

- [ ] Presented the structured summary BEFORE writing any file
- [ ] User confirmed or adjusted the summary
- [ ] Feature has a clear name and a one-paragraph problem statement
- [ ] Scope v1 is specific enough to hand to `/sdd plan` without more discovery
- [ ] Out-of-scope items are listed explicitly, not silently dropped
- [ ] Anti-goals defined (what this must NOT become)

## Output quality

- [ ] Output fills the existing `templates/spec.md.tmpl` structure — all five sections (Intent, Acceptance criteria, Non-goals, Open questions, Context / references)
- [ ] Acceptance criteria use the `Scenario: … Given/When/Then` sub-bullet shape for behavior, plain checkbox bullets for static facts (per `.claude/rules/spec-driven.md` § Acceptance scenarios)
- [ ] Each acceptance criterion is verifiable without re-reading the plan
- [ ] Open questions are honest — what we genuinely do not know, each with a path to resolution
- [ ] Every claim traces to a discovery-round answer; nothing invented the user did not confirm

## Integrity

- [ ] No code, no `plan.md`, no `tasks.md` — `refine` stops at `spec.md`
- [ ] No sycophancy — challenged weak aspects directly; "great idea" never said
- [ ] Every architectural suggestion grounded in actual repo context
- [ ] Kill signals checked — if the feature is not worth building, said so plainly
- [ ] Scope biased toward a small v1 — a shipped increment over a perfect solution
- [ ] Handoff stated — pointed the user at `/sdd plan` as the next step
