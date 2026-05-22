# Step 12 — GTM-launch schema

## Output file

`<out>/docs/gtm-launch.md`

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `gtm-launch.md` | 4 KB | below this the canvas is too thin or the launch plan misses weeks |

A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Required H2 sections (in order)

1. `## Positioning Canvas`
2. `## Launch Plan`
3. `## Pricing Strategy`
4. `## Open Decisions`

## Positioning Canvas — 5 lines required

```
**For:** <target customer>
**Who:** <problem statement, user voice>
**We are:** <category> that <differentiator>
**Unlike:** <primary alternative>
**Our product:** <value vs alternative>
```

All 5 lines required. Missing line = sub-agent re-emit.

## Launch Plan — 4 weeks required

Each week:
- 1-3 deliverables (concrete artifacts)
- 1 measurement line (what we observe)
- User-flow shaped title (NOT generic labels like "Outreach")

## Pricing Strategy

Either tier table (free/standard/pro shape if relevant) OR explicit "no tiers v1 — single price $X/mo". Pricing model declaration required: `flat-rate | usage-based | per-seat | freemium | trial`.

## Open Decisions

Table: Decision | Default | Flip if. 2-4 rows minimum.

## Compliance discipline

Refuse claims like:
- "GDPR-compliant" → use "designed for GDPR"
- "SOC 2 certified" → use "SOC 2 readiness in progress"
- "HIPAA-compliant" → use "HIPAA-eligible architecture"

Unless Step 09 legal posture confirms those certifications are actually in place at launch.

## Validation rules (parent-side)

1. All 4 H2 sections present
2. Positioning Canvas has 5 lines
3. Launch Plan has exactly 4 weeks
4. Each week has 1-3 deliverables + 1 measurement
5. Pricing Strategy declares tier shape OR single-price
6. Open Decisions has 2-4 rows
7. File size ≥ 4 KB (anti-stub floor — no ceiling; scope is the quality judge's call)

## Cross-references

- `prompt.md` — full sub-agent brief
- `.claude/skills/product/references/pipeline-coverage.md` § Step 12
