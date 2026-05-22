---
mode: draft-after-input
delegable: partial
delegation_hint: "draft step-10 cost-estimate.md from step-8 PRD + step-9 system-design — single-artifact financial model (build + run cost, scenarios, sensitivity, risks) with documented assumption table; parent collects 2 inputs first (pricing model + ballpark price point); sub-agent does the math"
---

# Step 10 — Cost Estimate

**Goal:** the one-page-ish financial model for v1 — build cost (one-time / first 3 months), run cost per month at v1 scale, unit economics if revenue-generating, scenario analysis (bear / base / bull), sensitivity (the 2-3 assumptions that drive 80% of variance), and the top 5 financial risks. The artifact step 11 (roadmap) reads to phase v1 spend and step 12 (legal) reads to size the compliance budget.

**Mode:** `draft-after-input` with `delegable: partial`. The parent must extract two pieces of input that no prior artifact pinned down — **pricing model** (free / freemium / one-time / subscription / usage-based / hybrid / not-for-profit) and **ballpark price point** (order of magnitude; $10/mo vs $100/mo vs $1k/mo — not exact). Once locked, the model derivation is mechanical from step-9 system-design + step-8 PRD inputs.

**Output file:** `cost-estimate.md` in `docs/`. Single-artifact — no `extra_files`.

---

## How to conduct this step

Read `references/cost-modeling-conventions.md` for the assumption-table shape (the load-bearing anthill-FPA discipline: every input has source + confidence), the scenario discipline (bear / base / bull NOT single-point estimates), the sensitivity heuristic (find the 2-3 assumptions that drive 80% of variance), and the product-class calibration ladder (compact micro-product → ~5 KB; SMB SaaS Full → ~10-15 KB).

### 1. Read everything prior

- **System design** — `docs/system-design.md` — § Stack drives infrastructure cost (managed Postgres vs self-hosted, Vercel vs Fly), § Integrations drives third-party cost (Stripe fees, OpenAI tokens, Auth0 vs Supabase), § Non-Functional § Scale Assumptions drives volume.
- **Architecture JSON** — `docs/data-flow.json` — quick scan of the components surface confirms the line-item count for run-cost.
- **Security** — `docs/security.md` — compliance posture (LGPD / GDPR / SOC 2) drives line items step 12 will expand (DPA cost, audit fees if SOC 2 pre-work).
- **PRD** — `docs/prd/v1.md` — § Goals drives the target price point (e.g. "<50% of competitor X" anchors the pricing-model conversation); § Success Metrics row 1 drives the scale-assumption to use; § User Stories drives build-cost surface; § Audit Response drives step-4 audit-driven cost items.
- **Cost-ceiling pointer** from step-9 system-design § Overview — the v1 infra cost ceiling target (e.g. `<$200/month at closed-beta scale`) is the anchor this step REFINES with concrete line items; do not silently revise it without naming why.

### 2. Parent collects pricing model + price point (2 questions, ~2 min)

The parent MUST conduct this exchange directly — not delegate. Two questions, sometimes a third:

1. **Pricing model.** *"Pricing model for v1 — free / freemium / one-time purchase / subscription / usage-based / hybrid / not-for-profit?"* If the PRD already named the model (it often does — competitive positioning in § Goals usually pins this), confirm rather than re-ask. Push back gently if the model conflicts with the PRD's audience (e.g. enterprise persona + free-only model = mismatch).

2. **Ballpark price point** *(skip if free / not-for-profit / internal):* *"Order of magnitude price target — $10/mo, $100/mo, $1k/mo, $10k/mo? Not exact; just the magnitude."* PRD § Goals usually names this too (e.g. "<$4/seat" anchors $1-10/user/mo magnitude). Confirm rather than re-ask when the PRD is clear.

3. **(Optional) Hourly rate placeholder** *(when build-cost needs anchoring):* *"Hourly rate for build-cost math? Default is $150/hr blended."* Skip when the founder already named a rate; default to $150/hr blended otherwise (a typical Bay-Area-ish dev rate; flag explicitly as a placeholder, mark `[Estimated]`).

