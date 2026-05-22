# Quality rubric — `/product` v0.4.0

_Referenced as `quality-checklist.md` for historical continuity. Spec 075 repositioned it from an orchestrator self-check doc into the **quality judge's rubric contract** — the semantic half of the per-step rubric the judge grades against._

For each pipeline step the quality judge assembles a rubric from three sources and grades the step's artifact(s) pointwise:

1. **structural** — the step's `templates/pipeline/<NN-step>/schema.md` required sections + `contains`-anchors (deterministic Layer 1, also enforced at submit);
2. **semantic** — the per-step criteria in this file (§ Per-step rubric criteria, § Visual-contract rubric criteria) — what a `grep` cannot verify but a reader can;
3. **right-sizing** — one universal scope-aware criterion the judge adds to every step's rubric; defined in `quality-judge.md`, not duplicated here.

`quality-judge.md` owns rubric assembly, the verdict JSON shape, and the verdict→gate routing. This file owns the content of source (2).

**Size is not a criterion.** Spec 075 retired artifact size as a quality/scope signal. The `schema.md § Size floor` `min_size` is a `wc -c` anti-stub pre-filter (the orchestrator skips the judge on a stub); the uniform 200 KB catastrophe cap is a token-runaway circuit-breaker. The judge grades neither — it grades whether the artifact is correctly scoped, complete, and coherent (the right-sizing criterion), never how many bytes it is.

**Spec 066 reshaped Phase 4-5.** The v2/v3 per-route screen-writer fan-out is gone — no `app/**/page.tsx` set, no `pnpm install` / build verification, no `tsc` / `biome` ship gate. Steps 01-14 are unchanged; Step 15 is the three-part visual contract (§ Visual-contract rubric criteria); Phase 5 is the SDD handoff (§ Deterministic gates).

## Per-step rubric criteria (steps 01-14)

Each criterion has a stable `id` (the **bold label**) — the quality judge's verdict keys `criteria[].id` on it. The judge grades each `pass` / `concern` / `fail`.

### 01 — Ideation → `docs/concept-brief.md`
- **structure** — 9 H2 sections present, including `§ Market Sizing`
- **citations** — ≥ 5 `[N]`-style citations

### 02 — Prototype v1, lo-fi → `docs/direction-a.html` + `docs/screens/*.html` ×3-5
- **mood-files** — `direction-a.html` plus 3-5 killer-flow lo-fi mood screens present
- **token-anchors** — `direction-a.html` carries `:root`, `--background`, `--foreground`, `--primary`, `Most Popular`, and `<svg`
- **od-citation** — cites ≥ 1 Open-Design vendor

### 03 — Spec → `docs/functional-spec.md`
- **gherkin** — `**Given**` / `**When**` / `**Then**` present; ≥ 3 Gherkin scenarios
- **problem-validation** — `§ Problem-Validation Interviews` present

### 04 — UX Testing → `docs/validation-report.md`
- **heuristics** — references both `Nielsen` and `WCAG`
- **validation-mode** — a `validation_mode:` line is present
- **findings** — YAML `findings[]` ≥ 3, each carrying `severity` + `fix_skill_hint`

### 05 — PRD → `docs/prd/v1.md`
- **user-stories** — at least one literal `| US-NN |` table row
- **structure** — 9 H2 sections (6 Lenny bones + 3 our-specific)
- **nsm** — exactly ONE North Star Metric, in its dedicated slot
- **priority-tiers** — P0 / P1 / P2 tiers visible

### 06 — OST → `docs/ost.md`
- **tree-shape** — 1 outcome → 3-5 opportunities → 2-3 solutions per opportunity
- **solution-status** — every solution carries a status

### 07 — Sitemap-IA → `docs/sitemap.yaml`
- _No semantic criterion._ The sitemap is fully deterministic-gated — valid YAML + `required_categories` coverage, enforced by the orchestrator (§ Deterministic gates → Sitemap completeness). The judge still grades schema structure + right-sizing.

### 08 — System Design → `docs/system-design.md` + `docs/security.md` + `docs/data-flow.json`
- **structure** — `system-design.md` has 8 H2 sections, including RACI + Risk Register
- **security-doc** — `docs/security.md` present
- **data-flow** — `docs/data-flow.json` is valid JSON with `flows[]` ≥ 3

### 09 — Legal posture → `docs/legal-posture.md`
- **escape-clause** — an escape-clause line within lines 1-5
- **dpia-conditional** — `§ DPIA` present iff `data-flow.json` carries sensitive categories
- **subprocessor-consistency** — sub-processor count matches `system-design.md`

### 10 — Roadmap → `docs/roadmap.md`
- **phases** — 3 phase headers, user-flow-shaped
- **milestones** — 1-3 milestones per phase
- **open-decisions** — `§ Open Decisions` present

### 11 — Cost Estimate → `docs/cost-estimate.md`
- **structure** — Assumptions / Build Cost / Run Cost / Legal & Audit Budget / Recommendations headers
- **roadmap-traceability** — build-cost rows reference roadmap phases

### 12 — GTM-launch → `docs/gtm-launch.md`
- **positioning-canvas** — a 5-line Positioning Canvas
- **launch-plan** — a Launch Plan with 4 weekly milestones
- **pricing-strategy** — a Pricing Strategy section

### 13 — Brand → `docs/brand-book.md`
- **metadata** — `**Version:**` + `**Date:**`
- **language-glossary** — `## Language` + `## Glossary` (both sub-sections)
- **voice** — `**We are**` / `**We are not**` + ≥ 3 voice samples
- **product-name** — a Product Name decision

