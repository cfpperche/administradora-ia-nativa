---
mode: interactive
delegable: partial
delegation_hint: "synthesize the concept brief from a locked direction + discovery findings + selected concept (sub-agent gets the brief shape + sources via context; cannot conduct user interview)"
---

# Step 1 — Ideation (Concept Brief)

**Goal:** produce a deeply-validated, source-cited concept brief that names the product, articulates the bet, and stands as the design contract every downstream step (prototype, spec, PRD, system-design) refers back to. The output file is `04-concept-brief.md` — the numeric prefix mirrors anthill's pipeline numbering for the sub-steps it conducts internally (00-direction → 01-opportunity-map → 02-concepts → 03-ranking → 04-concept-brief). This MCP collapses those sub-steps into one user-conducted conversation; the file name is preserved so anyone familiar with the anthill source recognizes the artifact.

**Mode:** `interactive`. The agent conducts a 6-axis direction interview with the user, runs market discovery (15-25 web searches across 5 tracks), generates 5-8 candidate concepts (or pinned + 4-7 challengers in critique mode), ranks them on 5 axes, lets the user select, then synthesizes the deep brief. Sub-agent delegation is `partial`: the synthesis half (steps 4-6 below — concept brief drafting from a locked selection) can be delegated; the interview + selection cannot, because they require the user channel.

**Output file:** `docs/concept-brief.md` — single primary artifact, no `extra_files`. The schema enforces section presence + min_size; quality (the discipline of *deep* answers, not stubs) is the agent's responsibility, reinforced by the references this template ships.

---

## Two execution shapes

### Default — from-zero ideation

The user has a problem space but no locked concept. The agent runs all 6 sub-stages in sequence: direction → discovery → ideation → ranking → user selection → deep brief.

### Critique mode — adversarial validation of a pre-decided concept

The user arrives with a concept already in mind ("I want to build a Linear clone", "I want to ship a personal-knowledge tool"). The agent does NOT replace the pinned concept; instead, it generates 4-7 structural challengers and runs adversarial ranking. The pinned concept always gets the deep-dive regardless of rank; the brief's Risks section cites any challenger that beat it.

Auto-detect critique mode by listening for: (a) user explicitly names a product/concept on first contact, (b) user provides an audience, business model, or comparator. Confirm out loud with the user: *"I'll validate this against challengers (critique mode) instead of generating from scratch. If you'd rather I forget your concept and ideate from zero, say so now."*

---

## How to conduct this step

### 1. Direction interview (6 axes)

Ask the user about each axis. Skip any they've already answered in conversation. Be brief — one question per axis, accept short answers.

1. **Domain.** "What space/industry are you exploring?"
2. **Audience.** "Who is the target user? Role, company size, geography."
3. **Constraints.** "Any technical, budget, or timeline constraints I should respect?"
4. **Ambition.** "What scale? Micro-product (one founder, $1-10K MRR), SMB SaaS ($10-100K MRR), venture-scale ($1M+ ARR target), marketplace, developer tool, mobile app?"
5. **Business model.** "How do you want to monetize? Subscription, usage-based, hybrid, marketplace, service-as-software, undecided?"
6. **JTBD.** "What job is the customer hiring this product to do? When [trigger], they want to [accomplish], so they can [outcome]."

Pin the answers in the conversation before discovery. In critique mode, the audience + concept one-liner + business model are typically already known; only ask about the gaps.

### 2. Discovery (15-25 web searches, 5 tracks)

Read `references/discovery-playbook.md` for the full track-by-track methodology. Summary:

- **Track 1 — Market Signals (5-7 searches).** Recent funding rounds, news, conference themes, analyst reports in the chosen domain.
- **Track 2 — Pain Points (5-7 searches).** Reddit / HN / community threads where the audience complains about current solutions.
- **Track 3 — Competitive White Space (3-5 searches).** Direct competitors, adjacent players, what they charge, where they fall short. Most important track in critique mode.
- **Track 4 — Platform & API Opportunities (2-3 searches).** What recent platform shifts (LLM APIs, new device categories, regulatory changes) unlock that wasn't possible 2 years ago.
- **Track 5 — Adjacent Inspiration (2-3 searches).** Products in different industries that solve structurally similar problems — fodder for recombination.

Every factual claim that lands in the brief MUST carry an inline citation `[1]`, `[2]`. Estimates are explicitly marked "Estimated". Minimum 10 unique sources across the brief; 15-20 is healthier. Never fabricate competitor data — if a number can't be sourced, omit it.

In critique mode, scope every search to the pinned concept's market. Track 3 becomes load-bearing — find where the pinned concept genuinely differentiates vs. where it's table stakes.

### 3. Ideation (5-8 concepts default / pinned + 4-7 challengers in critique)

Read `references/mechanics-catalog.md` (concept generation patterns) and `references/anti-patterns.md` (what to reject) before drafting.

