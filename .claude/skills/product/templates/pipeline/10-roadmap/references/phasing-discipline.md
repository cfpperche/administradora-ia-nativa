# Phasing discipline — slice = end-to-end user value, per-phase exit criteria, risk + buffer calibration

How to phase v1 in `roadmap.md`. The load-bearing disciplines from anthill-roadmap + the calibration rules that make phasing smart, not rigid.

## Slice = end-to-end user value (Shape Up style)

Each phase delivers ONE end-to-end slice of user value — backend + frontend + tests for ONE complete user flow. NOT a horizontal layer.

### Anti-pattern: horizontal layering

```markdown
## Phase 1 — Backend (Weeks 1-6)
- All API endpoints
- All database tables
- All auth

## Phase 2 — Frontend (Weeks 7-12)
- All screens
- All state management
- All forms

## Phase 3 — Tests (Weeks 13-14)
- Test suite
- Manual QA
```

This is the regression mode. User value lands ONLY at end of Phase 2 (12 weeks in); Phase 3 finds bugs that backend-and-frontend integration would have surfaced 6 weeks earlier. The roadmap optimised for "feature complete" instead of "user value flowing".

### Canonical shape: vertical slicing

```markdown
## Phase 1 — Sign up, land in an empty workspace (Weeks 1-4)
**Goal:** A user can sign up, create a workspace, see an empty dashboard on staging.
(Auth + data model + deploy pipeline + observability floor; no user-visible product features yet.)

## Phase 2 — Triage a 25-issue sprint via keyboard (Weeks 5-8)
**Goal:** Keyboard-first triage (US-07) walks end-to-end: user creates an issue, triages with `j/k/x/y` keys, sees it land in the right swimlane.
(Issue CRUD + triage state machine + keyboard shortcuts + UI for triage view + tests for the flow.)

## Phase 3 — Upgrade plan + invite a teammate (Weeks 9-12)
**Goal:** Bulk action (US-19) + Stripe checkout (US-05) shipped behind feature flag.
(Surrounding P0 features; each ships end-to-end before the next starts.)

## Phase 4 — Closed-beta launch with 10 design partners (Weeks 13-14)
**Goal:** Closed-beta launchable. Accessibility audit clean; error states wired; onboarding flow exists.
```

Each phase ships USER-OBSERVABLE BEHAVIOR. Phase 1's "empty dashboard" is observable (user can navigate to it); Phase 2's keyboard triage is observable (user can demo it to a non-engineer in <5 min).

### When horizontal layering is OK

Foundation phase is the one exception. Auth, data model, deploy pipeline, observability — these are infrastructure that has no user-visible flow by definition. But Foundation should ship A user-visible artifact (the empty dashboard above), even if the artifact is hollow. The artifact proves the infrastructure works.

## Phase naming — user-flow outcomes first, label categories as fallback

The phase H2 title should be a sentence a non-engineer can verify as user-facing value, NOT a label that describes the phase's category. The user-flow shape is the default; label categories are fallback for compact roadmaps.

### Canonical (user-flow shaped)

- `## Slice 1 — Sign up, land in an empty workspace (Weeks 1-3)`
- `## Slice 2 — Import a Jira workspace and see real issues (Weeks 4-6)`
- `## Slice 3 — Triage flow + command palette (the killer flow) (Weeks 7-9)`
- `## Slice 4 — Backlog, billing, settings (week-to-week operation) (Weeks 10-12)`
- `## Slice 5 — Polish, accessibility-floor, public launch (Weeks 13-14)`

A reader skimming the H2s alone learns the v1 narrative. Each title declares an end-of-phase observable outcome.

### Acceptable fallback (label categories)

- `## Phase 1 — Foundation (Weeks 1-4)` — Foundation specifically is fine as a label because the phase ships infrastructure; the user-visible artifact is the hollow dashboard, and "Foundation" honestly names the category.
- `## Phase 4 — Polish + Launch (Weeks 13-14)` — Polish specifically is fine when the phase is a checklist (a11y audit, error states, launch prep); the user-flow shape collapses into "Closed-beta launchable".