### 14 — Design System → `docs/design-system/{tokens.css, components.md, README.md}`
- **tokens** — `tokens.css` carries a Tailwind v4 `@theme` block + a light-mode `@media` override
- **components** — `components.md` present
- **readme** — `README.md` carries an `Audit Response` section + an Open-Design vendor citation

## Visual-contract rubric criteria (Step 15 — three judge-units)

Step 15 dispatches three parallel sub-agents; each is a separate judge-unit with its own rubric and its own verdict.

### 15a — Screen atlas → `docs/screen-atlas.md`
- **structure** — all 8 required H2 headers present: Overview / Screens Index / Sitemap Coverage Cross-Check / PRD Coverage Matrix / Design Fidelity / States Coverage Matrix / User Flow Walkthrough / Open Decisions
- **screens-index** — the Screens Index table has one row per `docs/sitemap.yaml` route (full inventory, no silent drop)
- **prd-coverage** — the PRD Coverage Matrix lists every `US-NN` from `docs/prd/v1.md` (covered → route(s), or deferred → reason); a silent omission is a `fail`
- **sitemap-coverage** — the Sitemap Coverage Cross-Check confirms every `required_categories` member is represented
- **acceptance-clause** — `§ User Flow Walkthrough` carries the literal `Closed-beta partner` named-human acceptance clause
- **no-implementation** — NO `app/` / `.tsx` / `.html` file was written; a stray `app/` tree is a `fail` (the writer overstepped its brief)

### 15b — Hi-fi killer-flow mood → `docs/screens/hifi/<NN>-<name>.html` ×3-5
- **files** — 3-5 hi-fi HTML files present
- **self-contained** — each file is self-contained HTML: one `<style>` block + a `:root` token block (values copied from `docs/design-system/tokens.css`)
- **mobile-first** — the `<style>` block carries ≥ 1 `@media (min-width: …)` breakpoint, the base CSS targets 375 px, and there are NO `style=` layout attributes (lone exception: a single dynamic value like a progress-bar width)
- **on-brand-copy** — copy matches `brand-book.md` voice, respects `## Glossary § We don't say`, and is fixture-grounded (data from `docs/fixture-spec.md`, no lorem ipsum)

### 15c — Fixture spec → `docs/fixture-spec.md`
- **structure** — `## Persona` + `## Entities` + `## Cross-Screen Consistency Notes` present
- **entities** — one persona only; every `system-design.md § Data Model` entity has an example-records table
- **internal-consistency** — dates form a plausible timeline; foreign keys resolve; cross-screen totals agree

## Deterministic gates (orchestrator-checked — NOT judge-graded)

Mechanical checks the orchestrator runs directly — pass/fail by `grep`, parse, or exit code, so the judge does not grade them. Listed here so this file stays the single inventory of everything `/product` checks.

### Sitemap completeness (Step 07)
- `docs/sitemap.yaml` is valid YAML.
- All 5 `required_categories` (marketing / auth / primary / admin / error) each have ≥ 1 route, OR appear in `deferred_categories` with a reason. Otherwise the orchestrator BLOCKs Step 07 and re-dispatches with an augmented brief naming the uncovered category(ies) — up to 2 auto-retries before falling through to the user `iterate` choice at the Phase 2 gate (see `state-machine.md § Failure handling`).
- Per-route fields complete per `sitemap-schema.md` Rules 4-6.

### SDD handoff (Phase 5)
- `<out>/docs/specs/001-<slug>/` exists with `spec.md` filled — `**Type:** umbrella`, a `## Child-spec matrix` table, a `## Standing constraints` section.
- `<out>/docs/specs/002-foundation/` exists with `spec.md` filled (skeleton + tooling + route-group dirs + thin `layout.tsx` shells).
- The umbrella's child-spec matrix slices children #3..N by `docs/roadmap.md` phases (or falls back to a single `app-build` child when the roadmap lacks phase structure).
- The Phase 5 handoff message printed to chat names the umbrella spec path — NOT a `pnpm dev` instruction.
- See `references/sdd-handoff.md` for the full Phase 5 contract.

### Skill-self compliance (non-skippable)
`bash .claude/skills/skill/scripts/validate.sh .claude/skills/product` exits 0 — the spec 033 gate. NOT optional. The skill prints the result in the Phase 5 handoff.

### Best-effort visual check (Step 15b)
If the Playwright MCP is loaded this session, each `docs/screens/hifi/*.html` is screenshotted at 375 px + 1280 px and probed for horizontal overflow (`scrollWidth > clientWidth`). Results land in `REPORT.md § Visual check`. If the MCP is not loaded, a `visual-gate-skipped` advisory is recorded. **Best-effort — never blocks the run.**

## REPORT.md section mapping

| Source | REPORT.md section |
|---|---|
| Judge verdicts — per-step + visual-contract (`concern` / `fail` rows) | `## Quality concerns` (spec 075 — `scope_assessment` + flagged criteria) |
| Per-step rubric (01-14) — pass / blocked status | `## Pipeline coverage` |
| Visual-contract rubric (15a / 15b / 15c) | `## Visual contract` |
| SDD handoff | `## SDD handoff` |
| Sitemap completeness | `## Coverage scorecard` |
| Best-effort visual check | `## Visual check` |

## Cross-references

- `quality-judge.md` — rubric assembly, the verdict JSON shape, the verdict→gate routing
- `templates/pipeline/<NN-step>/schema.md § Size floor` — the structural Layer 1 anchors + the `min_size` anti-stub floor
- `delegation-briefs.md § quality-judge` — the judge sub-agent's 5-field brief
- `state-machine.md` — `.state.json` `quality_verdicts`, the phase gates the routing feeds
- `.claude/rules/artifact-budgets.md` — why size is no longer a criterion (the 200 KB catastrophe cap)