**Default mode rules:**
- Never copy — remix and recombine. Layer 2-3 mechanics from the catalog per concept.
- Each concept passes the Hook-Retain-Refer test (one sentence each, concrete).
- Each concept passes the Elevator Pitch test (2 sentences, non-technical reader).
- Range across scales (at least 1 micro, 1 SMB, 1 venture). Range across business models.
- Include at least 1 boring-industry wildcard.
- Include at least 2 AI-native concepts (remove AI = product dies, not "AI sprinkled in").
- Name every concept memorably (not "AI for X").
- Per concept: "what could kill this" line — honest risk.
- Run every concept through anti-patterns checklist before listing.

**Critique mode rules:**
- Concept #1 is the pinned concept — literal copy of the user's one-liner. Do NOT rename, reframe, or "improve".
- 4-7 challengers serve the SAME JTBD but differ structurally on at least one of: business model, primary mechanic, audience segment, or acquisition channel.
- Each challenger includes a line **"Why this could beat pinned:"** — specific, falsifiable, axis-named.
- Challengers that only rename the pinned or change surface wording are invalid — reject and regenerate.

### 4. Ranking (5-axis scoring)

Score each concept on 5 axes, 1-5 each, 25 max:
1. **Market.** Size, growth rate, timing.
2. **Feasibility.** Can 1 person validate the core loop in 4 weeks? **The Feasibility axis is where the founder's stated constraints (budget, team, timeline, AI-deferred, no-PII, etc.) live as scoring weights.** If a challenger relies on a capability the v1 envelope explicitly excludes (e.g. an AI-agent core when the fixture says "AI deferred to v2"), that concept's Feasibility score drops — not just its Risk. Make the constraint visible inside the score, not as an afterthought.
3. **Differentiation.** Is there a 10x angle that a competitor can't replicate in 6 months?
4. **Moat.** What compounds over time — data, network, integrations, brand?
5. **Monetization.** Clear path to revenue; willingness-to-pay validated by competitor pricing?

Present as a table with total scores + brief rationale per axis. Per-axis rationale is REQUIRED — a bare score with no reasoning blocks the next ranking pass. Use phrasing like "Honest score: 3, not 4 — [reason]" when calibration is non-obvious; the judge reading this brief should be able to audit your scoring math. In critique mode add a `delta_vs_pinned` column (challenger_total − pinned_total; pinned row shows `—`) and a Verdict block:

- **Pinned wins by ≥3:** "PINNED WINS. Decision holds. Proceed."
- **Pinned wins by 1-2:** "PINNED WINS NARROWLY. Review challenger's strongest axis."
- **Tie:** "TIE. Proceed with pinned by default; Risks section must address why."
- **Challenger wins:** "CHALLENGER BEATS PINNED on axis N. Founder decision required before deep-dive."

### 5. Selection (user decision)

In default mode: present the ranked table to the user; ask which concept(s) to deep-dive. Don't proceed without an explicit pick.

In critique mode: pinned gets the deep-dive regardless of rank. If a challenger won, surface the Verdict + ask the user whether to (a) proceed deep-diving pinned as planned, (b) re-pin to the winning challenger, or (c) pause for thinking.

### 5.5. Name commitment — placeholder discipline (consumer contract for steps 5/7)

The Identity block (§ 6 below) carries the product name. **Discipline:** commit to a real name at step 1, OR explicitly mark the name as a placeholder. Both are valid; silent half-commitments are not.

- **Real name committed** — write the chosen name in Identity; downstream steps (5 brand, 7 prototype-v2, 8 PRD) use it verbatim across all artifacts. No rename cascade needed.
- **Placeholder explicitly marked** — when the user prefers to defer the naming decision to step 5's brand-book conversation (legal/distinctive review pending, founder uncertain, working under a working name like "Linear-Clone"), write the placeholder in Identity AND mark it clearly: `**Working name:** Linear-Clone (placeholder, never shipped; final name decided at step 5 brand-book § Product Name)`. This explicit marker is the **consumer contract for step 5 and step 7**:
  - Step 5 brand-book § Product Name owns the final name commit (with shortlist + decision rationale).
  - Step 7 prototype-v2 § 5.4 owns the downstream rename across every screen + `direction-final.html` (brand-mark in topnav, page `<title>`, sidebar/footer, CLI commands, workspace URL prefix). The step-7 v2 dogfood (2026-05-15) surfaced this as a real silent-failure when the placeholder discipline was implicit: 4/9 screens leaked the placeholder despite the page title being correct. The explicit `placeholder, never shipped` marker triggers step 7's rename pass.
- **Anti-pattern: silent placeholder.** "Octant" or "ClassifyAI" written without marking, but the founder hasn't actually committed — step 5/7 inherit a name they don't know is conditional. The downstream rename only fires if the placeholder is explicitly tagged.

See [[consumer-contract-discipline]] for the cross-step pattern; this clause is the producer-side enforcement at step 1.

### 6. Deep dive (the concept brief)

Read `references/concept-brief-template.md` for the full output shape. The brief covers:

