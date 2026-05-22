# Step 11 — Schema (roadmap — single artifact)

The submitted `roadmap.md` MUST contain the level-2 markdown headings below + meet the Layer 1 size/content floor in the JSON fenced block. Both checks fire on submit; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list. Single-artifact step — no `extra_files`.

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains, enforced at submit by the Layer 1 block below.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `roadmap.md` | 6 KB | below this the 8 required sections are not at honest depth |

A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Required sections (roadmap.md markdown headings)

Section names slugify by lowercasing + dashing — `## Open Decisions` → `open-decisions`, `## v2-Vision` → `v2-vision`. Cosmetic variants accepted; slugifier strips them.

- `overview`
- `horizon`
- `phases`
- `milestones`
- `dependencies`
- `risks`
- `v2-vision`
- `open-decisions` (the deciding-signal-bearing decision-surface; mirrors step-9 § Open Decisions and step-10 § Recommendations)

## Conditional / optional sections

- `buffer` — optional dedicated H2; the per-phase buffer math may live inline in § Risks (a `**Buffer:**` paragraph row) OR as its own § Buffer H2. Either shape satisfies the schema. Bridge-mode roadmaps may omit § Buffer entirely (bridge has no week-math).
- `team` — optional H2; team shape recap may live inline in § Horizon. Surface as its own H2 only when team-composition is the dominant constraint (e.g. multi-specialist team with role-specific phases).

The schema does NOT structurally enforce the operating-mode (canonical timeline-aware vs bridge / priority-extraction). The prompt's `## How to conduct this step § 6` and `references/phase-extraction.md` enforce it discursively — a bridge-mode roadmap.md without sentinel block (`<!-- anthill:bridge:begin -->` ... `<!-- anthill:bridge:end -->`) is the regression mode the discipline catches at review time, not at submit time.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "roadmap.md",
      "min_size": 6144,
      "contains": [
        "## Overview",
        "## Horizon",
        "## Phases",
        "## Milestones",
        "## Dependencies",
        "## Risks",
        "## v2-Vision",
        "## Open Decisions",
        "| Deliverable | Owner | Status |",
        "**Exit criteria:**",
        "Deciding signal"
      ],
      "any_of_contains": [
        "**Buffer:**",
        "## Buffer",
        "anthill:bridge:begin"
      ]
    }
  ]
}
```

### Notes on the floors

- **`roadmap.md` `min_size: 6144` (6 KB)** — lowered from spec 026's 8 KB per spec 056 calibration (compact-product variants legitimately land at 6-8 KB without an OVERRIDE marker). Floor anchored against the 8 required sections at honest depth. A roadmap with 4 phases (each with goal + deliverable table 4-6 rows + dependencies + exit criteria), 3-6 milestones, dependency graph for ≥3 phases, per-phase risks table (4 rows + buffer paragraph), v2-vision (3-5 bullets), and open-decisions (2-4 rows) lands at 10-12 KB for SMB SaaS Full. Micro-products may legitimately land under 8 KB (use `# OVERRIDE: compact-product: <class>` shape in submit context); 8 KB is the universal sanity line. The floor is lower than step-10's 10 KB because roadmap is narrative-shorter (no probability tables, no projections, no unit-economics math) — but the load-bearing literal anchors stay the same.

- **The literal `## Phases` substring** — proves the phases section exists as an H2 (NOT inline as a sub-heading under § Horizon). The phases section is the spine; without an H2 anchor, the reader has no scan target.

- **The literal `| Deliverable | Owner | Status |` substring** — proves at least one phase carries a structured deliverable table (`Deliverable | Owner | Status | Source`), not paragraph prose. Without this, the phase silently degrades into "we'll do auth, then features, then polish" — useless for sequencing discipline. Mirrors step-7's `| Token | Voice |` fix, step-9's `| Method | Path |` discipline, step-10's `| # | Assumption |` literal-anchor pattern. The literal row only appears as a real markdown table header.

- **The literal `**Exit criteria:**` substring** — proves at least one phase carries explicit exit criteria. A roadmap with phases but no exit criteria is anthill anti-pattern #1 ("Phases without exit criteria"); Layer 1 catches it at file-shape level. The italic-bold structural element only appears as a real per-phase exit-criteria block (not loose prose mentioning "exit criteria").

- **The literal `Deciding signal` substring** — proves at least one § Open Decisions row carries a deciding signal that closes the deferral. Mirrors step-9's `## Open Decisions § Deciding signal` column and step-10 § Recommendations `*Flip if:*` discipline at the roadmap layer — every deferred decision either HOLDS or FLIPS on a measurable signal. Step-11 calibration inherits this anchor pattern.

