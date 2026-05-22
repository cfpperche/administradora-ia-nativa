# Pipeline — html-mockup direction generation

The operational playbook for step 2's Turn 1: discovery → 3 direction families → build → 5-dim critique → emit.

## OD vendor grounding — read `od-bridge.md` first

The Open Design (OD) vendor bundle ships **inside the `/product` skill** (spec 027 ported to MCP; spec 049 re-homed to the skill): 73 named `DESIGN.md` design systems at `.claude/skills/product/design-systems/<vendor>/DESIGN.md`, 33 skill bundles + the canonical 5-school direction library at `.claude/skills/product/vendor/open-design/`, all pinned and checksum-verified.

**The grounded path is `references/od-bridge.md`.** It teaches the catalogue lookup (`.claude/skills/product/references/od-catalog-index.json`), the per-system `Read` sequence, and the mandatory DS-citation rule. Each direction is composed from 1-4 named vendored design systems and cites them by name in `REPORT.md` — replacing "agent invents palette/typography from training data" with "agent reads a vendored, pinned `DESIGN.md`".

Read `od-bridge.md` before the discovery turn. The discovery / build / critique guidance below is the playbook `od-bridge.md` feeds into; the **Manual escape** section at the bottom of this file is the fallback when the vendor is genuinely unavailable.

## Discovery — what to elicit before picking directions

The brief from step 1 already carries audience + JTBD + scale + AI-nativity. Discovery fills the 3 gaps the brief usually doesn't cover at this depth:

1. **Visual tone preference** — 2-3 adjectives. If brief is silent, ask. Adjectives point at the OD schools (see `directions.extracted.md` via `od-bridge.md`)
2. **Brand context** — existing brand spec? Reference site to match? Or "pick for me"? A named reference (e.g., "match Linear's vibe") becomes a direction anchor — one of the 3 must be Linear-anchored
3. **Hard constraints** — explicit "no" patterns ("no dark mode default", "no serif", "must be PT-BR + Pix-first"). These disqualify schools that would violate them

Skip discovery entirely if the brief enumerates 3 specific directions. Treat the brief as pre-answered.

## Build phase — per-direction HTML scaffold

Each `direction-{a,b,c}.html` is a self-contained file (no external deps). Canonical structure:

```html
<!DOCTYPE html>
<html lang="<lang>">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Direction <ID> — <Codename></title>
  <style>
    :root {
      --background: <hsl or oklch>;
      --foreground: <hsl or oklch>;
      --primary:    <hsl or oklch>;
      --accent:     <hsl or oklch>;
      --border:     <hsl or oklch>;
      --muted:      <hsl or oklch>;
      --radius:     <value>;
      --font-display: <stack>;
      --font-body:    <stack>;
      --font-mono:    <stack>;
    }
    /* all styles inline — no external CSS */
  </style>
</head>
<body>
  <a href="#main" class="sr-only-focusable">Skip to content</a>
  <main id="main">
    <!-- 1. Header with codename + tagline -->
    <!-- 2. Palette strip — 6 swatches -->
    <!-- 3. Type sample — H1/H2/body/mono/caption -->
    <!-- 4. Hero sample — title + subtitle + CTA -->
    <!-- 5. Dashboard sample — kanban / metric cards / table -->
    <!-- 6. Personality footer — DS citation + signal paragraph -->
  </main>
</body>
</html>
```

When the OD vendor is available, seed from `<vendor_paths.skills>/web-prototype/assets/template.html` instead of the bare scaffold above — see `od-bridge.md` § *Build phase*. The scaffold above is the shape; the vendored template is the pre-baked token system + class inventory.

### Build phase rules (hard — any failure = fix pass before emit)

1. All 6 palette tokens declared in `:root` (`--background` / `--foreground` / `--primary` / `--accent` / `--border` / `--muted`)
2. **Recommended: enrich the token system beyond the 6 base palette tokens** for landing-page cohesion. Anthill's reference directions declare ~18 tokens; this richness is what makes sections feel like one designed product rather than independent fragments. Suggested extensions:
   - **Surface elevation:** `--surface-1` / `--surface-2` / `--surface-3` (progressively elevated card / panel / hover surfaces)
   - **Border weight:** `--border-subtle` (5-8% opacity) / `--border-std` (12-15% opacity) — semi-transparent variants of foreground
   - **Typography scale:** `--fs-display` (`clamp(36px, 5vw, 56px)` for fluid hero), `--fs-h2`, `--fs-h3`, `--fs-body` (15-16px), `--fs-meta` (12px)
   - **Spacing scale:** `--gap-xs` (4px) through `--gap-2xl` (72px) on an 8-point grid
   - **Layout:** `--container` (1200-1280px) + `--gutter` (16-24px) + `--radius` / `--radius-lg`
   - **Font stacks:** `--font-body` and `--font-mono` as full fallback stacks
   Directions that legitimately reject this richness (brutalist-experimental rejecting "scale" for "one big size") may use simpler systems — but justify in REPORT.md
