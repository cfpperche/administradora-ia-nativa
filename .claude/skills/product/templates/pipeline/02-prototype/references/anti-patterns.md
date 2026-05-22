# Anti-patterns + anti-AI-slop P0 gate

Two layers. Anti-patterns are mockup-level "don't do this" rules that apply regardless of direction. Anti-AI-slop is a P0 gate — failure on any item blocks emit until fixed.

---

## Mockup anti-patterns

| Pattern | Instead |
|---------|---------|
| Lorem ipsum placeholder text | Realistic data that tells a story about the product (from the brief) |
| External CDN dependencies | Self-contained file with inline styles |
| Desktop-only layout | Mobile-responsive with flexbox / grid + media queries |
| No visual hierarchy | Clear heading sizes, spacing, contrast |
| Complex JS interactivity for a mockup | CSS-only; JS only if explicitly part of the direction |
| Generic component names ("Card 1") | Domain-specific labels ("Monthly Revenue", "Pipeline Stage") |
| Missing empty states | Show what the UI looks like with zero data |
| Inaccessible markup | Semantic HTML, alt text, contrast ratios — see `a11y-checklist.md` |
| One-direction-is-just-darker-variant-of-another | Three genuinely distinct families — see `pipeline.md` |

---

## Anti-AI-slop P0 gate (BLOCK emit on any failure)

These rules exist because every one of them is a "tell" that an AI-generated mockup has slid into the visual cliché of generic-template-land. Direction picks live or die on their absence.

### 1. No aggressive purple / violet gradient backgrounds

**Rule:** No `linear-gradient(..., purple, violet)`, no `radial-gradient(..., #7c3aed, ...)`, no full-bleed purple→pink hero washes.

**Why:** the purple-violet gradient is the most overused AI-mockup signal. Every generic SaaS landing template ships with one. Whatever direction you're going for — minimal, editorial, brutalist — a purple-violet gradient says "I am a Bolt.new template, not a designed product."

**Allowed:** subtle accent gradients used sparingly (e.g., a single button hover state, a chart sparkline). Hard-stop on the full-bleed hero use.

### 2. No generic emoji feature icons

**Rule:** No `✨ 🚀 🎯 ⚡ 💡 🔥` used as icons next to feature headings. Single emoji used functionally (e.g., 🪙 as a token-economy currency mark) is fine.

**Why:** the ✨🚀🎯 trio is the second-most-overused AI signal. Real product designers use inline SVG icons (heroicons, lucide, custom) — not Unicode emoji as decoration.

**Allowed:** single-glyph functional emoji (token currency, status dots, kanban column markers if brief-approved). Inline SVG icons always allowed.

### 3. No left-coloured-border rounded card as default layout pattern

**Rule:** No `border-left: 4px solid <accent>` on every card. No `padding-left: 1rem` + colored stripe as the dominant card affordance.

**Why:** this is the third-most-overused AI signal — the "Bootstrap alert" pattern applied to every list item. It signals "I generated this from a template" louder than any palette choice.

**Allowed:** a sparingly-used colored border on a specific signal element (e.g., one "in progress" kanban card variant). Not the default layout.

### 4. No hand-drawn SVG humans / faces / scenery

**Rule:** No "open-peeps"-style SVG figures, no Storyset-style hero illustrations, no doodled people.

**Why:** these are template-illustration libraries with strong AI-mockup association. They look the same across every generated mockup.

**Allowed:** real product imagery (placeholder boxes labeled "screenshot"), abstract geometric SVG, photographic placeholders.

### 5. Inter / Roboto / Arial as body fonts only — never display

**Rule:** If a direction picks Inter / Roboto / Arial, those are body fonts. The display face must be different — a serif (Iowan Old Style, Newsreader, Source Serif), a mono (JetBrains Mono, IBM Plex Mono), or a different sans (Geist, Söhne, Söhne Mono).

