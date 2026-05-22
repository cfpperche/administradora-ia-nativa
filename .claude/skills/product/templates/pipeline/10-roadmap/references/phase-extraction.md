# Phase extraction — bridge-mode heuristics (PRD priority tiers → Phase 1 / 2 / 3)

How to detect priority tiers in a PRD and group stories into Phase 1 / Phase 2 / Phase 3 when operating in bridge mode (PRD `validation_mode: intuition` or `not-applicable`). Conservative by design: when priority tagging is ambiguous, REFUSE with hint rather than guess.

## When this applies

Bridge mode activates when:

- PRD frontmatter declares `validation_mode: intuition` or `validation_mode: not-applicable`
- The founder explicitly invokes bridge mode (e.g. "use bridge — I haven't validated enough for a timeline")

Bridge mode is the priority-extraction path; the canonical timeline-aware path (`validation_mode: tested` or absent) does NOT use this file.

## General rule — PRD is source of truth

The PRD is the source of truth for priorities. The bridge **consolidates** priority ordering — it does NOT re-prioritize. If a story has no detectable priority tier, the bridge MUST refuse and ask the founder to add tagging — silently bucketing untagged stories is worse than halting.

## Priority-tier detection (in priority order of preference)

### Tier 1 — Explicit P0 / P1 / P2 markers

Look for in PRD body, in this order:

