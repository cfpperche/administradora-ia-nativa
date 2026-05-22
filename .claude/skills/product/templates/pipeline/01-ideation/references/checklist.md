# Ideation — Per-Stage Self-Review Checklist

Use this checklist before advancing through each sub-stage. Do not move forward with unchecked items unless explicitly not applicable.

Adapted from anthill `anthill-product-ideator/references/checklist.md`. Removed anthill-specific sub-step file outputs (00-direction.md / 01-opportunity-map.md / 02-concepts.md / 03-ranking.md / 05-handoff.md); our MCP collapses those into the conversation and persists only the final concept brief.

---

## Stage 1 — Direction interview

- [ ] All 6 axes evaluated (Domain, Audience, Constraints, Ambition, Business Model, JTBD)
- [ ] If any axis was vague or missing, structured questions asked and answered before proceeding
- [ ] User answers pinned in conversation (echoed back so the user can correct)
- [ ] Critique vs. default mode chosen and confirmed with the user

---

## Stage 2 — Opportunity Map

- [ ] `references/discovery-playbook.md` read before starting
- [ ] Minimum 15 web searches executed across all 5 tracks
- [ ] Minimum 10 unique sources cited (with inline `[n]` references in the final brief)
- [ ] All 5 tracks represented (Market Signals, Pain Points, Competitive White Space, Platform/API, Adjacent Inspiration)
- [ ] Opportunity Map presented to user in the format specified in discovery-playbook.md
- [ ] In critique mode: Pinned Concept Validation section included

---

## Stage 3 — Concepts

- [ ] `references/mechanics-catalog.md` and `references/anti-patterns.md` read before starting
- [ ] **Default mode:** between 5 and 8 concepts generated (not fewer, not more)
- [ ] **Critique mode:** pinned + 4-7 challengers; pinned is verbatim Concept #1
- [ ] Each concept passes the Hook-Retain-Refer test
- [ ] Each concept passes the Elevator Pitch test (2 sentences max)
- [ ] Each concept has 2-3 mechanics from the catalog layered in
- [ ] **Default mode:** range of scales present (at least micro-product and one larger-scale concept), range of business models, at least 1 boring-industry wildcard, at least 2 AI-native concepts
- [ ] **Critique mode:** every challenger differs from pinned on at least one structural axis (model, mechanic, audience, channel, value-chain position) and has a falsifiable "Why this could beat pinned" line
- [ ] Each concept has a "what could kill this" risk line
- [ ] Anti-patterns quick check run on every concept

---

## Stage 4 — Ranking

- [ ] Every concept scored on all 5 axes (Market, Feasibility, Differentiation, Moat, Monetization)
- [ ] Scores are 1-5 integers with brief rationale per axis (not just a number)
- [ ] Output formatted as comparison table with totals
- [ ] **Critique mode:** `delta_vs_pinned` column included; Verdict block written (PINNED WINS / WINS NARROWLY / TIE / CHALLENGER BEATS PINNED) with action
- [ ] Ranking surfaced to user with explicit prompt for concept selection (default mode) or verdict review (critique mode) before proceeding

---

## Stage 5 — Concept Brief

- [ ] `references/concept-brief-template.md` read before starting
- [ ] Template followed exactly — no sections omitted, no sections reordered
- [ ] JTBD statement included
- [ ] 3-5 additional validation searches run for pricing, market size, or regulatory claims
- [ ] All competitor data is factual — no fabricated funding, user counts, or revenue
- [ ] Brief scored on the 6-category quality rubric (100-point total — aim ≥ 70)
- [ ] Brief written to `docs/concept-brief.md` via `product_step_submit`
- [ ] Layer 1 validation (min_size + contains) passed — schema-incomplete failure list addressed if any

---

## Quality rubric (100 points)

Score the brief before submitting. Aim ≥ 70/100.

| Category | Weight | What earns full points |
|---|---|---|
| Market signal strength | 25 | 15+ sources, multiple tracks, recent data, named players |
| Concept originality | 20 | Genuine recombination of mechanics; not an "Uber for X"; Core Value names a primitive (workflow state, ownership unit, etc.), not a feature list |
| Hook-Retain-Refer clarity | 15 | All three are concrete, with month 1-12 progression |
| Unit economics plausibility | 15 | ARPU + CAC + LTV with assumption per row; LTV:CAC ≥ 3:1; every line of math is reproducible from the stated inputs (a reader can audit step-by-step without a hidden number) |
| Honest risk assessment | 15 | Specific risks (not "market may not exist") with mitigations; at least one risk pushes back on the fixture's own assumptions when warranted (e.g. "your $100K MRR target is a stretch; $30-50K is the realistic plan") |
| Source coverage | 10 | Every factual claim cited; estimates marked "Estimated"; estimate count target ≥ 10 explicit markers per brief — being conservative about what counts as fact vs. estimate beats hedging |

---

## Things to NOT do (anti-patterns to avoid)

- Don't fabricate data — if not found, say "Estimated" or omit
- Don't skip web research — discovery is the load-bearing input
- Don't pad with weak concepts to reach 5 — better 4 strong than 8 weak
- Don't use corporate language ("leverage synergies")
- Don't produce concepts without a clear moat
- Don't present estimates as sourced facts
- Don't skip the anti-patterns check before generating concepts
- Don't submit a concept brief that scored < 70 on the quality rubric — iterate first
