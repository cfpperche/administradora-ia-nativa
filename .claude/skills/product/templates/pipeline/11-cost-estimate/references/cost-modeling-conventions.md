# Cost modeling conventions — assumption table + scenarios + sensitivity + product-class ladder

How to write `cost-estimate.md`. Section shapes + the load-bearing FPA disciplines from anthill-FPA + the calibration rules.

## The assumption table — the audit trail

Every input the model depends on lands in the `## Assumptions` table with **value + source + confidence**. The table IS the audit trail; every downstream number cites a row by index.

### Canonical shape

```markdown
## Assumptions

| # | Assumption | Value | Source | Confidence |
|---|---|---|---|---|
| 1 | Hourly rate (blended) | $150/hr | placeholder · founder · 2026-05-16 | Low (rate is illustrative) |
| 2 | v1 build estimate | 14 weeks (10 weeks engineering + 4 weeks polish) | step 8 PRD § User Stories + step 9 system-design § Stack complexity | Medium |
| 3 | Target scale (month-3) | 500 weekly-active teams | step 8 PRD § Success Metrics row 1 | High (founder-locked) |
| 4 | Avg users per team | 5 | step 8 PRD § Target Users (5-30 person squads, conservative) | Medium |
| 5 | Paid conversion (freemium) | 3% | benchmark · SaaS industry median 2-5% | Low (no product data yet) |
| 6 | Churn (annual gross) | 12% | benchmark · SMB SaaS Linear-clone analog | Medium |
| 7 | ARPU | $20/team/mo | $4/seat × 5 users/team avg (assumption 4) | High (math from PRD § Goals) |
| 8 | Token cost per user/mo (AI features) | $0.20 | placeholder · OpenAI pricing × estimated usage | Low |
| 9 | Stripe fee | 2.9% + $0.30/txn | vendor pricing page · 2026-05-16 | High |
| 10 | Postgres scaling trigger | Supabase Pro → Team at >500 WAT | vendor pricing tier · 2026-05-16 | High |
```

### Confidence levels (calibrated)

- **High** — vendor invoice / signed contract / pricing-page snapshot WITH DATE / direct PRD § Goals founder lock. The number won't move pre-launch unless something external changes (vendor pricing change, founder decision change).
- **Medium** — defensible inference from prior artifacts (PRD persona × industry benchmark; step-9 scale assumption × vendor tier). The number COULD move during build, typically by ±30%.
- **Low** — placeholder or benchmark with no product-specific evidence. The number is illustrative; expect ±2-3x movement when real data lands. Hourly rate, paid-conversion rate, token-cost-per-user routinely start Low.

### Anti-patterns the table catches

- **Undocumented numbers** — `"We expect 8 new customers per month at $24K ACV."` Bad; the same number in the table with Source + Confidence is good.
- **Aspirational confidence** — a paid-conversion-rate marked High without product data is the regression mode. Conservative confidence is the discipline.
- **Mixing sources across rows** — if half the rows cite vendor pricing pages and half cite "founder estimate" with no Confidence column, the table fails as an audit trail. Every row carries Source AND Confidence; no silent gaps.

## Scenarios — bear / base / bull (anthill-FPA non-negotiable for revenue products)

Single-point projections are the regression mode. Three scenarios with **probability weights** + 1-3 key variable changes per row, NOT three estimates of the same number.

### Canonical shape (post step-10 calibration — probability column required)

```markdown
## Scenarios

| Scenario | Probability | New paid teams/mo | Churn | ARR EOY | Runway (assume $200k cash) |
|---|---|---|---|---|---|
| Bear | 25% | 5 | 18% | $1.4k MRR / $17k ARR | 9 mo |
| Base | 50% | 15 | 12% | $4.2k MRR / $50k ARR | 16 mo |
| Bull | 25% | 30 | 8% | $9.1k MRR / $109k ARR | 22 mo |
```

### Probability column discipline

The probability column is the calibration anchor — sums to 100%, picked to reflect actual founder confidence not aspirational balance. Common shapes:

- **25/50/25 (default for SMB SaaS)** — tight base, symmetric tails. Use when the founder has moderate confidence in the base scenario and the bear/bull are honest stress-tests.
- **30/40/30 (heavier tails for unproven wedge)** — looser base, wider variance. Use when the product wedge is competitive-untested (no analog reference) OR persona signal is mixed.
- **20/60/20 (tight base for proven category)** — narrow tails, high base confidence. Use when the founder is in a category with strong analogs (e.g. Linear-clone in project management; benchmarks exist).
- **40/40/20 or 20/40/40 (skewed)** — pessimistic or optimistic; only use with explicit founder rationale in § Assumptions. Asymmetric defaults read as hedging if unexplained.