1. Story bullet prefixes: `- [P0]`, `- [P1]`, `- [P2]` or `- (P0)`, `- (P1)`, `- (P2)`
2. Story headings: `## P0 — Story Name`, `### [P0] Feature Name`
3. Frontmatter per-story field: `priority: P0` (in PRD's structured `stories:` block)
4. Inline tag: `Priority: P0` on the same line as story title
5. PRD User Story IDs prefixed by priority: `US-01 [P0]`, `US-14 [P1]` (step 8 PRD convention if present)

**Mapping:** P0 → Phase 1 (MVP), P1 → Phase 2 (Growth), P2 → Phase 3 (Optimization).

### Tier 2 — MVP / Growth / Post-launch markers

When P-tier markers are absent, accept these equivalents:

| Phase 1 (MVP) | Phase 2 (Growth) | Phase 3 (Post-launch) |
|---|---|---|
| `[MVP]` | `[GROWTH]` | `[POST-LAUNCH]` |
| `Must-have` | `Should-have` | `Could-have` |
| `Phase 1` | `Phase 2` | `Phase 3` |
| `v1` / `v1.0` | `v1.1` / `v2` | `v2+` / `Future` |
| `Critical` | `Important` | `Nice-to-have` |

Match case-insensitively. Pick the FIRST tier-system found in the PRD; do NOT mix tier systems within a single PRD.

### Tier 3 — MoSCoW

`Must / Should / Could / Won't` — same mapping as the table above. `Won't` stories are EXCLUDED from the roadmap (they are explicit non-goals; note them in the Source-of-truth paragraph but do not include in any phase).

### Tier 4 — Section-based grouping

If the PRD has explicit `## MVP`, `## Growth`, `## Post-launch` sections (or equivalents — `## v1`, `## v1.1`, `## v2+`), all stories under each section inherit that section's priority. Sections override per-story tags if both are present (rare).

## When NO priority tagging is detected

The bridge MUST refuse. Do NOT:

- Bucket all stories into Phase 1 silently
- Use story order in the PRD as a proxy for priority
- Use story length / detail as a proxy for priority
- Apply heuristics like "first 3 stories = MVP"
- Default to "all stories = P0" silently

Instead, emit via `product_step_submit` validation error:

```json
{
  "code": "schema-incomplete",
  "missing_or_invalid": [
    "PRD has no priority tiers (P0/P1/P2 or equivalent) on stories. Add priority tagging before /11-roadmap. See references/phase-extraction.md § Priority-tier detection for accepted markers."
  ]
}
```

## Story extraction

Within a phase, extract each story as one bulleted line:

- Story title (everything after the priority marker, up to first sentence period)
- If story has explicit one-line summary, use it
- If story is structured (As a... I want... so that...), use the "I want..." clause as the line
- Where US-NN IDs exist, prefix the bullet: `**US-07** — keyboard-first triage walks end-to-end with `j/k/x/y` shortcuts`

### Example PRD input

```markdown
- US-01 [P0] User can sign up with email — receives verification link, lands on dashboard
- ## P1 — US-15 — Project workspace
  As a user I want a project workspace so that I can organize my credits
- (P2) US-23 — Custom branding — paid tier only, ships post-launch
```

### Bridge output (Phase 1 + Phase 2 + Phase 3 sections)

```markdown
## Phase 1 — MVP

**Stories (P0):**
- **US-01** — User can sign up with email — receives verification link, lands on dashboard

**Goal:** <extracted from PRD's MVP definition / problem statement>

**Success criteria:** <extracted from PRD's success metrics for P0; if absent, emit "Defined at /anthill-delivery-plan time">

**Estimated duration:** TBD pre-delivery-plan

## Phase 2 — Growth

**Stories (P1):**
- **US-15** — I want a project workspace so that I can organize my credits

**Goal:** <extracted; growth/expansion theme>

**Trigger to start:** Phase 1 success criteria met + <any PRD-defined gate for Phase 2>

**Estimated duration:** TBD post-Phase-1

## Phase 3 — Optimization / Post-launch

**Stories (P2):**
- **US-23** — Custom branding — paid tier only, ships post-launch

**Goal:** <extracted; optimization / non-critical improvements>

**Trigger to start:** Phase 2 stability + <PRD post-launch markers if any>
```

## Empty phases — still emit

If a PRD has only P0 + P1 stories (no P2), the Phase 3 section is still emitted with:

```markdown
## Phase 3 — Optimization / Post-launch

*No stories at this priority tier — Phase 3 will be re-evaluated post-Phase 2 stability based on user feedback and metrics.*
```

This preserves the three-phase shape downstream consumers expect from bridge-mode roadmaps. Empty phases are valid; they document "the founder has not yet identified P2 stories".

## Goal extraction (per phase)

Look for:

1. PRD section explicitly titled `## Goals` with sub-bullets per priority tier
2. PRD section `## MVP Definition`, `## Phase 2 Goals`, etc.
3. PRD prose paragraphs starting with `Phase 1 goal:`, `MVP goal:`, etc.

If goal cannot be extracted, emit:

```markdown
**Goal:** <not declared in PRD — define at /anthill-delivery-plan time>
```

## Success-criteria extraction (per phase)

Look for:

1. PRD section `## Success Metrics` with per-tier breakdown
2. PRD section `## KPIs` or `## North Star Metric`
3. Inline `Success criteria:` lines within story bodies

If absent for Phase 1 (MVP), emit:

```markdown
**Success criteria:** <not declared in PRD — define at /anthill-delivery-plan time>
```

For Phase 2 / Phase 3, success criteria are usually post-launch (telemetry-driven). Emit:

```markdown
**Success criteria:** Re-evaluated post-Phase 1 launch with telemetry data.
```

## Duration — never inferred

Look for explicit `target_date:`, `Estimated duration:`, `Sprint count:`, or `Weeks:` markers in PRD. If none:

```markdown
**Estimated duration:** TBD pre-delivery-plan
```

The bridge does NOT estimate durations — only `/anthill-delivery-plan` (Step 13 future) and the canonical timeline-aware path (§ 4 in prompt.md) compute timelines.

## Sentinel block — idempotent regeneration

All bridge-generated content sits between sentinels:

```markdown
<!-- anthill:bridge:begin -->

## Phase 1 — MVP
... (generated content)

## Phase 3 — Optimization / Post-launch
... (generated content)

## Dependencies
... (generated content)

<!-- anthill:bridge:end -->
```

On re-run:

1. Re-read the existing `roadmap.md` (if it exists)
2. Regenerate ONLY content between sentinels
3. Preserve content OUTSIDE sentinels verbatim (manual founder edits: durations once Phase 1 ships, post-incident notes, executive narrative)
4. Atomic write via mktemp+rename

This idempotency is the discipline that makes bridge mode safe to re-run as the founder updates priorities in the PRD.

## Dependencies extraction

For each phase, scan PRD stories at that priority tier for inline `depends on X` or `requires Y` markers. Aggregate into the Dependencies section as cross-phase notes:

```markdown
- Cross-phase: Phase 2 story "Custom workspace" depends on Phase 1 story "Project workspace"
```

If no explicit deps in PRD, the standard phase-to-phase gates suffice:

```markdown
- Phase 2 depends on Phase 1 success criteria being met
- Phase 3 depends on Phase 2 stability (no Sev-1 incidents within first 30 days post-launch — adjust threshold by product class)
```

## Anti-patterns the discipline catches

- **Inferring priority from story order:** First 3 stories ≠ MVP. Refuse and ask for tagging.
- **Mixing tier systems:** Don't accept some P0/P1 + some MVP/growth in the same PRD; pick one consistently per the PRD's actual usage.
- **Dropping `Won't` stories silently:** Note them in the Source-of-truth paragraph; do not include in any phase.
- **Inventing durations:** No date heuristics. If the PRD doesn't say "8 weeks", the bridge doesn't either.
- **Reshuffling priorities:** If P0 has 22 stories and the founder wanted 10 in MVP, the bridge does NOT re-bucket — that's a PRD edit, not a bridge concern.
- **Skipping the sentinel block:** Without sentinels, re-runs overwrite manual founder edits. Always wrap.

## When the PRD is sparse on priority tagging

If only ~30% of stories have priority tiers, the bridge refuses with the priority-tag halt. The founder has three paths:

1. Augment the PRD with priority tags (preferred — keeps source-of-truth in one place)
2. Re-run step 8 PRD with priority tagging interactively
3. Promote `validation_mode` to `tested` and run the canonical timeline-aware path (when complexity justifies)

The bridge's job is to honestly reflect tagged priorities, not to rescue an underspecified PRD.

## When to upgrade from bridge to canonical mode

Replace the bridge block (regenerate from canonical timeline-aware mode) when ANY of:

- Phase 2 starts and timeline forecasting matters (capacity planning, hiring decisions)
- `validation_mode` shifts to `tested` for a major feature
- External stakeholders (investors, partners) need a public roadmap
- Multi-team coordination requires Gantt-style dependencies
- Compliance / regulatory milestones need explicit dating

The upgrade path: edit PRD frontmatter to `validation_mode: tested`, re-run step 11. The canonical mode regenerates the full timeline-aware roadmap; the sentinel block falls away (canonical mode does not use sentinels — the whole file is canonical-managed content).
