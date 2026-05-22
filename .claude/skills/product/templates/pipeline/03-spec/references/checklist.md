# Step-3 self-review checklist

Run before calling `product_step_submit`. Synthesised from `anthill-spec` and `anthill-feature-refiner` checklists. If a box can't be checked, fix it before submitting — Layer 1 will reject some of these mechanically, but most are quality gaps only this review catches.

## Inputs

- [ ] Read the step-1 concept brief — JTBD, target persona(s), killer flow, anti-goals internalised
- [ ] Read the step-2 prototype — all 3 directions + the chosen direction's hi-fi screens
- [ ] No prior artifact was missing or thin; if one was, stopped and flagged the parent rather than fabricating

## `functional-spec.md` — coverage

- [ ] `## Product Overview` present — 3–5 sentences, traceable to the concept brief
- [ ] `## Pages & Surfaces` — every page has a subsection, including auth, settings, admin, empty-first-run
- [ ] Every page subsection has: purpose, entry points, ASCII wireframe, Components table, Interactions table, States table
- [ ] Every interactive element appears in its page's Components table (no "obvious" omissions)
- [ ] Every interactive component has an Interactions row with concrete trigger / action / result
- [ ] Every page has at minimum empty / loading / error / populated states
- [ ] `## Features` — every feature decomposed: what it does, happy path, edge cases, success criterion
- [ ] No invented features — every feature traces to a step-1/step-2 surface
- [ ] Edge cases are feature-specific, not a generic copy-pasted list
- [ ] Success criteria are observable (they feed step 4's tests)
- [ ] `## Navigation Map` — ASCII diagram covers every page transition + trigger; no orphan pages
- [ ] `## Cross-Cutting Concerns` — auth / persistence / a11y / i18n, one paragraph each where they apply
- [ ] `## Acceptance Scenarios` — every feature with 3+ branches has 2–4 `**Given/When/Then**` scenarios
- [ ] Every `Then` clause is assertion-shaped (specific text/value/status/file — not "works correctly")
- [ ] `## Edge Cases & Error States` — cross-page failure/boundary scenarios that actually apply
- [ ] `## Non-Goals` — v1 exclusions, each with a reason, traceable to the concept brief's anti-goals
- [ ] `## Decisions Pending` table present — `| # | Question | Impact | Default if unresolved |`, or the explicit empty-state line

## `functional-spec.md` — register & floor

- [ ] Product language throughout — no "API", "store", "middleware", "schema", "endpoint"
- [ ] One section per page — no combined "Dashboard and Settings"
- [ ] ≥ 15 KB and it got there by coverage, not padding

## `architecture.md`

- [ ] `## Module Decomposition` — frontend + backend modules named, new-vs-extend marked; module names not tech names
- [ ] `## Data Model` — entities, relationships, key fields, informal — no SQL DDL / migration syntax
- [ ] `## Key Flows` — the killer flow traced through the modules
- [ ] `## Integration Points` — external systems named, with fallback posture
- [ ] `## Open Architecture Questions` — everything deferred to step 9 listed (recommended)
- [ ] Every module/entity/flow traces back to a page, component, or feature in `functional-spec.md`

## `architecture.html` / `architecture.json`

- [ ] Exactly one of the two is in the bundle (Layer 1 requires `min_count: 1` for `architecture.[hj]*`)
- [ ] It is derived from `architecture.md` — same modules, same entities, same flows
- [ ] `architecture.html`: renders a diagram (mermaid block or inline `<svg>`); opens standalone
- [ ] `architecture.json`: valid JSON with `modules` / `entities` / `flows` / `integrations` arrays

## Integrity

- [ ] The three artifacts agree — one truth, three projections; no module/entity in the diagram that isn't in `architecture.md`
- [ ] Stack is not pre-decided anywhere — step 9's job
- [ ] Open / uncertain choices are in `## Decisions Pending`, not silently assumed
- [ ] Submitted as one `product_step_submit` call: `functional-spec.md` as `content`, the rest as `extra_files`
