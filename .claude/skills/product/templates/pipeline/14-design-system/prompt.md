---
mode: synthesis
delegable: partial
delegation_hint: "synthesise the design-system bundle (design-system.md + tokens.css + components.md, optionally tokens.json) from the brand-book, the prototype's component inventory, and any audit findings tagged fix_skill_hint=design-system; pick catalog OR custom path based on parent-supplied path decision"
---

# Step 6 — Design System

**Goal:** translate the brand-book (step 5) into a concrete design system — actual hex values, type scale, spacing scale, component anatomy/states, accessibility floor — that step 15 (screen-atlas; absorbed step 7 per spec 045) and step 15 (screen-atlas; renamed per spec 045) consume to render screens consistently. This is where the *posture* the brand-book named (e.g. "Cool Brutalist", "Warm Humanist") becomes *spec* (e.g. `--color-canvas: oklch(0.10 0.005 240)`, `--space-2: 0.5rem`, `--radius-card: 2px`).

**Mode:** `synthesis` with `delegable: partial`. The path decision (catalog vs custom) is parent-side because it requires context the sub-agent shouldn't reinvent — does the brand-book name a catalog system explicitly? Did the founder declare a preference? Is there an existing DESIGN.md in the workspace? Once the path is decided, synthesis itself is fully delegable.

**Output bundle** (atomic via `extra_files` — all files written together or none):

| File | Role | Floor |
|---|---|---|
| `design-system.md` | the spec — narrative + tokens table + component anatomy + patterns + accessibility floor + audit-response | ≥ 12 KB |
| `tokens.css` | the actual values — `:root { --color-*, --font-*, --space-*, --radius-*, --shadow-*, ... }` | ≥ 1.5 KB, valid CSS |
| `components.md` | per-component anatomy + states + variants table | ≥ 4 KB |
| `tokens.json` *(optional)* | machine-readable token export, generated from tokens.css | n/a |

The four files are derived from a single source of truth — `tokens.css` is the canonical value layer, `design-system.md` documents *why*, `components.md` documents *how to compose*, `tokens.json` is the same values in machine-readable form. Mismatch between any two is a defect.

---

## How to conduct this step

Read `references/anti-patterns.md` and `references/examples.md` before drafting. Use `references/section-floor.md` for the per-product-class section calibration, `references/token-naming.md` for the naming convention, and `references/audit-response.md` for the structured-frontmatter consumption pattern from step 4. Run `references/checklist.md` before submitting.

### 1. Read the inputs

- **Brand book (step 5)** — `docs/brand-book.md`. The visual direction, voice samples, color story, logo posture. This is the *posture* the design system makes concrete.
- **Prototype (step 2)** — `docs/`. The component inventory the design system must cover (read each hi-fi screen for the actual UI primitives that appear; don't invent components the prototype doesn't use).
- **UX audit (step 4)** — `docs/validation-report.md`. **Read the YAML frontmatter if present.** Filter `findings[]` by `fix_skill_hint: "design-system"` — those are the token-level fixes step 6 must apply during synthesis (typically contrast tunes, semantic-color rebalances, lightness adjustments). Each applied fix is documented in the design-system's `## Audit Response` section with the originating finding ID.
- **Concept brief (step 1)** — `docs/concept-brief.md`. The product class (data dashboard / marketing site / mobile app / CLI tool / B2B SaaS) calibrates the section list and the density choice.

If brand-book or prototype is missing/thin, stop and report to the parent — don't fabricate the missing input.

### 2. Decide the path: catalog OR custom

The parent decides this and tells the sub-agent in CONTEXT. Two paths:

**Catalog path** — when one of:
- The brand-book § Visual Direction names a catalog system explicitly (e.g. "Cool Brutalist anchored on Composio + Voltagent + Warp")
- The founder declared a preference for a known design system (Linear / Vercel / Notion / etc — 73 vendored systems catalogued at `.claude/skills/product/references/od-catalog-index.json`)
- The product is in a category where a catalog system is a strong fit and the brand-book left visual direction open

