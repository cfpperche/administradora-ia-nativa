# PRD format — section shapes + US-NN ID convention

Canonical structure for `prd.md`. Inline examples + the load-bearing US-NN stability rule.

## US-NN user-story ID convention (the new MCP-port discipline)

Every user story carries a **stable, zero-padded sequential ID**: `US-01`, `US-02`, ..., `US-29`, `US-30`. The ID is the contract between the PRD and downstream consumers — step 13 (prototype-v3 NEW) reads the PRD for coverage scoring, mapping each `US-NN` to a screen in `screens/`. Without stable IDs, the coverage map breaks silently.

### ID stability rules (append, don't renumber)

- **New stories appended at the END** of the user-stories section. If you have `US-01` through `US-12` and need to add three more, they're `US-13`, `US-14`, `US-15` — even if the new stories conceptually belong "after US-03".
- **Removed stories keep their ID with strikethrough**: `~~**US-07.** As a manager...~~ — *removed v1.1, see Backlog row N*`. Never reuse a removed ID for a different story.
- **Reordered stories keep their original IDs.** If you reorganize the section so US-07 visually appears between US-03 and US-04, US-07 stays US-07. The ID is the story's identity, not its position.
- **Splitting one story into two**: keep the original ID on the broader half, append a new one for the carved-out half. `US-04` and `US-13` are siblings; the connection lives in `Source` columns (`from US-04`).

### Format

```markdown
**US-01.** As an engineering manager, I want to triage my sprint backlog in under 5 minutes so that I can stop spending lunch breaks on Jira sub-tasks.

**US-02.** As a tech lead, I want to bulk-reassign issues with keyboard shortcuts so that I don't lose context switching between mouse and keyboard mid-triage.

**US-03.** As a new user, I want to import my Jira workspace in under 2 minutes so that the migration cost is small enough that my team will actually try Octant.
```

**Note** the period after the ID (`**US-01.**`) — this is the Layer-1-substring shape the schema checks for. A PRD using `**US-01**` (no period), `**US01.**` (no dash), or `### US-01` (header instead of bold) trips Layer 1.

## Problem Statement

Concrete pain with evidence. Pull from step 1 brief (persona quotes, JTBD numbers) or step 4 audit (heuristic findings + WCAG verdict). Anti-pattern: vague ambition ("the experience could be better"). Good shape:

```markdown
## Problem Statement

Engineering managers at 5-30 person squads spend an average of 12 minutes daily on Jira triage tasks (persona interview, 2026-05; n=8). 47% of new Jira workspaces are abandoned within 90 days. The pain isn't the issue tracking — it's the friction of Jira's process tax: sub-tasks, custom fields, mandatory workflows. EM persona quote (concept brief § Persona): *"loves Linear's UX but balks at the per-seat price; would migrate today if onboarding cost <2 minutes and the keyboard model matched."*

v1 is the keyboard-first triage flow + 2-minute Jira import + per-seat pricing that breaks the linear scaling of competitors.
```

Three load-bearing sentences: (a) the user pain in concrete numbers/quotes, (b) the broader context, (c) the v1 thesis. Compact-mode PRDs may collapse to a single paragraph.

## Goals

3-5 outcome-oriented bullets. Outcome = what the user achieves. Output = what the team builds. The PRD names outcomes:

```markdown
## Goals

- EM persona triages a 25-issue sprint in under 5 minutes (vs 12-15 min on Jira)
- New user completes Jira import + first triage session in under 2 minutes from `/signup`
- v1 retains > 40% of week-1 signups into week 4 (DAU/WAU)
- Per-seat pricing remains < 50% of Jira's per-seat ($4 vs $8.45 at the Jira Standard tier)
```

Anti-pattern: "Build a triage view" / "Implement Jira importer" — those are outputs, naming what the team makes rather than what the user achieves.

## Non-Goals

Explicit out-of-scope, one-line reason each. The negative space discipline:

```markdown
## Non-Goals

- **Multi-project view across workspaces.** v1 is single-workspace; multi-workspace is a v2 enterprise tier expansion (deferred for pricing-segment reasons, not technical).
- **Native mobile app.** v1 is desktop-first; mobile is a "courtesy" responsive view per concept brief § Identity. Real mobile arrives only if v1 DAU growth justifies the build.
- **Custom workflows / state machines per project.** Jira's process tax is part of the problem we're solving — adding it back as a feature defeats the v1 thesis.
- **Integrations beyond Jira import.** GitHub Issues, Linear export, GitLab — all v2. v1 is "Jira refugees only".
```

Empty Non-Goals is a red flag. The parent's § 2 interview should produce 3-5 explicit cuts the founder is comfortable defending.

## Requirements (P0 / P1 / P2 / Backlog)

Four tables — same column shape. Routing rules in `scope-cut-discipline.md`. Example P0:

```markdown
### Must Have (P0)

| # | Requirement | Acceptance Criteria | Source |
|---|-------------|---------------------|--------|
| P0-1 | Jira workspace import via OAuth | Connect Jira; pull issues + sprints + assignees; complete in <2 min for ≤500 issues | US-03, prototype-v2 screens/02-onboarding-import.html |
| P0-2 | Keyboard-first triage mode | All triage actions reachable via keystroke; ESC exits to dashboard | US-01, US-02, spec § Killer flow, prototype-v2 screens/05-triage-view.html |
| P0-3 | Command palette (CMD-K) | Type-to-search across nav + actions + recent issues; returns ≤200ms; opens from any view | US-02, prototype-v2 screens/07-command-palette.html, step 4 F-12 (acceptance: real `<input>` element) |
| P0-4 | Per-seat pricing tier ($4) | Stripe integration; $4/seat/month; team can pay-as-you-grow | Goal #4, founder · 2026-05-16 |
```

