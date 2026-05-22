---
mode: draft-after-input
delegable: partial
delegation_hint: "draft step-11 roadmap.md from step-8 PRD + step-9 system-design + step-10 cost-estimate — single-artifact phased plan (overview / horizon / phases / milestones / dependencies / risks / v2-vision / open-decisions) calibrated by PRD validation_mode (canonical timeline-aware path when `tested`, priority-extraction bridge path when `intuition` / `not-applicable`); parent collects 2 inputs first (time horizon + team shape); sub-agent does the structural synthesis"
---

# Step 11 — Roadmap

**Goal:** sequenced execution plan for v1 — what ships when, in what order, with which dependencies, anchored to an explicit time horizon and team shape. Plus a v2 vision sketch (3-6 month post-v1 horizon) showing the trajectory. Time-bound enough to be planning, abstract enough to survive contact with reality. The artifact step 12 (legal) reads to size the compliance budget against launch timing, and future delivery-plan steps consume to weekly vertical slices.

**Mode:** `draft-after-input` with `delegable: partial`. The parent must extract two pieces of input that no prior artifact pinned down — **time horizon** (weeks to v1 launch) and **team shape** (solo / 2-3 / larger with specialists). Once locked, the phasing derives mechanically from PRD priorities + system-design dependencies + cost-estimate build-cost ranges.

**Output file:** `roadmap.md` in `docs/`. Single-artifact — no `extra_files`.

**Two operating modes:**

- **Canonical timeline-aware path** — when PRD frontmatter declares `validation_mode: tested` (or no `validation_mode` field — assume tested for revenue-generating / venture-scale products). Full phases with week ranges, milestones, dependency graph, risks + buffer per phase, v2 sketch.
- **Bridge / priority-extraction path** — when PRD frontmatter declares `validation_mode: intuition` or `not-applicable`. Phase-grouped stories with placeholder durations, sentinel-delimited block (`<!-- anthill:bridge:begin -->` ... `<!-- anthill:bridge:end -->`) for idempotent regen. Preserves manual founder edits outside the sentinels across re-runs.

---

## How to conduct this step

Read `references/phasing-discipline.md` for the slice = end-to-end user value (Shape Up style) discipline, per-phase exit criteria conventions, and risk/buffer calibration. Read `references/milestone-format.md` for the observable end-of-phase deliverable shape ("killer flow walks end-to-end on staging" NOT "Sprint 3 done"). Read `references/phase-extraction.md` for the bridge-mode priority-tier heuristics (P0/P1/P2, MVP/Growth/Post-launch, MoSCoW).

### 1. Read everything prior

- **PRD** — `docs/prd/v1.md` — § User Stories (with `US-NN` IDs) is the story surface to sequence; § Goals + § Success Metrics drive what "v1 is done" means; § Audit Response drives step-4 audit-driven scope; **PRD frontmatter `validation_mode`** picks the operating mode.
- **System design** — `docs/system-design.md` — § Services drives the build-dependency DAG (auth before features-needing-auth; data model before features-reading-data); § Stack drives the foundation-phase line items; § Integrations drives external-vendor sequencing (Stripe onboarding lag, Auth0 vs Supabase setup).
- **Cost estimate** — `docs/cost-estimate.md` — § Build Cost RANGES (per phase) are the phasing-by-cost-pressure anchor; § Run Cost line items drive vendor-setup tasks in Foundation phase; § Recommendations are constraints (e.g. "Defer EU region" = NOT in v1 phases); § Sensitivity § Build-cost overrun is the buffer-calibration source.
- **Architecture JSON** — `docs/data-flow.json` — quick scan of the components graph confirms the dependency ordering; nodes with no inbound edges go in Foundation.

### 2. Parent collects horizon + team shape (2 questions, ~2 min)

The parent MUST conduct this exchange directly — not delegate. Two questions, sometimes a third:

1. **Time horizon.** *"Weeks to v1 launch — 6 weeks, 12 weeks, 20 weeks, or longer?"* If the PRD § Timeline or step-9 cost-estimate § Assumptions named a build-week count (it often does — assumption 2 typically sits at "14 weeks engineering + polish"), confirm rather than re-ask. The horizon must be consistent with step-10 § Build Cost's range — if the founder asks for 6 weeks but step-10 said 14, surface the mismatch before locking.

2. **Team shape.** *"Team shape — solo founder coding? 2 engineers? 4-5 with specialists?"* Affects parallelism (more people → more parallel phases) and buffer (more people → more coordination overhead, NOT less elapsed time). Push back gently if the team shape is inconsistent with the build-cost (e.g. "solo founder, 6 weeks, 14-week-cost-estimate" is heroic and slips routinely).