Catalog path procedure:
1. `Read` `.claude/skills/product/references/od-catalog-index.json` to see the available 73 systems (each entry carries `name + category + mood + palette_primary + vendor_path`).
2. Pick 1 primary system (anchor) + optionally 1–2 secondary systems for accent treatment (e.g. *Composio anchor + Warp partial-fit on terminal-block layout*).
3. The `vendor_path` field of each chosen entry is the relative path to its `DESIGN.md` (e.g. `.claude/skills/product/design-systems/linear/DESIGN.md`).
4. `Read` the catalog DESIGN.md(s). They are dense (~10–20 KB each, 9 sections, full token specs). Derive the project's `tokens.css` directly from the catalog DESIGN.md's hex/typography/spacing values.
5. Document in `design-system.md` § "Catalog Lineage" which systems were borrowed from, what was taken verbatim, and what was deviated (every deviation needs a one-line justification grounded in the brand-book).

**Custom path** — when one of:
- The brand-book's color story is genuinely unique (no catalog system fits)
- The founder asked for a custom system explicitly
- The product class needs a hybrid that no catalog system matches

Custom path procedure:
1. Synthesise tokens directly from the brand-book's color story + visual direction + logo posture. Color story names hues and feelings ("a single saturated cyan as the only on-signal") — pick the actual hex values that match the named feel.
2. Pick the typography family from the brand-book's visual direction (e.g. "monospace throughout — typewriter-grade" → JetBrains Mono / IBM Plex Mono / Fira Code; "warm humanist serif pairing with sans" → Source Serif + Inter).
3. Calibrate the density (compact / comfortable / spacious — see § 3 below).

**Mixed path is allowed** — use a catalog system as the foundation, customize 1–2 dimensions where the brand-book diverges. Document the divergences explicitly.

### 3. Calibrate density to product class

Density is the spacing-scale base + the default vertical rhythm. Three buckets, **calibrated by product class** (read from concept brief):

| Product class | Density | Spacing base | Rationale |
|---|---|---|---|
| Data-dense dashboard, dev tool, terminal-aesthetic product, internal admin | **Compact** | 4 px / 0.25 rem | Information density wins; the user is reading + acting, not browsing |
| Standard B2B SaaS, productivity tool, prosumer app | **Comfortable** | 8 px / 0.5 rem | The category default; the "no opinion" baseline |
| Marketing site, luxury / editorial product, consumer app where browsing is the activity | **Spacious** | 12 px / 0.75 rem (or asymmetric 8/16/24/40) | Negative space is part of the product feel |

Don't rigidly pick one when the product is hybrid (e.g. a B2B SaaS whose marketing surface is editorial but whose product surface is dashboard-dense). Ship two scales when justified — `tokens.css` carries `--space-tight-*` AND `--space-spacious-*` with documented usage rules.

### 4. Synthesise the bundle

Files in order:

#### 4a. `tokens.css` — the canonical value layer

CSS custom properties under `:root`. Required token categories (the floor):

- **`--color-*`** — primary / surface(s) / foreground(s) / border(s) / accent(s) / semantic (success / warning / danger / info). 8–14 colors total in v1; resist palette inflation.
- **`--font-*`** — `--font-display`, `--font-body`, `--font-mono` (each value is a font stack with fallbacks). Type scale: `--text-xs / sm / base / lg / xl / 2xl / 3xl / 4xl` with line-height + weight pairs.
- **`--space-*`** — spacing scale derived from the density base (e.g. compact: `--space-1: 0.25rem; --space-2: 0.5rem; --space-3: 0.75rem; ...`).
- **`--radius-*`** — `--radius-none`, `--radius-sm`, `--radius-md`, optionally `--radius-full`. Cap the count — radii > 4 means the visual direction is unsettled.
- **`--shadow-*`** — `--shadow-sm`, `--shadow-md`, `--shadow-lg` (optional — many brutalist / minimalist directions explicitly omit shadows; document that as `/* no shadow tokens — direction is hairline-only */` rather than ship empty values).

