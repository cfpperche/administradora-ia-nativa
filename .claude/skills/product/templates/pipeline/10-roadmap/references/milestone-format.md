# Milestone format — observable end-of-phase deliverables (NOT procedural)

How to write `## Milestones` in `roadmap.md`. The format discipline that prevents procedural rot ("Sprint 3 done") and surfaces observable user value ("killer flow walks end-to-end on staging").

## The format

Each milestone is one line. Format:

```markdown
- **M<N> (end of week <N>):** <observable outcome — what a non-engineer can verify in <5 min>
```

Examples:

```markdown
- **M1 (end of week 4):** Killer-flow precondition met — `/signup` → workspace dashboard walks end-to-end on staging with auth + DB + observability wired.
- **M2 (end of week 8):** Killer flow walks end-to-end on staging — keyboard-first triage (US-07) and bulk-action (US-19) demoable to a non-engineer in <5 min.
- **M3 (end of week 12):** Feature-complete — all P0 stories from step 8 PRD shipped behind feature flag on staging.
- **M4 (end of week 14):** Closed-beta launch — 10 design-partner workspaces invited; Sentry + PostHog dashboards live.
```

3-6 milestones total across v1 — one per phase plus 1-2 mid-phase markers for long phases.

## Observable, NOT procedural

### Canonical (observable)

- "Killer flow walks end-to-end on staging"
- "User can sign up, create a workspace, see the empty dashboard"
- "Demo recording (<5 min, no narration) exists at `<url>`"
- "First 3 design partners have walked through the flow without facilitator intervention"
- "Closed-beta partner #1 reproduces the demo unassisted in <5 minutes"
- "Accessibility audit (axe-core) reports zero blocker findings on staging"
- "Sentry dashboard captures errors on staging for 7 consecutive days with no Sev-1 unaddressed"

These are CONTRACTS a non-engineer can verify empirically. Either the demo recording exists or it doesn't; either accessibility audit is clean or it isn't.

### Anchor at least one criterion to a real human

A milestone is strongest when at least one of its conditions names a specific human role who can independently verify the outcome — a closed-beta partner, a teammate, the founder, a design partner. Examples:

- `Closed-beta partner #1 completes the triage flow unassisted in ≤5 minutes.`
- `The first 3 design partners have walked through both flows without facilitator intervention.`
- `An invited teammate signs in via the Resend invite email and triages an issue without help.`
- `Founder hands the first key to a real customer and the customer's first session lands.`

"CI green + tests pass + no Sev-1 unaddressed" is necessary-but-not-sufficient — a human reproducing the flow is the contract. CI green proves the artifact builds; a partner using it proves the artifact works. The regression mode this catches: phase ships, tests pass, no human has actually touched it, Phase 2 starts unblocked while the killer flow is broken in ways the test suite doesn't exercise.

### Anti-pattern (procedural)

- "Sprint 3 done"
- "75% of tasks complete"
- "All tickets closed"
- "Feature-flag flipped to production"
- "PR #142 merged"
- "Test coverage at 80%"

These describe AGENT WORK, not user value. They rot — at week 4, "Sprint 3" is meaningless; at week 8, "PR #142" is forgotten. Procedural milestones also let scope creep — "Sprint 3 done" doesn't say WHAT was done.

## Exit criteria — bullet list when ≥4 conditions

Milestones live in § Milestones (one line each). Per-phase **exit criteria** (under each Phase H2 in § Phases) follow a similar discipline — observable conditions, real-human anchors where possible — but their FORMAT differs based on count.

### Canonical (4+ conditions → sub-bulleted list)

```markdown
**Exit criteria:**
- A user can sign up via `/signup`, complete email or Google OAuth, land on `/workspace/<slug>` on staging.
- Sentry captures a deliberately-thrown error from a probe route.
- PostHog records `signup_complete` events for the cohort.
- Both engineers have walked the flow end-to-end on staging without manual intervention.
- Closed-beta partner #1 reproduces the signup-to-dashboard flow unassisted in <5 min.
```

### Acceptable (1-3 conditions → inline paragraph)

```markdown
**Exit criteria:** A user can sign up via `/signup`, land on `/workspace/<slug>`, see the empty dashboard. PostHog captures the `signup_complete` event.
```

### Anti-pattern (wall-of-text paragraph with 5+ semicolon-separated conditions)

```markdown
**Exit criteria:** A user can hit /signup, complete signup via email OR Google, create a workspace at a slug, and land on an empty /dashboard on staging; Sentry captures a deliberately-thrown error from a probe route; PostHog captures the signup_complete event for the cohort; Logtail receives one structured log per authenticated request; both engineers (founder + hire) have walked the flow end-to-end on staging without manual intervention; Atlassian OAuth client_id + Stripe production-account onboarding both initiated.
```