3. **(Optional) Hard external deadline** *(when an external date constrains the plan):* *"Any hard external date — conference launch, funding milestone, regulatory deadline?"* If present, the roadmap pins to that date and works backward; if absent, weeks-from-start is the unit.

### 3. Drafting delegates to a sub-agent

Once horizon + team locked (and PRD `validation_mode` read), the parent dispatches an `Agent` sub-agent with the 5-field brief. CONTEXT includes:

- All prior artifact paths (step 8 PRD, step 9 system-design, step 9 architecture.json, step 10 cost-estimate)
- The captured time horizon (verbatim)
- The captured team shape (verbatim)
- Optional hard deadline (or "none — weeks-from-start")
- The PRD `validation_mode` value (drives operating mode)
- The step-10 § Build Cost range (the anchor the phasing must respect)

The sub-agent's job is structural synthesis — fill the canonical roadmap template using the captured inputs + the prior-artifact reads. No more user questions; the parent's interview was the last input needing the founder.

**Phase naming — user-flow outcomes first, label categories as fallback.** Each phase title should be a sentence a non-engineer can verify as user-facing value, NOT a label like "Foundation" or "Polish". Examples:

- Good (user-flow shaped): `## Slice 1 — Sign up, land in an empty workspace (Weeks 1-3)`, `## Slice 2 — Import a Jira workspace and see real issues (Weeks 4-6)`, `## Slice 3 — Triage flow + command palette (the killer flow) (Weeks 7-9)`.
- Acceptable fallback (compact roadmaps, micro-products, or when the user-flow is the infrastructure itself): `## Phase 1 — Foundation (Weeks 1-4)`. The label categories (Foundation / Killer Flow / Surrounding / Polish + Launch) are valid compact shorthand when the slice IS the named category — Foundation phase in particular often ships hollow infrastructure with an empty-dashboard artifact, so "Foundation" is honest. Avoid label categories for the middle phases (Killer Flow / Surrounding) when a user-flow sentence is available — "Killer flow" labels what the phase is ABOUT instead of what the user can DO at end-of-phase.

The user-flow shape closes the "phase label tells you nothing about what the user gained" audit-smell — a non-engineer reading the H2 should know what was shipped without reading the table.

Use `model: opus` for the sub-agent — sonnet sometimes flattens the slice-by-end-to-end-user-value discipline into horizontal-layer phases ("Phase 1: backend; Phase 2: frontend") which is the anthill-roadmap regression mode the discipline catches.

**Deliverable concern tags (optional disciplinary signals).** Deliverable rows MAY carry a bracketed cross-functional concern tag at the end of the deliverable name: `[engineering]`, `[product+engineering]`, `[product]`, `[design]`, `[founder]`. These signal disciplinary pairing (e.g. a `[product+engineering]` row implies designer + engineer pair-implementation) and surface parallelisation opportunity without a separate column. Tags are OPTIONAL — omit when the team is single-discipline (solo founder coding) or when the Owner column already names the discipline. Allow-list is the 5 tags above; don't invent new ones (a 6th tag should land in this rule first via spec revision, not ad-hoc in roadmap output).

### 4. The canonical roadmap structure (timeline-aware mode)

The sub-agent writes `roadmap.md` against this 8-required spine (full shape with depth conventions lives in `references/phasing-discipline.md` + `references/milestone-format.md`):

1. **Overview** — short paragraph PLUS two load-bearing one-liners (mirrors step-9 § Overview + step-10 § Overview shape):
   - **Paragraph:** what's being phased (v1 build), which time horizon + team shape the founder locked, which PRD `validation_mode` selected the operating path. Names the product class (micro / mobile / dev-tool / SMB-SaaS / venture-scale) so phase-count calibration is visible.
   - **Biggest sequencing risk:** one sentence naming THE phase boundary most likely to slip. Anti-pattern: even-keeled risk distribution. Most v1 builds have ONE risk that dominates (auth-before-features bottleneck, Stripe-onboarding lag, design-system-blocks-prototype). Say it. Example: *"Biggest sequencing risk: Stripe onboarding (US-05 dependency) typically lags 2-3 weeks behind code-ready — if it slips into Phase 3, Payments unification can't ship in week-10 as planned."*
   - **Cost-pressure restate:** repeat the step-10 § Build Cost range verbatim, then declare the phasing strategy (cost-pressure-by-phase: front-load expensive Foundation work when team is fresh, or back-load polish if launch date is fixed). Example: *"Build cost is $84k-120k range (per step 10 § Build Cost). Phasing front-loads Foundation (auth + data model + observability floor — $24-32k) into weeks 1-4 with both engineers; Killer Flow (weeks 5-8, $30-42k) is the bulk; Polish (weeks 13-14, $12-16k) compresses if Phase 3 slips."*

