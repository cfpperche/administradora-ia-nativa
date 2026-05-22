---
mode: synthesis
delegable: true
delegation_hint: "synthesize screen-atlas.md — a navigable markdown visual-contract document — from all prior 14 step outputs. sitemap.yaml (step 07) drives the full Screens Index; prd/v1.md (step 05) drives the PRD Coverage Matrix; design-system + brand-book drive the Design Fidelity prose; the hi-fi killer-flow mood (step 15b, parallel) is the rendered reference. ONE markdown file out — NO app/, NO .tsx, NO .html. fully delegable — sub-agent reads prior artifacts and produces the contract."
---

# Step 15a — Screen atlas (the navigable visual contract)

**Goal:** produce `screen-atlas.md` — the navigable markdown document engineering opens when starting the SDD build. The atlas **describes** every screen the v1 product needs (a contract); it does **not** build them. Per spec 066 the v2/v3 per-route screen-writer fan-out is deleted — Step 15a writes **ONE markdown file**: no `app/`, no `.tsx`, no `.html`, no layout files.

The atlas is one of the three Step 15 sub-agents (**15a** atlas · **15b** hi-fi killer-flow mood · **15c** fixture-spec), dispatched in parallel. The atlas is the **prose half** of the visual contract; the hi-fi mood screens at `docs/screens/hifi/` (Step 15b) are the **rendered half**. The atlas references the hi-fi mood; it does not reproduce its markup.

## Output

ONE file: `<out>/docs/screen-atlas.md`, **10-28 KB** (see `schema.md § Target`). Nothing else.

## Inputs — read everything prior

All artifacts at `<out>/docs/` (semantic-named; pipeline order via `REPORT.md`):

- **Phase 1 — Discovery:** `concept-brief.md` (persona, mechanics, killer flow), `functional-spec.md` (surfaces, Gherkin), `validation-report.md` (audit findings), `direction-a.html` + `screens/` (lo-fi mood — visual lineage).
- **Phase 2 — Specification:** `prd/v1.md` (**US-NN inventory — load-bearing for the PRD Coverage Matrix**), `ost.md`, `sitemap.yaml` (**route inventory — load-bearing for the Screens Index**), `system-design.md` + `security.md` + `data-flow.json`, `legal-posture.md` (legal-mandatory surfaces — consent dialog if DPIA fires), `roadmap.md`, `cost-estimate.md`, `gtm-launch.md`.
- **Phase 3 — Identity:** `brand-book.md` (voice), `design-system/tokens.css`, `design-system/components.md`, `design-system/README.md`.

If `sitemap.yaml` or `prd/v1.md` is missing, stop and report to the parent — those two are load-bearing; do not fabricate them.

## The 8 required sections (verbatim H2 headers, in order)

### 1. `## Overview`

Short paragraph + 3 load-bearing one-liners. The paragraph names: product class, screen count from the sitemap, the picked visual direction (from `direction-a.html`), and that this atlas is the visual contract handed to the SDD build. The 3 one-liners answer the three questions an engineering reader asks first:

- **PRD coverage:** `X/Y user-stories covered (Z deferred — see § PRD Coverage Matrix)`.
- **Visual lineage:** picked direction + `design-system/tokens.css` + brand voice posture.
- **Deciding signal for the SDD handoff:** the one-line condition under which the foundation child should NOT start (e.g. "hold if any P0 US-NN is uncovered below").

### 2. `## Screens Index`

The visual contract's table of contents — **one row per route in `sitemap.yaml`**, the full inventory the SDD children build against.

```markdown
| Route | Category | Chrome | Covers (US-NN) | States | Screen intent |
|---|---|---|---|---|---|
| `/` | marketing | chromeless | — | default | Marketing landing — the killer-message hook |
| `/login` | auth | auth | US-01 | default, loading, error | Email + OAuth sign-in |
| `/dashboard` | primary | app | US-04, US-06 | default, loading, empty, error | Authenticated workspace home |
```

Every sitemap route appears. `Covers (US-NN)` is `—` for non-US-NN screens (marketing, error). `Screen intent` is one line — what the screen is *for*, not how it looks.

### 3. `## Sitemap Coverage Cross-Check`

