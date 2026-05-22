# Step 6 — Design System Examples

Concrete shapes for `tokens.css` + `design-system.md` § Tokens table + `components.md` per-component blocks. Use as writing templates, not copy-paste sources — the values are product-specific.

---

## Example 1 — `tokens.css` (compact density, brutalist direction, custom path)

```css
/*
 * Octant — design tokens
 * Path: custom (synthesised from brand-book § Cool Brutalist)
 * Density: compact (4 px base) — dev-tool product class
 *
 * Step 4 audit findings applied: F-07 + F-09 (contrast lift), F-06 (disabled-state)
 */

:root {
  /* ── Color · canvas + surface (4 levels) ────────────────── */
  --color-canvas:        oklch(0.10 0.005 240);  /* page background — cool near-black */
  --color-surface:       oklch(0.14 0.008 240);  /* card surface — one stop lighter */
  --color-surface-2:     oklch(0.18 0.010 240);  /* inset / row hover */
  --color-surface-3:     oklch(0.22 0.012 240);  /* nested inset / focused row */

  /* ── Color · foreground hierarchy (3 levels) ────────────── */
  --color-foreground:           oklch(0.97 0.002 240);  /* primary text — cool off-white */
  --color-foreground-secondary: oklch(0.72 0.010 240);  /* secondary text — meta */
  --color-foreground-tertiary:  oklch(0.55 0.010 240);  /* fix(F-07/F-09): brightened from 0.50 → 5.10:1 on surface */

  /* ── Color · accents (3, role-disciplined) ──────────────── */
  --color-primary:    oklch(0.78 0.18 200);  /* the only on-signal — CTAs, links, focus */
  --color-accent:     oklch(0.62 0.27 350);  /* second-tier — single chart series, status pill */
  --color-success:    oklch(0.78 0.18 145);  /* "open" / "shipped" status — celebration moment */

  /* ── Color · semantic (3, never compete with primary) ──── */
  --color-warning:    oklch(0.75 0.14 75);   /* muted amber */
  --color-danger:     oklch(0.65 0.22 25);   /* warm red */
  --color-info:       var(--color-primary);  /* alias — info uses the on-signal */

  /* ── Color · borders (decorative, NOT state-bearing) ────── */
  --color-border:     oklch(0.28 0.005 240); /* hairline divider */
  --color-border-2:   oklch(0.36 0.005 240); /* slightly stronger separator */

  /* ── Typography ─────────────────────────────────────────── */
  --font-display: 'JetBrains Mono', ui-monospace, monospace;
  --font-body:    'JetBrains Mono', ui-monospace, monospace;  /* mono throughout */
  --font-mono:    'JetBrains Mono', ui-monospace, monospace;  /* alias */

  --text-xs:    0.75rem;   --text-xs-lh:    1rem;       --text-xs-fw:    400;
  --text-sm:    0.875rem;  --text-sm-lh:    1.25rem;    --text-sm-fw:    400;
  --text-base:  1rem;      --text-base-lh:  1.5rem;     --text-base-fw:  400;
  --text-lg:    1.125rem;  --text-lg-lh:    1.625rem;   --text-lg-fw:    500;
  --text-xl:    1.5rem;    --text-xl-lh:    1.875rem;   --text-xl-fw:    500;
  --text-2xl:   2rem;      --text-2xl-lh:   2.375rem;   --text-2xl-fw:   600;

  /* ── Spacing (compact, 4 px base) ───────────────────────── */
  --space-1:  0.25rem;   /* 4 px  — tight icon-text gap */
  --space-2:  0.5rem;    /* 8 px  — default inline gap */
  --space-3:  0.75rem;   /* 12 px — card inner padding */
  --space-4:  1rem;      /* 16 px — section gap */
  --space-6:  1.5rem;    /* 24 px — between-card gap */
  --space-8:  2rem;      /* 32 px — page section break */
  --space-12: 3rem;      /* 48 px — hero / split */
  --space-16: 4rem;      /* 64 px — page top/bottom margin */

  /* ── Radius (brutalist — capped at 2 px) ───────────────── */
  --radius-none: 0;
  --radius-sm:   2px;     /* the only non-zero radius — cards, buttons, inputs */

  /* ── Shadow ─────────────────────────────────────────────── */
  /* no shadow tokens — brutalist direction is hairline-only */

  /* ── Focus ring (audit-response F-01 — defined here, applied in step 7) ── */
  --focus-ring: 0 0 0 2px var(--color-primary);
  --focus-ring-offset: 2px;
}
```

---

## Example 2 — `design-system.md` § Tokens table