### 3. Drafting delegates to a sub-agent

Once pricing + price point are locked, the parent dispatches an `Agent` sub-agent with the 5-field brief. CONTEXT includes:

- All prior artifact paths (step 8 PRD, step 9 system-design, step 9 architecture.json, step 9 security.md)
- The captured pricing model (verbatim)
- The captured ballpark price point (verbatim)
- The captured rate (or "default $150/hr")
- The step-9 cost-ceiling target sentence (verbatim)

The sub-agent's job is structural synthesis — fill the canonical cost-estimate template using the captured inputs + the prior-artifact reads. No more user questions; the parent's interview was the last input needing the founder.

Use `model: opus` for the sub-agent — sonnet sometimes drops the assumption-table discipline (source + confidence columns get omitted, which is the anthill-FPA regression mode the discipline catches).

### 4. The canonical cost-estimate structure

The sub-agent writes `cost-estimate.md` against this 7-required + 3-conditional spine (full shape with depth conventions lives in `references/cost-modeling-conventions.md`):

1. **Overview** — short paragraph PLUS two load-bearing one-liners (mirrors step-9 § Overview shape):
   - **Paragraph:** what's being modelled (v1 build + run), which scale assumption applies (from step-9 § Non-Functional), which pricing model + price point the founder locked. Names the product class (micro / mobile / dev-tool / SMB-SaaS / venture-scale) so depth calibration is visible.
   - **Biggest cost risk:** one sentence naming THE assumption most likely to break the model. Anti-pattern: even-keeled risk distribution. A SaaS with usage-based AI calls has ONE risk that dominates (token-cost-per-user); say it. Example: *"Biggest cost risk: Stripe fees + Postgres scaling are bounded; the wild card is paid-conversion rate — if conversion lands at 1% instead of 3% projected, run-cost-per-paying-user crosses break-even into negative."*
   - **v1 cost ceiling restate:** repeat the step-9 § Overview cost-ceiling target verbatim, then flag whether the line-item math supports or revises it. If revising upward, name why (which assumption changed). Example: *"v1 cost ceiling target was <$200/month closed-beta (per step 9 § Overview). Concrete line items below land at $178/month — within target."*

2. **Pricing Model** — declared model (free / freemium / one-time / subscription / usage-based / hybrid / not-for-profit) + one-paragraph rationale anchored to the PRD's persona + audience + § Goals. If subscription/freemium, name the tier structure here (free tier limits + paid tier features) — don't defer to a separate section. If usage-based, name the metering unit and the per-unit price. If free / not-for-profit, declare explicitly and note that § Unit Economics + § Scenarios + § Break-even will skip (or carry a degenerate "no revenue" form).

3. **Assumptions** — the load-bearing anthill-FPA table. Every input the model depends on lands in this table with **value + source + confidence**. Format:
   ```markdown
   | # | Assumption | Value | Source | Confidence |
   |---|---|---|---|---|
   | 1 | Hourly rate (blended) | $150/hr | placeholder · founder · 2026-05-16 | Low (rate is illustrative) |
   | 2 | v1 build estimate | 14 weeks (10 weeks engineering + 4 weeks polish) | step 8 PRD § User Stories scope + step 9 system-design § Stack complexity | Medium |
   | 3 | Target scale (month-3) | 500 weekly-active teams | step 8 PRD § Success Metrics row 1 | High (founder-locked) |
   | 4 | Avg users per team | 5 | step 8 PRD § Target Users (5-30 person squads, conservative) | Medium |
   | 5 | Paid conversion (freemium) | 3% | benchmark · SaaS industry median 2-5% | Low (no product data yet) |
   ...
   ```
   Aim for 8-15 rows depending on product class. EVERY downstream number traces back to a row in this table — the assumption table IS the audit trail.