The probability values are themselves a Confidence-Low assumption — mark them so in § Assumptions table. Revise post-closed-beta when real data lands.

### Scenario discipline

- **The 1-3 variables that change between scenarios are the SAME variables** the § Sensitivity section identifies as 80%-of-variance drivers. The two sections cross-reference: § Sensitivity names which assumptions; § Scenarios shows their joint impact.
- **Bear is honest, not catastrophic.** Bear = "what happens if the obvious risks fire". Bear isn't "the company dies"; bear is "growth is half-projected and churn is doubled".
- **Bull is honest, not hopeful.** Bull = "what happens if execution is solid and the wedge lands". Bull isn't "viral growth"; bull is "double-projected new logos and below-baseline churn".
- **Base is the planning anchor.** Funding decisions, hiring decisions, runway analysis ALL anchor on Base. Bear is the stress-test; Bull is the upside scenario.

### When to skip § Scenarios

Skip for: free / not-for-profit / internal tools where revenue is degenerate (zero or operationally fixed). For these, replace § Scenarios with a single-paragraph run-cost sensitivity range in § Sensitivity ("Run cost varies $X-$Y depending on scale assumption Z; no revenue scenarios because pricing is free / NFP / internal").

## Projections — monthly cadence for the base scenario

The Projections table answers a DIFFERENT question than § Scenarios. Scenarios answer "what's the variance band?". Projections answer "what does the base-scenario monthly cash burn look like for runway planning?". Different consumer:

- **Founder doing burn-rate math:** reads Projections. Wants to see month-1 burn, month-3 break-even, month-6 cash position.
- **Founder doing fundraise prep / board prep:** reads Scenarios. Wants to see the bear/base/bull arc for the next 24 months.

Both sections matter for revenue-generating products at v1. Anthill-FPA's canonical Step 2 template carries both (§ Projections + § Scenarios as separate sections); the MCP port absorbed Projections in the post-step-10 calibration (2026-05-16) to close the gap with anthill-FPA's runway-math story.

### Canonical shape

```markdown
## Projections

Base-scenario monthly cadence through year-1. Bear/Bull variance bands in § Scenarios; this table is the single-line "what does the base look like month-by-month".

| Period | Active workspaces | Paid workspaces | MRR | Infra cost | Total cost (incl. build amort.) | Profit | Growth MoM |
|---|---|---|---|---|---|---|---|
| Mo 1 (launch) | 50 | 0 (free trial) | $0 | $156 | $7,156 [Estimated] | -$7,156 | — |
| Mo 2 | 120 | 3 | $60 | $178 | $7,178 | -$7,118 | +140% workspaces |
| Mo 3 | 250 | 8 | $160 | $200 | $7,200 | -$7,040 | +108% workspaces |
| Mo 4 | 380 | 15 | $300 | $222 | $7,222 | -$6,922 | +52% workspaces |
| Mo 5 | 500 | 24 | $480 | $245 | $7,245 | -$6,765 | +32% workspaces |
| Mo 6 | 600 | 32 | $640 | $268 | $7,268 | -$6,628 | +20% workspaces |
| Mo 9 | 850 | 51 | $1,020 | $315 | $7,315 | -$6,295 | +14% workspaces / mo |
| Mo 12 | 1,100 | 77 | $1,540 | $385 | $7,385 | -$5,845 | +9% workspaces / mo |
```

### Cadence rules

- **Monthly is the default** for v1 cost estimates (founder needs month-by-month burn-math granularity).
- **Bi-weekly for very-early stage** (first 2-3 months when growth swings widely).
- **Quarterly for steadier products** (year 2+; not v1 territory).
- **8-12 rows is the SMB SaaS target.** Micro-products may collapse to 4-6; venture-scale may need 18-24 with cohort overlay.
- **The first 4-6 months are the load-bearing rows** — that's the founder's runway-math watch window. Mo 9 + Mo 12 are scaling-trajectory snapshots; not every monthly row needs full fidelity.

### Amortised build-cost column

