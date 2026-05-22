# Spec-driven development

Non-trivial work in this repo is **spec-driven**: write the intent before the code. The discipline catches half-baked thinking on cheap markdown instead of expensive diffs, and gives the next session (human or AI) a contract to verify against.

## When SDD applies

Apply for any change that meets at least one of:

- Touches 3+ files, or introduces a new module/package/service
- Changes a public API, schema, or contract another component depends on
- Has user-visible behavior change worth describing in a PR body
- Has reversibility cost (migrations, infra, destructive ops)
- Was prompted by a vague request ("add auth", "make it faster") that needs decomposition

## When to skip

Mechanical or local-only work — go straight to the edit:

- Typos, renames, formatting, lint fixes
- One-file bug fixes with obvious cause
- Dependency bumps without behavior change
- Editing existing specs / docs / configs
- Throwaway exploration in a scratch branch

When in doubt, write a spec — 5 minutes of markdown is cheap insurance.

## The four artifacts

Specs live under `docs/specs/NNN-<slug>/` where `NNN` is zero-padded sequential (001, 002, …). Each spec has four files:

- **`spec.md`** — the *what* and *why*. Intent, acceptance criteria as scenarios or a checklist (see § *Acceptance scenarios* below), non-goals, open questions. This is the contract — hand it to a stakeholder or paste it into the PR body. The `**Status:**` line near the top declares lifecycle: `draft` (not started), `in-progress` (work begun), `shipped` (acceptance criteria satisfied), `superseded` (replaced by a later spec, slug named inline — e.g. `superseded by 0NN-<slug>`). An optional `**Type:**` line adjacent to `**Status:**` declares the spec's role — omitted (default) for feature/refinement specs that ship code; `umbrella` for aggregators that track closure of multiple child specs without shipping code themselves (acceptance is the closure of every row in a gap matrix, not a code delta). Expansion to other values (`bugfix` / `refactor` / `research`) is deferred until 3+ specs demand the distinction (rule-of-three demand-test).
- **`plan.md`** — the *how*. Approach, files to touch, alternatives considered and rejected (with reasoning), risks and unknowns. This is the engineering judgment.
- **`tasks.md`** — the *do*. Numbered checklist of concrete execution steps. This is what Claude (or you) works through one at a time, checking off as it goes.
- **`notes.md`** — the *in-flight design memory* (optional in v1). Decisions, deviations, tradeoffs, and open questions surfaced **while building** that weren't pre-empted by `spec.md` or `plan.md`. Append-only by convention. Four canonical sections (`Design decisions` / `Deviations` / `Tradeoffs` / `Open questions`) function as a routing rubric; sections may stay empty. Entry shape: `### YYYY-MM-DD — <author> — <one-line title>` followed by free-prose body, where `<author>` is `parent` or the `subagent_type` of the delegated worker. Distinct from `spec.md` § *Open questions* (pre-flight, set before implementation) and from `SESSION.md` (cross-session WIP, overwritten each handoff). Append entries when a non-trivial decision wasn't pre-empted by spec/plan; do not log every micro-step. Sub-agent integration via `DELIVERABLE` — see `.claude/rules/delegation.md` § *The 5-field handoff*.

Specs are **git-tracked** — they are the project's design memory. Don't gitignore them. Update them when the plan shifts; the file history *is* the audit trail.

## Workflow

0. **Refine** *(optional)* — `/sdd refine` runs a discovery interview that turns a vague idea into a filled `spec.md`. Opt-in, and especially suited to the "vague request" trigger in § *When SDD applies* — when the *what* itself is unclear, refine before you scaffold. Skip it when the intent is already sharp; go straight to step 1.
1. **Spec** — `/sdd new <slug>` scaffolds the three files. Fill `spec.md` first, alone (or let step 0 fill it). Don't plan how until you've nailed what.
2. **Plan** — `/sdd plan` drafts `plan.md` from `spec.md`. Review and edit. Stop here if assumptions need user confirmation.
3. **Tasks** — `/sdd tasks` drafts `tasks.md` from `plan.md`. Each task should be small enough that completing it is unambiguous.
4. **Implement** — work `tasks.md` top-to-bottom. Check off as you go. If a task reveals the plan is wrong, update `plan.md` *before* continuing.
5. **Close** — when the spec is delivered, the spec dir stays — it's the historical record. Reference it from the commit / PR.

## Acceptance scenarios

The acceptance section of `spec.md` should describe **observable behavior** in Given/When/Then scenarios. A scenario is a contract a verifier (human or sub-agent) can mirror directly into `tasks.md`'s verification steps.

### Canonical shape — nested sub-bullets

- [ ] **Scenario: <short title>**
  - **Given** <precondition: state that must hold>
  - **When** <action that triggers the behavior>
  - **Then** <observable outcome: what becomes true / visible>

### Compact shape — inline prose

For short scenarios that fit on one line:

- [ ] **Scenario: <title>** — **Given** <precondition>; **When** <action>; **Then** <outcome>

Use the nested shape by default; switch to inline only when the scenario is genuinely one-line.

### Plain bullets — for static-fact criteria

Not every criterion is a behavior. Existence checks, executable bits, JSON parses, file paths — these are static facts. Use a plain checkbox bullet:

- [ ] `<concrete static fact, e.g. .claude/hooks/foo.sh exists and is executable>`

Mixing scenario bullets with plain bullets in the same `## Acceptance criteria` is expected and correct. Do not force a static fact into Given/When/Then; do not write a behavior as a flat bullet.

### Why this shape

- A scenario is **executable in prose**: a sub-agent dispatched (via the delegation gate) with a 5-field brief whose DELIVERABLE references "scenario N from `docs/specs/NNN-<slug>/spec.md`" can construct the verification without follow-up clarification.
- The Given/When/Then split prevents the common failure mode where an acceptance bullet describes *what* without *when* — the verifier then has to infer the precondition and trigger from plan.md or conversation.
- Tasks.md verification steps map 1:1 from scenarios: each scenario becomes one task that asserts the Then under the Given/When.

### What this does NOT introduce

This is a writing discipline. There is no Cucumber, no Gherkin parser, no test-runner integration, no hook that validates `spec.md` shape. Scenarios are prose; their value is clarity for the next reader (often a sub-agent), not machine consumption. The earliest specs keep their flat-checklist shape — `git log` is the audit trail, not a rewrite.

## Relationship to other rules

- **`research-before-proposing.md`** — research happens *during* spec phase, before `plan.md` is locked. Cite sources in the spec or plan.
- **`session-handoff.md`** — if a spec is mid-flight at end of session, mention the active spec dir in `SESSION.md` so the next session resumes from `tasks.md`.

## Escalation path

For larger projects (multi-week features, multiple contributors), this convention-light approach has limits. Lightest opt-in upgrade: [OpenSpec](https://openspec.dev/) — `npm i -g @fission-ai/openspec && openspec init` adds delta-spec tracking (`ADDED` / `MODIFIED` / `REMOVED`) and proposal review on top of plain markdown. Doesn't conflict with `docs/specs/`; just adds an `openspec/` tree alongside.

Heavier tools (spec-kit, BMAD) are an option but bring Python/multi-agent overhead. Reach for them only if the project actually needs them.
