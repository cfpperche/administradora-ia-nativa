# Step 5 — Logo Direction Template

The brand book names logo *posture*, NOT logo *execution*. Execution is a downstream design task informed by this artifact (or a step-6 token + step-7 prototype-v2 motion). The three sub-sections under `## Logo Direction` enforce the discipline that anthill mandated and the deep port keeps:

## `### Clear Space`

The minimum padding around the logo, expressed in **logo units** (so the rule scales with the logo's actual rendered size).

**Common conventions:**

- `1× the logo's x-height on every side` — the standard for wordmarks and lockups; works for most cases
- `1× the cap-height on every side` — slightly tighter; appropriate when the logo has a distinct mark + wordmark and the wordmark's cap-height is the natural rhythm unit
- `0.5× the logo's container width` — for small icon marks (favicons, app icons) where x-height is too tight

**What to write in the brand book:**

```markdown
### Clear Space

`1× the logo's x-height` on every side. No other content — text, imagery, UI chrome — may
encroach this zone. The clear space scales with the logo: at 24 px the clear space is
~6 px; at 96 px the clear space is ~24 px.
```

## `### Minimum Size`

Directional figures, NOT exact tokens. The exact pixel + millimeter values emerge in step 6 when the logo is actually drawn and the legibility floor is measured against the typeface.

**Common conventions:**

- Digital: `24 px` for icon marks, `120 px` for full lockups (wordmark + mark)
- Print: `12 mm` for icon marks, `40 mm` for full lockups
- Embroidery / physical: `25 mm` floor for any mark with internal detail

**What to write in the brand book:**

```markdown
### Minimum Size

- **Digital:** `24 px` (icon mark) / `120 px` (lockup) — below this, the wordmark
  collapses and the mark loses its internal contour.
- **Print:** `12 mm` (icon mark) / `40 mm` (lockup) — below this, ink-spread on
  uncoated stock destroys the negative-space rhythm.
- **Embroidery:** `25 mm` minimum, regardless of mark or lockup.

These are directional floors — the exact pixel/mm values get pinned in step 6 once
the logo is drawn against the chosen typeface.
```

## `### Prohibited Uses`

Minimum **3** explicit prohibitions, each concrete and visually describable. "Don't misuse it" is not a prohibition.

**Categories to consider** (pick the 3 that matter most for the product):

- **Color violations** — "never recolored outside the brand palette", "never inverted to white-on-pure-black", "never gradient-filled"
- **Geometric violations** — "never distorted/stretched (uniform scaling only)", "never rotated past 0°/90°/180°/270°", "never outlined or stroked"
- **Background violations** — "never on busy photographic backgrounds without a contrast scrim", "never on backgrounds matching the logo's primary color (1:1 contrast = invisible)", "never inside a container with rounded corners that would fight the logo's geometry"
- **Composition violations** — "never paired with a tagline shorter than 3 words (visual imbalance)", "never used as a watermark with opacity below 30%", "never combined with another brand mark within the clear-space zone"

**What to write in the brand book:**

```markdown
### Prohibited Uses

1. **Never on busy photographic backgrounds** without a 60-opacity black or white
   contrast scrim behind the logo.
2. **Never distorted or stretched** — uniform scaling only. Aspect ratio is locked.
3. **Never recolored** outside the brand palette. The mark is allowed only in
   `--ink-primary`, `--surface-inverted`, or pure white on dark backgrounds.
4. **Never below the minimum size** — when the available space is below the digital
   floor, omit the logo entirely rather than render it illegibly.
```

## Why these three sub-sections (and not more)

`Clear Space` + `Minimum Size` + `Prohibited Uses` is the smallest set that prevents the most common logo regressions. Anthill's checklist mandates `clear space`, `minimum size`, `approved backgrounds`, and `prohibited uses`. The deep port consolidates "approved backgrounds" into the prohibited-uses list (one of the prohibitions is *background violations*) — same coverage, one fewer sub-section to enforce.

If the product genuinely needs more (e.g. enterprise products that ship logo to partners' marketing materials may need an `### Approved Color Variants` sub-section), add it under `## Logo Direction` as a fourth sub-section. The schema enforces presence of the three; nothing prevents a fourth.

## What this template does NOT do

- **Logo design.** This template captures posture (clear space, min size, prohibited uses); the actual logo geometry, weight, and finish are downstream design work informed by this artifact.
- **Token specification.** Hex values for the logo's colorways, exact size rules with breakpoints, animation specs — those are step 6 / step 7 deliverables.
- **Asset production.** SVG / PNG / favicon generation is the design + engineering team's downstream responsibility.
