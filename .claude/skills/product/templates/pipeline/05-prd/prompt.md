---
mode: draft-after-input
delegable: partial
delegation_hint: "draft the PRD 1-pager (Lenny Rachitsky hybrid bones + 3 Steward-specific sections) synthesizing step 01 + step 03 spec + step 04 audit; parent should confirm 2 inputs from founder first (priority cut P0/P1/P2 + NSM declaration); user-story IDs follow US-NN convention (consumed by step 07 sitemap-IA + step 15 atlas for coverage matrices); 4-7 KB hard ceiling — tight 1-pager discipline"
---

# Step 05 — PRD 1-pager (Lenny hybrid per spec 045 Decision 1 + 15)

**Goal:** the canonical product spec as a TIGHT 1-pager — what's in v1, what's out, what success looks like, with **stable user-story IDs (`US-NN`)** that Step 07 (sitemap-IA) maps to routes + Step 15 (screen-atlas) scores coverage against. This document is the CONTRACT downstream phases consume.

Per spec 045 Decision 1 + 15 (ported from spec 032): PRD is reshaped from monolithic spec to **1-pager** following Lenny Rachitsky's template, with **OST sibling** (Step 06) carrying the discovery landscape and **sitemap-IA** (Step 07) carrying the screen inventory. PRD's job is to compress: ONE NSM, ONE primary persona, P0/P1/P2 tiering hard-cut, 5-12 user stories max. If the PRD wants to grow past 7 KB, the work belongs in OST (opportunities) or sitemap (screens), not in PRD.

**Mode:** `draft-after-input` with `delegable: partial`. The parent may confirm two pieces of input that no prior artifact captured deterministically — **feature priority cut** (P0/P1/P2) and **NSM declaration** (the single primary observable). If founder is hands-off, sub-agent infers from prior artifacts + concept-brief's monetization tier + audit's severity findings. Once locked, the document writing delegates.

**Output file:** `<out>/docs/prd/v1.md`. Single-artifact.

## Required structure (H2 sections, EXACT order, Lenny hybrid)

### Lenny Rachitsky 1-pager bones (6 sections)

```markdown
## Problem
<2-3 sentences. User-voice problem statement. Cite Step 03 problem-validation interviews if real signal exists.>

## Why now
<2-3 sentences. What changed in the world / market / tech / regulation that makes this the right moment. Cite Step 01 concept-brief § Market Sizing + § Competitive positioning.>

## Success metrics
**NSM (North Star Metric):** <ONE observable. Format: <leading-indicator> hits <threshold> within <time-window> after <trigger>. E.g. "70% of new teams hit first-Slack-alert within 24 hours of install".>

**Supporting metrics (read-only):**
- <metric 1> — <how observed>
- <metric 2> — <how observed>

## Solution sketch
<2-4 bullets. High-level approach — NOT implementation. E.g. "Drop-in CLI installer wires hooks into .claude/settings.json; PostToolUse(Agent) captures override audit-log entries; Slack bot fires on configurable severity threshold."  Cross-ref to Step 03 functional-spec for surface decomposition.>

## User stories
| US-NN | Priority | Story | Acceptance |
|---|---|---|---|
| US-01 | P0 | As a <persona>, I can <action> so that <outcome> | <Given/When/Then in 1-2 sentences> |
| US-02 | P0 | ... | ... |
| ... | ... | ... | ... |

(5-12 stories total. P0 = must-ship-v1. P1 = should-ship-v1. P2 = nice-to-have-v1. Anything else → Backlog.)

## Anti-goals
<3-5 bullets. What v1 EXPLICITLY refuses to do. Lenny: "anti-goals are how you say no without sounding negative.">
- <anti-goal 1>
- <anti-goal 2>
- ...
```

### 3 Steward-specific sections (per spec 045 Decision 15)