Each token has a comment explaining the *intent* (e.g. `/* tertiary metadata text — must pass 4.5:1 body floor */`), not just the value. Token names are **semantic** (`--color-foreground-tertiary`), not visual (`--color-grey-500`); raw primitives can co-exist (`--primitive-grey-500`) when useful, but the consuming surface is semantic.

**Audit response inline:** if step 4 frontmatter handed over `fix_skill_hint: "design-system"` findings, apply each fix INSIDE `tokens.css` and reference the finding ID in the comment. E.g.:

```css
/* fix(F-07/F-09): brightened from oklch(0.50 …) to lift contrast on surface from 3.89:1 → 5.10:1 */
--color-foreground-tertiary: oklch(0.55 0.010 240);
```

#### 4b. `design-system.md` — the spec

Sections (the floor — see `references/section-floor.md` for product-class extensions):

- `## Overview` — visual direction restated in one paragraph from the brand-book + density choice + path declaration (catalog / custom / mixed). 3–6 sentences.
- `## Tokens` — narrative + table per category. The table mirrors `tokens.css` but adds a "where used" column (e.g. `--color-foreground-tertiary` → "issue meta, sidebar group headers, settings field labels, hint labels"). This is the human-readable view of the canonical CSS.
- `## Components` — pointer to `components.md` plus 1-paragraph philosophy (e.g. "Anatomy-first: every component is described by slots + states; implementation is the consuming surface's choice").
- `## Patterns` — 4–6 named composed structures (form layout, list-with-empty-state, error-handling pattern, loading skeleton, confirmation flow). Each pattern: when to use + the components it composes + the tokens it relies on.
- `## Accessibility Floor` — WCAG AA targets (contrast 4.5:1 body / 3:1 large + UI), focus indicator contract, keyboard navigation contract, semantic-element discipline. Tested against `tokens.css` — every color pair used in the system passes the floor (or the deviation is documented with rationale).
- `## Audit Response` — when step 4 frontmatter exists with `fix_skill_hint: "design-system"` findings, document each applied fix here: finding ID + before-state + after-state + which token(s) changed. Closes the loop from audit → token edit. If no findings to apply, emit the explicit empty-state line: `*No design-system-routed findings from step 4 audit.*`
- `## Catalog Lineage` *(catalog or mixed path only)* — which catalog systems were anchored on, what was taken verbatim, what was deviated and why.

#### 4c. `components.md` — anatomy + states inventory

