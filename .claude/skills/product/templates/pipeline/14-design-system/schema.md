# Step 6 — Schema (design system bundle)

Step 6 submits a **multi-artifact bundle**: `design-system.md` (primary `content`) plus `tokens.css` and `components.md` (via `extra_files`). Optionally `tokens.json` (extra_file). Two validation layers fire on `product_step_submit`:

1. **Section check** — the primary `design-system.md` must carry level-2 markdown headings (`## <Title>`) whose slugs match the required-sections list below.
2. **Layer 1** — every file in the bundle must satisfy the `required_files` floor (path present, `min_size`, `contains` substrings).

A failure in either layer produces `code: "schema-incomplete"` with the precise failure list; nothing is written until the whole bundle passes.

## Required sections (markdown headings in `design-system.md`)

Each name slugifies by lowercasing + dashing the H2 title. Match these slugs precisely.

- overview
- tokens
- components
- patterns
- accessibility-floor
- audit-response

`## Catalog Lineage` is required when the path declared in `## Overview` is `catalog` or `mixed`; not enforced by the schema (it'd require the validator to read the path declaration), but the checklist verifies it.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "design-system.md",
      "min_size": 12288,
      "contains": [
        "## Overview",
        "## Tokens",
        "## Components",
        "## Patterns",
        "## Accessibility Floor",
        "## Audit Response",
        "WCAG",
        "| Token |"
      ],
      "any_of_contains": [
        "### F-",
        "*No design-system-routed findings",
        "*Step 4 emitted structured findings, none routed to design-system",
        "Token(s) changed:"
      ]
    },
    {
      "path": "tokens.css",
      "min_size": 1536,
      "contains": [
        ":root",
        "--color-",
        "--font-",
        "--space-",
        "--radius-"
      ]
    },
    {
      "path": "components.md",
      "min_size": 4096,
      "contains": [
        "## Button",
        "**Anatomy",
        "**States",
        "**Tokens consumed"
      ]
    }
  ]
}
```

- `design-system.md` `min_size: 12288` (12 KB) — the deep-port floor. Once Overview + Tokens narrative + per-category token tables + Components pointer + 4–6 Patterns + Accessibility Floor + Audit Response all land, the artifact lands in 12–25 KB. Under 12 KB almost always means tokens collapsed to one undifferentiated block, patterns regressed to a single-line list, or audit response was skipped without the explicit empty-state line.
- `design-system.md` `| Token |` anchor enforces at least one per-category token table (the human-readable view of `tokens.css`). The 5 H2 slug anchors carry the section discipline; the `WCAG` token enforces the accessibility-floor section actually references the standard.
- `tokens.css` `min_size: 1536` (1.5 KB) — a real `:root` block with 8–14 colors + type scale + spacing scale + radius scale + comments lands above this floor. Below 1.5 KB usually means a category was skipped.
- `tokens.css` `contains` enforces the four core token-category prefixes (`--color-`, `--font-`, `--space-`, `--radius-`). The `:root` anchor enforces the canonical CSS-custom-properties shape rather than scattered selectors. Shadow tokens are intentionally NOT enforced — many brutalist / minimalist directions explicitly omit them; the prompt says document the omission as a CSS comment.
- `components.md` `min_size: 4096` (4 KB) — covers ~6 components with anatomy + states + variants + tokens-consumed each. Under 4 KB means several minimum-set components were elided.
- `components.md` `## Button` anchor enforces the minimum-component floor (Button is the load-bearing primitive every system has). The `**Anatomy` / `**States` / `**Tokens consumed` substring anchors (note: prefix-only — no closing `**` and no colon) enforce the per-component block shape — without them, `components.md` regresses to a flat list of names. **Why prefix-only:** the natural markdown shape for these labels is `**Anatomy:** description here` (colon inside the bold), but writers also legitimately write `**Anatomy**` (bold-bold, then prose follows on the next line). The schema accepts either by anchoring on the prefix only. This avoids a silent-failure gotcha — surfaced by the step-6 dogfood, where a strict `**Anatomy**` anchor rejected the natural `**Anatomy:**` writing form without warning.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; depth is the agent's responsibility, reinforced by `references/`.

### `design-system.md`

- **overview** — visual direction restated in one paragraph from the brand-book + density choice (compact / comfortable / spacious) + path declaration (`catalog` / `custom` / `mixed`). 3–6 sentences. The path declaration is what triggers (or skips) the `## Catalog Lineage` section.
- **tokens** — narrative + per-category table (Color / Typography / Spacing / Radius / Shadow-or-omission). Each table mirrors `tokens.css` but adds a "where used" column tying tokens to product surfaces. `| Token |` is the schema anchor for at least one such table.
- **components** — pointer to `components.md` plus 1-paragraph philosophy. Don't duplicate `components.md` content here; the pointer is the contract.
- **patterns** — 4–6 named patterns (form layout, list-with-empty-state, error-handling, loading skeleton, confirmation flow). Per pattern: when to use + components composed + tokens relied on.
- **accessibility-floor** — WCAG AA targets (4.5:1 body / 3:1 large + UI), focus indicator contract, keyboard navigation contract, semantic-element discipline. Tested against `tokens.css` — every color pair used in the system passes the floor (or the deviation is documented).
- **audit-response** — when step 4 frontmatter exists with `fix_skill_hint: "design-system"` findings, document each applied fix here: finding ID + before-state + after-state + which token(s) changed. When no findings to apply, emit `*No design-system-routed findings from step 4 audit.*` (the explicit empty-state line; presence of the section is enforced even when content is empty).
- **catalog-lineage** *(catalog or mixed path only)* — anchored systems + verbatim-borrowings + deviations with rationale.

### `tokens.css`

- `:root` block carrying all token categories. Each token has a comment explaining intent (what it represents, where it's used, any audit-fix lineage).
- Token names semantic (`--color-foreground-tertiary`), not visual (`--color-grey-500`). Raw primitives co-exist when useful (`--primitive-grey-500`).
- Audit-driven token fixes carry the originating finding ID in the comment (`/* fix(F-07): ... */`).

### `components.md`

- Per-component block: name + one-line purpose + **Anatomy** + **Variants** + **States** + **Tokens consumed**. Only variants/states the prototype actually uses (don't invent).
- Minimum component set derived from prototype, with Button as the universal primitive (enforced via Layer 1 anchor).

## Recommended additional sections (not required by schema)

- **motion** — durations + easing curves when motion is part of the brand. Skip when the brand is explicitly motion-light (e.g. brutalist: "no animation outside intentional micro-interactions").
- **iconography** — icon style direction (outlined / filled / hand-drawn / monochrome / etc) + primary icon source (Heroicons / Lucide / custom / system).
- **imagery** — photo / illustration style when relevant. Skip when imagery posture in the brand-book is "none" (e.g. "the product UI is the imagery — no stock photos, no illustrations").

These earn their place when the brand-book named them or when the product class needs them (mobile / consumer apps usually need motion + icons explicitly; dev tools often skip imagery entirely).
