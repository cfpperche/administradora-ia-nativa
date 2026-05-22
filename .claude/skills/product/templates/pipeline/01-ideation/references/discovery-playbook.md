# Discovery Playbook — Finding Product Opportunities

Structured web research methodology for the discovery sub-stage of ideation. Run 15-25 searches across 5 tracks before generating concepts. Findings consolidate into an Opportunity Map; concepts in the next sub-stage map back to at least one opportunity node.

Ported from anthill `anthill-product-ideator/references/discovery-playbook.md`. Unchanged except minor wording — methodology is content-only and travels intact.

---

## OST Overlay — Define the outcome first

Before running any searches, anchor the research to a desired user outcome:

**Define the outcome:** What is the user ultimately trying to achieve? State it as: "Users want to [outcome]."

As you work through the 5 tracks, map each finding to an OPPORTUNITY in an outcome tree:

```
Desired Outcome
├── Opportunity 1 (barrier or enabler from Market Signals)
├── Opportunity 2 (unmet need from Pain Points)
├── Opportunity 3 (gap from Competitive White Space)
├── Opportunity 4 (new capability from Platform & API)
└── Opportunity 5 (cross-industry pattern from Adjacent Inspiration)
```

Use this tree to organize ideation after the Opportunity Map is complete. Concepts should map back to at least one opportunity node.

---

## Track 1 — Market Signals (5-7 searches)

What's growing, what's dying, what's changing.

```
Queries:
  "[domain] market size [year]"
  "[domain] trends [year]"
  "[domain] SaaS funding crunchbase"
  "[domain] problems reddit"
  "[domain] changing regulations [year]"
  "fastest growing SaaS categories [year]"
  "YC request for startups [year]"

Extract:
  - Market size + growth rate (CAGR)
  - Key trends (3-5 with supporting data)
  - Recent funding signals (who raised, how much)
  - Regulatory tailwinds or headwinds
  - YC/VC thesis overlap (what smart money is funding)
```

## Track 2 — Pain Points (5-7 searches)

What real users complain about in current tools.

```
Queries:
  "site:reddit.com [domain] software frustrating"
  "site:reddit.com best [domain] tool alternative"
  "[domain] software review complaints G2"
  "[existing tool] alternative why switch"
  "[domain] spreadsheet workaround" (people using sheets = tool gap)
  "[domain] manual process automate"

Extract:
  - Top 5-10 pain points ranked by frequency
  - Specific quotes (paraphrased) showing emotional intensity
  - "I wish [tool] could..." patterns
  - Workarounds people use (spreadsheets, multiple tools stitched together)
  - Personas behind the complaints (who's complaining, what role, what size company)
```

> **JTBD Lens:** For each significant pain point extracted, format it as a job statement:
> "When [situation/trigger], I want to [motivation/job], so I can [desired outcome]."
>
> Example: "When I receive a vendor invoice in a format my accounting tool can't parse, I want the data extracted automatically, so I can close the month without manual re-entry."
>
> Capturing the situation and motivation — not just the pain — reveals what product experience needs to be designed.

## Track 3 — Competitive White Space (3-5 searches)

Where are the gaps in existing solutions.

```
Queries:
  "G2 [domain] software grid"
  "[domain] tools comparison [year]"
  "[main competitor] vs competitors"
  "[domain] no good solution for [niche]"
  "site:producthunt.com [domain]" (find what launched, see comments)

Extract:
  - Market map: who serves whom (draw the grid)
  - Underserved segments (too small for big players, too complex for simple tools)
  - Price gaps (expensive enterprise tools, nothing for SMB)
  - Feature gaps (everyone does X, nobody does Y)
  - Geographic gaps (tools for US, nothing for LATAM/APAC)
```

## Track 4 — Platform & API Opportunities (2-3 searches)

New APIs, platforms, or technologies enabling new products.

```
Queries:
  "[platform] new API [year]"
  "[platform] developer ecosystem"
  "new AI capabilities [domain] [year]"
  "[platform] marketplace opportunity"

Extract:
  - New APIs that unlock product categories
  - Platform changes creating needs (e.g., new regulations, deprecated features)
  - AI capabilities that make previously-impossible products viable
  - Marketplace gaps (app stores, plugin ecosystems underserved)
```

