# OD Bridge — grounding step 2 directions in the vendored Open Design bundle

This document teaches the agent how to consume the vendored **Open Design (OD)** bundle that ships *inside* the `/product` skill (spec 027 ported it to MCP; spec 049 re-homed it to the skill so `/product` stays self-contained after MCP discontinuation). It is the grounded replacement for `pipeline.md`'s inline 5-school description: instead of inventing palette/typography from training data, the agent reads a pinned, vendored `DESIGN.md` per direction and cites it by name in `REPORT.md`.

Ported from anthill's `anthill-prototype/references/od-bridge.md`. Anthill injected the vendor via symlink and used `.anthill/vendor/...` paths; spec 027 nested it under the MCP package and used MCP tools to resolve absolute paths; spec 049 collapsed that indirection — **the agent reads vendor paths directly under `.claude/skills/product/`**, no tool round-trip needed, because the skill ships the vendor in-tree.

## Vendor layout (canonical paths)

| What | Path |
|------|------|
| Design systems index (73 entries, lightweight) | `.claude/skills/product/references/od-catalog-index.json` |
| Per-system `DESIGN.md` | `.claude/skills/product/design-systems/<system>/DESIGN.md` |
| Skill bundles (`web-prototype`, `saas-landing`, 31 others) | `.claude/skills/product/vendor/open-design/skills/<bundle>/` |
| Prompt sources (`directions`, `discovery`, `system`) | `.claude/skills/product/vendor/open-design/prompts/<name>.ts` |
| Frames (`iphone-15-pro`, `macbook`, `browser-chrome`) | `.claude/skills/product/vendor/open-design/frames/<frame>.html` |
| Pitch-deck template | `.claude/skills/product/vendor/open-design/templates/deck-framework.html` |
| Manifest + provenance | `.claude/skills/product/vendor/open-design/{MANIFEST.json,LICENSE,NOTICE}` |

Paths are repo-relative; sub-agents working from `$CLAUDE_PROJECT_DIR` resolve them via the `Read` tool with an absolute prefix.

## Pre-flight reads (do once, before writing any HTML)

Run in order. Reading these *before* writing prevents re-deriving defaults the vendored assets already encode.

```
1. Read .claude/skills/product/references/od-catalog-index.json
   → the 73-system catalogue (name + category + mood + palette + path)
   → scan moods/palettes; shortlist 1-4 systems per direction (a/b/c)

2. For each shortlisted system:
   Read .claude/skills/product/design-systems/<system>/DESIGN.md
   → this is the compositional source for that direction: palette roles,
     typography rules, component stylings, layout principles, do's/don'ts

3. Read .claude/skills/product/vendor/open-design/prompts/directions.ts
   → the 5 canonical visual schools, full specs — map each direction to one
     school (or justify a blend, citing both)

4. Read .claude/skills/product/vendor/open-design/prompts/discovery.ts
   → discovery-form structure, if step 2's discovery turn needs one

5. Pick the right skill bundle:
   Read .claude/skills/product/vendor/open-design/skills/web-prototype/SKILL.md
       + assets/template.html  (seed: token system + class inventory)
       + references/layouts.md  (paste-ready section skeletons)
       + references/checklist.md  (P0/P1/P2 self-review)
   → for a marketing-led brief, use saas-landing/ instead of web-prototype/
```

OD skill selection heuristic:
- Multi-screen app prototype → `web-prototype`
- Primarily a marketing landing → `saas-landing`
- Both → `web-prototype` (covers landing + app screens in one file)

## The 5 canonical schools

Source of truth: `.claude/skills/product/vendor/open-design/prompts/directions.ts`. Each direction the agent emits maps to ONE school, or explicitly justifies a blend in `REPORT.md`.

| id | Label | Mood |
|----|-------|------|
| `editorial-monocle` | Editorial — Monocle / FT magazine | Print-magazine feel, serif, off-white + ink + warm rust |
| `modern-minimal` | Modern minimal — Linear / Vercel | Dark or near-white, system fonts, cobalt accent, content-led |
| `warm-soft` | Warm & soft — Stripe pre-2020 / Headspace | Cream bg, serif display, terracotta accent, fintech-friendly |
| `tech-utility` | Tech / utility — Datadog / GitHub | Data-dense, monospace, dark or light + grid, ops-focused |
| `brutalist-experimental` | Brutalist / experimental — Are.na / Yale | Loud type, visible grid, hot-red accent |

The vendored `directions.ts` carries the full per-school spec (palette families, type stacks, school-specific OpenType tells). Read it — do not work from this table alone.

## Grounding rule — DS citation is mandatory

Each direction (`direction-{a,b,c}.html`) must be composed from **1-4 named vendored design systems**, and `REPORT.md` must cite them by name with the path that grounded them:

```
### Direction A — <codename>
School: modern-minimal
Design systems consulted:
  - linear-app  (design-systems/linear-app/DESIGN.md) — palette roles, cv01/ss03 OpenType
  - vercel      (design-systems/vercel/DESIGN.md)     — hairline borders, weight-300 display
```

This is the citation chain that makes 3 directions genuinely distinct: their grounding sources are distinct, not their prompt-engineered variety. `schema.md` enforces a `Design systems consulted` section in `REPORT.md` (substring `design-systems/` must appear at least once).

## Build phase

Follow `pipeline.md` § *Build phase* for the per-direction HTML scaffold, the 8 required surfaces, the token-system enrichment guidance, and the hard rules. The OD bridge adds two grounding obligations on top of that playbook:

1. **Seed from the vendored template, not from scratch.** Copy `.claude/skills/product/vendor/open-design/skills/web-prototype/assets/template.html` as the starting token system + class inventory. Replace the `:root` tokens with palette values *taken from the consulted DESIGN.md files* — verbatim, not improvised.
2. **Apply the school-specific tells from `prompts/directions.ts`** — e.g. the Linear-anchored direction carries `font-feature-settings: "cv01", "ss03"` on body.

Frames (`.claude/skills/product/vendor/open-design/frames/{iphone-15-pro,macbook,browser-chrome}.html`) are optional device-chrome wrappers for screen mocks.

## Anti-AI-slop hard rules

Unchanged from `pipeline.md` § *Anti-AI-slop hard rules* — that P0 gate still applies. The vendored `checklist.md` (`.claude/skills/product/vendor/open-design/skills/web-prototype/references/checklist.md`) carries the OD project's own P0/P1/P2 list; run both.

## When the vendor is genuinely missing

The vendor ships inside the skill; if it's missing, the skill itself is broken. The agent surfaces the error (`OD vendor missing at .claude/skills/product/design-systems/ — reinstall the /product skill or check git status for an incomplete checkout`) and consults the "Manual escape" section of `pipeline.md` (the pre-OD inline 5-school method) only as an explicit, documented fallback. The escape is a conscious choice, not a silent degradation.

## PT-BR product considerations

When the brief indicates a Brazilian product:

- All copy in PT-BR (landing, onboarding labels, dashboard states, error messages)
- Currency: `R$ 19,90`, not `$19.90`
- Payment surface: Pix-first (QR Code prominent), cartão and boleto secondary
- Token-economy UX: saldo visible in header, cost badge on action buttons (`Otimizar CV · 3🪙`), double-confirm for ≥ 5 tokens
- Mobile-first layouts; contrast AAA for primary text; 44px minimum touch targets
- LGPD privacy link in footer — required, not optional