Per-component block:
- **Name** + one-line purpose.
- **Anatomy** — the slots (`[icon]? [label] [trailing-icon]?` etc).
- **Variants** — primary / secondary / ghost / destructive (only the variants the prototype actually uses — don't invent).
- **States** — default / hover / active / focus / disabled / loading / error (only those that apply).
- **Tokens consumed** — which `--color-*`, `--space-*`, `--radius-*` this component reads.

Minimum component set, derived from prototype: Button, Input (text + textarea + select where present), Card, Modal/Sheet (when prototype shows one), Toast (when prototype shows one), NavBar / Sidebar (whichever the prototype uses), EmptyState (the empty-first-run + filtered-empty surfaces).

#### 4d. `tokens.json` *(optional)*

Machine-readable export of `tokens.css` for downstream tooling (Style Dictionary, Tailwind config generation, Figma variables). Shape: `{ "color": {...}, "font": {...}, "space": {...}, "radius": {...}, "shadow": {...} }`. Skip when no consumer needs it.

### 5. Submit + advance

Call `product_step_submit` with `filename: "design-system.md"`, `content: <design system narrative>`, `extra_files: [{path: "tokens.css", content: ...}, {path: "components.md", content: ...}]` (and optionally `{path: "tokens.json", content: ...}`). Layer 1 validates all files atomically — nothing is written unless every file passes.

Step 6 is mid-Identity. No gate yet. After a clean submit, `product_advance` moves to step 7 (screen-atlas — re-render the prototype with brand+tokens applied). Step 7 reads `tokens.css` directly and pre-fixes every step-4 audit finding tagged `fix_skill_hint: "screen-atlas"` during the re-render.

---

## Voice & rigor

- **Tokens have semantic names, not visual names.** `--color-primary` survives a rebrand; `--color-blue-500` doesn't. Both can co-exist (raw + semantic) but the consuming surface reads semantic.
- **Resist tokens-by-the-yard.** A v1 design system with 30 colors and 12 type scales is over-engineered. 8–14 colors and 5–7 type scales force the designer to make hard choices early — which is what good systems do.
- **Components describe ANATOMY + STATES, not implementation.** "Button has [icon-slot]? [label] [icon-slot]?" beats "Button uses React.forwardRef and accepts className prop". Implementation is the consuming surface's choice.
- **The brand voice should appear IN the design system.** Sardonic brand → sardonic empty states. Warm-humanist brand → warm error messages. The tokens.css is values; the design-system.md is *also* a brand artifact.
- **One brand per design system.** Mixing Stripe's purple with Vercel's typography is a category error. If the brand-book is hybrid, the design system documents the hybrid as a deliberate composition, not a soup.
- **Every value traces back.** Every `tokens.css` value either (a) comes from a catalog DESIGN.md cited in `## Catalog Lineage`, OR (b) comes from a brand-book color story / visual direction line, OR (c) is a step-4 audit fix with the finding ID in the comment. Tokens with no provenance are inventions.

## What this step does NOT do

- **Implementation.** This is a spec + tokens + anatomy. React components, Tailwind config files, Figma variables generation are downstream consumer choices.
- **Per-screen designs.** Step 7 (screen-atlas) re-renders the screens; step 6 produces the system step 7 reads.
- **Marketing site assets.** Future GTM step.
- **Component testing / Storybook stories / docs site.** All downstream of the spec.

## What this step replaces

This template synthesises two archived anthill skills (see `.claude/memory/anthill-archived.md`):

- **`anthill-design-system`** — the bootstrap discipline: catalog OR custom, 9-section DESIGN.md, stack-adapted token output. The `/product` skill keeps the catalog/custom split, expands to a 4-file bundle (spec + tokens + components + optional JSON), and integrates the catalog lookup via the bundled `.claude/skills/product/references/od-catalog-index.json` + direct `Read` of `.claude/skills/product/design-systems/<system>/DESIGN.md` (anthill used `npx getdesign add`; spec 027 used MCP tools; spec 049 collapsed the indirection — the skill ships the vendor in-tree).
- **`anthill-design-system-lead`** — the governance discipline: token semantic naming, primitive vs semantic distinction, component inventory with status, accessibility-as-a-hard-gate. The MCP port keeps the discipline; the inventory + governance posture flow through `components.md`.

Anthill's runtime scaffolding — `.anthill/teams/design.md` reads, `npx getdesign` shell-out, `tailwind.config.patch.js` / `design-tokens.css` / `style-dictionary.config` stack-adaptation auto-generation, the deliverable-registry hook — does not port. Stack adaptation is deferred to consumer choice (the consuming codebase converts `tokens.css` to whatever its framework uses); the catalog lookup flows through MCP tools instead of a shell-out.

**The audit-response handoff is new.** Anthill's design-system skills did NOT consume audit findings programmatically — the audit lived in `anthill-ux-audit` as an artifact, and any token tunes downstream were the designer's manual responsibility. The MCP port closes that loop: when step 4 emits the YAML frontmatter (its own port-improvement, see `04-ux-testing/schema.md`), step 6 reads it and applies `fix_skill_hint: "design-system"` findings inline, documenting each in the `## Audit Response` section. This is the audit-as-delegation-manifest pattern restored from the anthill comparison.
