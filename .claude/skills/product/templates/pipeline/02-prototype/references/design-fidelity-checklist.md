# Design fidelity — when a DESIGN.md exists

Skip this entire checklist if no DESIGN.md was detected at the project root (`DESIGN.md` or `docs/DESIGN.md`). When no DESIGN.md exists, the agent picks tokens from `visual-constraints.md` § "Conditional style presets" or invents tokens grounded in named design systems (Linear, Notion, Stripe, etc.) cited in REPORT.md.

When DESIGN.md exists, that file is the authoritative source. Direction picks BLEND with DESIGN.md (one direction may anchor on DESIGN.md tokens; the other two propose alternatives). REPORT.md's Brief Compliance section should call out which direction matches DESIGN.md vs which deviates.

> **OD vendor note:** The skill ships the OD vendor library at `.claude/skills/product/design-systems/<vendor>/DESIGN.md` (73 vendored systems — spec 049). Sub-agents pick from the catalogue index at `.claude/skills/product/references/od-catalog-index.json` and `Read` the chosen `DESIGN.md` paths directly. The repo-root DESIGN.md detection (if a fork has its own root-level `DESIGN.md` or `docs/DESIGN.md`) still takes precedence; the OD library is the grounding source when no project-specific DESIGN.md exists.

---

## Color fidelity

- [ ] Primary color from DESIGN.md Section 2 appears in the main accents + CTAs of the matching direction
- [ ] Secondary / accent colors from DESIGN.md applied to secondary elements
- [ ] Neutral scale matches DESIGN.md grays (not generic slate / zinc / gray)
- [ ] Semantic colors (success / warning / error) match DESIGN.md if specified
- [ ] Background and surface colors match DESIGN.md tokens

## Typography fidelity

- [ ] Heading font-family matches DESIGN.md Section 3
- [ ] Body font-family matches DESIGN.md Section 3
- [ ] Signature font weights used (e.g., if DESIGN.md specifies weight 300 for headings, do not default to 600)
- [ ] Type scale (sizes) aligns with DESIGN.md hierarchy table

## Spacing & layout fidelity

- [ ] Border-radius values match DESIGN.md Sections 4 and 6 (component tokens + elevation scale)
- [ ] Spacing scale consistent with DESIGN.md Section 5
- [ ] Shadow / elevation formulas match DESIGN.md Section 6

## Component fidelity

- [ ] Button styles (padding, radius, font-weight, colors) match DESIGN.md Section 4
- [ ] Card styles (border, shadow, padding) match DESIGN.md Section 4
- [ ] Input / form styles match DESIGN.md Section 4 if specified

## Agent prompt guide (if DESIGN.md Section 9 exists)

- [ ] Section 9 positive guidance followed
- [ ] Section 9 prohibitions avoided

## Extraction procedure

Before running this checklist, extract these values from the project's DESIGN.md:

1. Primary / secondary / accent color values (Section 2)
2. Heading + body font families (Section 3)
3. Signature font weights (Section 3)
4. Border-radius range (Sections 4 and 6)
5. Shadow formulas (Section 6)

Search each generated direction-{a,b,c}.html for the extracted values. Flag any item where the file uses a different value than DESIGN.md specifies.

## When two of three directions deviate

That's the expected shape when DESIGN.md exists — the user gets one "match DESIGN.md" direction + two "alternative tone proposals". REPORT.md's `## 3 Direction Summaries` notes the match status per direction explicitly (e.g., "Direction A — DESIGN.md aligned (Section 2 primary palette)" vs "Direction B — alternative warmth proposal, deviates from DESIGN.md Section 3 typography"). User picks which to advance from.