## Track 5 — Adjacent Inspiration (2-3 searches)

What works in OTHER industries that could apply here.

```
Queries:
  "AI [adjacent domain] SaaS success"
  "[mechanic from mechanics-catalog] applied to [domain]"
  "boring industry SaaS high growth"
  "vertical AI [year] examples"

Extract:
  - Cross-industry patterns that haven't been applied to this domain
  - Boring industries with high willingness to pay
  - Mechanics from consumer apps applicable to B2B
```

---

## Opportunity Map Format

Present findings to the user BEFORE ideating. Structure:

```markdown
## Opportunity Map: [Domain]

### Market Snapshot
- Size: $X (growing Y%/year)
- Key players: [list 5-8]
- Recent funding: [notable rounds]

### Top Pain Points (from real users)
1. "[paraphrased complaint]" — frequency: HIGH — who: [persona]
2. ...
3. ...

### Jobs Identified
- Job 1: "When [situation], I want to [motivation], so I can [outcome]."
- Job 2: "When [situation], I want to [motivation], so I can [outcome]."
- Job 3: ...

### White Space (gaps nobody fills)
- Gap 1: [description] — potential: [high/medium/low]
- Gap 2: ...

### Platform Opportunities
- [API/platform] enables [new product category]
- [AI capability] makes [previously impossible thing] viable

### Trends Favoring New Entrants
- Trend 1: [description + data]
- Trend 2: ...

### Adjacent Inspiration
- [Product in other industry] → applicable pattern: [what]

### Signals Summary
[Strong] [what's clearly working]
[Emerging] [what's growing but unproven]
[Avoid] [what's saturated or declining]
```

Ask the user: "Based on this map, which gaps/signals interest you most?" before proceeding to concept generation.

---

## Critique-mode scoping

When the agent is in critique mode (user arrived with a pinned concept), queries narrow to the pinned concept's market rather than open domain exploration. Same 5 tracks, different query shape.

### What changes

**Track 1 — Market Signals:** replace generic domain queries with queries specific to the pinned concept's audience + category.
- Generic: `"[domain] market size [year]"`
- Critique: `"[pinned-concept-category] pricing tiers [year]"`, `"[pinned-audience] willingness to pay for [pinned-category]"`

**Track 2 — Pain Points:** target pain points that the pinned concept claims to solve. If the claimed pain is thin in the data, that's a critical finding.
- Critique: `"site:reddit.com [pinned-audience] frustrated with [status-quo-alternative]"`, `"[pinned-category] alternative missing feature"`

**Track 3 — Competitive White Space:** **most important track in critique mode.** Map all players who serve the pinned audience with any overlap. Find both direct competitors and adjacent incumbents who could expand.
- Critique: `"[pinned-audience] tool comparison"`, `"[pinned-category] competitor landscape [year]"`, `"[main-known-competitor] vs alternatives"`, `"[pinned-category] YC startup"`

**Track 4 — Platform & API Opportunities:** check for platform shifts that either validate or threaten the pinned concept.
- Critique: `"[pinned-platform-dependency] API changes [year]"`, `"[pinned-platform] deprecation"`

**Track 5 — Adjacent Inspiration:** find what other industries do for similar jobs; source challenger angles.
- Critique: `"how does [adjacent-category] solve [pinned-JTBD]"`, `"[pinned-category] equivalent in [adjacent-industry]"`

### Query count

If the market is niche and a track yields thin results after 2-3 queries, **cap the track** rather than padding with off-topic searches. Total still targets 15-25 but distribution is concentrated in Tracks 2-3 (pain + competitive) where critique-mode value is highest.

### Output addition

Append a **Pinned Concept Validation** section to the Opportunity Map, after Signals Summary:

```markdown
### Pinned Concept Validation

**Pinned:** <one-liner from direction>

**Findings supporting pinned:**
- [source] — [how it supports]
- ...

**Findings exposing risks to pinned:**
- [source] — [what risk it exposes]
- ...

**Unanswered questions the discovery could not resolve:**
- [question] — implication for the concept
- ...
```

This section feeds challenger generation + adversarial ranking rationale.