Compact roadmaps (Micro / CLI helper) may use label categories throughout — the user-flow shape adds little when there's only 2-3 phases. SMB SaaS and Venture-Scale roadmaps should use user-flow shapes for the middle phases (Killer Flow / Surrounding / per-persona) where the label tells you nothing.

### Anti-pattern (uninformative label)

- `## Phase 2 — Killer Flow (Weeks 5-8)` — what does the user gain at end of Phase 2? Not in the title. Reader has to read the table.
- `## Phase 3 — Surrounding Features (Weeks 9-12)` — "surrounding" is engineer-vocabulary; a non-engineer reading the heading learns nothing about what shipped.

Replace with the user-flow shape: `## Phase 2 — Triage a 25-issue sprint in 5 minutes (Weeks 5-8)` / `## Phase 3 — Upgrade plan + invite teammate via email (Weeks 9-12)`.

## Phase shape — deliverable rows, optional concern tags

Each phase H2 carries a deliverable table with 4-10 rows. Row format:

```markdown
| Deliverable | Owner | Status | Source |
|---|---|---|---|
| <deliverable name> [optional concern-tag] | <Eng / Designer / Founder> | not-started | <PRD US-NN; system-design § X; F-NN resolved> |
```

### Concern tags (optional disciplinary signals)

The deliverable name MAY end with a bracketed cross-functional concern tag. Allow-list:

- `[engineering]` — pure engineering work; no design or product input needed beyond what the spec carries.
- `[product+engineering]` — designer + engineer pair-implementation; the row depends on a design decision that's not pre-locked.
- `[product]` — product / designer-led work (landing copy, brand surface, partner outreach).
- `[design]` — design-only work (token revisions, illustration, in-product copy review).
- `[founder]` — founder bandwidth (partner recruiting, legal coordination, launch thread, OAuth app submission).

Tags are OPTIONAL. Omit when the team is single-discipline (solo founder coding) or when the Owner column already names the discipline. The tag exists to signal parallelisation opportunity (a `[product+engineering]` row implies designer + engineer pair) without adding a separate column.

Don't invent new tags. A 6th tag should land in this rule first via spec revision, not ad-hoc in roadmap output.

## Per-phase exit criteria

Every phase has explicit exit criteria. Without them, the phase is "done when we say it's done" — discipline gap.

### Exit criteria are testable

```markdown
**Exit criteria:** A user can sign up via `/signup`, land on `/workspace/<id>`, see the empty issue list. Sentry captures errors; PostHog captures pageview events. Two engineers have run through the flow on staging without manual intervention.
```

The criteria are testable — a reviewer can verify each clause empirically. NOT testable:

- "Foundation phase complete" (circular)
- "Auth works" (works how? for what flow?)
- "Backend deployed" (deployed to where? doing what?)

### Format — bullet list when ≥4 conditions

When exit criteria carry **4 or more observable conditions**, format as a sub-bulleted list under the bold label, NOT a single paragraph:

```markdown
**Exit criteria:**
- A user can sign up via `/signup`, land on `/workspace/<slug>`, see the empty dashboard on staging.
- Sentry captures a deliberately-thrown error from a probe route.
- PostHog records `signup_complete` events.
- Two engineers have walked the flow end-to-end on staging without manual intervention.
- Closed-beta partner #1 reproduces the demo unassisted in <5 min.
```

1-3 conditions may stay inline as a paragraph; 4+ conditions belong in a list. Wall-of-text paragraphs with 5+ semicolon-separated conditions are unscannable — a reviewer (human or sub-agent) can't check each clause individually.

### Exit criteria anchor to a real person (not just CI green)

At least one exit criterion per phase SHOULD anchor to a real human role who can independently verify the outcome — a closed-beta partner, a teammate, the founder, a design partner. NOT just "CI green / tests pass / no Sev-1 open".

Strong human-verification examples:

- `Closed-beta partner #1 completes the triage flow unassisted in ≤5 minutes.`
- `The first 3 design partners (recruited from week 1) have demoed the flow without help.`
- `An invited teammate signs in via the Resend invite email and triages an issue without facilitator intervention.`
- `Founder hands the first key to a real customer and the customer's first session lands.`

