# Pipeline coverage — 15 steps × 5 phases at "standard" tier (v0.4.0)

How `/product` v0.4.0 (spec 066) maps the 15-step industry-aligned product pipeline onto the 5 phases. **Single tier — "standard".** Lightening per step is fixed by this doc; no `--fast`/`--deep` flag soup.

**Spec 066 restructure:** Phase 4 no longer runs a per-route screen-writer fan-out — it ends at the visual contract (screen-atlas + hi-fi killer-flow mood + fixture-spec). The new Phase 5 mandatorily scaffolds the SDD umbrella + foundation child the engineering build runs as. `/product` produces a docs-first foundation, never a runnable app.

Industry-aligned per spec 032's 17 decisions ported via spec 045 (`/prototype` v3 — historical name) and renamed + layout-refactored via spec 048 (Cagan/SVPG · Teresa Torres OST · GDPR Art 25 shift-left · Stage-Gate · Lenny Rachitsky 1-pager · April Dunford positioning).

## Phase ↔ step map

| Phase | Pipeline steps | Gate at end? | Bulk wall-clock target |
|---|---|---|---|
| **Phase 1 — Discovery** | 01-ideation · 02-prototype (lo-fi) · 03-spec · 04-ux-testing | ✓ AskUserQuestion (`gate_discovery`) | 8-12 min |
| **Phase 2 — Specification** | 05-prd · 06-ost · 07-sitemap-ia · 08-system-design · 09-legal · 10-roadmap · 11-cost-estimate · 12-gtm-launch | ✓ AskUserQuestion (`gate_specification`) | 18-25 min |
| **Phase 3 — Identity** | 13-brand · 14-design-system | ✓ AskUserQuestion (`gate_identity`) | 6-10 min |
| **Phase 4 — Visual contract** | 15-screen-atlas (15a atlas · 15b hi-fi mood · 15c fixture-spec) | (no gate) | 5-8 min |
| **Phase 5 — SDD handoff** | scaffolds the umbrella + foundation child spec | (no gate; terminal) | 2-3 min |

**Total target: 35-55 min** end-to-end for a clean run. Add ~5 min per gate iteration if user picks `iterate`. The spec 066 restructure REMOVES the old worst-case multi-hour tail — there is no per-route screen-writer fan-out, no `pnpm install`, no build verification; Phase 4 is three parallel sub-agents and Phase 5 is local file scaffolding.

## Phase 5 — SDD handoff

Phase 5 has no step number — it is the terminal phase. `/product` scaffolds, under `<out>/docs/specs/`, the **umbrella spec** (`001-<slug>/`, `**Type:** umbrella`, child-spec matrix sliced by `roadmap.md` phases, standing constraints) plus the **foundation child** (`002-foundation/`, skeleton + tooling + route-group dirs + thin layout shells). Children #2..N are matrix rows, not pre-scaffolded. The full contract is `references/sdd-handoff.md`. This is the deliberate fix for the v2/v3 36-route fan-out whose output quality collapsed: `/product` hands a *contract* to SDD, which is built for deliberate harness-disciplined implementation.

## Per-step output + size floors (standard tier)

**The per-step `min_size` anti-stub floor lives in each step's `templates/pipeline/<NN-step>/schema.md`** — the `## Size floor` section + the Layer 1 `required_files` block (per spec 075). The `Size floor` column below is a **derived view**: when a floor changes, update the schema, not this table.

**Catastrophe cap (uniform 200 KB — per spec 075, `.claude/rules/artifact-budgets.md`):** artifact size is no longer a scope or quality signal. One uniform absolute cap of 200 KB applies to any artifact a sub-agent writes — past it, the sub-agent STOPs and emits a partial-result naming what it was producing. The cap is a dumb token-runaway circuit-breaker, not a budget: no per-step number, no overshoot multiplier. **Trim-loop and re-emit-at-smaller-scope stay forbidden** — both are "redo to fit budget" antipatterns that hide the scope-mismatch signal. The retired `1.2`/`1.8` overshoot cascade (spec 065) was a scope-blind fixed constant; the mei-saas dogfood proved it broken (10/10 overshoots, 0 true positives). See `docs/specs/075-product-quality-audit/`.