Divide the build-cost range (§ Build Cost) over a chosen amortisation period (commonly 12 or 24 months) and surface the per-month allocation in the Total cost column. Format: `$X infra + $Y amort. = $Z total`. Mark `[Estimated]` on the amortised line. The Total column is the load-bearing column for runway math; without it the founder has to compute the burn-rate themselves.

### Growth MoM honest, not extrapolated

Early-stage growth percentages are typically very high (Mo 1 → Mo 2 commonly +100-200%) because the denominator is small. Don't smooth the curve to look healthier; the curve IS the data. The honest curve also surfaces the "scale becomes hard around Mo 4-6" inflection point that flat-extrapolation would hide.

### Anti-patterns the section catches

- **Single-row "Year 1 EOY: $X MRR"** — defeats the purpose. The whole point is the monthly cadence for runway planning.
- **Smoothed-curve projection** — fits a linear or exponential to the actual stair-step. Misleading.
- **Profit column with no Total cost** — half the math, useless for burn-rate planning.

### When to skip § Projections

Skip for: free / not-for-profit / internal tools (no MRR → projections degenerate to monthly burn only). Collapse to a 4-6 row monthly burn table in § Run Cost instead.

## Recommendations — decisions, not summaries

The load-bearing decision-surface closer (3-5 founder/engineering actions, NOT a summary of sections above). Each recommendation is verb-shaped and carries a deciding signal that would flip it. This is the WHAT to do Monday morning; § Sensitivity is the WHY.

### Canonical shape

```markdown
## Recommendations

1. **Hold per-seat price at $4/mo.** Pricing wedge is load-bearing for the PRD's competitive positioning; absorbing $50/mo Stripe-fee ramp via annual-prepay incentive (R1) preserves the wedge without re-pricing. *Flip if:* paid-conversion below 1% at week-4 of closed-beta forces revenue scrutiny.

2. **Defer EU region + SOC 2 audit spend.** Both are 4-figure budget lines (DPA legal review ~$3k, SOC 2 Type 1 pre-audit ~$15k). v1 cost ceiling holds without them. *Flip if:* first 5 EU prospects in pipeline OR enterprise prospect requires SOC 2.

3. **Pause public-launch acquisition spend until week-1 retention clears 40%.** PRD § Success Metrics row 1 names retention as the v1-worked signal; acquisition spend on a leaky bucket compounds CAC waste. *Flip if:* week-1 retention ≥ 40% in closed-beta for 2 consecutive weeks.

4. **Reconcile bottom-up build estimate against top-down 6-month runway constraint pre-Phase-2.** Build-cost $84k-120k (range) sits inside $200k cash runway; sensitivity row 3 (week-overrun) is the watch — every 2 weeks over collapses runway headroom. *Flip if:* Phase-2 milestone slips > 2 weeks; rescope or extend.

5. **Re-run this cost-estimate at week-6 of closed-beta** with measured paid-conversion + churn + Stripe-fee data. Pre-v1 numbers are placeholders; week-6 is the first point of real data.
```

### Format discipline

- **Verb-shaped first word** — `Hold`, `Defer`, `Pause`, `Reconcile`, `Re-run`. Not noun-shaped (`Pricing strategy: ...`) or hedge-shaped (`Consider whether to...`). The verb forces a decision.
- **One-paragraph rationale** — tie to a prior section (Risks row N, Sensitivity row M, PRD § X). The rationale is the audit trail; the action is the decision.
- **`*Flip if:* <measurable condition>`** — every recommendation either HOLDS or FLIPS on a measurable signal. The Layer-1 `Flip if:` anchor enforces this at file-shape level.
- **3-5 rows is the target.** Fewer than 3 reads as under-prescribed; more than 5 reads as scattered. Pick the load-bearing decisions, not exhaustive coverage.

### Anti-patterns the section catches

- **Summary-shaped:** "Continue to track expenses carefully and monitor key metrics." Non-action. Section's job is to PREVENT this.
- **Non-decision:** "Recommendations: revisit pricing in Q2." A decision-deferral without a deciding signal is a hedge.
- **Decision without deciding signal:** "Defer EU region." OK, but for how long? Under what condition would we revisit? `*Flip if:* first 5 EU prospects in pipeline` closes the deferral.

### When to skip § Recommendations

NEVER skip § Recommendations. Even free / not-for-profit / internal products have founder/eng decisions to make (vendor lock-in posture, scaling triggers, audit budget, sunset criteria). The decision surface is the section that exists in every cost-estimate.

## Sensitivity — the 2-3 drivers of 80% of variance