Unscannable. A reviewer can't check each clause individually; the wall-of-text packs 6 conditions into one prose block, and three of them are buried mid-sentence. Format as a sub-bulleted list when there are 4+ conditions — scannability is the point.

The rule: **count the observable conditions in the criterion. If 4+, format as sub-bullets under the bold label. If 1-3, inline as a paragraph is fine.**

## Trace to PRD stories where possible

Where the milestone satisfies specific PRD stories, name them:

```markdown
- **M2 (end of week 8):** US-07 (keyboard triage) and US-19 (bulk action) walk end-to-end on staging.
```

This closes the trace: milestone → PRD US-NN → audit trail back to discovery phase. Without the US-NN reference, the milestone is unanchored — "killer flow walks end-to-end" could mean anything.

## Milestone count by phase count

| Phase count | Milestone count | Pattern |
|---|---|---|
| 2-3 phases (micro) | 2-3 milestones | One per phase end |
| 3-4 phases (mobile / dev-tool) | 3-4 milestones | One per phase end |
| 4-5 phases (SMB SaaS) | 4-5 milestones | One per phase end |
| 5-6+ phases (venture-scale) | 5-8 milestones | One per phase end + 1-2 mid-phase markers for the longest phases |

**Mid-phase markers** are optional and only for long phases (>6 weeks). Example: a 10-week Killer Flow phase might carry a week-5 mid-phase marker ("First killer-flow demo exists — rough, unpolished, demonstrates the core interaction") in addition to the week-10 phase-end milestone.

## The "5-minute test"

A good milestone passes the **5-minute test**: a non-engineer can verify it in under 5 minutes by:

1. Reading the milestone
2. Following the verification path it implies
3. Producing a yes/no answer

Examples that pass:
- "User can sign up via `/signup` → land on `/workspace/<id>`" → non-engineer opens browser, follows link, sees dashboard.
- "Demo recording (<5 min) exists at `<url>`" → non-engineer clicks link, watches video, confirms it shows what milestone claims.
- "axe-core report shows zero blocker findings on staging" → non-engineer opens CI artifact link, reads report header.

Examples that fail:
- "Killer flow is working" — what does "working" mean? Who verifies?
- "Stripe integration complete" — complete how? Tested? In production?
- "Polish phase done" — done by whose standard?

## Milestones declare DATES (or week numbers)

Each milestone has a date (when real launch deadline) OR a week-from-start number (when no fixed deadline). Format:

```markdown
- **M1 (end of week 4):** ... (no fixed launch date — weeks-from-start)
- **M1 (2026-07-12):** ... (fixed launch date — 2026-09-15 closed-beta target backed up 9 weeks)
```

Anti-pattern: "M1: TBD" / "M1 (eventually)" / "M1 (Phase 1)" — defeats the planning purpose. If the milestone has no date, the founder doesn't have a roadmap; they have a wishlist.

## Mid-phase markers (optional)

For phases >6 weeks, add 1-2 mid-phase markers. Useful for:

- **Early demo gates** — "Rough killer-flow demo exists at end of week 5" (forces 50% completion checkpoint)
- **Design-partner feedback gates** — "First 3 design partners have walked through the flow at end of week 6" (forces user-feedback loop)
- **External-coordination gates** — "Stripe Activate application submitted by end of week 6" (forces external-dependency frontloading)

Format:

```markdown
- **M2a (end of week 5, mid-Phase 2):** Rough killer-flow demo exists — keyboard triage works, UI is rough, no error states yet. Demo recording exists.
- **M2 (end of week 8, end-Phase 2):** Killer flow walks end-to-end on staging — keyboard triage + bulk action + UI polish + error states + tests.
```

Mid-phase markers are SUFFIX-numbered (`M2a`, `M2b`) under the parent end-of-phase milestone. Keep total milestones ≤8 across v1; more than that means the phase decomposition was too coarse.

## When to skip § Milestones

Bridge-mode roadmaps (PRD `validation_mode: intuition` / `not-applicable`) degrade § Milestones to `*Re-evaluated at /anthill-delivery-plan time*`. The bridge has no week numbers; without week numbers, milestones degenerate to phase-end markers ("end of MVP", "end of Growth") which add no information beyond the phase headings.

Canonical-mode roadmaps NEVER skip § Milestones. They are the load-bearing observable-contract section.

## Anti-patterns the format catches

- **Procedural rot:** "Sprint N done", "PR # merged", "all tickets closed" — describe agent work, not user value.
- **Vague observable:** "Killer flow is working" — what does "working" mean? Who verifies?
- **Date-less milestones:** "M1: TBD" — defeats the planning purpose.
- **One-milestone-per-week** — confuses milestones with sprint goals. Milestones are PHASE-end (or phase-mid for long phases), NOT week-end.
- **More than 8 milestones in v1** — phase decomposition was too coarse; rescope phases.
- **No trace to PRD US-NN** — milestone is unanchored; reader can't verify what scope it represents.
