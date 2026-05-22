# Step 1 — Schema (concept brief)

The submitted concept brief MUST contain level-2 markdown headings (`## <Title>`) for the required sections below + meet the Layer 1 size/content floor in the JSON fenced block. Both checks fire on `product_step_submit`; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list.

## Required sections (markdown headings)

Each name slugifies by lowercasing + dashing — `## Target Persona(s)` → `target-persona-s` matches `target-persona` (we accept trailing-s as cosmetic). The agent should match these slugs precisely.

- hook
- retain
- refer
- target-persona
- mechanics-breakdown
- user-flow
- growth-loop
- monetization-sketch
- business-model
- technical-sketch
- competitive-positioning
- risks
- anti-goals
- moat-analysis
- distribution
- elevator-pitch
- jtbd-statement

Identity block (name, tagline, scale, model, AI-nativity, comparables) is enforced via `contains` in the Layer 1 block below — it lives in the brief's frontmatter / opening block, not under a slugified H2.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "04-concept-brief.md",
      "min_size": 12288,
      "contains": [
        "**Tagline:**",
        "**Scale:**",
        "**Model:**",
        "**AI-native:**",
        "## Hook",
        "## Retain",
        "## Refer",
        "## Risks",
        "## JTBD"
      ]
    }
  ]
}
```

- `min_size: 12288` (12 KB) — anthill reference briefs land at 15-25 KB. A brief under 12 KB is almost certainly under-developed (likely missing the unit-economics, distribution, or moat-analysis depth).
- `contains` checks the identity-block field labels + key section headings as anchors; section-slug check covers the rest.

## Section content guidance (depth, not just presence)

The schema enforces presence and floor; *depth* is the agent's responsibility. Quality cues per section:

- **identity block (top of brief)** — `Tagline` is one sentence, max 10 words, makes a non-technical reader curious. `Scale` is one of: Micro-Product / SMB / Venture-Scale / Marketplace / Developer Tool / Mobile App. `Model` is one of: Subscription / Usage-based / Hybrid / Service-as-Software. `AI-native` is Yes (remove AI → product can't exist) or No (AI enhances).
- **hook** — why someone signs up. Must fit in a tweet (280 chars).
- **retain** — why they stay past month 3, with a Month 1 / 3 / 6 / 12 progression showing accumulating switching cost.
- **refer** — what specific moment triggers sharing. Concrete: "when they see their report saved them $2K this month" beats "when they have a good experience".
- **target-persona** — 1-3 personas as tables: Who / Pain today / Budget / Where they hang out / Trigger to search.
- **mechanics-breakdown** — 3 layers (Core Value / Growth / Moat) with one paragraph each.
- **user-flow** — three phases (First Visit < 2 min / First Week / Power User month 3+) with 3 bullets each.
- **growth-loop** — text diagram of the loop + growth type (PLG / Viral / Content / Community / Paid / Marketplace) + estimated viral coefficient bucket (<0.5 paid-dependent, 0.5-1.0 organic supplement, >1.0 self-sustaining).
- **monetization-sketch** — plan table (Free / Starter / Pro / Enterprise rows, with price + limits + persona-fit per row) + ARPU + expansion revenue narrative.
- **business-model** — revenue rationale table + unit economics estimates (marked "Estimated", with assumption per row) + GTM phases + key metrics (North Star / Guardrail / Leading).
- **technical-sketch** — only make-or-break decisions (Frontend / Backend / AI / Key integration / Data) + MVP build estimate. NOT a full architecture — that's step 9.
- **competitive-positioning** — vs. 2-3 named competitors table + "Why now" (what changed that makes this timely).
- **risks** — 4-6 rows: Risk / Severity High|Med|Low / Mitigation. Generic risks are wrong; concrete ones are right.
- **anti-goals** — 3-5 bullets of "NOT this — because [why this kills the product]".
- **moat-analysis** — table: Moat type (network / data / integration / brand) × How it works here × Strength over time progression (Weak → Strong markers).
- **distribution** — First 100 Users tactics + Launch Calendar table + Validation Metric (concrete number that proves the concept has legs).
- **elevator-pitch** — exactly 2 sentences. Sentence 1: what it is. Sentence 2: why it matters. If the agent can't write these 2 sentences cleanly, the concept needs simplification — back to ideation.
- **jtbd-statement** — When [trigger], I want to [job], so I can [outcome]. Plus Functional / Emotional / Social job breakdown.

## Sources (citations)

Every factual claim in the brief MUST carry an inline `[N]` citation. The numbered list of sources can live at the end as `## Sources` (not required as a schema slug, but expected). Minimum 10 unique sources for a healthy brief.
