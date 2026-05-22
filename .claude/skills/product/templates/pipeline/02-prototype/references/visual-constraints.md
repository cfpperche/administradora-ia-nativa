# Visual constraints — density, structure, presets

Structural guardrails for direction HTML files + Turn 2 screens. Apply regardless of the chosen direction's family. These are the floors that prevent any direction from drifting into illegibility or AI-slop layout patterns.

## Density table

| Screen type | Max metric cards | Max table columns | Max nav items | Max form fields per group | Max groups | Max chart widgets | Max tabs |
|-------------|------------------|-------------------|---------------|---------------------------|------------|-------------------|----------|
| Dashboard | 6 per row, 12 total | 8 | 8 sidebar items | — | — | 4 | 4 |
| Form | — | — | — | 6 | 3 | — | — |
| Settings | — | — | — | 8 per section | — | — | 5 |
| List / Table | 4 summary cards | 10 | 6 | — | — | 2 (sparklines) | 4 |
| Detail view | 6 stats | — | — | 8 per section | — | 2 | 4 |
| Landing | — | — | 5-7 top nav | 4 (signup form) | — | — | — |
| Auth / Login | — | — | — | 4 | 1 | — | — |

If a screen type is not in this table, use the closest match. If no match, apply the Dashboard limits as default.

## Structural CSS rules

Stack-agnostic — apply to every direction file and every Turn 2 screen.

### Layout

- Container: `max-width: 1280px`, centered, horizontal padding `1-1.5rem`
- Section spacing: `1.5-3rem` vertical gap between major sections
- Card grid: CSS grid or flexbox with `minmax(280px, 1fr)` pattern (stack equivalent on mobile)
- **No fixed widths on containers** — `max-width` + percentage/auto only

### Typography

- Maximum 3 heading levels used per screen (page title / section title / card title)
- Body text: `0.875-1rem` (14-16 px)
- Never below `0.875rem` (14 px) for any readable text
- Use `rem` units, not `px` (except for borders and hairlines)
- Tabular numerics on prices / counts / timestamps: `font-variant-numeric: tabular-nums`

### Color

- 1 primary accent color · 1 neutral scale (the grays) · 1 semantic set (success / warning / error)
- No more than 5 distinct hues total per screen
- Text on background: ≥ 4.5:1 contrast ratio (WCAG AA)
- All colors in `hsl()` or `oklch()` — no bare hex, no `rgb()`

### Responsiveness

- Minimum 2 breakpoints: mobile (< 768 px) and desktop (≥ 768 px)
- Recommended 3: mobile (< 768 px), tablet (768-1023 px), desktop (≥ 1024 px)
- Multi-column layouts stack to single column on mobile
- Touch targets ≥ 44×44 px on mobile

### Spacing

- Grid / flex `gap` for card spacing (not margin)
- Section vertical padding: `1.5-3rem`
- Card internal padding: `1-1.5rem`
- Consistent spacing scale (don't mix arbitrary values)

### Interactions

- CSS-only animations unless JS interactions are explicitly part of the direction (rare)
- Hover states on all clickable elements
- Focus states on all interactive elements (a11y floor — see `a11y-checklist.md`)
- Empty states for every list / table — what it looks like with 0 items

## Conditional style presets (HTML-only, no DESIGN.md)

Activate ONLY when no project design system is detected (no DESIGN.md at repo root or `docs/DESIGN.md`). When a DESIGN.md exists, IGNORE these presets — use the project's tokens (see `design-fidelity-checklist.md`).

| Preset | Font | Accent | Background | Border style | Density |
|--------|------|--------|------------|--------------|---------|
| **Clean** | system-ui | `oklch(63% 0.18 250)` (blue-500) | white + `oklch(98% 0.005 250)` alternating | none, shadow-sm cards | Medium |
| **Corporate** | Georgia (display) + system-ui (body) | `oklch(28% 0.08 240)` (navy) | white | 1px solid `oklch(90% 0.005 240)` | Low |
| **Dashboard** | system-ui | `oklch(58% 0.20 280)` (indigo-500) | `oklch(15% 0.02 250)` header + white body | none, `oklch(25% 0.02 250)` dividers | High |
| **Minimal** | system-ui (light weights) | `oklch(15% 0 0)` (near-black) | white | thin 1px `oklch(92% 0 0)` | Very low |
| **Technical** | monospace (display + data) + system-ui (body) | `oklch(62% 0.13 200)` (cyan-500) | `oklch(15% 0.02 250)` dark sections + `oklch(96% 0.005 250)` light | none | High |

Each preset defines visual personality. When generating HTML with a preset, apply its values consistently across all sections — don't mix presets within a single direction.

These presets are TEMPLATES, not direction families. A direction inspired by Linear lands in `Minimal`-flavored tokens but with a Linear-specific accent — not the literal Minimal preset. Use presets as the fallback when the brief gives no anchor.

## CSS verification checklist

After generating a direction HTML, every item must pass before emit:

- [ ] No horizontal overflow at 375 px viewport width
- [ ] No text smaller than 14 px (`0.875rem`)
- [ ] No fixed widths on containers (use `max-width` + percentage/auto)
- [ ] All images / charts have explicit `aspect-ratio` or height constraint
- [ ] Section vertical padding between `1.5rem` and `3rem`
- [ ] Color contrast: text on background ≥ 4.5:1 (WCAG AA)
- [ ] No more than 3 font-size levels used
- [ ] Grid / flex `gap` used instead of `margin` for card spacing
- [ ] Interactive elements ≥ 44×44 px touch target
- [ ] No inline styles exceeding 3 properties (extract to class / variable)
- [ ] `:root` declares all 6 palette tokens; every color reference uses `var(--token)` not a literal value
- [ ] Tabular numerics on prices / counts (`font-variant-numeric: tabular-nums`)