- **`any_of_contains: ["**Buffer:**", "## Buffer", "anthill:bridge:begin"]`** — the OR-semantic check that catches three valid roadmap shapes: (a) canonical timeline mode with buffer inline (`**Buffer:**` paragraph in § Risks), (b) canonical timeline mode with dedicated § Buffer H2, (c) bridge mode (`anthill:bridge:begin` sentinel — buffer is degenerate since bridge has no week math). A roadmap that omits all three is one of two things: (i) canonical mode silently dropped the buffer calibration (regression mode — single-point estimates, anti-pattern), or (ii) bridge mode malformed (sentinel missing, idempotent regen broken). Layer 1 catches both. Step-9's `any_of_contains` invented-for-step-6/7-Audit-Response is the precedent; step-10 reused it for revenue-vs-NFP; step-11 reuses for canonical-vs-bridge.

- **No `required_glob`** — single-artifact step; nothing to glob.

- **Dogfood lesson inherited from steps 7 + 8 + 9 + 10 (2026-05-15 → 2026-05-16):** loose section-name substrings (`Phase`, `Milestone`, ...) are silently fakeable from prose. Step 11's Layer 1 uses the literal H2 heading anchors (`## Overview`, `## Phases`, ...) and the table-header / bold-emphasis literals (`| Deliverable | Owner | Status |`, `**Exit criteria:**`, `Deciding signal`). The literal heading + table row + emphasis blocks only appear as real markdown structure.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; *depth* is the agent's responsibility, reinforced by `references/phasing-discipline.md` + `references/milestone-format.md` + `references/phase-extraction.md`.

### `roadmap.md`

- **Overview** — short paragraph + biggest-sequencing-risk one-liner + step-10 cost-pressure restate one-liner. Names product class (micro / mobile / dev-tool / SMB-SaaS / venture-scale) + phase count + operating mode (canonical vs bridge) so depth calibration is visible. Mirrors step-9 § Overview + step-10 § Overview shape.
- **Horizon** — total weeks/months to v1 launch + team shape + velocity assumption + optional hard deadlines + external coordination triggers. Locked at parent interview (§ 2 in prompt).
- **Phases** — 2-6 named phases (count calibrated by product class). Per phase: **Goal** (one sentence) + **Week range** + **Deliverables table** (Deliverable | Owner | Status | Source) + **Dependencies** + **Exit criteria** + **Build cost range** (from step 10 § Build Cost). Slice = end-to-end user value (Shape Up); NOT horizontal layer.
- **Milestones** — 3-6 observable end-of-phase deliverables. Format: `**M1 (end of week N):** <observable outcome>`. "You'd recognise it when you see it." Anti-pattern: "Sprint 3 done" / "75% complete" (procedural, not observable).
- **Dependencies** — phase-to-phase DAG (visualized as code fence diagram when ≥3 phases) + external dependencies (vendor onboarding, legal review, design-partner recruiting). No circular deps.
- **Risks** — per-phase: single biggest unknown + mitigation. Plus **Buffer** paragraph (calibrated per-phase by unknowns-count, NOT flat-30%). Format: markdown table `| Phase | Biggest risk | Probability | Impact | Mitigation |`.
- **v2-Vision** — 3-5 bullets sketching the next 3-6 months post-v1. Each bullet carries a "drives v1 decision" clause that names what v1 should design FOR or AGAINST.
- **Open Decisions** — 2-4 decisions the founder hasn't made yet that the roadmap is parked on. Markdown table `| # | Decision | Default if no decision by | Deciding signal |`. Mirrors step-9 § Open Decisions + step-10 § Recommendations § Flip if: discipline.

### Operating mode (declared inline; NOT a separate section)

The agent declares operating mode at top of `roadmap.md` as a single line: `**Mode:** canonical (timeline-aware; validation_mode: tested)` or `**Mode:** bridge (priority-extraction; validation_mode: intuition)`. Visible to downstream consumers (step 12 reads the mode to size the legal-posture compliance budget).

Bridge mode degrades sections explicitly:
- § Horizon → `**Total horizon:** TBD pre-delivery-plan` + team shape declared
- § Phases → Phase 1 / 2 / 3 by priority tier (P0/P1/P2), each with **Stories** bulleted list + **Goal** + **Trigger to start** (no week ranges, no deliverable table, no exit criteria with week numbers)
- § Milestones → `*Re-evaluated at /anthill-delivery-plan time*` placeholder
- § Risks → `*Re-evaluated at /anthill-delivery-plan time*` placeholder; § Buffer absent (no week math to buffer)
- § v2-Vision → may collapse to `*Deferred — re-evaluate post-MVP*`
- § Open Decisions → 1-2 rows typical (validation-mode upgrade trigger; phase-1 success-criteria definition)

Bridge mode wraps the regenerated content in `<!-- anthill:bridge:begin -->` ... `<!-- anthill:bridge:end -->` sentinels for idempotent regen.

## Atomic write semantics

`product_step_submit` validates `roadmap.md` against both layers (section presence + Layer 1 contains/size) before writing. On any failure, response is `{ code: "schema-incomplete", failures: [...] }` and nothing persists. On success, the file writes via mktemp+rename — atomic, or absent. Bridge-mode re-runs preserve content OUTSIDE the sentinel block verbatim — manual founder edits (durations once Phase 1 ships, post-incident addenda, executive narrative) are NOT overwritten.