CI-only exit criteria are necessary-but-not-sufficient. A human reproducing the flow is the contract — CI green is the prerequisite, not the proof. The regression mode this discipline catches is "tests pass, but no real user has touched the flow yet, and Phase 2 ships unblocked while keyboard-triage UX is actually broken in ways the test suite doesn't catch".

### Exit criteria reference PRD stories AND step-4 findings

Where possible, exit criteria reference the PRD user-story IDs (US-NN) that the phase satisfies AND the step-4 finding IDs (F-NN) the phase resolves:

```markdown
**Exit criteria:**
- US-07 (keyboard triage) and US-19 (bulk action) both walk end-to-end on staging.
- F-12 (palette no-results state) and F-13 (palette ranked-results ordering) both resolved.
- Demo recording exists (<5 min, no narration).
- 3 design partners have walked through both flows without facilitator intervention.
```

This closes the trace — exit criteria → PRD story / step-4 finding → audit trail.

### Exit criteria are observable, not procedural

Anti-pattern: "Sprint 3 done" / "75% of tasks complete" / "all tickets closed" / "feature flag flipped".

Canonical: "A user can <do thing>" / "<artifact> exists at <path>" / "<metric> measures <value> on <env>".

The criterion's job is to be a contract the team agrees on BEFORE the phase starts. Procedural criteria let scope creep; observable criteria force scope to lock.

## Source column — full audit trail

Every deliverable row's Source column traces back to one or more prior-step artifacts. Accepted citation shapes:

- **PRD user-story IDs:** `US-NN`, `US-NN, US-MM`, `US-NN (scaffold)`, `US-NN acceptance row 3`.
- **PRD priority requirements:** `P0-N`, `P1-N`, `P2-N` (when the PRD uses priority-prefixed requirement IDs).
- **System-design section refs:** `step 9 § Services § X`, `step 9 § Data Model`, `step 9 § Integrations § Atlassian`, `system-design § APIs § Workspaces`.
- **Cost-estimate refs:** `step 10 § Build Cost Phase 1`, `step 10 § Run Cost`, `step 10 § Sensitivity row 2`.
- **Step-4 finding IDs:** `F-NN`, `F-NN resolved`, `F-NN closed`, `F-08 + F-09 resolved`. **This is the lineage step-9 + step-10 don't carry** — when a deliverable resolves an observed-user-pain finding from prototype testing, cite it. Closes the step-4 → step-11 trace from "user struggled with X" to "we shipped Y".
- **Prototype-v2 screen refs:** `prototype-v2 screens/05-triage-view.html`, `prototype-v2 screens/07-command-palette.html`. Useful when the deliverable's visual shape comes from a step-6 prototype.
- **Security / compliance refs:** `security.md § Auth § MFA posture`, `security.md § OAuth token leak`.

A single deliverable may cite multiple sources separated by semicolons (the column is comma-allergic — commas mean "this is one source with multiple parts"). Example: `step 9 § Services § ImportModule; § Integrations § Atlassian; PRD US-03, US-10, P0-1; F-08 resolved`.

A deliverable with NO Source is an anti-pattern — the row is unmotivated, and the roadmap loses its audit trail. If a deliverable genuinely has no prior-step lineage (rare; usually means it should be a v2 item, not v1), the Source column says `*founder-initiated; no prior step trace*` so the gap is visible.

## Dependency DAG (no circular deps)

Phase-to-phase dependencies are explicit AND acyclic. Draw the graph; verify it's a DAG.

### Canonical shape

```
Phase 1 (Foundation) → Phase 2 (Killer Flow) → Phase 3 (Surrounding) → Phase 4 (Polish + Launch)
                                  ↘ Phase 2.5 (Stripe integration, parallel weeks 6-8)
```

The diagram lives in `## Dependencies` as a code-fence block when ≥3 phases. Below the diagram, enumerate non-obvious edges:

```markdown
- Phase 2 depends on Phase 1 (auth + data model are prerequisites for issue CRUD)
- Phase 3 depends on Phase 2 (Stripe checkout depends on workspace creation which depends on auth)
- Phase 2.5 (Stripe Activate onboarding) runs in parallel weeks 6-8; can complete before Phase 2 ends
```

### Anti-pattern: circular dependencies

```
Phase 1 → Phase 2 → Phase 3 → Phase 1 (??)
```

Always a discipline gap — re-decompose. Usually means one of the phases is mis-scoped (Phase 3 should be split, or Phase 1 should expand to absorb the cycle source).

### Parallel work streams

Identify independent phases that CAN overlap (Phase 2.5 above). Some constraints:

- **Solo founder:** parallelism is impossible (one person, one phase at a time). Buffer the elapsed weeks accordingly.
- **2-engineer team:** can parallel 2 phases when dependencies allow. The DAG names which phases are truly independent.
- **Larger team:** more parallelism, but coordination overhead grows. A 4-engineer team doesn't ship 4x faster than a 1-engineer team — typically ~2.5x with full parallelism.

## Risk + buffer calibration (NOT flat 30%)

Per-phase: the single biggest unknown + mitigation. Buffer is calibrated per-phase by unknowns-count, NOT flat.

### Risks are SPECIFIC

Anti-pattern: "Schedule slip" / "scope creep" / "team coordination challenges". Useless — every project has these.

Canonical: "Auth0 onboarding may require custom-domain DNS coordination (typical 2-3 day delay)" / "Keyboard-triage UX needs 2-3 iterations against design-partner feedback (week 6-7 risk)" / "Stripe Activate review may take 1-2 weeks (week 6-9 risk window)".

Specific risk = nameable assumption + measurable impact-in-weeks + mitigation playbook.

### Buffer calibration table

```markdown
| Phase | Unknowns count | Buffer | Rationale |
|---|---|---|---|
| 1 Foundation | 1 (auth onboarding) | +10% | Well-understood; 1 vendor unknown |
| 2 Killer Flow | 3 (UX iteration, perf, design-partner feedback) | +25% | User-feedback-driven; highest unknown count |
| 3 Surrounding | 2 (Stripe Activate, bulk-action UX) | +20% | Medium; external dependency lag |
| 4 Polish | 1 (accessibility audit findings) | +10% | Well-understood checklist |
```

Net buffer = weighted average across phases. For a 14-week plan-of-record: 4 × 10% + 4 × 25% + 4 × 20% + 2 × 10% = 0.4 + 1.0 + 0.8 + 0.2 = **2.4 weeks honest buffer**. Plan-of-record = 14 weeks aggressive; realistic line = 16.4 weeks.

### Buffer calibration heuristics

- **Foundation phases:** +10-15% (well-understood; failure modes are known)
- **Killer-flow / UX-iteration phases:** +20-30% (user-feedback unknowns; iteration is the discipline)
- **External-dependency phases:** +15-25% (vendor onboarding lag; mitigate with frontloading)
- **Polish phases:** +5-15% (well-understood checklist; rarely slips except for late-discovery findings)

### Buffer is NOT 30% flat

The anthill-roadmap canonical skeleton said "add 30% to estimates" (flat). This is the magic-number audit-smell — hides which phases have the real risk. The MCP port calibrates per-phase.

### Buffer reporting shape

```markdown
**Buffer:** +10% on Phase 1, +25% on Phase 2, +20% on Phase 3, +10% on Phase 4. Net horizon: 14 weeks plan-of-record + 2.4 weeks buffer = 16.4 weeks honest. The 14-week line is the aggressive commitment; 16.4 weeks is the realistic line. Buffer activates phase-by-phase if the milestone slips by >50% of the phase's allotted weeks.
```

OR as a dedicated `## Buffer` H2 section (when buffer math is dominant — venture-scale projects).

## Owner discipline

Every deliverable in the phase table has exactly ONE owner. NOT "team" / "everyone" / "TBD".

### Single-owner rule

```markdown
| Deliverable | Owner | Status | Source |
|---|---|---|---|
| Postgres schema + migrations | Eng (founder) | not-started | step 9 § Data Model |
| Auth0 integration | Eng (hire) | not-started | step 9 § Integrations |
```