```markdown
## Tokens

The token layer that step 15 (screen-atlas; absorbed step 7 per spec 045) and step 15 (screen-atlas; renamed per spec 045) read from `tokens.css`. Names are semantic; primitives are inlined (this v1 has no need for the primitive layer — see `references/token-naming.md` § "two-layer model").

### Color (14 total)

| Token | Value | Where used |
|---|---|---|
| `--color-canvas` | `oklch(0.10 0.005 240)` | page background; the void from which everything emerges |
| `--color-surface` | `oklch(0.14 0.008 240)` | card surface; row default; modal background |
| `--color-surface-2` | `oklch(0.18 0.010 240)` | inset region; row hover; sidebar collapsed state |
| `--color-surface-3` | `oklch(0.22 0.012 240)` | nested inset; focused row; popover background |
| `--color-foreground` | `oklch(0.97 0.002 240)` | primary text; headings; body copy |
| `--color-foreground-secondary` | `oklch(0.72 0.010 240)` | secondary text; meta labels; non-essential UI text |
| `--color-foreground-tertiary` | `oklch(0.55 0.010 240)` | tertiary metadata; sidebar group headers; settings field labels (F-07/F-09 fix applied) |
| `--color-primary` | `oklch(0.78 0.18 200)` | the only "on" signal — CTAs, links, focus rings, brand mark |
| `--color-accent` | `oklch(0.62 0.27 350)` | second-tier — single chart series, status pills, ≤ 1× per surface |
| `--color-success` | `oklch(0.78 0.18 145)` | "shipped" / "open" status — the one celebration moment |
| `--color-warning` | `oklch(0.75 0.14 75)` | muted amber — system warnings |
| `--color-danger` | `oklch(0.65 0.22 25)` | warm red — destructive actions, error states |
| `--color-border` | `oklch(0.28 0.005 240)` | hairline dividers; card borders |
| `--color-border-2` | `oklch(0.36 0.005 240)` | stronger separator — major section breaks |

### Typography (3 families × 6 sizes = 18 tokens)

[same shape — Family table + Size table with where-used column]

### Spacing (8 steps, compact density)

[same shape — Step table with where-used column]

### Radius (2 values total — brutalist)

| Token | Value | Where used |
|---|---|---|
| `--radius-none` | `0` | tables, dividers, hard-edged elements |
| `--radius-sm` | `2px` | the only non-zero radius — buttons, inputs, cards, modals |

### Shadow (intentionally omitted)

The brutalist direction is hairline-only; depth is conveyed via border weight and surface lightness, not shadow. `tokens.css` documents the omission inline.
```

---

## Example 3 — `components.md` per-component block

```markdown
## Button

Primary interactive primitive — initiates an action.

**Anatomy:** `[icon-leading]? [label] [icon-trailing]?`

**Variants:**
- `primary` — the load-bearing CTA. Cyan fill, near-black text. One per surface.
- `secondary` — neutral action. Surface-colored fill, hairline border, foreground text.
- `ghost` — minimal action. Transparent fill, foreground text, hover reveals surface-2 fill.
- `destructive` — irreversible action. Danger fill, foreground text. Always paired with confirmation pattern.

**States:**
- `default` — the base style per variant
- `hover` — fill brightens 10%, no scale change (brutalist — no motion)
- `active` — fill brightens 5%, no scale change
- `focus` — `--focus-ring` applied (2px primary outline + 2px offset)
- `disabled` — opacity 0.6, no hover/active response (F-06 fix applied)
- `loading` — text replaced by mono spinner glyph; click suppressed

**Tokens consumed:**
- Color: `--color-primary` (primary fill), `--color-canvas` (primary text on fill), `--color-surface-2` (ghost hover), `--color-danger` (destructive fill), `--color-border` (secondary border)
- Spacing: `--space-2` (vertical padding), `--space-3` (horizontal padding), `--space-1` (icon gap)
- Type: `--text-sm`, `--text-sm-fw: 500`
- Radius: `--radius-sm`
- Focus: `--focus-ring`, `--focus-ring-offset`
```

---

## Example 4 — Bad token names (rejected)

```css
/* ❌ visual names — what happens when the brand pivots? */
--color-blue-500: #2563eb;
--color-orange-warm: #fb923c;

/* ❌ component-scoped at the design-system layer */
--btn-primary-bg: #2563eb;
--card-padding: 1rem;

/* ❌ no category */
--blue: #2563eb;

/* ❌ semantic-by-component (the component decides which scale = H1) */
--text-h1: 2.25rem;
--text-h2: 1.875rem;
```

```css
/* ✅ semantic, category-prefixed, generalizable */
--color-primary: #2563eb;
--space-md: 1rem;
--text-4xl: 2.25rem;
```