**Right-sizing is judged, not measured.** Whether an artifact is correctly scoped, complete, and right-sized for its declared job is the **quality judge**'s call — an independent `opus` sub-agent dispatched after each step, grading the artifact against the step's rubric (`schema.md` required sections + `quality-checklist.md` criteria + a scope-aware right-sizing criterion). See `references/quality-judge.md`. The `min_size` anti-stub floor below is the one cheap deterministic size check that remains — a `wc -c` stub-detector enforced at submit by each schema's Layer 1 block.

| # | Step | Sub-agent model | Output file(s) (paths relative to `<out>/`) | Size floor (anti-stub) | Canonical source | Industry source |
|---|---|---|---|---|---|---|
| 01 | Ideation | **opus** | `docs/concept-brief.md` (includes § Market Sizing TAM/SAM/SOM) | ≥ 4 KB | (legacy — 056 phase 2) | extends per spec 032 Decision 6 |
| 02 | Prototype v1 (lo-fi) | sonnet × N | `docs/direction-a.html` (1 only at standard) + `docs/screens/<NN>-<name>.html` × 3-5 (killer flow) | direction ≥ 10 KB, screens ≥ 4 KB each | `02-prototype/schema.md § Size floor` ✓ 056 | unchanged content; sitemap moved to Step 07 |
| 03 | Spec | sonnet | `docs/functional-spec.md` (includes § Problem-Validation Interviews) | ≥ 12 KB | `03-spec/schema.md § Size floor` ✓ 056 | extends per spec 032 Decision 6 |
| 04 | UX Testing | sonnet | `docs/validation-report.md` (YAML frontmatter) | ≥ 5 KB | (legacy — 056 phase 2) | unchanged from v2 |
| 05 | PRD (1-pager hybrid) | sonnet | `docs/prd/v1.md` (Lenny 1-pager bones + 3 our-specific sections; US-NN stable IDs; NSM slot) | ≥ 4 KB | (legacy) | spec 032 Decisions 1 + 9 + 15 |
| 06 | OST | sonnet | `docs/ost.md` (Opportunity Solution Tree — 1 outcome root → 3-5 opportunities → 2-3 solutions per) | ≥ 3 KB | `06-ost/schema.md § Size floor` ✓ 075 | spec 032 Decision 12 (Torres) |
| 07 | Sitemap-IA | sonnet | `docs/sitemap.yaml` (schema-bound to `references/sitemap-schema.md` — `required_categories: [marketing, auth, primary, admin, error]` enforced) | ≥ 2 KB | `07-sitemap-ia/schema.md § Size floor` ✓ 075 | spec 032 Decisions 5 + 13 (load-bearing root-cause fix) |
| 08 | System Design | sonnet | `docs/system-design.md` (bridge-floor + § RACI + § Risk Register) + `docs/security.md` + `docs/data-flow.json` (consumed by Step 09) | sd ≥ 15 KB, sec ≥ 3 KB, data-flow ≥ 1 KB | `08-system-design/schema.md § Size floor` ✓ 056 | spec 032 Decision 10 |
| 09 | Legal posture | sonnet | `docs/legal-posture.md` (DPIA-triggered by Step 08 data-flow; shift-left per Decision 4) | ≥ 5 KB base (conditional floor model — base + a floor per triggered section) | `09-legal/schema.md § Size floor` (conditional) ✓ 056 | spec 032 Decision 4 (GDPR Art 25 + IAPP shift-left) |
| 10 | Roadmap | sonnet | `docs/roadmap.md` (3-phase sketch — defines phases consumed by Step 11) | ≥ 6 KB | `10-roadmap/schema.md § Size floor` ✓ 056 | **moved before cost per spec 045 cost↔roadmap swap** |
| 11 | Cost Estimate | sonnet | `docs/cost-estimate.md` (single-scenario; uses Step 10 phases + Step 09 legal-review budget) | ≥ 5 KB | (legacy — 056 phase 2) | **moved after roadmap per spec 045** |
| 12 | GTM-launch | sonnet | `docs/gtm-launch.md` (positioning canvas Dunford + launch plan 4-week sketch + pricing strategy) | ≥ 4 KB | `12-gtm-launch/schema.md § Size floor` ✓ 075 | spec 032 Decision 7 (Stage-Gate stage 6 + April Dunford) |
| 13 | Brand | sonnet | `docs/brand-book.md` | ≥ 4 KB (2-3 section snapshot) | (legacy) | spec 032 Decision 3 (moved after Specification — PRD-first) |
| 14 | Design System | sonnet | `docs/design-system/tokens.css` (imported by `app/globals.css` as `@import "../docs/design-system/tokens.css"`) + `docs/design-system/components.md` + `docs/design-system/README.md` | tokens ≥ 1.5 KB, components ≥ 3 KB, ds ≥ 8 KB | (legacy) | unchanged content; renumbered |
| 15 | Visual contract (15a atlas · 15b hi-fi mood · 15c fixture-spec) | sonnet × (1 + N + 1) | `docs/screen-atlas.md` (navigable contract — sitemap cross-check + PRD coverage matrix; NO `app/` writes) + `docs/screens/hifi/<NN>-<name>.html` × 3-5 (hi-fi killer-flow mood, mobile-first static HTML) + `docs/fixture-spec.md` (shared mock-data contract) + `docs/REPORT.md` | atlas ≥ 10 KB, hi-fi mood ≥ 4 KB each, fixture-spec ≥ 2 KB, REPORT ≥ 6 KB | `15-screen-atlas/schema.md § Size floor` | spec 066 (delete the screen-writer fan-out; end at the visual contract) |

