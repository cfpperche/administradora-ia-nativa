# Step 10 — Schema (cost-estimate — single artifact)

The submitted `cost-estimate.md` MUST contain the level-2 markdown headings below + meet the Layer 1 size/content floor in the JSON fenced block. Both checks fire on submit; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list. Single-artifact step — no `extra_files`.

## Required sections (cost-estimate.md markdown headings)

Section names slugify by lowercasing + dashing — `## Pricing Model` → `pricing-model`, `## Build Cost` → `build-cost`. Cosmetic variants accepted; slugifier strips them.

- `overview`
- `pricing-model`
- `assumptions`
- `build-cost`
- `run-cost`
- `sensitivity`
- `risks`
- `recommendations` (the load-bearing decision-surface closer — 3-5 founder/engineering actions with deciding signals; mirrors anthill-FPA's Step-2 template § Recommendations section)

## Conditional sections (required when pricing-model is revenue-generating; skipped for free / not-for-profit / internal)

- `unit-economics` — CAC / LTV / LTV:CAC / payback / gross margin / contribution margin
- `projections` — month-by-month base-scenario cadence (period · active workspaces · paid workspaces · MRR · infra cost · total cost · profit · growth MoM). 8-12 rows for v1 through year-1.
- `scenarios` — bear / base / bull table with **probability column** + key variables + ARR / runway impact
- `break-even` — at what user count revenue covers run cost

The schema does NOT structurally enforce the conditional shape (would require pricing-model-aware validation). The prompt's `## Voice & rigor` and `references/cost-modeling-conventions.md` enforce it discursively — a revenue-product cost-estimate.md without these three sections is the regression mode the discipline catches at review time, not at submit time.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "cost-estimate.md",
      "min_size": 10240,
      "contains": [
        "## Overview",
        "## Pricing Model",
        "## Assumptions",
        "## Build Cost",
        "## Run Cost",
        "## Sensitivity",
        "## Risks",
        "## Recommendations",
        "| # | Assumption | Value | Source | Confidence |",
        "| Vendor | Tier | Monthly cost |",
        "[Estimated]",
        "Flip if:"
      ],
      "any_of_contains": [
        "## Unit Economics",
        "Pricing model: not-for-profit",
        "Pricing model: internal",
        "Pricing model: free"
      ]
    }
  ]
}
```

### Notes on the floors

- **`cost-estimate.md` `min_size: 10240` (10 KB)** — anchored against the 8 required sections at honest depth + 4 conditional for revenue products. An 8-section cost estimate with an assumption table (8-15 rows), a run-cost vendor table (5-8 rows), sensitivity on 2-3 drivers, 5 risks, projections table (8-12 monthly rows for revenue products), scenarios with probability column, and 3-5 recommendations lands at 13-18 KB for SMB SaaS Full. Micro-products may legitimately land under (use the `# OVERRIDE: compact-product: <class>` shape in submit context). The 10 KB floor is the universal sanity line; full-template SMB SaaS typically 13-18 KB. Bumped from 8 KB → 10 KB by spec 026 Phase B step-10 calibration (2026-05-16) which added § Recommendations + § Projections in response to anthill-FPA judge-feedback.

- **The literal `| # | Assumption | Value | Source | Confidence |` substring** — proves the assumption table carries the canonical 5-column shape from anthill-FPA (`# | Assumption | Value | Source | Confidence`). A cost-estimate that ships assumptions as bullet prose (anti-pattern: "**Hourly rate**: $150/hr — placeholder") trips Layer 1 — the table is the audit-trail contract; without it, the model is "trust me on these numbers". The literal row only appears as a real markdown table header.

- **The literal `| Vendor | Tier | Monthly cost |` substring** — proves the run-cost section carries a structured vendor table (`Vendor | Tier | Monthly cost | Source`), not paragraph prose. Without this, the run-cost silently degrades into "we use Vercel and Supabase, plus other stuff" — useless to step 11 roadmap (which reads the line items for phasing) and useless for cost-tracking discipline.

- **The literal `[Estimated]` substring** — proves AT LEAST ONE number in the model is explicitly tagged as an estimate. A cost-estimate with zero `[Estimated]` flags is one of two things: (a) every number traces to a current vendor invoice / signed contract (vanishingly rare at v1) or (b) the agent forgot the calibration discipline. Layer 1 catches (b). Step-9 calibration (2026-05-16) introduced this contains-anchor pattern; mirrored here.

- **The literal `Flip if:` substring** — proves at least one § Recommendations row carries a deciding signal (`*Flip if:* <measurable condition>`). The discipline mirrors step-9's `## Open Decisions § Deciding signal` column at the recommendation layer — every action either HOLDS or FLIPS on a measurable signal. Step-10 calibration (2026-05-16) added this anchor in response to anthill-FPA judge-feedback that recommendations without deciding-signals degrade into "continue current approach" non-decisions.