The load-bearing 30-second-scan section. A reader who has only seconds with the cost estimate reads § Overview + § Sensitivity. The section forces the agent to NAME which assumptions actually matter, not just list 15 things that could matter.

### The 80/20 rule applied

For most v1 SaaS products, 80% of total cost / ARR variance comes from 2-3 assumptions:

- **Paid conversion rate** (freemium / subscription) — drives revenue more than any other single variable
- **Build-cost overrun** — drives $50k-200k of v1 total spend; weeks 1-12 sensitivity
- **Token / API cost per user** (AI-enabled products) — usage-based external costs swing 10x routinely
- **Churn** (mature subscription products) — at month 12+, dominates NRR; at v1 closed-beta scale, less load-bearing
- **Customer acquisition cost** (sales-led / paid-marketing channels) — drives gross margin

Pick 2-3 of these (or product-specific equivalents) and skip the rest. § Sensitivity is the place to NAME what's load-bearing; § Risks is the place to list the long tail.

### Canonical shape

```markdown
## Sensitivity

The 3 assumptions driving 80% of cost / ARR variance:

- **Paid conversion rate** (assumption 5 above): 3% projected, 1-5% plausible band. At 1%, run-cost-per-paying-user crosses break-even into negative ($136 / (500 × 0.01 × $20) = -$22/paying-team/mo); at 5%, gross margin clears 80% comfortably. **Deciding signal:** week-4 closed-beta paid conversion rate.

- **Token-cost-per-user** (assumption 8 above): $0.20/mo placeholder, $0.05-$0.80 plausible band based on usage patterns. At $0.80, AI features turn from break-even helpers to loss leaders. **Deciding signal:** week-2 closed-beta AI-feature usage rate.

- **Build-cost overrun** (assumption 2 above): 14 weeks projected, 14-22 weeks plausible. Each week over adds $6k at $150/hr × 40 hr/week. **Deciding signal:** end-of-Phase-2 milestone slip > 2 weeks.
```

### Anti-patterns the section catches

- **Listing every assumption as "sensitive"** — defeats the purpose. The section's job is to name what's LOAD-BEARING; if every assumption is sensitive, none are.
- **Deciding signal absent** — "Paid conversion could be lower than projected" without naming the closed-beta measurement that confirms it is the anthill-port discipline gap. Every sensitivity row carries a deciding signal that closes the band.
- **Sensitivity without quantification** — "If conversion is lower, costs are higher" is useless. The band + the formula + the impact-in-dollars are the load-bearing content.

## Product-class calibration ladder

Mirrors step-9's calibration ladder; the cost-estimate.md depth scales with product complexity:

| Product class | cost-estimate.md depth | Notes per section |
|---|---|---|
| **Micro-Product / CLI helper / single-purpose tool** | Compact ~5 KB | Build-Cost: 1-2 weeks total. Run-Cost: 1-3 line items (single host vendor + maybe Sentry). Scenarios: bear/base only; bull is "we sell more copies" which doesn't shift the model. Unit Economics: simplified to "one-time price × N copies − fixed run cost". Sensitivity: 1-2 drivers (CAC for paid; usage spike for free-with-API). |
| **Mobile App (focused, 1 persona)** | Standard ~8 KB | Build-Cost: 12-20 weeks typical. Run-Cost: app-store revenue-share line (15-30% Apple / Google cut). Scenarios: account for review-cycle delays (1-2 week impact on launch). Unit Economics: ARPU calculated after store-cut. |
| **Developer Tool / API-first** | Standard-Expanded ~10 KB | Pricing model often usage-based (per-API-call). Build-Cost: 14-22 weeks typical (SDK + docs + API + dashboard). Run-Cost emphasises per-API-call infra cost; token cost if AI-backed. Unit Economics emphasises per-call cost / per-call price + free-tier abuse risk. |
| **SMB SaaS (the spec 026 default)** | Full ~10-15 KB | Full structure. Pricing model typically per-seat subscription. Build-Cost: 14-20 weeks. Run-Cost: 5-8 vendor line items + Stripe fees. Scenarios: 3 paid-conversion bands. Unit Economics: ARPU + CAC + LTV calibrated to SMB-SaaS benchmarks. |
| **Venture-Scale / Marketplace / multi-persona** | Expanded ~15-20 KB | Full structure. Pricing model multi-tier (free / pro / enterprise) or take-rate (marketplace). Build-Cost: 24-40 weeks. Run-Cost: 8-15 vendor line items + per-persona variable cost. Scenarios add upside/downside on take-rate (marketplaces) or per-persona conversion (multi-persona). Unit Economics expanded per-persona. |