3. All colors in `hsl()` or `oklch()` syntax — no bare hex literals, no `rgb()`. `hsl()` is the safe default for browser compat; `oklch()` is preferred when the palette is being tuned for perceptual uniformity (warm-soft, editorial directions especially benefit)
4. **All 8 required surfaces present** per prompt.md § 4: header, palette strip, type sample, hero sample, dashboard sample, **charts & sparklines sample (≥ 2 data-viz instances — one brief-grounded chart + one flex second)**, **pricing tile grid (3 tiers, "Most Popular" emphasis on Pro)**, personality footer / DS lineage. Pricing-as-product-UI gives the founder a second product surface beyond the dashboard; charts validate the direction's data-viz token vocabulary (line colors, axis style, sparkline density) which the palette strip alone can't reveal
5. **Section rhythm: 4-layer pattern per content section** — every content section uses eyebrow + title + lead + body (see prompt.md § 4 for the canonical HTML pattern). Headings alone produce "loose sections"; the eyebrow + title + lead trio produces landing-page narrative cohesion. The header and palette strip sections may use a lighter variant (no lead) but sections #3-#6 require all 4 layers
6. **School-specific OpenType applied** — per the school spec in `directions.extracted.md` (vendored; via `od-bridge.md`) or the Manual escape table below. The Linear-anchored direction MUST carry `font-feature-settings: "cv01", "ss03"` on body; other schools apply their school tells when applicable
7. Maximum 3 heading levels per file (page title / section title / card title)
8. No fixed widths on containers — use `max-width` + percentage/auto + flex/grid for layout
9. Skip-to-content link as first focusable element (a11y floor)
10. `:focus-visible` outline on all interactive elements
11. Tabular numerics on prices / counts / dates: `font-variant-numeric: tabular-nums`
12. No external resources (no `<link rel="stylesheet">`, no remote `<script src>`, no Google Fonts unless the system fallback works alone)
13. Renders without horizontal overflow at 375px AND 1440px viewports
14. Dashboard / metric / pricing / table content uses REAL data from the brief-identifier extraction table pinned in prompt.md § 1 — product name, issue ID prefix, persona slugs, sprint label, metric values, pricing tiers — all verbatim. Substituting plausible variants ("Maya Chen" when the brief says "@mara.ic") weakens Specificity at D7

## Anti-AI-slop hard rules (P0 gate — block emit)

Read `references/anti-patterns.md` for the full rationale per rule. Quick reference:

- No aggressive purple/violet gradient backgrounds (`linear-gradient(..., purple, violet)`)
- No generic emoji feature icons (`✨ 🚀 🎯` — inline SVG or single-glyph functional only)
- No "rounded card with left coloured border accent" as default layout pattern
- No hand-drawn SVG humans / faces / scenery
- Inter / Roboto / Arial are body fonts only — never display
- No invented metrics ("10× faster", "99.9% uptime") without a source from the brief
- No filler copy — zero "Feature One / Two", lorem ipsum, vague benefit bullets
- No motivational copy for user states ("Vamos lá, campeão!" / "Você consegue!")
- **PT-BR products:** Pix QR Code prominent if fintech/payment-adjacent; LGPD footer link mandatory; PT-BR copy throughout (currency `R$ 19,90` not `$19.90`)
- **Token-economy products:** cost badge on action buttons (`Otimizar CV · 3🪙`); saldo visible in header; double-confirm for ≥ 5 tokens

When the OD vendor is available, also run the vendored `checklist.md` (`<vendor_paths.skills>/web-prototype/references/checklist.md`) — it carries the OD project's own P0/P1/P2 list.

## 5-dim critique (pre-emit gate)

Score each direction 1-5 on each dimension. Any dimension < 3/5 requires a fix pass. Read `references/checklist.md` for the full rubric.