**Legend:**
- ✓ 056 = `min_size` floor reconciled per spec 056 against the 3-dogfood empirical pass (045 / 048 / Vetro)
- (legacy) = floor unchanged from pre-056 declaration; awaiting phase 2 calibration when next dogfood data accumulates

**HTML report manifest (spec 073):** the per-step artifact list above is mirrored — for rendering order only — by `ARTIFACT_MANIFEST` in `scripts/build-report.ts`, which generates the navigable `docs/REPORT.html` reading surface at each gate + the terminal step. That `const` is the single source of truth for the report's nav order; adding or removing a pipeline step means editing it alongside this table.

## Lightening op applied per step (single-tier "standard" decisions)

1. **01 Ideation:** 5-8 web searches (vs 15-25 canonical); skip `critique mode`. **NEW (Decision 6):** § Market Sizing — TAM/SAM/SOM as 1-paragraph each, NOT primary research, desk research with 1-2 cited sources per number.
2. **02 Prototype v1 (lo-fi):** ONE direction only (vs 3 mood boards); 3-5 killer-flow screens; **sitemap NO LONGER produced here** (moved to dedicated Step 07).
3. **03 Spec:** Combined `functional-spec.md` (no separate architecture.md). **NEW (Decision 6):** § Problem-Validation Interviews — 3-5 summaries, synthetic OK at standard tier, seeds OST opportunities.
4. **04 UX Testing:** Heuristic-only (Nielsen 10 + WCAG 2.1 AA top issues). Projected-mode default. Validation mode declaration required.
5. **05 PRD (1-pager):** Lenny bones (Problem · Why now · Success metrics · Solution sketch · User stories · Anti-goals) + 3 our-specific (Release scope · NSM-dedicated-slot · Upstream/downstream refs). TIGHT — each section ≤3 bullets to preserve 1-pager honesty. US-NN stable IDs (P0/P1/P2). ONE NSM in dedicated slot.
6. **06 OST:** 1 desired outcome (the NSM from PRD) → 3-5 opportunities (user problems discovered/inferred) → 2-3 solutions per opportunity (the "how"). Sibling artifact to PRD, NOT embedded — feeds the post-launch-review sibling tool when MCP-side ships it.
7. **07 Sitemap-IA:** YAML with schema-enforced `required_categories: [marketing, auth, primary, admin, error]`. Each route has `path / category / states / covers_us / components`. Top-level `deferred_categories: [{name, reason}]` escape clause for genuinely-out-of-v1 categories (must include reason). Orchestrator parses + BLOCKS step if uncovered category found without deferral. **Mechanical fix for atlas under-cover (Pass E silent gap on auth/admin/error).**
8. **08 System Design:** Bridge-floor (6 sections: stack, integrations, data model, decisions locked, security, observability) + **NEW (Decision 10)**: § RACI Matrix + § Risk Register. Also produces `docs/data-flow.json` — structured data-flow inventory consumed by Step 09 legal for DPIA trigger.
9. **09 Legal:** Brief checklist (regulations, sub-processors, IP) + DPIA section IF Step 08 data-flow includes sensitive categories (PII/health/minors/financial). Reads `docs/data-flow.json` to determine DPIA trigger. **Shifted left per Decision 4** — informs Step 11 cost (legal review budget) + Step 12 GTM (compliance signals).
10. **10 Roadmap:** 3-phase sketch (MVP / Growth / Polish) with user-flow-shaped titles. **Defines phases for Step 11 cost** — cost calculates per-phase using THESE phase boundaries (not implicit ones).
11. **11 Cost Estimate:** Single-scenario burn rate, per-phase from Step 10's phase boundaries + Step 09's legal-review budget. Skip bear/base/bull + sensitivity + unit economics.
12. **12 GTM-launch:** Positioning canvas Dunford-lite (2-3 lines: who-for / alternative-to / why-better) + launch plan 4-week sketch (week-by-week milestones) + pricing strategy (free/standard/pro tier shape if relevant). Skip full launch playbook (post-PMF concern).
13. **13 Brand:** 2-3 section snapshot (voice samples + visual direction posture + "we are/we are not" pair). Synthesizes from finalized PRD + sitemap + system-design (no longer from half-formed concept brief like v2). Skip founder-interview turn.
14. **14 Design System:** Catalog-path PREFERRED (1-2 vendors from `od-catalog-index.json`); custom-derive fallback. Resist token inflation (8-14 colors, 5-7 type scales).
15. **15 Visual contract:** Three sub-agents — (15a) `screen-atlas.md`, a navigable markdown contract indexing every sitemap route + PRD coverage; (15b) the hi-fi killer-flow mood, 3-5 brand+tokens-applied mobile-first static HTML screens; (15c) `fixture-spec.md`, the shared mock-data contract. **No per-route `page.tsx` set is generated** (spec 066) — the runnable app is built by the SDD children scaffolded in Phase 5.