```markdown
## Release scope
<1 paragraph. v1 scope summary in 3 sentences. References anti-goals for what's deferred to v2/vN.>

| Release | Scope summary | Target horizon |
|---|---|---|
| v1 (MVP) | <P0 + P1 stories — the minimum that proves NSM is achievable> | <Step 10 roadmap Phase 1 end> |
| v2 (Growth) | <P2 stories + first-wave Backlog from OST> | <Step 10 roadmap Phase 2 end> |
| vN (deferred) | <out-of-scope from anti-goals> | post-PMF |

## NSM (dedicated slot)
<Same NSM from § Success metrics, but with full operational definition:>
- **What it measures:** <plain-English description>
- **How calculated:** <formula or query — even pseudocode>
- **Where observed:** <product surface OR analytics tool>
- **Threshold for success:** <number + time window>
- **Threshold for concern:** <number that triggers iterate-vs-pivot conversation>

## Upstream/downstream refs
- **Upstream (informs this PRD):** `<out>/docs/concept-brief.md`, `<out>/docs/functional-spec.md`, `<out>/docs/validation-report.md`
- **Downstream (consumes this PRD):**
  - `<out>/docs/ost.md` — OST root = this PRD's NSM
  - `<out>/docs/sitemap.yaml` — every P0/P1 US-NN appears in ≥1 route's `covers_us`
  - `<out>/docs/system-design.md` — system-design references US-NN for scale assumptions
  - `<out>/docs/screen-atlas.md` — atlas coverage matrix lists every US-NN

(NEVER renumber US-NN — Step 07 sitemap.yaml + Step 15 atlas coverage matrix BOTH depend on stable IDs. Append new stories at the end; resolved/deferred stories keep their original ID with status annotation.)
```

## Constraints

- 4-7 KB HARD CEILING. Each section ≤3 bullets to preserve 1-pager honesty.
- All 9 H2 sections present in order: 6 Lenny bones (Problem · Why now · Success metrics · Solution sketch · User stories · Anti-goals) + 3 Steward-specific (Release scope · NSM dedicated slot · Upstream/downstream refs).
- US-NN: zero-padded sequential (US-01, US-02, ..., US-NN). APPEND-don't-renumber discipline.
- ONE NSM (NOT two equal-priority). Supporting metrics optional, read-only.
- P0/P1/P2 tiering — hard cut. Anything not P0/P1/P2 → Anti-goals or implicit (don't mention).
- Cross-references to upstream/downstream files use absolute `<out>/docs/NN-<slug>.<ext>` paths.
- Attribution header: `_PRD shape based on Lenny Rachitsky's 1-pager template (lennysnewsletter.com/p/prds-1-pagers-examples) — hybrid w/ Steward-specific Release scope · NSM · Upstream refs sections per spec 045 Decision 15._`

## What this step does NOT do

- **OST (opportunity discovery)** — Step 06.
- **Sitemap / full screen inventory** — Step 07.
- **System design** — Step 08.
- **Legal posture** — Step 09 (DPIA-triggered by Step 08 data-flow per shift-left).
- **Roadmap with timing** — Step 10.
- **Cost estimate** — Step 11 (per-phase using Step 10 roadmap).
- **GTM positioning + launch + pricing** — Step 12.

## Why 1-pager (not multi-page)

Camp C from spec 032 Decision 1: PRD shrinks to 1-pager, OST sibling carries discovery, prototype hi-fi (Step 15) is the executable spec. Lenny Rachitsky's framing: a 1-pager PRD that fits on one screen forces clarity. A 12-page PRD hides ambiguity. The 4-7 KB ceiling enforces this — over-budget triggers re-emit at smaller scope.

## Cross-references

- `.claude/skills/product/references/delegation-briefs.md` § Step 05 — full sub-agent brief
- `.claude/skills/product/references/pipeline-coverage.md` § Step 05 — size targets + lightening
- `references/prd-format.md` (this step's own reference) — US-NN convention details
- `docs/specs/045-prototype-skill-pipeline-realign/spec.md` § Decision 1 + 15
- `docs/specs/032-pipeline-industry-alignment/spec.md` § Decision 1 + 15 — industry rationale