4. **Build Cost** — range estimate for v1 scope.
   - Format: `weeks × $/hr × hours-per-week = $-range`. Always a range, never a single point (the anthill-FPA scenario discipline applied to build-cost).
   - Breakdown by phase (Foundation / Killer flow / Surrounding features / Polish — mirroring step 11's roadmap shape).
   - Mark every number `[Estimated]` unless it traces to a vendor invoice or a signed contract.
   - Acknowledge the range. v1 build estimates are wrong by 30-50% routinely; bake it in.

5. **Run Cost** — per-month line items at v1 scale assumption. Format:
   ```markdown
   | Vendor | Tier | Monthly cost | Source |
   |---|---|---|---|
   | Vercel | Pro | $20 | vendor pricing page · 2026-05-16 |
   | Supabase | Pro | $25 | vendor pricing page · 2026-05-16 |
   | Stripe | per-transaction | est $40 at v1 vol | 0.029 × 30 paid teams × $20 ARPU = $17.4; rounded with churn refunds | Medium |
   | Sentry | Team | $26 | vendor pricing page · 2026-05-16 |
   | Resend | Pro | $20 | vendor pricing page · 2026-05-16 |
   | Cloudflare R2 | per-GB | est $5 | usage projection | Low |
   | **Total** | | **$136/mo** | |
   ```
   Use current vendor pricing where available (mark `Source: vendor pricing page · YYYY-MM-DD`); mark scale-extrapolated numbers `[Estimated]` with confidence column. The total goes at the bottom of the table.

6. **Sensitivity** — the 2-3 assumptions that drive 80% of variance in the model. Per-assumption: name the assumption + the variance band + the model impact + the deciding signal that flips the design.
   - Format (single paragraph or short table — pick what scans best):
     ```markdown
     - **Paid conversion rate** (assumption 5 above): 3% projected, 1-5% plausible band. At 1%, run-cost-per-paying-user crosses break-even into negative ($136 / (500 × 0.01 × $20) = -$22/paying-team/mo); at 5%, gross margin clears 80% comfortably. **Deciding signal:** week-4 closed-beta paid conversion rate.
     - **Token-cost-per-user** (assumption 8 above): $0.20/mo placeholder, $0.05-$0.80 plausible band based on usage patterns. At $0.80, AI features turn from break-even helpers to loss leaders. **Deciding signal:** week-2 closed-beta AI-feature usage rate.
     - **Build-cost overrun** (assumption 2 above): 14 weeks projected, 14-22 weeks plausible. Each week over adds $6k at $150/hr × 40 hr/week. **Deciding signal:** end-of-Phase-2 milestone slip > 2 weeks.
     ```
   - This is the load-bearing FPA-discipline section. Treat it like step-9's `## Trade-off Triggers` — the 2-3 highest-stakes drivers that flip the recommendation. A cost-estimate without sensitivity is a single-point projection in disguise.

7. **Risks** — top 5 financial risks (NOT every financial risk; just the 5 most-likely-or-impactful). Per row: probability + financial impact + mitigation.
   ```markdown
   | # | Risk | Probability | Impact (1-month) | Mitigation |
   |---|---|---|---|---|
   | 1 | Stripe fees ramp faster than projected (high-volume small-ticket pattern) | Medium | +$50/mo at 100 paid teams | Switch to annual prepay; reduces fee % from 2.9% to 1.5% effective |
   | 2 | Postgres tier upgrade triggers (>500 weekly-active teams) | Medium | +$80/mo | Caps headroom at 5000 WAT; v1.1 carves out read-replica |
   | ... | | | | |
   ```

8. **Recommendations** — the load-bearing **decision** surface (3-5 founder/engineering actions, NOT a summary of sections above). Each recommendation is a verb-shaped call the founder makes Monday morning, with a deciding signal that would flip the recommendation. This section closes the artifact with decisions, not analysis. Format (one of two styles, pick the cleaner one for the product):
   ```markdown
   ## Recommendations

   1. **Hold per-seat price at $4/mo.** Pricing wedge is load-bearing for the PRD's competitive positioning; absorbing $50/mo Stripe-fee ramp via annual-prepay incentive (R1) preserves the wedge without re-pricing. *Flip if:* paid-conversion below 1% at week-4 of closed-beta forces revenue scrutiny.
   2. **Defer EU region + SOC 2 audit spend.** Both are 4-figure budget lines (DPA legal review ~$3k, SOC 2 Type 1 pre-audit ~$15k). v1 cost ceiling holds without them. *Flip if:* first 5 EU prospects in pipeline OR enterprise prospect requires SOC 2.
   3. **Pause public-launch acquisition spend until week-1 retention clears 40%.** PRD § Success Metrics row 1 names retention as the v1-worked signal; acquisition spend on a leaky bucket compounds CAC waste. *Flip if:* week-1 retention ≥ 40% in closed-beta for 2 consecutive weeks.
   4. **Reconcile bottom-up build estimate against top-down 6-month runway constraint pre-Phase-2.** Build-cost $84k-120k (range) sits inside $200k cash runway; sensitivity row 3 (week-overrun) is the watch — every 2 weeks over collapses runway headroom. *Flip if:* Phase-2 milestone slips > 2 weeks; rescope or extend.
   5. **Re-run this cost-estimate at week-6 of closed-beta** with measured paid-conversion + churn + Stripe-fee data. Pre-v1 numbers are placeholders; week-6 is the first point of real data.
   ```
   - 3-5 rows; pick the load-bearing decisions, not exhaustive coverage. The deciding signal ("Flip if:") is the discipline anchor — every recommendation either holds OR flips on a measurable signal.
   - Anti-pattern: "Recommendations: continue current approach" (no decision); "Recommendations: monitor metrics carefully" (no action). Both are sloppy and the section's job is to prevent them.
   - This section mirrors step-9's `## Trade-off Triggers (digest)` discipline — the 30-second-scan that a busy founder reads first. Treat the table above (§ 5 § Sensitivity) as the WHY and the recommendations as the WHAT.

**Conditional sections (revenue-generating products — skip for free / not-for-profit / internal):**

9. **Unit Economics** — CAC / LTV / LTV:CAC / payback period / gross margin / contribution margin. Format:
   ```markdown
   | Metric | Value | Calculation |
   |---|---|---|
   | ARPU | $20/mo | $4/seat × 5 users/team avg |
   | Gross margin | 78% | (ARPU − variable-run-cost-per-team) / ARPU = ($20 − $4.36) / $20 |
   | CAC | $80 | placeholder · founder estimate (sales-led, ~2 hrs founder time per close × $40/hr cost-basis) |
   | LTV (24mo churn-adj) | $360 | $20 × 24mo × 0.75 (NRR after 25% gross churn) |
   | LTV:CAC | 4.5:1 | $360 / $80 — healthy band is >3:1 |
   | Payback period | 4 months | $80 / ($20 × 0.78 gross margin × 1 paying team) |
   ```
   Skip when: free-only, not-for-profit, internal tool (no revenue → no unit economics; just say so).

10. **Projections** — month-by-month cadence for the **base** scenario (this is NOT the scenario variance table — that's § 11 next). 8-12 monthly rows from launch through year-1. Format:
    ```markdown
    | Period | Active workspaces | Paid workspaces | MRR | Infra cost | Total cost | Profit | Growth MoM |
    |---|---|---|---|---|---|---|---|
    | Mo 1 (launch) | 50 | 0 (free trial) | $0 | $156 | $156 + amort. build | -$156 | — |
    | Mo 2 | 120 | 3 | $60 | $178 | $178 + amort. | -$118 | +140% workspaces |
    | Mo 3 | 250 | 8 | $160 | $200 | $200 + amort. | -$40 | +108% workspaces |
    | Mo 4 | 380 | 15 | $300 | $222 | $222 + amort. | +$78 | +52% workspaces |
    | Mo 5 | 500 | 24 | $480 | $245 | $245 + amort. | +$235 | +32% workspaces |
    | Mo 6 | 600 | 32 | $640 | $268 | $268 + amort. | +$372 | +20% workspaces |
    | ... | | | | | | | |
    ```
    - **Cadence:** monthly is the default; bi-weekly for very-early stage (first 2-3 months), quarterly for steadier products (year 2+). v1 cost estimate should land at monthly.
    - **The Projections section answers a different question than § Scenarios.** Scenarios answer "what's the variance band?" — Projections answer "what does the base-scenario monthly cash burn look like for runway planning?". A founder doing burn-rate math wants Projections; a founder doing fundraise prep wants Scenarios.
    - **Growth MoM column is honest, not extrapolated.** Early-stage growth percentages are typically very high (Mo 1 → Mo 2 commonly +100-200%) because the denominator is small. Don't smooth the curve; the curve IS the data.
    - Amortised build-cost column: divide the build-cost RANGE (§ 4 Build Cost) over a chosen period (commonly 12 or 24 months) and surface the per-month allocation. Mark `[Estimated]`. This is the load-bearing column for founder runway-math.
    - Skip when: free-only or not-for-profit (no MRR → projections degenerate to "monthly run cost only" — replace with a 6-row burn-only table in § Run Cost instead).

11. **Scenarios** — bear / base / bull (anthill-FPA discipline). Per scenario: probability weight + 1-3 key variable changes + impact on ARR + impact on runway / break-even.
   ```markdown
   | Scenario | Probability | New paid teams/mo | Churn | ARR EOY | Runway (assume $200k cash) |
   |---|---|---|---|---|---|
   | Bear | 25% | 5 | 18% | $1.4k MRR EOY → $17k ARR | 9 mo |
   | Base | 50% | 15 | 12% | $4.2k MRR EOY → $50k ARR | 16 mo |
   | Bull | 25% | 30 | 8% | $9.1k MRR EOY → $109k ARR | 22 mo |
   ```
   - **Probability column is required** (not just decorative). Forces honest calibration vs hedging. The probabilities sum to 100%; common shapes are 25/50/25 (default for SMB SaaS), 30/40/30 (heavier tails for unproven wedge), 20/60/20 (tight base for proven category). Pick a shape that reflects how confident the founder actually is.
   - The probability values are themselves a Confidence-Low assumption. Mark them so in § Assumptions table; revise post-closed-beta when real data lands.
   - Skip when: free-only or not-for-profit (scenarios degenerate to cost-only — handle as a run-cost sensitivity range in § Sensitivity instead).

12. **Break-Even** — at what user count revenue covers run cost. State the assumption (paid conversion rate, ARPU) used.
    ```markdown
    Break-even: 9 paid teams ($136 run-cost / ($20 ARPU × 78% gross margin) = 8.7 → 9 teams).
    At 3% paid conversion: 300 weekly-active teams produces 9 paid teams → break-even at 60% of v1 target scale.
    ```
    Skip when: free-only or not-for-profit (no break-even concept — frame as "monthly burn at v1 scale" instead, which is just § Run Cost total).

### 5. Calibrate by product class (smart, not rigid)

Mirrors step-9's product-class calibration ladder:

| Product class | cost-estimate.md depth | Sections to keep / adapt |
|---|---|---|
| **Micro-Product / CLI helper / single-purpose tool** | Compact (~7 KB) | Full structure but Build-Cost is 1-2 weeks, Run-Cost is 1-3 line items, Projections may collapse to 4-6 rows, Scenarios may degenerate to bear/base only |
| **Mobile App** | Standard (~10 KB) | Full structure; § Run Cost adds app-store revenue-share line (15-30% Apple/Google cut); § Scenarios accounts for review-cycle delay impact on launch; § Projections handles app-store gating delays in early months |
| **Developer Tool / API-first** | Standard-Expanded (~12 KB) | Full structure; § Pricing Model often usage-based (per-API-call / per-seat-with-API-rate-limits); § Unit Economics emphasises token cost / per-call infra cost; § Projections per-call-volume tracking |
| **SMB SaaS (the spec 026 default)** | Full (~13-18 KB) | Full structure; § Pricing Model typically per-seat subscription; § Scenarios carry 3 paid-conversion bands; § Projections 8-12 monthly rows through year-1 |
| **Venture-Scale / Marketplace / multi-persona** | Expanded (~18-25 KB) | Full structure; § Unit Economics expanded to per-persona ARPU/CAC; § Scenarios add upside/downside on take-rate (marketplaces) or per-persona conversion (multi-persona); § Projections may need cohort overlay or per-persona breakdown |

Brief field missing or ambiguous → default to **SMB SaaS (Full)**. Mark the chosen depth in `## Overview` opening sentence (`v1 cost estimate for an SMB SaaS — full template depth applied.`).

For free / not-for-profit / internal tools: full structure minus § Unit Economics + § Scenarios + § Projections + § Break-Even (which degenerate); document the skip in `## Pricing Model` (`Pricing model: not-for-profit / internal — § Unit Economics, § Scenarios, § Projections, § Break-Even intentionally absent.`). Free/NFP products still keep § Recommendations — even non-revenue products have founder/eng decisions to make (vendor lock-in posture, scaling triggers, audit budget).

### 6. Submit + advance

Call `product_step_submit` with:
- `step: 10`
- `filename: "cost-estimate.md"`
- `content: <full cost estimate>`

No `extra_files` — single-artifact step.

Schema enforces section presence + Layer 1 contains/size floors (assumption-table header, run-cost vendor-table header, total-line literal). On success, `product_advance` moves to step 11 (roadmap — reads PRD + system-design + cost-estimate to sequence v1 build).

**No gate at step 10.** Step 12 (legal-posture) closes the Specification phase gate. Steps 8 → 12 advance fluidly through Specification.

---

## Voice & rigor

- **Mark every number `[Estimated]` that isn't a current vendor invoice / signed contract / pricing-page snapshot with date.** Vendor pricing pages are factual (`Source: vendor pricing page · 2026-05-16`); user-count projections are estimates; build-cost is the most-likely-wrong number, always a range never a point.
- **Order of magnitude is what matters.** `$2k/mo at 1000 users` is useful; `$2,143/mo at 1000 users` is false precision — three significant figures is the upper limit at v1 (you don't know enough to claim more).
- **If unit economics don't work (run-cost-per-user > price × gross margin), surface loudly.** Don't bury in § Sensitivity. The PRD's pricing target may be wrong; the founder needs to see this.
- **The assumption table IS the audit trail.** Every number downstream cites a row in § Assumptions. No room for floating numbers.
- **Bear / base / bull are not optional for revenue products.** Single-point projections are the regression mode. Skip ONLY for free / not-for-profit (where they degenerate).
- **Build-cost overruns are systemic.** Every project goes over. Bake 30% buffer into the range high-end; the buffer isn't pessimism, it's calibration.
- **Sensitivity + Recommendations are the load-bearing scans.** A reader who has 30 seconds reads § Overview + § Sensitivity (the WHY) + § Recommendations (the WHAT). § Sensitivity names the 2-3 assumptions that drive the variance; § Recommendations names the 3-5 actions to take Monday morning. Both work standalone.
- **§ Projections answers monthly burn math; § Scenarios answers variance bands.** Different questions, different consumers (founder doing runway math vs founder doing fundraise prep). Don't conflate them. Projections is the base-scenario monthly cadence; Scenarios is the bear/base/bull variance.
- **§ Scenarios carries probability weights (25%/50%/25% or similar).** Sums to 100%. Forces honest calibration vs hedging. Mark the probabilities themselves as Confidence-Low in § Assumptions; revise post-closed-beta when real data lands.
- **§ Recommendations are DECISIONS, not summaries.** Verb-shaped ("Hold per-seat price", "Defer EU spend", "Pause acquisition until retention clears"). Each carries a deciding signal that flips it. Anti-pattern: "Continue current approach" / "Monitor metrics carefully" — both are non-decisions; the section's job is to prevent them.
- **PRD `US-NN` cross-references where useful.** § Build Cost may scope per-user-story (e.g. "US-07 keyboard-first triage: 3 weeks; US-19 bulk-action: 1 week"); § Run Cost may scope per-integration (e.g. "Stripe drives US-25 + US-28; Resend drives US-23"). Not mandatory at the row level — but useful when the trace is non-obvious.
- **No meta-commentary about the document's own discipline.** Do NOT write a `## Notes on this cost model's assumption traceability` H2 or any equivalent. The assumption table + the Source columns + the `[Estimated]` flags ARE the discipline; a section *about* them is noise. Spec 026 Phase B step-9 judge-feedback (2026-05-16) flagged this anti-pattern across the pipeline; the rule applies here pre-emptively.
- **No "locked decisions" sub-section.** Pricing model, price point, and rate-placeholder are locked in the running prose of § Pricing Model + § Assumptions table. Re-tabling them as a separate Locked H2 duplicates the running commitment. Carries the step-9 calibration discipline.

## What this step does NOT do

- **Detailed financial planning.** This is a one-page-ish artifact for the product spec, not a CFO model. 10-15 KB is the full-template upper bound for SMB SaaS; if it grows past 25 KB, the agent is over-prescribing.
- **Pricing decisions.** Pricing tier values are an estimate / starting point; real pricing comes from market test post-launch. The founder's locked ballpark is the anchor.
- **Fundraising deck inputs.** Step 17 GTM (future MCP) absorbs that work.
- **Capacity planning under viral growth.** v1 scale assumption only; viral-growth modeling is post-v1 cost-revision work.
- **Detailed forecast accuracy backtesting.** This is a one-shot model; revision happens in subsequent product cycles.
- **Roadmap phasing.** Step 11 reads this artifact to phase v1 build by cost-pressure; build-cost ranges land here, sequencing lands there.
- **Compliance budget.** Step 12 (legal-posture) absorbs DPA cost, audit fees if SOC 2, sub-processor budget. § Run Cost may flag "compliance line items deferred to step 12" with a pointer.

## What this step replaces

Step 10 ports `anthill-fpa` (112 LOC SKILL + 59 LOC references — anti-patterns + checklist + examples). The MCP port keeps anthill's load-bearing discipline (documented assumption table with source + confidence; bear / base / bull scenarios; sensitivity for the 2-3 drivers of 80% variance; top-5 financial risks register; unit economics for revenue products) and inherits its anti-patterns catalog (undocumented assumptions, single-point estimates, no sensitivity).

The MCP port diverges from anthill on three points worth naming:

1. **`anthill-bizops-analyst` is NOT ported into step 10.** anthill-bizops is the operational-metrics / process-mapping / efficiency-analysis sibling — that's ops-monitoring territory, not product-spec cost modeling. The MCP port keeps bizops separate; if a future pipeline step models operational efficiency (capacity planning, headcount-to-revenue ratio, process throughput), it lands there, not in step 10. Spec 026 task 19 explicitly named the FPA-vs-bizops decision; FPA wins for cost-estimate.

2. **Anthill's `.anthill/budget.md` ingestion is not ported.** The MCP analog is the parent's § 2 interview (pricing model + price point + rate) which captures the budget inputs at synthesis time, not from a fork-level config file. The MCP doesn't model fork-level financial state.

3. **Cost-ceiling cross-reference to step 9.** Anthill's principal-engineer doesn't carry a cost-ceiling pointer; the MCP step-9 calibration (post-task-18 judge-feedback) added it. Step 10 § Overview restates the step-9 ceiling and flags whether line-item math supports or revises it — closes the cross-step loop. Anthill has no equivalent because anthill's pipeline doesn't enforce step-to-step contract symmetry the same way.

Anthill's calls-for-action (`Save the analysis to docs/sdlc/10-cost-estimate/<slug>-cost.md`) translate to the MCP's `product_step_submit` path discipline. Resumability is `product_status` + `.state.json`; the halt protocol is the `schema-incomplete` validation error.