2. **Horizon** — explicit time bounds + team shape + assumed velocity. Format:
   ```markdown
   - **Total horizon:** 14 weeks (2026-06-01 → 2026-09-07 to closed-beta launch)
   - **Team shape:** 2 engineers (founder + 1 hire), no specialists at v1
   - **Velocity assumption:** 80 engineering-hours/week (2 × 40), bake in 20% coordination overhead = 64 effective hr/week
   - **Hard deadlines:** none — weeks-from-start
   - **External coordination:** Stripe Activate onboarding (week 6-7 trigger), legal review for ToS / Privacy (week 12 trigger)
   ```

3. **Phases** — the sequence. Count calibrated by product class (see § 5 below):
   - Per phase: **Goal** (one sentence — what end-to-end user value this slice delivers) + **Week range** (e.g. weeks 1-4) + **Deliverables table** + **Dependencies** + **Exit criteria**.
   - Format (mirrors anthill-roadmap § Step 3 + step-10's table-discipline; phase title is user-flow shaped per § 3):
     ```markdown
     ## Phase 1 — Sign up, land in an empty workspace (Weeks 1-4)

     **Goal:** A user can sign up via email or Google, create a workspace, and land on an empty dashboard on staging — auth + data model + deploy pipeline + observability floor wired. No product features yet, but the infrastructure that proves the next 3 phases can ship.

     | Deliverable | Owner | Status | Source |
     |---|---|---|---|
     | Postgres schema + migrations (Workspace, User, Issue, Comment) [engineering] | Eng | not-started | step 9 § Data Model |
     | Auth0 integration + session middleware [engineering] | Eng | not-started | step 9 § Integrations; US-01 prereq |
     | Vercel + Neon deploy pipeline (preview + prod envs) [engineering] | Eng | not-started | step 9 § Deployment |
     | Empty-state dashboard — `aria-live="polite"` hint inviting first action [product+engineering] | Designer + Eng | not-started | step 9 § Frontend modules; F-08 resolved |
     | Sentry + PostHog wired (observability floor) [engineering] | Eng | not-started | step 10 § Run Cost; step 9 § Observability |

     **Dependencies:** none (Foundation is the root)

     **Exit criteria:**
     - A user can sign up via `/signup`, complete email or Google OAuth, land on `/workspace/<slug>` and see the empty dashboard on staging.
     - Sentry captures a deliberately-thrown error from a probe route.
     - PostHog records `signup_complete` events for the cohort.
     - Both engineers have walked the flow end-to-end on staging without manual intervention.
     - Closed-beta partner #1 reproduces the signup-to-dashboard flow unassisted (founder-led 5-min screenshare; the first real-human verification of v1's surface).

     **Build cost range (from step 10 § Build Cost):** $24-32k
     ```
   - **Slice = end-to-end user value, NOT horizontal layer.** A slice might include backend + frontend + tests for one complete user flow. Anti-pattern: "Phase 1: all backend; Phase 2: all frontend" (Shape-Up violation).
   - Status values: `not-started` / `in-progress` / `done` / `blocked` / `at-risk`. For greenfield v1, everything starts at `not-started`.
   - Source column references prior-step artifacts (`step 8 PRD US-NN`, `step 9 § X`, `step 10 § Y`). This is the audit trail — every deliverable traces back.

4. **Milestones** — observable end-of-phase deliverables. 3-6 across v1 total. Each one is "you'd recognise it when you see it" — not "Sprint 3 done". See `references/milestone-format.md` for the format discipline.
   ```markdown
   - **M1 (end of week 4):** Killer-flow precondition met — `/signup` → workspace dashboard walks end-to-end on staging with auth + DB + observability wired.
   - **M2 (end of week 8):** Killer flow walks end-to-end on staging — keyboard-first triage (US-07) and bulk-action (US-19) demoable to a non-engineer in <5 min.
   - **M3 (end of week 12):** Feature-complete — all P0 stories from step 8 PRD shipped behind feature flag.
   - **M4 (end of week 14):** Closed-beta launch — 10 design-partner workspaces invited; Sentry + PostHog dashboards live.
   ```

5. **Dependencies** — sequencing constraints between phases AND external dependencies (vendor onboarding, legal review, design-partner recruiting). Format:
   ```markdown
   ### Phase-to-phase

   ```
   Phase 1 (Foundation) → Phase 2 (Killer Flow) → Phase 3 (Surrounding) → Phase 4 (Polish + Launch)
                                      ↘ Phase 2.5 (Stripe integration, parallel weeks 6-8)
   ```

   ### External

   - **Stripe Activate onboarding** — trigger at week 6 (mid-Phase 2); typical 1-2 week review delay, must complete before week-9 Phase 3 entry
   - **Legal review (ToS + Privacy)** — trigger at week 12 (start of Phase 4); allocate 1 week elapsed
   - **Design-partner recruiting** — start at week 1 (parallel to Foundation); need 10 commits by end of week 13
   ```
   - **No circular dependencies.** Draw the graph; verify it's a DAG. The graph block is required when ≥3 phases.

6. **Risks + Buffer** — per-phase: the single biggest unknown + mitigation. Plus a buffer line that calibrates by team-shape × unknowns-count (see `references/phasing-discipline.md` § Buffer calibration). Format:
   ```markdown
   | Phase | Biggest risk | Probability | Impact | Mitigation |
   |---|---|---|---|---|
   | 1 Foundation | Auth0 integration debt (custom domain + session-handling edge cases) | Medium | +1 week slip | Wire Auth0 in week 1 (frontload); fallback to Supabase Auth if Auth0 onboarding stalls |
   | 2 Killer Flow | Keyboard-first triage UX (US-07) requires 2-3 iterations against design-partner feedback | High | +1-2 weeks slip | Ship rough version end of week 6 to first 3 design partners; iterate in week 7 |
   | 3 Surrounding | Stripe Activate onboarding lag | Medium | +2-3 weeks slip | Submit application week 6 (NOT week 9); have fallback metered-billing if Stripe rejects |
   | 4 Polish | Accessibility audit surfaces blocker findings | Low | +1 week slip | Run axe-core early in week 13; budget 2 days for remediation |

   **Buffer:** +20% on Phase 2 + 3 estimates (the slice-risk phases), +10% on Phase 1 + 4 (lower-unknown phases). Net horizon: 14 weeks + 2.5 weeks buffer = 16.5 weeks honest. The 14-week plan-of-record is the aggressive line; 16.5 weeks is the realistic line.
   ```
   - Buffer is calibrated by phase, NOT flat-30%. Foundation is well-understood (lower buffer); Killer Flow has the most user-feedback unknowns (higher buffer).

7. **v2-Vision** — 3-5 bullets describing the next 3-6 months post-v1 launch. Drives platform / extension decisions in v1. Format:
   ```markdown
   - **Public API + webhook surface (3 months post-launch).** v1 internal API is REST-shaped to absorb this without refactor. Drives v1 decision: model internal API as resource-oriented (NOT RPC-shaped).
   - **AI-assisted triage (4-5 months post-launch).** v1 keyboard-first triage produces the training corpus (user actions → triage decisions). Drives v1 decision: log triage actions with intent (not just side-effect) in PostHog.
   - **Mobile companion app (6 months post-launch, deferred).** v1 does NOT design for mobile; web-first is the v1 wedge. Drives v1 decision: skip mobile-responsive polish in Phase 4 (saves ~1 week).
   ```
   - 3-5 bullets, NOT a roadmap-2.0. Sketch, not plan. The bullets exist to anchor v1 design decisions that are reversible in v1 but expensive in v2.

8. **Open Decisions** — decisions the founder hasn't made yet that the roadmap is parked on. Each row carries a deciding signal. Mirrors step-9 + step-10's `Open Decisions` / `Recommendations § Flip if:` discipline. Format:
   ```markdown
   | # | Decision | Default if no decision by | Deciding signal |
   |---|---|---|---|
   | 1 | Public launch date — week 14 (aggressive) or week 16 (buffer-honest)? | end of week 8 (end of Killer Flow phase) | Phase 2 milestone slip; if ≥1 week slip by week 8, default to week 16 |
   | 2 | Auth0 vs Supabase Auth — primary auth provider | end of week 2 | Auth0 onboarding latency; if Auth0 docs / setup blocks for >2 days, switch to Supabase Auth |
   | 3 | Stripe Standard vs Stripe Activate (subsidiary onboarding model) | end of week 5 | Founder bandwidth to navigate Activate forms (~4 hr commitment) vs accept Standard fees (~1% higher) |
   ```
   - 2-4 rows is the target. NOT every decision — just the ones the roadmap is parked on. Each row has a deciding signal that closes the deferral.

### 5. Calibrate by product class (smart, not rigid)

Mirrors step-9 + step-10 calibration ladder. **Phase count + roadmap depth scale with product complexity:**

| Product class | roadmap.md depth | Phase count | Notes per section |
|---|---|---|---|
| **Micro-Product / CLI helper / single-purpose tool** | Compact ~6 KB | 2-3 phases | Foundation + Build + Ship. § Milestones collapses to 2-3. § v2-Vision optional (some micro-products genuinely v1-and-done). § Open Decisions may have 1-2 rows only. |
| **Mobile App (focused, 1 persona)** | Standard ~9 KB | 3-4 phases | Adds App-Store-Review phase (1-2 week buffer for first review). § Risks: review-rejection probability + remediation playbook is a load-bearing row. |
| **Developer Tool / API-first** | Standard ~9 KB | 3-4 phases | Foundation + API/Core + SDK/Dashboard + Docs/Launch. § Dependencies emphasises external SDK consumers (early-access programs, beta-partner onboarding). |
| **SMB SaaS (the spec 026 default)** | Full ~10-12 KB | 4-5 phases | Foundation + Killer Flow + Surrounding + Polish + Launch (sometimes Polish + Launch merge to 4). § Risks: 4 phase rows + buffer calibration. § Open Decisions: 2-4 rows typical. **Pick 5 phases when the killer flow has a separate migration / on-ramp demo worth separating from the post-import core flow (e.g. import-then-triage — Slice 2 = "import a workspace and see real issues", Slice 3 = "triage flow + command palette"); pick 4 phases when the killer flow is a single tightly-coupled demo (no separate on-ramp / migration step worth showing alone).** The trigger is whether the founder would record TWO distinct demo videos for closed-beta partners (one "look, your data lives here now", one "look, you can clear a sprint in 5 minutes") or ONE. Two demos → 5 phases; one demo → 4 phases. |
| **Venture-Scale / Marketplace / multi-persona** | Expanded ~14-18 KB | 5-6+ phases | Foundation + Per-Persona-Onboarding (1-2 phases) + Killer Flow + Marketplace-Bootstrap + Polish + Launch. § Dependencies graph carries cross-persona ordering (supply side before demand side, typical). |

Brief field missing or ambiguous → default to **SMB SaaS (Full, 4-5 phases)**. Mark the chosen class + phase count in `## Overview` opening sentence (`v1 roadmap for an SMB SaaS — 4-phase full template applied.`).

For non-revenue (free / not-for-profit / internal) products: structure unchanged; § Open Decisions § revenue-related rows drop; § Risks § business-impact rows degrade to operational-impact ("loss of internal user trust", "tool unused by Q3"). Document the class explicitly in § Overview.

### 6. Bridge mode — when PRD `validation_mode` is `intuition` or `not-applicable`

When PRD frontmatter declares `validation_mode: intuition` or `not-applicable`, the canonical timeline-aware path is overkill — the founder hasn't validated enough to commit to a timeline. The bridge mode produces a real-light roadmap that extracts phases from PRD priority tiers (P0 → Phase 1 MVP, P1 → Phase 2 Growth, P2 → Phase 3 Optimization) WITHOUT synthesizing a timeline the founder never produced.

The bridge mode:

1. **Reads PRD frontmatter `validation_mode`.** If `tested` (or absent), fall back to canonical timeline-aware path (§ 4 above).
2. **Extracts priority tiers from PRD.** See `references/phase-extraction.md` for the heuristics (P0/P1/P2 explicit markers; MVP/Growth/Post-launch equivalents; Must/Should/Could MoSCoW; section-based grouping). If no priority tagging detected, refuse with `code: "schema-incomplete"` and `missing_or_invalid: ["PRD has no priority tiers; add P0/P1/P2 tagging before /11-roadmap"]`.
3. **Groups stories into phases:**
   - **Phase 1 — MVP** ← all P0 (or MVP / must-have) stories
   - **Phase 2 — Growth** ← all P1 (or growth / should-have) stories
   - **Phase 3 — Optimization / Post-launch** ← all P2 (or post-launch / could-have) stories

   Empty phases are still emitted (with note `*No stories at this priority tier — Phase will be re-evaluated post-Phase N stability.*`).
4. **Emits sentinel-delimited block.** All bridge-generated content sits between `<!-- anthill:bridge:begin -->` and `<!-- anthill:bridge:end -->`. On re-run, only the content between sentinels regenerates — manual founder edits OUTSIDE the sentinels (durations once Phase 1 ships, post-incident notes, executive narrative) are preserved verbatim.
5. **NO timeline / durations / dates.** The bridge has no week ranges by default; `**Estimated duration:** TBD pre-delivery-plan` is the placeholder. The bridge does NOT estimate; only the canonical mode does.
6. **NO buffer math, NO dependency graph (cross-phase only).** Phase-to-phase gates suffice: Phase 2 depends on Phase 1 success criteria; Phase 3 depends on Phase 2 stability.

Bridge-mode required sections collapse to: `overview`, `horizon` (declares "TBD pre-delivery-plan"), `phases`, `dependencies`, `v2-vision` (collapses to "deferred — re-evaluate post-MVP"), `open-decisions`. § Milestones + § Risks degenerate to one-line `*Re-evaluated at /anthill-delivery-plan time*`.

The agent reports operating-mode at top of file: `**Mode:** bridge (priority-extraction; validation_mode: intuition)` — visible to downstream consumers.

### 7. Submit + advance

Call `product_step_submit` with:
- `step: 11`
- `filename: "roadmap.md"`
- `content: <full roadmap>`

No `extra_files` — single-artifact step.

Schema enforces section presence + Layer 1 contains/size floors (phase heading, deliverable-table header, milestone format anchor). On success, `product_advance` moves to step 12 (legal-posture — reads roadmap to size launch-timing-driven compliance budget).

**No gate at step 11.** Step 12 closes the Specification phase gate. Steps 8 → 12 advance fluidly through Specification.

---

## Voice & rigor

- **Concrete dates only if dates are real.** Real launch deadline, conference window, regulatory cutoff. Otherwise weeks-from-start (`Week 3-6: Phase 2`). Dates without commitment rot fast. Anti-pattern: invented dates that signal false precision.
- **The killer flow gets a phase to itself.** Don't split it across phases — it's the spine. Surrounding features fit AROUND the killer flow, NOT before it.
- **Slice = end-to-end user value, NOT horizontal layer.** A slice = backend + frontend + tests for one complete user flow. Anti-pattern: "Phase 1: all backend; Phase 2: all frontend" — defeats Shape Up discipline; user value lands only at end of Phase 2.
- **Resist heroic estimates.** Solo founder building v1 in 3 weeks works for very-small v1s; everything else slips. Push back on horizon-cost mismatches at the interview step, NOT post-hoc.
- **Buffer is per-phase, NOT flat.** Foundation is well-understood (lower buffer); Killer Flow has the most user-feedback unknowns (higher buffer). Polish has the lowest unknown count (well-understood checklist). A flat-30% buffer hides which phases have the real risk.
- **Risks are SPECIFIC.** "Schedule slip" is not a risk; "OpenAI tokens may exceed budget if usage 3x our assumption — mitigation: per-user rate limit ships with auth" is. Every phase row in § Risks names the assumption + the impact-in-weeks + the mitigation playbook.
- **Milestones are observable, not procedural.** "Killer flow walks end-to-end on staging" is observable; "Sprint 3 done" / "feature-complete" / "75% progress" are procedural. Procedural milestones rot — they describe agent work, not user value.
- **Exit criteria anchor to a real person who can verify the outcome, not just CI green.** Where possible, name a concrete human role — closed-beta partner #N, a teammate, the founder — who can independently confirm the outcome. Example: `Closed-beta partner #1 reproduces the demo unassisted in <5 minutes` is stronger than `Axe-core CI gate green`. CI checks are necessary-but-not-sufficient; a human reproducing the flow is the contract. At least one exit criterion per phase SHOULD name a human-verification clause; "CI green + tests pass + no Sev-1" alone is the regression mode this discipline catches.
- **v2 vision anchors v1 decisions.** 3-5 bullets max. Each bullet carries a "drives v1 decision" clause that names what v1 should design FOR or AGAINST. Without the v1-decision clause, v2 sketch is decorative.
- **Open Decisions carry deciding signals.** Every deferred decision either HOLDS or FLIPS on a measurable signal. Mirrors step-9 § Open Decisions § Deciding signal and step-10 § Recommendations § Flip if: discipline.
- **No meta-commentary section about the document's own discipline.** Do NOT write a `## Notes on this roadmap's sequencing discipline` or any equivalent. The phases + dependencies + risks + buffer math ARE the discipline; a section *about* them is noise. (Inherits step-9/10 CUT-2.)
- **No "locked decisions" sub-section.** Time horizon, team shape, optional deadline are locked in running prose of § Horizon. Re-tabling them as a separate Locked H2 duplicates the running commitment. (Inherits step-9/10 CUT-1.)
- **PRD `US-NN` cross-references in the deliverable Source column.** Every Phase deliverable row traces back to a PRD story / system-design section / cost-estimate line. This is the audit trail; without it, the roadmap is a wish list.
- **Step-4 finding-ID lineage in the Source column.** The Source column MAY also cite step-4 (ux-testing) finding IDs (`F-NN`, `F-NN resolved`, `F-NN closed`) when the deliverable resolves a step-4 finding. Example: `prototype-v2 screens/07-command-palette.html, F-12 + F-13 resolved`. This adds the step-4 → step-11 lineage that step-9 + step-10 don't carry — closes the trace from observed-user-pain → shipped-fix. Skip when no step-4 finding applies; the citation is opportunistic, not mandatory.
- **No metadata banner with pipe-separators at the top of the file.** Do NOT emit a header line in the shape `**Pipeline step:** 11 (Roadmap) | **Generated:** YYYY-MM-DD | **Mode:** canonical (...)` (or any other pipe-delimited metadata banner with `Status:` / `Reads:` / `Inputs locked at...` blocks). Ceremony with no payoff — the file's title + the inline `**Mode:**` declaration near § Overview already carry the operating-mode signal, and "Pipeline step: 11" is recoverable from the file's path. The single `**Mode:** canonical (timeline-aware; validation_mode: tested)` line near the top is fine; the metadata-banner shape is the anti-pattern.
- **Exit criteria with ≥4 observable conditions format as a sub-bulleted list, not a single paragraph.** The bold `**Exit criteria:**` label introduces a sub-list (`- ...`) when 4+ conditions are listed. Wall-of-text paragraphs with 5+ semicolon-separated conditions are unscannable; the bulleted shape lets a reviewer (human or sub-agent) check each clause individually. Single-condition or 2-3-condition exit criteria may stay inline as a paragraph. Format example lives in `references/milestone-format.md` § Exit criteria + `references/phasing-discipline.md` § Exit criteria.

## What this step does NOT do

- **Sprint planning.** Roadmap is phases/weeks; sprints are week-by-week tasks. Sprint planning is `/anthill-delivery-plan` (future MCP step) or `/sdd new <feature>` post-pipeline.
- **Detailed task breakdowns.** Per-feature engineering specs come from `/sdd` post-pipeline. The roadmap names deliverables; the deliverables decompose to tasks in `/sdd`.
- **Hiring plans.** Step 10 cost-estimate touched team cost; hiring sequence is post-handoff. The roadmap assumes the team shape locked at § 2; it does NOT plan when to hire.
- **Post-launch growth roadmap.** Post-launch territory (future MCP step 18+ GTM). The v2-Vision section sketches direction; it does NOT plan launch + post-launch metrics tracking.
- **Capacity / velocity modeling.** No story-point math, no velocity-from-prior-sprints. v1 is greenfield; velocity assumption is industry-default (40 hr/eng-week, 20% coordination overhead).
- **Issue-board ingestion.** Anthill's `anthill-roadmap` ingests `.anthill/issues/issue-*.md` at Step 2b. The MCP doesn't have a fork-side issue tracker; issue ingest is deferred to a future MCP step. Consumer tracker integration (Linear, Jira, GitHub Issues) lives downstream of the pipeline.

## What this step ports vs diverges

Step 11 ports **anthill-roadmap** (179 LOC SKILL + 51 LOC references — anti-patterns + checklist + examples) AND **anthill-roadmap-bridge** (189 LOC SKILL + 180 LOC references — phase-extraction). The MCP port keeps anthill's load-bearing disciplines (phase shape; exit criteria per phase; dependency DAG; risks-with-mitigations; slice = end-to-end user value Shape-Up style) and inherits its anti-patterns catalog (phases-without-exit-criteria, circular deps, no-owners, missing-risk-assessment).

The MCP port diverges from anthill on six points worth naming:

1. **Two-mode unification.** Anthill ships TWO separate skills (`anthill-roadmap` for canonical, `anthill-roadmap-bridge` for intuition / not-applicable). The MCP port unifies into ONE template with PRD-`validation_mode`-keyed mode selection. Both paths share the same Layer-1 schema floor + section list (with bridge-mode degenerate sections explicitly noted). Removes the "which skill do I invoke?" decision from the founder; the PRD's `validation_mode` declaration drives the routing. The sentinel-delimited block (`<!-- anthill:bridge:begin -->` ... `<!-- anthill:bridge:end -->`) discipline is preserved for idempotent regen.

2. **Product-class calibration ladder.** Anthill ships 4 fixed phases (Foundation / Killer flow / Surrounding / Polish) as the universal shape. The MCP port calibrates phase count by product class — Micro 2-3 phases, Mobile / Dev Tool 3-4, SMB SaaS 4-5, Venture-Scale 5-6+. Closes the "one-mode template" audit-smell. Brief defaults to SMB SaaS Full (4-5 phases) when unspecified.

3. **Per-phase buffer calibration.** Anthill anti-patterns.md says "at least 2 risks per phase" (magic number) and the canonical skeleton said "add 30% to estimates" (flat buffer). The MCP port calibrates buffer per-phase by unknowns-count (Foundation +10%, Killer Flow +20%, Polish +10% typical) and risk-count is "biggest unknown per phase" (one row, not 2 minimum). Closes the "magic numbers" audit-smell.

4. **Cost-pressure phasing anchor.** Anthill-roadmap doesn't read a cost-estimate (anthill steps 10 + 11 are independent). The MCP step-11 reads step-10 § Build Cost RANGES as the phasing-by-cost-pressure input — front-loads expensive Foundation work when team is fresh, OR back-loads polish if launch date is fixed. Closes the cross-step contract gap that step-10's § Build Cost was opening.

5. **§ Open Decisions with deciding signals (mirrors step-9 + step-10).** Anthill-roadmap has `## Open Questions` (questions without resolution mechanism — discipline gap). The MCP port replaces with `## Open Decisions` (decisions WITH a deciding signal that closes the deferral). Inherits step-9's `Deciding signal` column and step-10's `*Flip if:*` recommendation discipline.

6. **Parent-collects-2-questions split (delegable: partial).** Anthill-roadmap is single-orchestrator (one agent does the interview + research + draft). The MCP port splits: parent collects time horizon + team shape live (2 questions); sub-agent synthesises structurally from prior artifacts. Closes the "single-orchestrator" audit-smell + mirrors step-10's interview-then-synthesize discipline.

Anthill's `.anthill/issues/` ingestion (Step 2b) is NOT ported — the MCP doesn't have a fork-side issue tracker. Consumer tracker integration (Linear, Jira, GitHub Issues) is deferred to a future MCP step. Anthill's halt-protocol (`Halting: Missing prerequisite: ...`) translates to the MCP's `product_step_submit` validation error semantics (`{code: "schema-incomplete", missing_or_invalid: [...]}`). Resumability is `product_status` + `.state.json`.

### Calibration revisions (2026-05-16)

Blind judge feedback on the step-11 dogfood scored the MCP template 30/30 vs anthill's canonical 17/30. Five disciplines from the lower-scoring template were nonetheless worth absorbing (KEEPs); two patterns the MCP template carried were worth cutting (CUTs). Inheritance from step-11 judge-feedback (mirrors step-9 + step-10's commit-body convention):

