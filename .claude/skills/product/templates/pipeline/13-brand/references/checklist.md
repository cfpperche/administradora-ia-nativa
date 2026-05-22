# Step 5 — Brand Checklist

Run before submitting `brand-book.md`. Items map to schema sections + prompt rigor; if a row fails, fix before `product_step_submit`.

## Required structure

- [ ] Header line `**Version:** X.Y | **Date:** YYYY-MM-DD` present at the top
- [ ] `## Voice` section — 1–2 paragraphs, concrete adjectives + examples in practice (not "modern, friendly, professional")
- [ ] `## Voice Samples` section — 3 minimum (single-tool) / 5–7 ceiling (multi-surface platform); each sample is *actual copy* the brand would emit on a *real* surface
- [ ] `## We Are / We Are Not` section — minimum 3 paired bullets in `**We are** X. **We are not** <near-adjacent-Y>.` shape (the contrast is the discipline)
- [ ] `## Visual Direction` section — paragraph naming the visual *feel* (e.g. "Cool Brutalist") + locked posture decisions (typography family, imagery posture). NO hex codes, NO type scale.
- [ ] `## Logo Direction` section with three sub-sections:
  - [ ] `### Clear Space` — in logo units (e.g. `1× the logo's x-height on every side`)
  - [ ] `### Minimum Size` — directional figures (px digital + mm print)
  - [ ] `### Prohibited Uses` — ≥ 3 explicit, each concrete (not "don't misuse it")
- [ ] `## Color Story` section — color *names* + *feelings*. NO hex codes (those are step 6).
- [ ] `## Anti-Patterns` section — 3–5 concrete bullets describing what the brand should NEVER sound like

## Founder voice fidelity

- [ ] Founder's verbatim phrasing quoted at least once where it was sharp (interviews flatten through translation)
- [ ] Voice samples avoid brand-strategy filler ("empower teams", "achieve goals", "unleash potential")
- [ ] Where founder vision and target audience tension exists, it's named explicitly + a posture is chosen (not papered over)

## Boundary discipline (preserved between step 5 and step 6)

- [ ] No hex codes anywhere in the artifact
- [ ] No typography scale (no `48px / 56px line-height` etc)
- [ ] No token files (no `tokens.css`, no `--color-*` variables)
- [ ] Visual direction *named* (e.g. "Cool Brutalist") but not *specified* (the spec is step 6's job)

## Sub-agent dispatch hygiene (when synthesis is delegated)

- [ ] Founder interview transcript inlined in the sub-agent's CONTEXT field OR written to a temp file referenced from CONTEXT
- [ ] Sub-agent given access to all 5 references (`anti-patterns`, `examples`, `prompt-bank`, `logo-direction-template`, `checklist`)
- [ ] Sub-agent's output reviewed by the parent BEFORE submit (the synthesis is a writing task; the parent owns the quality gate)