**Why:** Inter-as-display is the single most overused AI typography choice. Even if Inter is the correct body choice for a direction (Vercel uses it that way), the display face needs to give the direction its voice.

**Allowed:** Inter as body in a `modern-minimal` direction paired with a serif display, OR Inter as both body and display ONLY if the brief explicitly anchors on a Linear/Vercel-style stack and the agent justifies the choice in REPORT.md.

### 6. No invented metrics without a source from the brief

**Rule:** No "10× faster than competitors", "99.9% uptime", "$2M ARR", "10,000+ teams trust us" UNLESS the number comes from the brief or a real public source. Estimates must be marked "Estimated" with an assumption line.

**Why:** invented metrics are the cheapest way for an AI mockup to look "polished" while actually making the prototype unshippable — the user has to scrub every number before showing it to a real customer.

**Allowed:** placeholder metrics labeled clearly ("12 teams (your customers)", "1.2k MAU — placeholder"). Estimates with explicit assumption ("Estimated: $50k ARR by month 6 assuming 2% conversion from a 100k waitlist").

### 7. No filler copy

**Rule:** Zero "Feature One / Feature Two / Feature Three", zero lorem ipsum, zero "Lorem ipsum dolor sit amet", zero vague benefit bullets ("Save time. Work smarter. Get results.").

**Why:** filler copy is unshippable AND it signals the mockup wasn't taken seriously. Every word should be brief-sourced or self-citable.

**Allowed:** TBD placeholders explicitly labeled (`[TBD: pricing copy after step 5]`). Real copy can use the brief's mechanics-breakdown almost verbatim as section copy.

### 8. No motivational copy for user states

**Rule:** PT-BR products especially: no "Vamos lá, campeão!", "Você consegue!", "Hora de brilhar!", "Sucesso garantido!", "Sua melhor versão começa aqui!". English equivalents: "You got this!", "Great job!", "Crush your goals!".

**Why:** the user — especially in fragility-adjacent products (career, finance, health) — does not want their tool to coach them like a self-help app. Neutral, direct, respectful copy is what real product designers ship. AI mockups default to motivational because it's the lowest-friction copy mode for LLMs.

**Allowed:** neutral state messages ("Pronto" / "Done", "Salvo" / "Saved", "3 itens" / "3 items"). Confirmations without exclamation marks.

### 9. PT-BR products — Pix + LGPD

**Rule:** If the product is Brazilian fintech / payment-adjacent: Pix QR Code prominent in payment flows (saldo / wallet / checkout). LGPD privacy footer link mandatory on every screen. Currency in `R$ 19,90` format (comma decimal, R$ prefix), NOT `$19.90`.

**Why:** these are non-negotiable for Brazilian audiences and immediately read as "this designer doesn't understand the market" when absent. Pix-first hierarchy beats cartão / boleto unless brief specifies otherwise.

**Allowed (and expected):** Pix prominent + cartão secondary + boleto tertiary. LGPD link as plain footer link, not banner.

### 10. Token-economy products — cost surface

**Rule:** If the product uses a token economy (credits, AI-actions-as-currency, etc.): saldo always visible in header. Cost badge on action buttons (`Otimizar CV · 3🪙`, `Gerar Pacote · 8🪙`). Double-confirm prompt for ≥ 5-token actions. Low-balance banner (< 3🪙) is soft/non-blocking.

**Why:** token-economy products live or die on the user's confidence about cost. Hidden costs erode trust on the first click.

---

## Audit table format (for REPORT.md)

REPORT.md's `## Anti-AI-Slop Audit` section is a table of all 10 P0 rules × A/B/C with `✓` or specific note. Rules 9-10 only apply when the product is Brazilian / token-economy respectively (mark `n/a` otherwise). Example shape:

| Rule | A | B | C |
|------|---|---|---|
| No purple/violet gradient bg | ✓ | ✓ | ✓ |
| No generic emoji feature icons | ✓ | ✓ | ✓ |
| ... | ... | ... | ... |