1. **KEEP — User-flow shaped phase names.** Phase H2 titles read as user-flow outcomes ("Sign up, land in an empty workspace") not phase labels ("Foundation"). Documented in § 3 Drafting + `references/phasing-discipline.md` § Phase naming. The label categories (Foundation / Killer Flow / Surrounding / Polish + Launch) remain valid fallback shorthand for compact roadmaps and for the Foundation phase specifically.
2. **KEEP — Cross-functional concern tags on deliverable rows.** Optional `[engineering]` / `[product+engineering]` / `[product]` / `[design]` / `[founder]` tags signal disciplinary pairing without a separate column. Documented in § 3 Drafting + `references/phasing-discipline.md` § Phase shape. Optional — omit when single-discipline.
3. **KEEP — Real-human acceptance in exit criteria.** At least one exit criterion per phase SHOULD name a concrete human role (closed-beta partner #N, a teammate, the founder) who can independently verify the outcome. Documented in § Voice & rigor + `references/phasing-discipline.md` § Exit criteria + `references/milestone-format.md`.
4. **KEEP — 5-phase trigger for SMB SaaS sharpened.** Pick 5 phases when the killer flow has a separate migration / on-ramp demo worth recording separately (import-then-triage); pick 4 phases when the killer flow is a single tightly-coupled demo. Documented in § 5 product-class calibration ladder.
5. **KEEP — Step-4 finding-ID lineage in Source columns.** Source column may cite `F-NN`, `F-NN resolved`, `F-NN closed` when the deliverable resolves a step-4 (ux-testing) finding. Adds the step-4 → step-11 lineage that step-9 + step-10 don't carry. Documented in § Voice & rigor + `references/phasing-discipline.md` § Source column.
6. **CUT — Metadata banner with pipe-separators at top of file.** No `**Pipeline step:** 11 (Roadmap) | **Generated:** YYYY-MM-DD | **Mode:** canonical (...)` header — ceremony with no payoff. The single inline `**Mode:** canonical (timeline-aware; validation_mode: tested)` line is fine; the banner shape is the anti-pattern. Documented in § Voice & rigor.
7. **CUT — Wall-of-text exit-criteria paragraphs.** When exit criteria carry ≥4 observable conditions, format as sub-bulleted list under the bold label, not single paragraph. Documented in § Voice & rigor + `references/milestone-format.md` + `references/phasing-discipline.md` § Exit criteria.

Step-9 + step-10's prior calibration anti-patterns are preserved unchanged: § Voice & rigor still carries "no meta-commentary section" and "no Locked Decisions sub-section" (the two CUTs from step-9/10 calibration).
