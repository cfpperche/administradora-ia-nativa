# Step 5 — Schema (brand book)

Step 5 submits a single artifact, `brand-book.md`. Two validation layers fire on `product_step_submit`:

1. **Section check** — the report must carry level-2 markdown headings (`## <Title>`) whose slugs match the required-sections list below.
2. **Layer 1** — the report must satisfy the `required_files` floor (size + `contains` substrings).

Either failure produces `code: "schema-incomplete"` with the precise failure list; nothing is written until both pass.

## Required sections (markdown headings)

Each name slugifies by lowercasing + dashing the H2 title — `## Voice & Samples` → `voice-samples`, `## We Are / We Are Not` → `we-are-we-are-not`. Match these slugs precisely.

- product-name
- language          (NEW per spec 054 — declares `target_language: <bcp47>` so downstream sub-agents have a machine-readable surface)
- voice
- voice-samples
- we-are-we-are-not
- glossary          (NEW per spec 054 — `### We say` + `### We don't say` sub-sections with table format)
- visual-direction
- logo-direction
- color-story
- anti-patterns

## Glossary shape (spec 054)

The `## Glossary` H2 carries two sub-sections, each with a 4-column table:

```markdown
## Glossary

### We say

| Term | Replacement | Reason | Applies to |
|---|---|---|---|
| Mais escolhido | (preferred) | matches warm-confident pt-BR voice; not corporate-en | marketing, pricing |
| Próximo horário | (preferred) | concrete next-action framing | booking |

### We don't say

| Term | Replacement | Reason | Applies to |
|---|---|---|---|
| Most Popular | Mais escolhido | English in a pt-BR product | marketing, pricing |
| upstream-conflito | conflito de interesse | engineering jargon leaking into customer copy | marketing, legal |
| retail bundled | pacote varejo | anglicism on a Brazilian product | marketing |
```

**Cap:** ≤ 20 entries per sub-section. Less is more — focus on terms the voice positioning actually trips on (the founder's natural anti-jargons, the comparables they reject by phrasing).

**`applies_to` column:** comma-separated surface scopes (e.g. `marketing`, `auth`, `booking`, `app`, `legal`, `pricing`). Empty cell or `all` = applies everywhere. Lets downstream Step 15 screen-writer disable a Glossary entry when working on a surface where the English is correct (e.g. `API` in `/settings/integrations`).

## Language shape (spec 054)

The `## Language` H2 declares the target language as a BCP-47 tag mirroring `.state.json.target_language` (resolved at Phase 0.5 — see SKILL.md):

```markdown
## Language

**target_language:** pt-BR

All user-facing copy in this product — page headings, button labels, microcopy, empty-state text, error messages — uses pt-BR. Surfaces where English is canonical (e.g. code-flavored `/settings/integrations` API references) may use English locally; flag those in `## Glossary § applies_to` exemptions.
```

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "brand-book.md",
      "min_size": 6144,
      "contains": [
        "**Version:**",
        "**Date:**",
        "## Language",
        "**target_language:**",
        "## Voice",
        "## Voice Samples",
        "## We Are / We Are Not",
        "**We are**",
        "**We are not**",
        "## Glossary",
        "### We say",
        "### We don't say",
        "| Term | Replacement | Reason | Applies to |",
        "## Visual Direction",
        "## Logo Direction",
        "### Clear Space",
        "### Minimum Size",
        "### Prohibited Uses",
        "## Color Story",
        "## Anti-Patterns"
      ]
    }
  ]
}
```

- `brand-book.md` `min_size: 6144` (6 KB). The deep-port floor — once voice + 3+ pairs + scale-calibrated voice samples + visual-direction paragraph + logo-posture (clear space + min size + 3+ prohibited uses) + 3–5 anti-patterns + color story all land, the artifact lands in 6–12 KB naturally. Under 6 KB almost always means the "we are / we are not" pairs collapsed to a flat adjective list, the logo direction got hand-waved, or voice samples regressed to one bland sentence each.
- `**Version:**` + `**Date:**` anchors enforce the version-line discipline anthill mandated. A brand book without version + date drifts silently across iterations.
- `**We are**` / `**We are not**` substring anchors enforce the contrast-pair shape (≥ 1 pair). The `## We Are / We Are Not` heading carries the section, the inline anchors prove the pair shape was followed.
- `### Clear Space`, `### Minimum Size`, `### Prohibited Uses` enforce the logo-posture triple under the `## Logo Direction` H2. A logo section with only "use approved colors" is the regression mode.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; depth is the agent's responsibility, reinforced by `references/`.

- **product-name** — final name OR shortlist with one-line rationale per candidate. If shortlist, mark which is preferred.
- **language** — declares `target_language: <bcp47>` (matches `.state.json.target_language` resolved at SKILL.md Phase 0.5). Single sentence stating which surfaces use the target language + which exemptions (code-flavored surfaces). Sub-agents read this as the machine-readable language signal.
- **voice** — 1–2 paragraphs describing the voice. Concrete adjectives + what they look like in practice. Quote the founder verbatim where they were sharp. "Modern, friendly, professional" is rejection-bait — push for examples.
- **voice-samples** — 3 minimum, 5–7 ceiling. Calibrate to product surface count (single-purpose tool → 3; multi-surface platform → 5–7). Each sample is the *actual copy* the brand would emit on that surface (error message, onboarding welcome, marketing tagline, support reply, paywall, empty state). Filler samples for surfaces that don't exist are the regression mode.
- **we-are-we-are-not** — minimum 3 paired bullets in shape `**We are** <X>. **We are not** <near-adjacent-Y>.` The contrast (X vs Y) is the discipline; flat adjective lists fail the section.
- **glossary** — 2 sub-sections (`### We say`, `### We don't say`), each a 4-column table per § Glossary shape above. ≤ 20 entries per sub-section. Identify terms ORGANICALLY from concept-brief + positioning + product domain (jargon the founder uses naturally; comparables phrasings the brand rejects). **DO NOT auto-derive from positioning Unlike-clause** — positioning operates at product-vs-product level (e.g. "we're not enterprise"), glossary operates at copy-trap level (e.g. "Most Popular → Mais escolhido"); the translation isn't mechanical and pseudo-derivation produces noise. The sub-agent reads positioning + concept-brief + voice posture and identifies domain-specific traps that real downstream sub-agents would otherwise drift on.
- **visual-direction** — paragraph naming the visual feel (e.g. "Cool Brutalist", "Warm Humanist", "Editorial Minimalist") + locked posture decisions (typography preference: serif vs sans? imagery posture: photography vs illustration vs none?). NO hex codes, NO type scale, NO token files — those are step 6.
- **logo-direction** — three required sub-sections (`### Clear Space`, `### Minimum Size`, `### Prohibited Uses`). Clear space in logo units. Minimum size directional (px digital + mm print). Prohibited uses ≥ 3, each concrete (not "don't misuse it").
- **color-story** — color *names* + *feelings* (e.g. "anchor on a single saturated cyan as the only on-signal; warm-near-black as canvas; secondary cyan-tinted greys for hierarchy"). NO hex codes — that's step 6.
- **anti-patterns** — what the brand should NEVER sound like. 3–5 concrete bullets. Pair each with a counter-example where useful.

## Recommended additional sections (not required by schema)

- **comparables** — admired brand references with what's borrowed and what's deliberately rejected.
- **emotion-target** — the single emotion the user should feel in the first 30 seconds.

These earn their place when the founder named them sharply during the interview. Skip if the section would be filler.
