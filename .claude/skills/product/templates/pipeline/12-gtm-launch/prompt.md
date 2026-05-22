---
mode: synthesis
delegable: true
delegation_hint: "produce gtm-launch.md — April Dunford positioning canvas (5 lines: For / Who / We are / Unlike / Our product) + 4-week launch plan sketch (week-by-week milestones) + pricing strategy (tier shape if relevant); 4-7 KB hard ceiling; reads PRD + concept-brief + roadmap + legal-posture; fully delegable from prior artifacts"
---

# Step 12 — GTM-launch (positioning + launch + pricing)

**Goal:** produce `<out>/docs/gtm-launch.md` — a tight positioning canvas (April Dunford methodology) + 4-week launch plan sketch + pricing strategy. Stage-Gate stage 6 equivalent at standard tier per spec 045 Decision 7 (ported from spec 032). Closes Phase 2 (Specification) — gate fires after this step.

**Mode:** `synthesis` with `delegable: true`. Sub-agent reads prior artifacts and produces the canvas + launch plan + pricing strategy mechanically.

## Output

| File | Role | Floor | Ceiling |
|---|---|---|---|
| `<out>/docs/gtm-launch.md` | positioning canvas + 4-week launch plan + pricing strategy | 4 KB | 7 KB |

## Inputs (read first)

- `<out>/docs/prd/v1.md` § NSM + § User stories — target customer + value prop signal
- `<out>/docs/concept-brief.md` § Competitive positioning + § Monetization + § Growth loop — alternatives + tier hints
- `<out>/docs/roadmap.md` § Phase 1 — launch timing aligns with Phase 1 close (MVP ready milestone)
- `<out>/docs/legal-posture.md` § Regulated Aspects + § Privacy Posture — compliance signals affect launch claims (no "GDPR-compliant" claims without DPA in place; no "SOC 2 certified" without actual audit)
- Reference reading: April Dunford, [*Obviously Awesome*](https://www.aprildunford.com/obviously-awesome) (positioning canvas methodology)

## Required structure (H2 sections in this order)

```markdown
# GTM-launch — <product name>

_Positioning canvas per April Dunford, Obviously Awesome (aprildunford.com)._

## Positioning Canvas

**For:** <target customer persona — verbatim or refined from PRD audience>
**Who:** <problem statement — what they're trying to do; user voice>
**We are:** <product category> that <unique differentiator>
**Unlike:** <primary alternative — competitor OR status quo OR DIY hand-rolled>
**Our product:** <primary value vs that alternative>

## Launch Plan

(4-week sketch — week-by-week milestones with 1-3 deliverables + measurement per week)

### Week 1 — <user-flow shaped title>
- Deliverable: <concrete artifact>
- Deliverable: <concrete artifact>
- Measurement: <what we observe to know it worked>

### Week 2 — <title>
- Deliverable: ...
- Measurement: ...

### Week 3 — <title>
- Deliverable: ...
- Measurement: ...

### Week 4 — <title>
- Deliverable: ...
- Measurement: ...

## Pricing Strategy

(tier shape if relevant — references concept-brief monetization tiers)

| Tier | Price | Audience | Includes |
|---|---|---|---|
| <name> | <price> | <who> | <what> |
| ... | ... | ... | ... |

**Pricing model:** <flat-rate | usage-based | per-seat | freemium | trial>
**Decision:** <one paragraph explaining the model choice — e.g. "Per-seat $19 Team / $39 Business because audit-log is per-developer signal; usage-based on hook events would create misaligned incentive">

## Open Decisions

(2-4 decisions still pending — ship vN questions)

| Decision | Default | Flip if |
|---|---|---|
| ... | ... | ... |
```

## Constraints

- 4-7 KB hard ceiling.
- All 4 H2 sections present in order: Positioning Canvas / Launch Plan / Pricing Strategy / Open Decisions.
- Positioning Canvas has all 5 lines (For / Who / We are / Unlike / Our product).
- Launch Plan has exactly 4 weeks (week-by-week milestones; titles are user-flow shaped NOT generic labels like "Outreach").
- Each week has 1-3 deliverables + 1 measurement line.
- Pricing Strategy declares tier shape OR explicit "no tiers v1 — single price $X/mo".
- "Unlike" line names the PRIMARY alternative (often the status quo / DIY / hand-rolled approach for early markets).
- Compliance discipline: NO "GDPR-compliant" / "SOC 2 certified" / "HIPAA-compliant" claims unless Step 09 legal posture confirms those are actually in place at launch. Default: claims are POSTURE ("designed for GDPR" / "SOC 2 readiness in progress"), not certifications.
- Attribution header: "Positioning canvas per April Dunford, Obviously Awesome (aprildunford.com)."

## SKIP at standard tier

- Full launch playbook (PR / influencer / SEO / paid acquisition / content calendar) — post-PMF concern
- Funnel modeling (conversion rates, CAC/LTV) — insufficient data at v1
- Multi-segment positioning (one canvas per persona) — standard tier targets the primary persona only
- Competitor matrix (one row per competitor with feature comparison) — concept-brief already covers competitive positioning

## Why this step matters

Stage-Gate stage 6 (commercialization) is industry-mandatory but routinely skipped in startup playbooks ("we'll figure out launch when we get there"). The cost of skipping: cost-estimate at Step 11 doesn't budget for launch activities; roadmap at Step 10 doesn't carve out Phase 1 close for launch readiness; brand book at Step 13 doesn't know the positioning voice to lean into. By making GTM a deliberate step BEFORE Identity phase, the brand voice (Step 13) can REINFORCE the positioning (Step 12), not contradict it.

## Cross-references

- `.claude/skills/product/references/delegation-briefs.md` § Step 12 — full sub-agent brief
- `.claude/skills/product/references/pipeline-coverage.md` § Step 12 — size targets + lightening
- `docs/specs/032-pipeline-industry-alignment/spec.md` § Decision 7 — original industry rationale (Stage-Gate stage 6 + Asana 9-step GTM + HubSpot + PMA citations)
