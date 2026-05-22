# Step 6 — Section Floor + Per-Product-Class Extensions

The schema enforces 6 required sections (`Overview`, `Tokens`, `Components`, `Patterns`, `Accessibility Floor`, `Audit Response`) plus `Catalog Lineage` when path is `catalog` / `mixed`. **These are the floor — every design-system.md has them.**

Some product classes earn additional sections that wouldn't be filler. Read the concept brief to decide which extensions apply; don't ship a section the product doesn't need.

## Always required (the floor — schema-enforced)

- `## Overview` — visual direction + density + path declaration
- `## Tokens` — narrative + per-category tables (Color, Typography, Spacing, Radius, Shadow-or-omission)
- `## Components` — pointer to `components.md` + 1-paragraph philosophy
- `## Patterns` — 4–6 named composed structures
- `## Accessibility Floor` — WCAG AA + focus + keyboard + semantic-element contract
- `## Audit Response` — applied fixes from step 4 frontmatter, OR explicit empty-state line

## Required-when-applicable (schema-enforced via path declaration)

- `## Catalog Lineage` — when path is `catalog` or `mixed`. Anchored systems + verbatim borrowings + deviations.

## Per-product-class extensions (judgment — not schema-enforced)

### Mobile / consumer apps

- `## Touch Targets` — minimum 44×44 px tap target, spacing rules between adjacent touch zones, tap-feedback duration. WCAG 2.5.8 floor (24×24 minimum) + the 44×44 platform convention.
- `## Motion` — durations + easing curves. Mobile expects more motion than dev tools (state changes feel mechanical without it). 2–3 durations (`instant 150ms`, `quick 250ms`, `expressive 400ms`) + 1–2 easing curves.
- `## Iconography` — icon style + primary source. Mobile UIs are icon-dense; without a documented system, the screen-atlas step ships inconsistent icons.

### Marketing sites / luxury / editorial

- `## Imagery` — photo style (subject matter, mood, color treatment, what to avoid) + illustration posture (when to use, when not). For brands where imagery is part of the product, this is required.
- `## Motion` — narrative-driven animations (scroll-revealed, hover-revealed, page-transition). Often *spacious* densities pair with deliberate motion as part of the brand experience.
- `## Type Specimens` — display-weight specimens of the heading typeface(s) at 96 px / 64 px / 48 px. Marketing surfaces are typography-led; specimens prevent step-7 from picking the wrong weight at the wrong scale.

### Data-dense dashboards / dev tools / terminal-aesthetic products

- `## Density Profiles` — when the product ships compact + comfortable scales together (a SaaS whose marketing surface is editorial but whose product surface is dashboard-dense). Document the boundary rule: which scale lives on which surface, and how navigation between them feels.
- `## Tabular Data Patterns` — row height, column padding, sort-indicator placement, alternating-row treatment (or explicit "no zebra striping" if the brand-book rejected it). Tables are the killer surface in this product class.
- `## Keyboard Shortcuts` — global shortcuts table + per-component keyboard contracts. The brand voice may already be "keyboard-first" — the design system makes that concrete.

### CLI / API tools

- `## Terminal Adaptations` — how the heuristic adaptations from step-4 ux-testing land in the system. Most "components" in CLI tools are output-formatting rules (table padding, error-message structure, help-text discoverability). Document those instead of UI components.
- Drop `## Components` per-component blocks for visual primitives that don't apply (no Modal, no Toast, no NavBar). Replace with `## Output Patterns` covering the emission shape per command type.

### B2B SaaS (the no-extension default)

The 6 required sections + Catalog Lineage when applicable cover B2B SaaS without extension. Don't over-add — adding `## Imagery` to a tool whose imagery posture is "the product UI is the imagery" produces filler.

## How to use this floor

1. Start with the 6 required sections (always there).
2. Read concept brief § persona + § product class signals.
3. Add 0–3 extensions from the matching product-class block above.
4. Justify each extension in the sub-agent's report-back: why this product needed Touch Targets / Imagery / Density Profiles / etc.
5. If considering a 4th+ extension, push back on yourself — the design system is leaner the better; over-extending produces a documentation maze.

The schema enforces presence of the 6 required + applies the Catalog Lineage rule via the path declaration. Extensions are judgment calls; the checklist confirms they earn their place.
