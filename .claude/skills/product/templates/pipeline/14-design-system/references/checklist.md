# Step 6 — Design System Checklist

Run before submitting the bundle (`design-system.md` + `tokens.css` + `components.md`, optionally `tokens.json`). Items map to schema sections + prompt rigor; if a row fails, fix before `product_step_submit`.

## Bundle structure

- [ ] `design-system.md` ≥ 12 KB with all 6 required H2 sections (Overview, Tokens, Components, Patterns, Accessibility Floor, Audit Response)
- [ ] `tokens.css` ≥ 1.5 KB with `:root` block carrying `--color-*`, `--font-*`, `--space-*`, `--radius-*` (shadow optional + commented if omitted)
- [ ] `components.md` ≥ 4 KB with at least Button + 5 more components, each block having Anatomy + Variants + States + Tokens consumed
- [ ] `tokens.json` shipped only when a real consumer needs it (Style Dictionary / Tailwind config-gen / Figma variables) — no speculative export

## Path discipline

- [ ] Path declared in `## Overview` is one of: `catalog` / `custom` / `mixed`
- [ ] `## Catalog Lineage` section present when path is `catalog` or `mixed`; absent when path is `custom`
- [ ] Catalog systems named explicitly (no "inspired by various brutalist systems") — full kebab-case names matching `.claude/skills/product/design-systems/<name>/` directories (catalogue index: `.claude/skills/product/references/od-catalog-index.json`)
- [ ] Verbatim borrowings + deviations both documented (a deviation without rationale is undisciplined)

## Token integrity

- [ ] Every `tokens.css` value traces back to (a) catalog DESIGN.md citation, (b) brand-book color story / visual direction line, OR (c) step-4 audit fix with finding ID in comment
- [ ] Token names semantic (`--color-primary`, `--color-foreground-tertiary`), not visual (`--color-blue-500`)
- [ ] Each token has an intent comment (what it represents, where it's used)
- [ ] Spacing scale uses rem (`0.25rem`, `0.5rem`, ...), not raw px (except `1px` borders)
- [ ] Color count in v1: 8–14 total (palette inflation rejected)
- [ ] Type scale count: 5–7 sizes (over-specification rejected)

## Audit response

- [ ] If step 4 frontmatter exists: every finding tagged `fix_skill_hint: "design-system"` is addressed inline in `tokens.css` AND documented in `## Audit Response` (finding ID + before-state + after-state)
- [ ] If no design-system-routed findings: the explicit empty-state line `*No design-system-routed findings from step 4 audit.*` present
- [ ] Every applied fix carries the originating finding ID in the `tokens.css` comment

## Components fidelity

- [ ] Component inventory derived from prototype (step 2 hi-fi screens) — no invented components
- [ ] Per-component block has Anatomy + Variants + States + Tokens consumed
- [ ] Variants list only what the prototype actually uses (don't add "destructive" if no destructive button appears)
- [ ] States list only what applies (disabled-state on a component that's never disabled is filler)

## Accessibility floor

- [ ] WCAG AA targets stated (4.5:1 body / 3:1 large + UI)
- [ ] Focus indicator contract defined (which token carries the focus ring; offset; thickness)
- [ ] Keyboard navigation contract defined (tab order rules, escape-to-dismiss for overlays, etc)
- [ ] Every color pair used in the system computed against the floor (or deviation documented with rationale)

## Sub-agent dispatch hygiene (when synthesis is delegated)

- [ ] Path decision (catalog vs custom vs mixed) made parent-side BEFORE dispatch
- [ ] Catalog system name(s) supplied in CONTEXT field if path is catalog or mixed
- [ ] Sub-agent given access to all 5 references + step-2 prototype dir + step-4 validation-report (read frontmatter if present) + step-5 brand-book + step-1 concept brief
- [ ] Sub-agent's bundle reviewed by parent BEFORE submit (the synthesis is high-leverage; the parent owns the quality gate)