For a 2-engineer team, owner is `Eng (founder)` or `Eng (hire)` — names the human. For a larger team, owner is a role + name (`Eng (Alice)`, `Eng (Bob)`). "Team" / "Engineering" without specificity is the discipline gap — no one is responsible.

### When owner is TBD

If the founder genuinely hasn't decided who owns a deliverable, the roadmap surfaces it in § Open Decisions ("Decision N: Auth0 vs Supabase Auth owner") — NOT in the deliverable table as `TBD`. TBDs in the table are the procrastination mode the discipline catches.

## Product-class phase-count calibration (smart, not rigid)

Mirrors step-9 + step-10 calibration ladder. Phase count scales with product complexity:

| Product class | Phase count | Typical phase names |
|---|---|---|
| **Micro-Product / CLI helper** | 2-3 | Foundation + Build + Ship |
| **Mobile App (1 persona)** | 3-4 | Foundation + Killer Flow + Polish + App-Store-Review |
| **Developer Tool / API-first** | 3-4 | Foundation + API/Core + SDK/Dashboard + Docs/Launch |
| **SMB SaaS (the spec 026 default)** | 4-5 | Foundation + Killer Flow + Surrounding + Polish + Launch |
| **Venture-Scale / Marketplace** | 5-6+ | Foundation + Per-Persona-Onboarding (1-2) + Killer Flow + Marketplace-Bootstrap + Polish + Launch |

Brief field missing or ambiguous → default to **SMB SaaS (4-5 phases)**. Mark the chosen phase count in § Overview opening sentence.

### SMB SaaS — when 4 vs when 5 phases

The 4-or-5 choice is real, not optional. The trigger:

- **Pick 5 phases** when the killer flow has a separate migration / on-ramp demo worth recording on its own — typically `Sign up + workspace` (Phase 1) + `Import data and see it` (Phase 2) + `Use the killer flow on the imported data` (Phase 3) + `Surrounding day-to-day surfaces` (Phase 4) + `Polish + Launch` (Phase 5). Example trigger: a Jira-import-then-keyboard-triage product where the import is the migration story and the triage is the wedge story — two distinct demos. The 5-phase shape lets each demo land at a clean phase boundary.
- **Pick 4 phases** when the killer flow is a single tightly-coupled demo — no separate on-ramp / migration step worth showing alone. Foundation + Killer Flow + Surrounding + Polish + Launch (Polish + Launch merged). Example trigger: a greenfield issue tracker without import, or a product where signup directly opens onto the killer flow (no migration).

The deciding question: would the founder record TWO distinct demo videos for closed-beta partners (one "look, your data lives here now", one "look, you can clear a sprint in 5 minutes") or ONE? Two demos → 5 phases; one demo → 4 phases.

When in doubt, pick 4 phases and merge import-and-killer-flow into one. The 5-phase shape is the upgrade triggered by genuine migration-on-ramp complexity, not the default.

## Anti-patterns the discipline catches

- **Phases without exit criteria** — covered above; observable, testable, traces to PRD stories.
- **Horizontal layering** — Phase 1 backend, Phase 2 frontend. Defeats Shape Up; user value lands at end of Phase 2 only.
- **No owners on deliverables** — covered above; single-owner rule.
- **Circular dependencies** — covered above; DAG validation.
- **Over-planning distant phases** — Phase 4 in week-1 doesn't need the same detail as Phase 1. Sketch later phases; detail current + next.
- **Mixing product and engineering without labels** — label each deliverable's `Source` column with PRD US-NN (product) vs system-design § X (engineering). Closes the trace.
- **Missing risk assessment** — one risk per phase MINIMUM. NOT "at least 2" (anthill anti-patterns.md magic-number); the constraint is "every phase has a named risk + mitigation".
- **Timeline without constraints** — § Horizon names team shape, velocity assumption, hard deadlines, external coordination triggers. Without these the timeline is decorative.
- **Ignoring parallel work streams** — identify the independent phases that can overlap. Solo founders skip this; 2+ engineers MUST identify parallelism opportunities.