The Source column proves traceability. Empty Source is a discipline failure — every P0 requirement traces to user story, spec, prototype, audit, or interview decision.

## Success Metrics — ONE primary

```markdown
## Success Metrics

### Primary (the v1 thesis is wrong if this misses)

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Week-1 → Week-4 retention | n/a (new product) | > 40% DAU/WAU at week 4 | Analytics: `signup_complete` cohort + `daily_active` event; measured at week 4 from each cohort's signup date |

### Observability metrics (read-only — not optimization targets)

| Metric | Why we watch | Baseline | Target threshold |
|--------|--------------|----------|------------------|
| Time-to-first-triage | Onboarding friction signal | n/a | < 2 min median |
| Jira import success rate | Importer reliability | n/a | > 95% across ≤500-issue workspaces |
| Paid conversion | Pricing signal (NOT a v1 gate) | n/a | > 8% of week-4 retained users |
```

The primary metric is the gate. Observability is read-only — informs v2 decisions, doesn't drive v1 execution trade-offs.

**Why ONE primary, not "at least 2"** (the anthill prescription): two equal-priority metrics produce optimization conflicts. Team A optimizes retention; team B optimizes activation; trade-offs aren't surfaced honestly because both metrics are "primary". The MCP-port discipline: ONE metric is the v1 thesis-test; everything else is observability.

## Acceptance Criteria (BDD per P0)

Every P0 story has 2-4 Given/When/Then scenarios. The scenarios are the test cases engineering will write:

```markdown
## Acceptance Criteria

### US-01 — Triage 25-issue sprint in <5 min

**Given** the user has imported a 25-issue Jira workspace AND is on `screens/05-triage-view.html`
**When** the user presses `t` to enter triage mode
**Then** the first untriaged issue is presented full-screen with keyboard hints visible at the bottom

**Given** the user is in triage mode reviewing an issue
**When** the user presses `1` / `2` / `3` for priority OR `a` to assign OR `l` to label
**Then** the action applies, the issue is marked triaged, and the next untriaged issue auto-loads within 100ms

**Given** the user has triaged all 25 issues
**When** the last issue's action completes
**Then** the triage-mode-complete summary appears with cycle-time stat and CTA to return to dashboard
```

Reference the prototype-v2 screen filename when behavior is screen-specific. The scenarios map to test cases in step 9 system-design → engineering's test suite.

## Open Questions

Each has an owner OR a downstream step:

```markdown
## Open Questions

1. **What's the Stripe webhook latency budget for paid-tier upgrade flow?** → step 9 system-design (Q1)
2. **GitLab importer — v1.5 or v2?** → @founder, decision needed by 2026-06-30 (commitments to closed-beta users)
3. **Does the activation event fire on import-complete or first-triage-complete?** → step 10 cost-estimate (Q2: affects analytics infrastructure scale)
4. **Should the free tier cap at 5 active users or 5 seats including inactive?** → @founder, decision needed before pricing-page copy ships
```

Questions without an owner or downstream step are a parent-interview failure. Push back at § 2.

## Backlog

```markdown
## Backlog

Low-priority items, post-v1 candidates, deferred audit findings. Re-evaluated each iteration.

| # | Title | Source | Why deferred |
|---|-------|--------|--------------|
| B-1 | `prefers-reduced-motion` wrap on triage transitions | step 4 F-15 | Cosmetic, AAA-only; v1 motion is minimal |
| B-2 | GitHub Issues import | spec § Identity (multi-importer note) | v1 is Jira-refugees-only per Non-Goals |
| B-3 | Multi-project dashboard view | spec § Open questions | v2 enterprise tier |
| B-4 | Custom keyboard remapping | founder · 2026-05-16 (post-interview) | Post-launch refinement; ship default first |
| B-5 | Mobile responsive polish on triage | step 4 F-08 (touch-target review) | v1 is desktop-first per Non-Goals; mobile is courtesy |
```

Empty backlog is fine when v1 is genuinely complete — say so explicitly (`*v1 is genuinely complete; no post-v1 items surfaced.*`). Silent empty is the regression mode.

## Anti-patterns (quick reference)

- **Vague problem statement.** "Improve UX" → name the friction with numbers.
- **No success metrics OR multiple equal primaries.** ONE primary; observability is optional and clearly labeled.
- **Requirements without acceptance criteria.** Every P0 row needs the AC column filled.
- **Mixing problem and solution.** Problem section names pain; Goals/Requirements name the v1 response.
- **Scope creep via "nice to have" bloat.** P2 capped at 3-5 items; rest goes to Backlog.
- **Skipping Non-Goals.** Empty Non-Goals = scope creep waiting to happen.
- **Implementation details in requirements.** PRD = WHAT and WHY; step 9 system-design = HOW.
- **Assuming technical feasibility.** Flag as Open Questions for step 9 review.
- **US-NN renumbering across PRD revisions.** Breaks step 13's PRD-coverage scoring silently. Append, don't renumber.
- **Source column empty.** Every requirement traces to a prior artifact or the parent interview.
