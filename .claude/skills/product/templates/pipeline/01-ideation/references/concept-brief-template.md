# Concept Brief Template

This is the output format for the deep-dive step of ideation. One brief per selected concept. This document IS the design contract handed to step 2 (prototype) — it must contain enough detail to start prototyping and downstream pipeline steps.

Ported from anthill `anthill-product-ideator/references/concept-brief-template.md` (2026-04 vintage). Adapted: handoff section now points at our `product_advance` flow + step 2 (prototype) instead of `/anthill-prototype`; removed `docs/sdlc/` path references.

---

```markdown
# [Product Name]

**Tagline:** [One sentence, max 10 words. Must make a non-technical person curious.]
**Scale:** Micro-Product | SMB | Venture-Scale | Marketplace | Developer Tool | Mobile App
**Model:** Subscription | Usage-based | Hybrid | Service-as-Software
**AI-native:** Yes (remove AI = can't exist) | No (AI enhances but isn't required)
**Comparable(s):** "[X] meets [Y]" or list 2-3 inspirations with what's borrowed from each

---

## Hook (why they sign up)

[Why does someone try this? Must be explainable in one breath.
Must work as a tweet — if it doesn't fit in 280 chars, simplify.]

## Retain (why they stay past month 3)

[Why do they keep paying? What would they lose by leaving?]

```
Month 1: [what happens — first value]
Month 3: [what's accumulated — switching cost building]
Month 6: [what's locked in — leaving is painful]
Month 12: [why they'd never churn — identity/workflow embedded]
```

## Refer (why they tell others)

[What specific moment triggers sharing? Be specific:
"When they see their report saved them $2K this month" — not "when they have a good experience."]

---

## Target Persona(s)

For each persona (1-3):

| Attribute | Detail |
|-----------|--------|
| Who | [role, company size, industry] |
| Pain today | [what they do now, why it sucks] |
| Budget | [what they pay today for alternatives or workarounds] |
| Where they hang out | [communities, platforms, events] |
| Trigger to search | [what event makes them look for a solution] |

## Mechanics Breakdown

### Layer 1 — Core Value
[The fundamental problem it solves. What's the "job to be done"?]

### Layer 2 — Growth
[How does this grow? Viral loop, network effect, content flywheel, PLG?]

### Layer 3 — Moat
[What compounds over time? Data, network, integrations, brand, community?]

---

## User Flow (first visit to power user)

### First Visit (< 2 minutes to value)
1. [what they see]
2. [what they do]
3. [what value they get — the "aha moment"]

### First Week
1. [what changes with repeated use]
2. [what data/content they've accumulated]
3. [what brings them back]

### Power User (month 3+)
1. [what the experience looks like at scale]
2. [what they'd lose by leaving]
3. [how they've invited others]

---

## Growth Loop

```
[Text diagram of the primary growth loop]

Example:
User creates report → shares with client → client asks "what tool is this?"
→ client signs up → creates their own reports → shares with THEIR clients → ...
```

**Growth type:** PLG / Viral / Content / Community / Paid / Marketplace
**Estimated viral coefficient:** < 0.5 (paid-dependent) / 0.5-1.0 (organic supplement) / > 1.0 (self-sustaining)

---

## Monetization Sketch

| Plan | Price | What's included | Who buys this |
|------|-------|----------------|---------------|
| Free | $0 | [limits] | [persona — discovery] |
| Starter | $X/mo | [limits] | [persona — validates] |
| Pro | $X/mo | [limits] | [persona — scales] |
| Enterprise | $X/mo | [limits] | [persona — org-wide] |

**ARPU estimate:** $X/mo (based on plan distribution assumption)
**Expansion revenue:** [how does revenue grow per customer over time?]

---

## Business Model

### Revenue Model Rationale
| Question | Answer |
|----------|--------|
| Why this model? (subscription/usage/hybrid) | [Why it fits the value delivery pattern] |
| What triggers upgrade? | [Specific limit or feature that drives conversion] |
| What prevents downgrade? | [Switching cost or accumulated value] |

### Unit Economics (Estimates — mark as "Estimated", not fact)
| Metric | Value | Assumption |
|--------|-------|------------|
| ARPU | $X/mo | [plan distribution: 60% free, 30% starter, 10% pro] |
| Gross margin | X% | [infrastructure cost estimate] |
| Estimated CAC | $X | [primary channel + conversion rate assumption] |
| Target LTV | $X | [ARPU x avg lifetime months] |
| LTV:CAC ratio | X:1 | [healthy = 3:1+] |
| Payback period | X months | [CAC / monthly gross profit] |

**Disclaimer:** These are day-zero estimates based on comparable software products, NOT validated data. Treat as hypotheses to test, not targets to hit.

### Go-to-Market Strategy
| Phase | Channel | Motion | Target |
|-------|---------|--------|--------|
| Pre-launch | [channel] | [self-serve / sales-led / community-led] | [waitlist / design partners] |
| Launch (month 1-3) | [channel] | [motion] | [first X paying users] |
| Growth (month 3-12) | [channel] | [motion] | [MRR target] |

### Key Metrics
| Type | Metric | Target | Why this metric |
|------|--------|--------|----------------|
| North Star | [metric] | [target] | [why it captures core value] |
| Guardrail | [metric] | [threshold] | [what it protects against] |
| Leading | [metric] | [target] | [what it predicts] |

## Technical Sketch

[NOT a full architecture — just the key decisions that make or break the concept. Full architecture is step 9 (system-design).]

| Decision | Choice | Why |
|----------|--------|-----|
| Frontend | [tech] | [reason] |
| Backend | [tech] | [reason] |
| AI | [provider/approach] | [what it enables] |
| Key integration | [API/platform] | [what it unlocks] |
| Data | [what's stored] | [why it matters for the moat] |

**MVP build estimate:** [time for 1 person to validate the core loop]

---

## Competitive Positioning

| This product | vs [Competitor 1] | vs [Competitor 2] |
|-------------|-------------------|-------------------|
| [what we do] | [what they do] | [what they do] |
| [our advantage] | [their weakness] | [their weakness] |

**Why now?** [What changed recently that makes this possible/timely?]

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| [risk 1] | High/Med/Low | [what to do] |
| [risk 2] | ... | ... |
| Platform risk: [will platform build this?] | ... | ... |
| Competition: [who could clone this?] | ... | ... |

---

## Anti-Goals

[What this product must NEVER become — guardrails.]

- **NOT** [anti-goal 1] — [why this kills the product]
- **NOT** [anti-goal 2] — [why this kills the product]
- **NOT** [anti-goal 3] — [why this kills the product]

---

## Moat Analysis

| Moat type | How it works here | Strength over time |
|-----------|------------------|--------------------|
| Network effects | [more users = more value because...] | Weak → Strong |
| Data moat | [usage data improves product because...] | Medium → Strong |
| Integration moat | [connected to X tools, switching = disconnecting all] | Medium |
| Brand/community | [category = product name, community identity] | Slow → Very Strong |

**Overall moat:** Weak / Medium / Strong / Category-defining

---

## Distribution Strategy

### First 100 Users
- [Channel 1]: [specific tactic]
- [Channel 2]: [specific tactic]
- [Channel 3]: [specific tactic]

### Launch Calendar
| Week | Channel | Angle | Format |
|------|---------|-------|--------|
| 0 | X/Twitter | Build-in-public teaser | Thread |
| 1 | Product Hunt | MVP launch | Show HN-style |
| 2 | Hacker News | Technical story | "I built X — here's how" |
| 4 | [Niche community] | Community showcase | "What users built" |

### Validation Metric
[What specific number proves this concept has legs?]
Example: "500 waitlist signups in 30 days with $2K ad spend" or "10 paying users in first month from cold outreach."

---

## Elevator Pitch Test

[Can a non-technical person understand this in 2 sentences?]

Sentence 1: [what it is]
Sentence 2: [why it matters]

[If you can't write these 2 sentences clearly, the concept needs simplification.]

---

## JTBD Statement

When [situation/trigger], I want to [motivation/job], so I can [desired outcome].
Functional job: [what they need to accomplish]
Emotional job: [how they want to feel]
Social job: [how they want to be perceived]

---

## Sources

[Numbered list of every source cited as [N] in the brief above. Minimum 10. URL + one-line description per source.]

1. [URL] — [what was sourced from this]
2. [URL] — [what was sourced from this]
   ...

```

---

## Example: InvoiceAI (condensed reference from a real brief)

Shown to anchor the level of specificity expected. Not a template to clone — your brief is for YOUR product, not InvoiceAI.

### Identity

**Name:** InvoiceAI
**Tagline:** Never get a tax invoice wrong again.
**Scale:** SMB SaaS → Venture-scale
**Model:** Hybrid (free tier + usage-based per invoice)
**AI-native:** Yes — remove AI, the product is just another invoice emitter in a crowded market.

### Hook — Retain — Refer

| Stage | Mechanism |
|-------|-----------|
| **Hook** | "Issue your first invoice with AI in 3 minutes — free, no credit card." Functional free plan (10 invoices/month). Free NCM lookup tool on the blog drives organic traffic. |
| **Retain** | Data compounds: confirmed classifications, product catalog, fiscal history. The more you use it, the better the AI gets at your specific business. Switching = losing all that training. |
| **Refer** | Accountants as viral channel: 1 satisfied accountant refers 20-200 SMB clients. Partner program with 20% recurring commission. SMB-to-SMB referral code. |

### Mechanic Stack

| Layer | Mechanic | How It Works |
|-------|----------|-------------|
| Base (value) | AI-powered automation | AI classifies taxes, saves 10-20 hours/month of manual work |
| Growth (viral) | Channel partners (accountants) | 50,000 accounting firms as zero-CAC distribution network |
| Moat (defensibility) | Data flywheel | Every invoice issued trains the model. After 100K invoices, accuracy exceeds any new entrant. |

### Unit Economics (Estimated)

| Metric | Value | Rationale |
|--------|-------|-----------|
| ARPU | R$89/mo | Weighted average: 40% Starter + 35% Pro + 20% Business + 5% Enterprise |
| CAC | R$120 | 60% via accountants (~R$20), 25% via SEO (~R$80), 15% via integrations (~R$200) |
| LTV | R$2,136 | ARPU x 24 months average retention |
| LTV:CAC | 17.8x | Excellent |
| Gross margin | 85% | AI cost ~R$0.03/invoice, infra ~R$0.15/invoice |

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Bling/Omie add AI fiscal features in 6-12 months | High | Launch first, build data moat. ERPs are slow to add focused AI. |
| SMBs don't trust AI for tax documents | Medium | "AI suggests, you confirm" — always human-in-the-loop. Show confidence %. |
| NFS-e fragmentation (5,570 municipalities) | Medium | Start with top 100 cities (covers 70% of volume). Use NFe.io as backend. |
| Google/Microsoft launch fiscal-AI free in Workspace/365 | Existential | Build moat via Brazilian tax data + accountant channel. Big tech doesn't understand BR taxation. |

---

## Handoff to step 2 (prototype)

The concept brief is the source of truth for step 2 (prototype HTML directions). The agent conducting step 2 reads this brief verbatim via `product_step_get(2)`'s `prior_artifacts` field; the brief shapes which screens make the killer flow, which audience the voice targets, which mechanic the visual restraint should emphasize.

After `product_step_submit(1, "04-concept-brief.md", <content>)` returns success, call `product_advance` — no human checkpoint required for step 1 (the user-led conversation IS the checkpoint). Pipeline moves to step 2.
