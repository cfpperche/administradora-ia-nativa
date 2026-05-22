# Step 6 — Token Naming Convention

The naming discipline that keeps `tokens.css` durable across rebrands and consumable by step 7 + step 13.

## The two-layer model: primitives vs semantics

**Primitive tokens** carry raw values. They have visual names that describe what they ARE.

```css
:root {
  --primitive-grey-50:  #fafafa;
  --primitive-grey-500: #737373;
  --primitive-grey-900: #1f1f1f;
  --primitive-blue-500: #2563eb;
  --primitive-blue-700: #1d4ed8;
}
```

**Semantic tokens** carry references (or values) that describe what they MEAN. Consuming code reads only semantic tokens.

```css
:root {
  --color-foreground:           var(--primitive-grey-900);
  --color-foreground-secondary: var(--primitive-grey-500);
  --color-primary:              var(--primitive-blue-500);
  --color-primary-hover:        var(--primitive-blue-700);
}
```

A rebrand changes `--primitive-blue-500` from `#2563eb` to `#16a34a` — every consuming surface still reads `--color-primary` and gets the new value. Without the primitive layer, you grep-and-replace hex codes across the codebase.

**For small v1 systems (≤ 14 colors total), primitive layer is optional.** When every primitive is consumed by exactly one semantic, the indirection is dead code. Ship semantic-only tokens with comments:

```css
:root {
  --color-foreground: oklch(0.97 0.002 240); /* primary text — cool off-white, not warm */
  --color-primary:    oklch(0.65 0.150 200); /* the only on-signal */
}
```

When the system grows past ~14 colors or starts repeating values across tokens, refactor to two layers.

## Naming structure: `--<category>-<role>-<state>`

The convention anthill mandated and the port keeps.

- **`--<category>-<role>`** — base name. e.g. `--color-primary`, `--color-foreground`, `--color-border`, `--space-md`, `--radius-lg`, `--font-display`, `--text-base`.
- **`--<category>-<role>-<state>`** — interactive variants. e.g. `--color-primary-hover`, `--color-primary-active`, `--color-primary-disabled`, `--color-foreground-muted`.

States: `hover`, `active`, `focus`, `disabled`, `selected`, `pressed`. Use only the states the component actually has.

For typography:

- `--font-<role>` — family stack. `--font-display`, `--font-body`, `--font-mono`. Each value is a full font stack with fallbacks: `'Geist Mono', ui-monospace, 'JetBrains Mono', 'Fira Code', monospace`.
- `--text-<scale>` — size + line-height + weight as a tuple per scale step. Convention: shorthand via separate tokens for the three components, OR Tailwind-style stacked vars.

```css
:root {
  --font-body: 'Inter', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;

  /* size · line-height · weight per scale step */
  --text-xs:    0.75rem;   --text-xs-lh:    1.0rem;   --text-xs-fw:    400;
  --text-sm:    0.875rem;  --text-sm-lh:    1.25rem;  --text-sm-fw:    400;
  --text-base:  1rem;      --text-base-lh:  1.5rem;   --text-base-fw:  400;
  --text-lg:    1.125rem;  --text-lg-lh:    1.75rem;  --text-lg-fw:    500;
  --text-xl:    1.25rem;   --text-xl-lh:    1.75rem;  --text-xl-fw:    500;
  --text-2xl:   1.5rem;    --text-2xl-lh:   2rem;     --text-2xl-fw:   600;
  --text-3xl:   1.875rem;  --text-3xl-lh:   2.25rem;  --text-3xl-fw:   600;
  --text-4xl:   2.25rem;   --text-4xl-lh:   2.5rem;   --text-4xl-fw:   700;
}
```

For spacing — derive from the density base:

```css
:root {
  /* compact density (4 px base) */
  --space-1:  0.25rem;  /* 4 px */
  --space-2:  0.5rem;   /* 8 px */
  --space-3:  0.75rem;  /* 12 px */
  --space-4:  1rem;     /* 16 px */
  --space-6:  1.5rem;   /* 24 px */
  --space-8:  2rem;     /* 32 px */
  --space-12: 3rem;     /* 48 px */
  --space-16: 4rem;     /* 64 px */
}
```

Numeric tokens (`--space-1`, `--space-2`) OR semantic (`--space-tight`, `--space-default`) — pick one and stick. Numeric is more flexible; semantic forces hard choices about what each space "means". For most v1 systems, numeric wins.

For radius:

```css
:root {
  --radius-none: 0;
  --radius-sm:   2px;     /* tight, brutalist */
  --radius-md:   6px;     /* comfortable, B2B SaaS default */
  --radius-lg:   12px;    /* friendly, consumer app */
  --radius-full: 9999px;  /* pill / circle */
}
```

Cap at 4 values total. Radii > 4 means visual direction is unsettled.

## Anti-naming

These name shapes are wrong:

- `--blue` (no category, no role) — what is it? primary? accent? a literal blue?
- `--color-blue` (visual, not semantic) — what happens when the brand pivots to green?
- `--spacing-medium` (`spacing` not `space`; categories should be consistent and short)
- `--btn-primary-bg` (component-scoped tokens at the design-system layer) — components consume tokens, they don't define new ones. If the Button needs a unique color, name it `--color-primary` and let the Button consume it.
- `--text-h1` (semantic-by-component) — `--text-4xl` + the component decides which size is `H1`. Visual scale at the token layer; component mapping at the consuming surface.

## Catalog vs custom token names

When path is `catalog`, the borrowed system's DESIGN.md may use different naming conventions (e.g. Tailwind's `--color-primary-500` vs anthill's `--color-primary` + `--color-primary-hover`). Pick one for the project and convert on import — don't ship a `tokens.css` that mixes two conventions. Document the conversion in `## Catalog Lineage` ("borrowed Composio's color values; renamed to semantic-only convention because Composio's `-500` scale is not used elsewhere in this product").

## Token comments — what they should say

Every token gets a comment. The pattern:

```css
--<name>: <value>; /* <role description> — <where used / contract> */
```

Examples:

```css
--color-primary:              oklch(0.65 0.150 200);  /* the single on-signal — CTAs, links, focus rings */
--color-foreground-tertiary:  oklch(0.55 0.010 240);  /* metadata text — must pass 4.5:1 body floor */
--space-3:                    0.75rem;                /* compact density — tight padding inside cards */
--radius-sm:                  2px;                    /* brutalist hairline — never softer */
```

When the value comes from a step-4 audit fix, prepend the finding ID:

```css
--color-foreground-tertiary: oklch(0.55 0.010 240); /* fix(F-07/F-09): brightened from 0.50 → 0.55 to lift contrast 3.89→5.10:1 on surface */
```

Comments are the audit trail. A `tokens.css` without them is just numbers; with them, it's a system.