- Identity (name, tagline, scale, model, AI-nativity, comparables)
- Hook / Retain / Refer (with month 1 / 3 / 6 / 12 retention progression)
- Target persona(s) — who, pain today, budget, where they hang out, search trigger
- Mechanics breakdown (3 layers: Core Value / Growth / Moat)
- User flow (first visit < 2 min to value / first week / power user month 3+)
- Growth loop (text diagram + growth type + estimated viral coefficient)
- Monetization sketch (plan table + ARPU + expansion revenue)
- Business model (revenue rationale + unit economics estimates marked as such + GTM + key metrics)
- Technical sketch (only the make-or-break decisions, NOT full architecture — that's step 9)
- Competitive positioning (vs. 2-3 named competitors + "why now")
- Risks (severity + mitigation per row)
- Anti-goals (what this product must NEVER become — guardrails)
- Moat analysis (per moat type: how it works here + strength over time)
- Distribution (first 100 users + launch calendar + validation metric)
- Elevator pitch test (2 sentences)
- JTBD statement (when / I want to / so I can)

May run 3-5 additional targeted searches to validate specific claims in the brief (competitor pricing, market size, regulatory landscape).

Score the brief against the quality rubric (in `references/checklist.md`):

| Category | Weight |
|---|---|
| Market signal strength | 25 |
| Concept originality | 20 |
| Hook-Retain-Refer clarity | 15 |
| Unit economics plausibility | 15 |
| Honest risk assessment | 15 |
| Source coverage | 10 |

Aim ≥ 70/100 before submitting.

### 7. Submit

Call `product_step_submit` with:
- `filename: "04-concept-brief.md"`
- `content: <full brief>`

The schema enforces presence of required sections + min_size of ~12 KB (a real brief lands at 15-25 KB). On schema-incomplete, the failure list names exactly which sections are missing.

After submit, call `product_advance` — no human-checkpoint required for step 1 (the conversation itself was the checkpoint). The next step is step 2 (prototype), which is a visual step with its own Layer 3 checkpoint discipline.

---

## Voice & rigor

- Never fabricate data. If a number isn't sourced, say "Estimated" and explain the basis.
- Name every concept memorably. "AI for accountants" is not a name; "ClassifyAI" or "TaxOracle" is.
- Be honest about risks. The Risks section that hand-waves is the section that kills the product post-launch.
- Estimates are hypotheses to test, not targets to hit. Mark them.
- Competitor data must be factual — funding rounds, public pricing, named features. Never invent revenue or user counts.
- Critique mode is adversarial. Pinned does NOT get protected scoring. If a challenger wins, say so.

## Market Sizing (NEW per spec 045 Decision 6 — extends Discovery phase)

The concept brief MUST include an `## Market Sizing` H2 section with TAM / SAM / SOM estimates (one paragraph each). At standard tier:

- **TAM (Total Addressable Market):** the universe of potential customers if everyone in the world used this category of product. Top-down: industry analyst report (Gartner / Forrester / IDC / Statista). 1 paragraph + citation.
- **SAM (Serviceable Addressable Market):** subset reachable by THIS product's geography + language + segment. Top-down: filter TAM by reachable subset. 1 paragraph + citation OR explicit derivation from TAM.
- **SOM (Serviceable Obtainable Market):** realistic v1 customer count in 1-3 years given founder's resources. Bottom-up: founder's pipeline / waitlist / outbound capacity × conversion. 1 paragraph + hedged ("estimated; based on...").

**Discipline:** desk research, NOT primary research. 1-2 cited sources per number. NEVER invent numbers — if no source exists for a number, say "Estimated; based on <basis>" and explain. Worst case (zero sources): write "[Estimated — no public source found; 1-paragraph derivation from cost of building x competitor TAM y]".

This section is the lightweight upstream signal a heavier pipeline would dedicate a full step to (TAM/SAM/SOM market sizing). Standard tier folds it into ideation as 3 paragraphs.

## What this step does NOT do

- High-fidelity visual prototype. Step 2 (prototype lo-fi) renders 1 mood direction + 3-5 killer-flow HTML screens.
- Functional spec (edge cases, validation rules). Step 3 (spec).
- User testing. Step 4 (ux-testing) validates the prototype with real users (tested mode) or articulates intuition (intuition mode).
- PRD 1-pager / OST / sitemap / system-design / legal / roadmap / cost / GTM. Specification phase, steps 5-12.
- Brand voice / design system. Steps 13 / 14 in the Identity phase (moved after Specification per spec 045 PRD-first ordering).
- Comprehensive screen atlas. Step 15 (screen-atlas) synthesizes the full surface.

## What this step replaces

Anthill's `anthill-product-ideator` skill (435 LOC SKILL + ~1074 LOC references = 1509 LOC total) ran 6 internal sub-steps with file-per-substep persistence under `docs/sdlc/01-ideation/<slug>/`. Our MCP collapses those sub-steps into the conversation; only the final concept brief lands as an artifact. Resumability is handled by `product_status` + `.state.json`, not by parsing sub-step file presence. The COMPANY.md update + handoff manifest (anthill steps 5-6) are absorbed by `product_advance` → step 2 + later `product_done` → `/sdd new <slug>`.