Confirm the Screens Index is complete: every `sitemap.yaml` route is present, and every `required_categories` member (marketing / auth / primary / admin / error) has ≥ 1 row. List any gap as `[GAP — <category> has no route]`. This is the silent-undercover guard — a sitemap category dropped from the index is the regression mode this section catches.

### 4. `## PRD Coverage Matrix`

The load-bearing scorecard — **one row per `US-NN` from `prd/v1.md`**:

```markdown
| US-NN | Priority | Screen(s) | Status |
|---|---|---|---|
| US-01 | P0 | `/login`, `/signup` | covered |
| US-18 | P2 | — | deferred — Phase 3 per roadmap |
```

**Every US-NN appears**, OR carries an explicit `deferred — <reason>` status. Silent omission is the regression mode. Close the section with a `## PRD coverage: X/Y` summary line.

### 5. `## Design Fidelity`

There are no built screens to score 1-5 — the atlas describes *intended* fidelity:

- For the **3-5 killer-flow screens**, name the matching `docs/screens/hifi/<NN>-<name>.html` (Step 15b) as the rendered fidelity reference — that file IS the fidelity target the SDD build matches.
- For **every other route**, one line of prose stating the intended fidelity: tokens from `design-system/tokens.css` applied via Tailwind utilities, brand voice from `brand-book.md`, components reused from `design-system/components.md`.

State the standing fidelity contract once: tokens not raw values, on-brand copy (respecting `brand-book.md § Glossary`), components from the design system, mobile-first.

### 6. `## States Coverage Matrix`

Matrix table, routes × states — which states each route must implement:

```markdown
| Route | Loading | Empty | Error | Disabled | Success |
|---|---|---|---|---|---|
| `/dashboard` | ✓ | ✓ | ✓ | — | ✓ |
| `/login` | ✓ | — | ✓ | ✓ | ✓ |
```

✓ = the route requires this state · — = N/A for this route. Primary-category routes require at least `loading + empty + error`. Source the declared states from each route's `states` field in `sitemap.yaml`.

### 7. `## User Flow Walkthrough`

Narrative walkthrough of the killer flow, anchored to a named persona from `concept-brief.md`. Trace one end-to-end session through the routes with copy snippets at each step. Sub-bulleted list when the flow has ≥ 4 distinct actions; prose paragraph when ≤ 3. Close with the named-human acceptance clause — carry the literal phrase **`Closed-beta partner`**: e.g. `Closed-beta partner #1 walks the atlas + hi-fi mood unassisted and reproduces this flow in <5 minutes.`

### 8. `## Open Decisions`

2-5 **integration-shape** decisions the SDD build resolves — engineering choices the visual contract leaves open. Each row reads *"engineering chooses between X / Y; the contract supports both; deciding signal is N."*

```markdown
| # | Decision | Deciding signal | Concern |
|---|---|---|---|
| 1 | SSE vs WebSocket for the import progress screen | one-way progress → SSE; user can cancel mid-import → WS | [engineering] |
```

## Voice & rigor

- **The atlas IS the visual contract.** Write every section for the next reader — the engineer opening the SDD foundation child. The matrices ARE the discipline; do not add a section *about* the atlas's own discipline.
- **PRD coverage is binary per US-NN.** Covered or deferred-with-reason. Silent omission is the failure mode.
- **The atlas is a navigable index, not a re-summarized PRD.** It points at the PRD for acceptance-criterion depth; it does not reproduce it. Sweet spot 12-20 KB.
- **No `app/`, no `.tsx`, no `.html`.** If you find yourself writing a code file, stop — that is the SDD children's job. The atlas is markdown.
- **Target language** — all prose + screen descriptions in the run's `target_language`; H2 headers stay English-canonical.

## What this step does NOT do

- **Build screens.** No `app/**/page.tsx`, no layout files, no HTML. The runnable app is the SDD children's job (Phase 5 scaffolds them).
- **Render the hi-fi mood.** That is Step 15b (the parallel mood-screen-writer in hi-fi mode → `docs/screens/hifi/`).
- **Define the fixture data.** That is Step 15c (`fixture-spec.md`).
- **Revise the PRD, sitemap, or roadmap.** The atlas reads them and flags coverage gaps; it does not modify them.