| Dim | What it measures | Typical -1 cause |
|-----|------------------|------------------|
| **Philosophy** | Visual posture matches what was asked | Drifted to a generic default mid-build |
| **Hierarchy** | One obvious focal point per surface | Two equal-weight CTAs competing |
| **Execution** | Typography / spacing / alignment correct, not approximate | Inconsistent token use; non-tabular numerics |
| **Specificity** | Every word / number / label is from the brief | Generic copy slipped in; invented persona names |
| **Restraint** | One accent used at most twice per screen; one decisive flourish | Three competing flourishes or gradients |

Two fix passes is normal. Do NOT emit with a failing dimension.

## Manual escape — OD vendor unavailable

**Use this section when the OD vendor is genuinely missing on disk** — `.claude/skills/product/design-systems/` directory absent or empty (the skill itself is broken; reinstall or check `git status`). The grounded path (`od-bridge.md` + direct `Read` of vendored `DESIGN.md` paths) produces measurably better output because each direction carries a real DESIGN.md citation chain — so `od-vendor-missing` is not a legitimate steady-state path. Degradation stays explicit, never silent: surface the missing-vendor error before falling into manual escape.

In manual-escape mode the agent grounds directions in training-data knowledge of named design systems, using the 5-school table below as the direction library (the same library `directions.extracted.md` carries in vendored form).

### 5 canonical schools (starting families)

Each direction the agent emits should map to ONE of these, OR explicitly justify a blend (e.g., "Notion × Stripe — warm-soft × tech-utility hybrid for fintech-clean aesthetic").

| id | Label | Mood | Palette family | Type | Named references | School-specific tells |
|----|-------|------|----------------|------|------------------|----------------------|
| `editorial-monocle` | Editorial — Monocle / FT magazine | Print-magazine feel, content-led, calm | Off-white + ink + warm rust | Serif display + system body | Monocle, FT, NYT Cooking, The New Yorker | `font-feature-settings: "smcp"` for small-caps eyebrows; rule-line dividers (`border-top: 1px solid`); pull-quote with rust `border-left` |
| `modern-minimal` | Modern minimal — Linear / Vercel | Dark or near-white, restrained, tech-product | Near-black or near-white + cobalt accent | System sans throughout | Linear, Vercel, Raycast, Arc browser | **Linear OpenType:** `font-feature-settings: "cv01", "ss03"` on body (activates Linear's actual variant alternates — insider tell); hairline borders 1px no shadow; tight letter-spacing `-0.03 to -0.04em`; weight-300 display |
| `warm-soft` | Warm soft — Stripe pre-2020 / Headspace | Approachable, fintech-friendly, human | Cream bg + terracotta or moss-green accent | Serif display + system body | Stripe (pre-2020), Headspace, Notion (pre-AI), Calm | Soft shadow stack (multi-layer low-opacity); generous radius (`8-16px`); warm neutral grays (not pure gray) |
| `tech-utility` | Tech / utility — Datadog / GitHub | Data-dense, ops-focused, functional | Dark or light + grid + monospace accents | Mono headings + system body | Datadog, GitHub, Grafana, Sentry | Monospace display: `font-feature-settings: "kern", "liga"` on JetBrains/IBM Plex Mono; square corners `3px max radius`; grid-paper background pattern allowed |
| `brutalist-experimental` | Brutalist / experimental — Are.na / Yale | Loud type, visible grid, statement | Hot-red / electric-yellow + black + white | Display sans (large), tight letter-spacing | Are.na, Yale School of Art, MSCHF, KFC Studios | Display sans at 6-9rem; visible 12-column grid overlay; one decisive flourish (rotated heading, oversized punctuation, baseline shift) |

### Picking 3 distinct directions

- The 3 directions MUST come from different palette families. Two "modern-minimal" picks with different greens are NOT distinct — pick one and replace the other with a contrasting school
- A direction can blend 2 schools (e.g., `tech-utility` × `warm-soft`) when the brief justifies it. Cite both in REPORT.md ("custom — Notion × Stripe blend, justified by brief's explicit Notion-meets-Stripe example")
- Match a brief-stated preference verbatim. Brief says "brutalist with hot red"? → `brutalist-experimental` is one of the 3, not optional
- Brief silent on tone → pick 3 contrasting schools that cover different product personalities (e.g., `modern-minimal` + `warm-soft` + `tech-utility` is a safe diverse triple)

Even in manual-escape mode, `REPORT.md` still cites the named design systems each direction draws from — the citation chain is the quality wedge, vendored or not.