Brief field missing or ambiguous → default to **SMB SaaS (Full)**. Mark the chosen depth in `## Overview` opening sentence.

## When cost ceiling (step-9 carry-over) is exceeded

Step-9 § Overview names a v1 infra cost ceiling target. Step-10 § Overview restates that target verbatim, then flags whether line-item math supports or revises it. Four cases:

1. **Within target by 10%+** — declare confidently, no revision needed. *"v1 cost ceiling target was <$200/month closed-beta (per step 9 § Overview). Concrete line items below land at $156/month — within target with $44/mo headroom."*
2. **At target ±10%** — declare with mild flag. *"v1 cost ceiling target was <$200/month closed-beta. Concrete line items land at $194/month — at target; sensitivity bands could push this over by month 6."*
3. **Exceeds target by 10-50%** — name the assumption(s) that moved the math. *"v1 cost ceiling target was <$200/month closed-beta. Concrete line items land at $278/month — 39% over. The Postgres tier-upgrade trigger (assumption 10) was wrong in step-9: at 500 WAT we cross the Supabase Pro→Team boundary, adding $80/mo. Either accept the higher ceiling or rescope to delay Pro→Team until 1000 WAT (changes step-9 § Open Decision row 2's deciding signal)."*
4. **Exceeds target by >50%** — surface loudly + name the deciding question for the founder. The founder needs to decide: accept the new ceiling OR rescope v1 to fit the old ceiling OR push pricing higher to absorb the difference. This is a founder-level decision, not an agent decision.

The cost-ceiling cross-reference is an MCP-port discipline that anthill doesn't carry; spec 026 step-9 calibration introduced it.

## Cross-references to other steps

- **PRD `US-NN` IDs** — § Build Cost may scope per-user-story when complexity varies widely (e.g. "US-07 keyboard-first triage: 3 weeks; US-19 bulk-action: 1 week"). Not mandatory at row level — useful when the trace is non-obvious.
- **Step 9 system-design § Integrations** — § Run Cost line items mirror step-9's integration list. Step-9 names the vendor; step-10 names the tier + cost.
- **Step 9 system-design § Non-Functional § Scale Assumptions** — drives the v1 scale assumption that § Run Cost extrapolates against. NEVER independent — if step-9 named 500 WAT and step-10 models for 5000 WAT, that's a step-step contract violation.
- **Step 11 roadmap § Phases** — reads § Build Cost ranges for phasing the v1 spend. Cost-estimate doesn't sequence; roadmap does. The contract: cost-estimate produces $-by-phase; roadmap consumes it to time the spend.
- **Step 12 legal-posture** — compliance budget (DPA cost, SOC 2 audit fees, sub-processor budget) lives there. § Run Cost may flag "compliance line items: deferred to step 12" with a one-line pointer.

## Voice & anti-patterns

- **Mark every number `[Estimated]` that isn't vendor invoice / signed contract / pricing-page snapshot with date.** False precision is the regression mode FPA discipline catches.
- **Order of magnitude is what matters.** $2k/mo at 1000 users beats $2,143/mo at 1000 users. Three significant figures is the upper limit at v1.
- **Build-cost is always a range, never a point.** Single-point build estimates are wrong by 30-50% routinely.
- **Bear/base/bull are not optional for revenue products.** Single-point projections defeat the FPA discipline.
- **Sensitivity is the load-bearing scan.** A reader with 30 seconds reads § Overview + § Sensitivity. Make those work standalone.
- **No meta-commentary about the document's own discipline.** Don't write `## Notes on this cost model's assumption traceability` or any equivalent. The assumption table + Source columns + `[Estimated]` flags ARE the discipline; a section about them is noise. (Inherits step-9's CUT-2 calibration.)
- **No "locked decisions" sub-section.** Pricing model + price point + rate-placeholder are locked in the running prose of § Pricing Model + § Assumptions table. Re-tabling them as a separate Locked H2 duplicates the running commitment. (Inherits step-9's CUT-1 calibration.)
- **Cost-ceiling cross-reference to step 9 § Overview.** § Overview restates the step-9 ceiling target verbatim, then flags whether line-item math supports or revises it. Closes the cross-step loop.