## Bundled-template provenance + drift discipline

All 15 step prompts + schemas + references live at `.claude/skills/product/templates/pipeline/<step>/`. **Source: spec 045 derives each template from spec 032's 17 decisions.** The MCP `packages/mcp-product-pipeline/` (specs 025-027) was discontinued 2026-05-19; the skill is the canonical delivery.

**Why bundle (not symlink or runtime-read):** the skill is standalone — must work in any fork. Bundle is the price of portability.

## Two-mood-pass rationale (lo-fi + hi-fi)

Spec 032 Decision 8 collapsed the 3-prototype-pass into 2; spec 066 keeps both passes as **mood passes** (static HTML, not framework code):

- **Step 02 (Pass 1 — lo-fi mood):** Which visual direction resonates? Pre-brand, pre-tokens. Killer flow only. Mood HTML at `docs/screens/`.
- **Step 15b (Pass 2 — hi-fi mood):** Does the killer flow cohere with brand + tokens + audit fixes? Post-Specification + Identity. 3-5 brand+tokens-applied **mobile-first static HTML** screens at `docs/screens/hifi/` — the rendered half of the visual contract. The `screen-atlas.md` (Step 15a) is the prose half, spanning the full PRD coverage. **Real framework code is the SDD children's job (Phase 5)** — spec 066 deleted the per-route screen-writer fan-out that tried to generate it inline.

The deleted v2 Step 7 (prototype-v2 brand-tuned) was a redundant mid-step (3-stage felt over-engineered per Cagan SVPG "Flavors of Prototypes"). Its work (brand + tokens applied to killer-flow surfaces) is the Step 15b hi-fi mood. Tombstone: `docs/specs/045-prototype-skill-pipeline-realign/artifacts/deleted-step-7-prototype-v2.md`.

## Cross-references

- `state-machine.md` — phase/step progression, `.state.json` v5 shape, resume support
- `delegation-briefs.md` — 5-field briefs for every sub-agent dispatch (one per step; Step 15 = 15a/15b/15c; shared mood-screen-writer)
- `sdd-handoff.md` — the Phase 5 umbrella + foundation-child scaffold contract
- `sitemap-schema.md` — required_categories enforcement (load-bearing for Step 07)
- `od-catalog-index.json` — Step 14 catalog path vendor index (72 vendors at 2026-05-18 snapshot)
- `quality-checklist.md` — the quality judge's semantic rubric (per-step + visual-contract criteria) + the deterministic orchestrator gates
- `docs/specs/066-product-ui-quality/` — the restructure spec (this version)
- `docs/specs/045-prototype-skill-pipeline-realign/` — pipeline lineage
- `docs/specs/032-pipeline-industry-alignment/` — parent industry-alignment spec (the 17 decisions ported here)
