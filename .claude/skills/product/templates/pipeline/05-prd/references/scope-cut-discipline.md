# Scope-cut discipline — must-have vs should-have vs nice-to-have vs Backlog

The hardest part of writing a PRD is the cut. Founders default to "everything is must-have" because everything feels important. This reference is the discipline for forcing real cuts during the parent's § 2 interview.

## The 4-tier model

| Tier | Definition | Engineering signal |
|---|---|---|
| **P0 — Must Have** | v1 is broken without it. Killing this requirement kills the v1 thesis. | If P0 slips, launch slips. |
| **P1 — Should Have** | v1 is weaker but viable without it. Ships if budget allows; doesn't gate launch. | If P1 slips, ship anyway. |
| **P2 — Nice to Have** | v1 is materially the same without it. Optional polish; clearly post-launch. | If P2 slips, may not even be missed. |
| **Backlog** | Out of v1 scope. May re-enter v1.5 / v2 / future. | Documented for traceability; not in the v1 plan. |

The order matters. P2 is NOT a P1 with low effort; P2 is a polish item that the founder is comfortable shipping without. If the founder hesitates at "ship without it?", it's P1, not P2.

## The forcing function — "What if we cut this?"

For every candidate P0, ask: **"If we cut this from v1, does the v1 thesis still hold?"**

- **Thesis still holds, but feels weaker** → P1 (Should Have)
- **Thesis still holds, no real change** → P2 (Nice to Have) or Backlog
- **Thesis dies / no one would migrate** → genuine P0
- **Founder hesitates, can't articulate** → red flag; the thesis isn't sharp; pause and re-articulate the thesis before continuing the cut

This is the question that exposes scope inflation. Founders who say "everything is must-have" haven't done the forcing function; the parent's job is to make them do it once per candidate.

## When "should-have" is the cowardly version of "no"

A common founder failure mode: routing items to P1 because saying "no for v1" feels too aggressive. Symptom: P1 grows to 15-20 items. Reality: a 15-item P1 list is almost entirely Backlog with optimism.

Rule of thumb: **P1 should be 3-7 items** for a typical SMB SaaS v1. Larger P1 lists are usually 50%+ Backlog masquerading as "Should Have". Walk the founder back through each P1 item asking: **"Is this in v1.0 if we hit our launch date, or is this v1.1?"** v1.1 = Backlog.

The "should-have" tier exists for items that genuinely COULD slip without killing the launch. If the founder says "yes ship without it" → P1 is correct. If they say "I really want this in v1.0" → it's a P0 in denial, not a P1.

## P2 cap discipline

P2 (Nice to Have) caps at **3-5 items** in the anti-patterns guidance for a reason: P2 bloat is where Backlog items get optimistically promoted because "they're small". Engineering's discovery later: the 5 small P2s collectively cost more than 2 P1s did. Force the cap.

If the candidate P2 list runs 10+ items, walk through with the founder:
- Items that are genuinely small + visible win → keep up to 5 in P2
- Items that are small but not visible → Backlog
- Items that aren't small → P1 demotion candidates (which kicks them back to the forcing function)

## When P0 grows beyond 10 items

For SMB SaaS v1, **P0 > 10 items is a structural red flag**. Two responses:

1. **Some P0s are actually P1.** Re-run the forcing function. Almost always, 2-4 of the "P0" items are actually "feel important but the thesis survives without them".
2. **The v1 is genuinely big.** Then split v1 into v1.0 and v1.1 with an explicit milestone, and rewrite the PRD's Goals + Success Metric to match v1.0's scope.

A 15-item P0 PRD ships at half-quality on twice the timeline. The cut discipline exists to prevent that.

## When the founder pushes back on cutting

The interview at `prompt.md § 2` is the right place for pushback. If the founder insists "all 15 of these are must-have", reframe:

- **"Pick the 5 that, if absent, kill the v1 thesis."** Now you have P0.
- **"Of the remaining 10, which 5 would you ship v1.0 without if launch date were tomorrow?"** Now you have P2 / Backlog candidates.
- **"The other 5 are P1 — they ship if engineering has budget."** Calibrated and explicit.

This is uncomfortable but it's the parent's job. A PRD that captures the founder's wish-list verbatim doesn't survive engineering reality; the cut is part of the PRD's value-add.

## Step-4 audit findings — where they route

Step 4 audit findings tagged `fix_skill_hint: "deferred"` typically route to Backlog with `Source: step 4 F-NN`. Examples:

- F-15 (`prefers-reduced-motion` wrap) → Backlog (`Cosmetic, AAA-only; v1 motion is minimal`)
- F-08 (touch-target review on mobile) → Backlog (`v1 is desktop-first per Non-Goals; mobile is courtesy`)
- F-04 (multi-language support flag) → Backlog (`v1 is English-only; i18n is v2`)

Findings tagged `fix_skill_hint: "design-system"` or `"prototype-v2"` are already actioned at step 6/7; they land in Backlog with `Source: step 4 F-NN (resolved at step 6)` so the audit trail is end-to-end visible from PRD reading.

## Source column traceability

Every requirement (P0/P1/P2/Backlog) names its origin in the Source column. Routing:

- **`US-NN`** — user-story origin (same PRD)
- **`spec § <name>`** — step 3 functional-spec section
- **`prototype-v2 screens/<NN>-<name>.html`** — step 7 screen filename (verifiable via `file://` open)
- **`step 4 F-NN`** — step 4 audit finding ID. Sub-finding IDs (`F-NNa`, `F-NNb`, ...) preserve the original audit's hierarchy when one finding has multiple parts — cite them verbatim, never renumber. Example: `step 4 F-05a` cites the "import-log signpost" sub-finding of F-05.
- **`founder · <YYYY-MM-DD>`** — captured during step 8 interview, with date
- **`Goal #N`** — derived from the Goals section position (counted top-to-bottom; first bullet = `Goal #1`). Goals are bulleted prose by default; `#N` numbering is implicit-by-position, materialized only in `Source` citations. Reordering Goals after PRD-ship requires re-numbering all `Goal #N` citations — same stability discipline as the US-NN append-don't-renumber rule.

A requirement without a Source is invented mid-PRD. The discipline isn't a stylistic preference — it's the audit trail that lets a later reader (or step 13's coverage scoring) verify the PRD wasn't padded with wish-list items.

## The end-state shape

A well-cut SMB SaaS v1 PRD typically lands:

- P0: 5-10 items, each with 2-4 BDD scenarios
- P1: 3-7 items
- P2: 3-5 items
- Backlog: 5-15 items (most from step 4 deferred + post-v1 spec questions)
- Success metric: ONE primary + 2-4 observability
- US-NN: 10-20 user stories with stable IDs
- Non-Goals: 3-5 explicit cuts

Smaller scopes (micro-products, focused features) calibrate down per `prompt.md § 6`. Larger scopes (marketplace, multi-persona) calibrate up. The 4-tier model + the forcing function are stack-agnostic.
