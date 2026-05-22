# Pre-emit gate — direction-file checklist + 5-dim critique

Two gates fire before `product_step_submit`:
1. **Per-direction structural checklist** — every direction file (a/b/c) must pass every item
2. **Per-direction 5-dim critique** — score 1-5 on each dim; any dim < 3/5 requires a fix pass

Run both. Document the second in `REPORT.md § 5-Dim Critique Pre-Emit Scores`.

---

## Per-direction structural checklist

Every direction-{a,b,c}.html must pass every item below before the 5-dim critique runs:

- [ ] All required sections from `prompt.md § 4` are represented (header, palette strip, type sample, hero, dashboard sample, personality footer)
- [ ] Mock data is realistic (not placeholder text) — brief-sourced product name, persona names, real metric labels
- [ ] Layout is mobile-responsive (test mentally at 375 px and 1440 px)
- [ ] Visual hierarchy is clear (headings, spacing, contrast)
- [ ] No external dependencies (fully self-contained file — no CDN scripts, no remote fonts beyond system fallback)
- [ ] Semantic HTML used (`<nav>`, `<main>`, `<section>`, `<article>`, `<figure>`)
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] Code is syntactically valid (run through a validator if uncertain)
- [ ] File opens directly in a browser without console errors
- [ ] Component structure matches the brief's data model
- [ ] Density limits from `visual-constraints.md` § "Density table" are respected
- [ ] CSS verification checklist from `visual-constraints.md` § "CSS verification" passes
- [ ] All 5 items from `a11y-checklist.md` pre-emit verification pass
- [ ] If DESIGN.md exists at repo root: `design-fidelity-checklist.md` fully passes for the DESIGN.md-aligned direction
- [ ] No item from `anti-patterns.md` § "Anti-AI-slop P0 gate" is present (this is the BLOCK gate — fix before continuing)

---

## 5-dim critique — per direction

Score each dimension 1-5. Any dimension < 3/5 requires a fix pass before emit. Two fix passes is normal.

- [ ] **Philosophy (1-5):** Visual posture matches what was asked (editorial / minimal / tech-utility / brutalist / warm-soft). Did the direction drift back to a generic default mid-build? A 5 = the direction makes a statement true to its school. A 3 = the direction is competent but unmemorable. Below 3 = the direction wandered.

- [ ] **Hierarchy (1-5):** One obvious focal point per screen. Nothing competing equally for attention. A 5 = the reader's eye lands exactly where the brief's primary CTA wants it. A 3 = focal point is correct but not prominent enough to dominate. Below 3 = two CTAs competing or no clear focal point.

- [ ] **Execution (1-5):** Typography, spacing, alignment, contrast are correct — not approximately right. Tabular numerics on prices/counts. Tokens used consistently throughout. A 5 = no visible alignment / spacing / token inconsistency. A 3 = one or two minor inconsistencies (e.g., one card uses `gap: 1.5rem`, another uses `gap: 24px`). Below 3 = multiple token violations or visible misalignment.

- [ ] **Specificity (1-5):** Every word, number, label is specific to THIS brief. Zero filler copy ("Feature One", lorem ipsum, invented metrics). PT-BR copy if product is Brazilian. A 5 = a reader could identify the brief from the copy alone. A 3 = mostly brief-sourced but one or two generic phrases slipped in. Below 3 = pervasive filler / unsourced metrics.

- [ ] **Restraint (1-5):** One accent used at most twice per screen. One decisive flourish (a serif display, a hairline border, a colored chip — pick one). Not three competing flourishes. A 5 = the direction commits to one move and lets it carry. A 3 = restraint mostly holds but one element competes. Below 3 = multiple competing visual moves.

**Scoring threshold:** all dims ≥ 3/5 to emit.

**Two fix passes are normal.** When a direction scores 2/5 on Specificity, the fix is to rewrite the offending copy section with brief-sourced phrases — not to lower the bar.

---

## Anti-AI-slop P0 gate (re-verify before emit)

Read `anti-patterns.md` for full rules. Quick reference table — every box must be ✓:

- [ ] No aggressive purple / violet gradient backgrounds
- [ ] No generic emoji feature icons (✨ 🚀 🎯 as decoration)
- [ ] No rounded card with left coloured border accent as default layout
- [ ] No hand-drawn SVG humans / faces / scenery
- [ ] Inter / Roboto / Arial used as body text only — never as display face
- [ ] No invented metrics without a source from the brief
- [ ] No filler copy — zero lorem ipsum, "Feature One / Two", vague benefit bullets
- [ ] No motivational copy for user states (PT-BR: "campeão", "você consegue"; EN: "you got this", "crush your goals")
- [ ] (BR fintech) Pix QR Code prominent in payment surfaces
- [ ] (BR fintech) LGPD footer link present
- [ ] (Token economy) Cost badge on action buttons (`X · N🪙`); saldo visible in header

---

## When a direction fails the gate

If a direction scores < 3 on any dim, or trips an anti-slop rule:

1. Note the specific failure ("Direction B Specificity 2/5 — hero copy uses 'all-in-one platform' generic")
2. Fix that direction (rewrite copy, swap palette, adjust hierarchy)
3. Re-run the 5-dim critique on the fixed direction (only that direction — others don't need re-scoring unless they were also fixed)
4. Document the fix pass in REPORT.md's critique notes (e.g., "Direction B initial Specificity 2 → fixed by replacing hero with brief-sourced primitive language → re-scored 4")

Do not lower a score to ≥ 3 without an actual fix. Score inflation breaks the discipline; the next reader of REPORT.md trusts the numbers.

---

## When all directions clear ≥ 3

Proceed to `prompt.md § 7` — write REPORT.md. The 5-dim scores from this checklist are what populate the `## 5-Dim Critique Pre-Emit Scores` section verbatim.