- **`any_of_contains: ["## Unit Economics", "Pricing model: not-for-profit", "Pricing model: internal", "Pricing model: free"]`** — the OR-semantic check that catches the conditional-sections discipline at the file-shape level. Either § Unit Economics is present (revenue product) OR the pricing-model is explicitly declared as free / not-for-profit / internal in running prose (which justifies skipping § Unit Economics + § Scenarios + § Break-Even). A revenue-generating product that omits all four trips Layer 1 — typically because the agent shipped a free-only cost estimate without declaring the model explicitly, or shipped a paid-product estimate that punted on unit economics. Step 9 calibration's `any_of_contains` invented-for-step-6/7-Audit-Response is the precedent; this is its first cross-step reuse.

- **No `required_glob`** — single-artifact step; nothing to glob.

- **Dogfood lesson inherited from steps 7 + 8 + 9 (2026-05-15 → 2026-05-16):** loose section-name substrings (`Cost`, `Pricing`, ...) are silently fakeable from prose. Step 10's Layer 1 uses the literal H2 heading anchors (`## Overview`, `## Pricing Model`, ...) and the table-header literals (`| # | Assumption | ...`, `| Vendor | Tier | ...`) — mirrors step 7's `| Token | Voice | ...` fix and step 9's `| Method | Path |` discipline. The literal heading + table row only appear as real markdown structure.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; *depth* is the agent's responsibility, reinforced by `references/cost-modeling-conventions.md`.

### `cost-estimate.md`

- **Overview** — short paragraph + biggest cost risk one-liner + step-9 cost-ceiling restate one-liner. Names product class (micro / mobile / dev-tool / SMB-SaaS / venture-scale) so depth calibration is visible. Mirrors step-9 § Overview shape.
- **Pricing Model** — declared model + tier structure (if subscription/freemium) or metering unit (if usage-based) or explicit declaration of skip (if free / not-for-profit / internal). One-paragraph rationale anchored to PRD § Goals + § Target Users.
- **Assumptions** — markdown table `# | Assumption | Value | Source | Confidence`. Aim for 8-15 rows. Every downstream number traces to a row here.
- **Build Cost** — range estimate (NOT single point). Breakdown by phase mirroring step-11 phasing (Foundation / Killer flow / Surrounding / Polish). Mark `[Estimated]`.
- **Run Cost** — markdown table `| Vendor | Tier | Monthly cost | Source` with total. Each line: vendor name, tier (free / Hobby / Pro / Enterprise / per-unit), monthly cost. Use current vendor pricing where available; mark scale-extrapolated `[Estimated]`.
- **Sensitivity** — the 2-3 assumptions driving 80% of variance. Per row: variance band + model impact + deciding signal. The load-bearing 30-second-scan section.
- **Risks** — top 5 financial risks. Markdown table `| # | Risk | Probability | Impact | Mitigation`. NOT every risk — just the 5 most-likely-or-impactful.
- **Recommendations** — 3-5 founder/engineering decisions with deciding signals. Verb-shaped (`Hold per-seat price`, `Defer EU spend`, `Pause acquisition`). Each row carries `*Flip if:* <measurable condition>`. Anti-pattern: `Continue current approach` or `Monitor metrics carefully` (non-decisions). The load-bearing decision-surface closer.

### Conditional (revenue-generating products):

- **Unit Economics** — markdown table `| Metric | Value | Calculation` with rows: ARPU, Gross margin, CAC, LTV, LTV:CAC (>3:1 healthy), Payback period. Skip explicitly for free / not-for-profit (declare in § Pricing Model).
- **Projections** — month-by-month base-scenario cadence. Markdown table `| Period | Active workspaces | Paid workspaces | MRR | Infra cost | Total cost | Profit | Growth MoM`. 8-12 monthly rows from launch through year-1. Answers the founder's runway-math question (different from § Scenarios variance bands). Skip explicitly for free / not-for-profit (collapse to 6-row burn-only in § Run Cost instead).
- **Scenarios** — bear / base / bull table with **probability column** (e.g. 25%/50%/25%, sums to 100%) + 1-3 key variable changes per row + ARR/runway impact. Anthill-FPA discipline: never single-point; probability weights force honest calibration vs hedging.
- **Break-Even** — at what user count revenue covers run cost. State paid-conversion rate + ARPU used.

## Atomic write semantics

`product_step_submit` validates `cost-estimate.md` against both layers (section presence + Layer 1 contains/size) before writing. On any failure, response is `{ code: "schema-incomplete", failures: [...] }` and nothing persists. On success, the file writes via mktemp+rename — atomic, or absent.
