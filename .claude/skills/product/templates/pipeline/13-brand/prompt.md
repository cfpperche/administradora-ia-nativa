---
mode: draft-after-input
delegable: partial
delegation_hint: "synthesise brand-book.md from the founder-interview transcript the parent gathered: identity, voice with 'we are / we are not' pairs, voice samples scaled to the product's surface count, visual direction (name only — no hex/no scale), logo posture (clear space + min size + ≥3 prohibited uses), anti-patterns, version+date header"
---

# Step 5 — Brand

**Goal:** the brand foundation — name, voice, audience positioning, visual direction (named, not specified), and the anti-patterns that keep the product from drifting into another category. 80% founder vision, 20% concept-brief context. This is the FIRST step of the **Identity** phase, after the Discovery gate.

**Mode:** `draft-after-input`. The parent MUST conduct the founder interview live (the voice cannot be derived from prior artifacts — it's a posture choice). The synthesis itself (writing the brand-book artifact from the captured interview transcript) can delegate — a sub-agent reads the transcript + concept brief and produces the artifact without further user input.

**Output file:** `brand-book.md` in `docs/`. Single artifact.

---

## How to conduct this step

Read `references/anti-patterns.md` and `references/examples.md` before drafting (or before dispatching the synthesis sub-agent) — `examples.md` carries voice-samples examples AND the ≥20-pair "we are / we are not" bank organised by product category. Use `references/prompt-bank.md` for the calibrated interview question set and `references/logo-direction-template.md` for logo posture conventions (clear space + min size + prohibited uses worked examples). Run `references/checklist.md` before submitting.

### 1. Anchor to step 1 — and gauge founder clarity

Re-read the concept brief. Brand has to fit the product, not float independently. Note the target audience, differentiation, and any voice cues the founder already encoded (the brief's hook, the persona language, taglines).

Then **gauge founder-clarity** — this calibrates the interview depth in step 2:

| Clarity signal | Branch | Interview depth |
|---|---|---|
| Brief carries a sharp hook + named persona language + admired-brand references already | **Sharp vision** | 2–3 *deepening* probes — the brand mostly exists; you're sharpening edges and surfacing anti-patterns |
| Brief has a clear product-shape but voice is mostly implicit (adjectives without examples) | **Mostly-vibes** | 5–7 *broadening* probes — pull voice out into concrete samples; map adjectives to anti-patterns |
| Brief is thin on identity (founder said what the product DOES but not what it FEELS like) | **No clarity** | 7–9 *foundational* probes — start from comparable brands, persona reactions, single-emotion-target |

Rigid "5–7 questions every time" produces a slop-shaped interview. Match the depth to the founder's existing position. When in doubt, ask one calibration question — *"Do you have a sharp brand voice in mind, or are we working it out together?"* — and branch from there.

### 2. Interview the founder — calibrated to clarity branch

Pull from `references/prompt-bank.md`. The bank groups questions by branch (sharp / mostly-vibes / no-clarity) so you don't have to re-derive them. Some always-ask anchors regardless of branch:

- "Product name — locked, or 2–3 candidates on the table?"
- "Name 1–2 brands whose voice you'd RUN AWAY FROM. Why?" *(anti-patterns are easier to articulate than the positive ideal — start here when stuck)*
- "What's the single emotion the user should feel in the first 30 seconds?"

The interview is a transcript, not a quiz. Quote the founder verbatim where they're sharp. Push back when an answer is generic ("modern, friendly, professional" describes nothing — re-ask with examples).

### 3. Dispatch the synthesis sub-agent

Once the interview is captured, the parent calls `product_get_delegation_brief(5)` and dispatches an `Agent` sub-agent with the 5-field brief. The sub-agent's CONTEXT field includes:

- The concept brief path (`docs/concept-brief.md`)
- The captured interview transcript (parent inlines it in the brief or writes it to a temp file referenced in CONTEXT)
- The 5 references (full set; the sub-agent reads them as the writing template)

The sub-agent produces the brand-book.md artifact synthesising founder voice → brand-book sections. This shape mirrors step 4 (UX testing): parent gathers user input, sub-agent does the writing.

### 4. Synthesise — what the brand-book covers

Cover at minimum the schema's required sections:

- **Header line** — `**Version:** 1.0 | **Date:** YYYY-MM-DD` at the top. Brand books drift; the version + date are the audit trail.
- **Product name + positioning paragraph** — final name OR shortlist with one-line rationale per candidate.
- **Language section (NEW per spec 054)** — `## Language` H2 declaring `**target_language:** <bcp47>` (matches `.state.json.target_language` resolved at SKILL.md Phase 0.5). Single sentence stating which surfaces use the target language + which exemptions (code-flavored surfaces). Sub-agents read this as the machine-readable language signal — propagates to Step 14 design-system + Step 15 screen-writers.
- **Voice** — 1–2 paragraphs describing the voice. Concrete adjectives + what they look like in practice. Quote the founder verbatim where they were sharp.
- **We are / we are not** — at minimum **3 paired bullets** in the shape `**We are** <adjective>. **We are not** <near-adjacent-adjective-the-brand-rejects>.` (e.g. *"We are direct. We are not blunt."*). The contrast is what makes the guidance actionable; "we are direct" alone is a vague aspiration. Pull the contrast pairs from `references/we-are-we-are-not-bank.md` if the interview didn't surface them naturally.
- **Voice samples** — concrete short snippets the brand would actually say. **Calibrate count to product surface count**: 3 minimum (an error message + an onboarding welcome + a marketing tagline) for a single-purpose tool; 5–7 for a multi-surface platform (add support reply + paywall copy + empty-state hint + admin notification, picking the surfaces that matter most for the persona). The cap is honest: writing a sample for a surface that doesn't exist is filler.
- **Glossary section (NEW per spec 054)** — `## Glossary` H2 with two sub-sections (`### We say`, `### We don't say`), each a 4-column table: `| Term | Replacement | Reason | Applies to |` (see schema.md § Glossary shape for the exact format). Cap ≤ 20 entries per sub-section. Identify entries ORGANICALLY from concept-brief + positioning + product domain — domain-specific jargon the founder uses naturally, voice traps the comparables fall into, anglicisms the brand should localize. **DO NOT auto-derive from positioning Unlike-clause** — positioning operates at product-vs-product level ("we're not enterprise"), glossary operates at copy-trap level ("Most Popular → Mais escolhido"); pseudo-deriving one from the other produces noise, not signal. Downstream Step 15 screen-writers read `### We don't say` as a string-replace lookup; clear, scoped entries are worth more than completionist lists.
- **Visual direction** — paragraph naming the visual *feel* (e.g. "Cool Brutalist", "Warm Humanist", "Editorial Minimalist") plus any locked posture decisions (typography preference: serif vs sans? imagery posture: photography vs illustration vs none?). **Name the direction; do NOT specify hex codes, full type scale, or token files** — those are step 6 (design-system) deliverables. Single-number *posture* statements ARE allowed when they describe the visual stance (e.g. "hairline 1-px borders only", "corner radius capped at 2 px max", "no element below 12 px font size") because they express brutalist/minimalist/editorial *posture*; what the boundary rejects is enumerated *scale* (e.g. `borders: 1 / 2 / 4 / 8 px`, `H1 48px / H2 36px / Body 16px`, `space: 4/8/12/16/24/32 px`). Posture says "we don't soften with thicker borders"; scale says "use this token". Step 6 takes the posture and derives the scale.
- **Logo direction** — posture only, NOT execution. Cover: **clear space** (in logo units, e.g. `1× the logo's x-height on every side`), **minimum size** guidance (e.g. `24 px digital, 12 mm print` — directional, exact figures emerge in step 6 as tokens), **prohibited uses** (≥ 3 explicit, e.g. "never on busy photographic backgrounds without a contrast scrim", "never distorted/stretched", "never recolored outside the brand palette"). The actual logo *design* is a downstream task informed by this artifact.
- **Anti-patterns** — what the brand should NEVER sound like. 3–5 concrete bullets. "Never refer to users as 'guys'" is sharper than "be inclusive". Pair each anti-pattern with a counter-example where useful.
- **Color story** — color *names* + *feelings* (e.g. "Anchor on a single saturated cyan as the only on-signal; warm-near-black as the canvas; secondary cyan-tinted greys for hierarchy"). **NOT hex codes.** Hex + token names are step 6. Same posture-vs-scale distinction as Visual Direction applies: relative-lightness posture descriptions like "secondary text at roughly 70% lightness, tertiary at roughly 50%" describe hierarchy stance and ARE allowed; locking specific oklch / HSL values is NOT (`oklch(0.72 0.010 240)` is a token, not a story). When in doubt, say it the way the founder would describe it to a designer — "warm but a little cooler than parchment", not `#faf7f2`.

Recommended additional sections (use when they earn their place):

- **Comparables** — admired brand references with what's borrowed and what's deliberately rejected. Useful when the founder named brands during the interview.
- **Emotion target** — the single emotion the user should feel in the first 30 seconds. Useful when the founder named one sharply.

### 5. Submit + advance

Call `product_step_submit` with `filename: "brand-book.md"`, `content: <the brand book>`. Layer 1 validates section presence + the version-line floor + the `**We are**`/`**We are not**` and logo anchors.

Step 5 is mid-Identity. No gate yet. After a clean submit, `product_advance` moves to step 6 (design-system) — synthesis-mode, fully delegable. Step 6 reads the brand-book and produces the actual tokens (hex codes, type scale, token files) the visual-direction line named.

---

## Voice & rigor

- **Brand books that say "modern, friendly, professional" describe nothing.** If you can swap your words with another product's brand book, the words aren't doing work.
- **Voice anti-patterns are as valuable as voice patterns.** "Never refer to users as 'guys'" is sharper than "be inclusive".
- **"We are / we are not" pairs are the discipline that makes voice actionable.** A list of adjectives is a wishlist; a contrast is a decision. Insist on the contrast even when the founder gives you a flat list.
- **Quote the founder verbatim.** When the founder said something sharp in the interview, put it in the artifact. Translation flattens.
- **Founder vision and target audience can be in tension** (founder wants edgy, audience is conservative). When they conflict, name it explicitly and pick a posture — don't paper over.
- **Brand book ≠ design system.** Brand is voice, feel, name, positioning, logo posture, color *story*. Design system is tokens, components, type scale, hex codes. Step 6 follows from step 5; the boundary is intentional.

## What this step does NOT do

- **Hex codes / type scale / spacing tokens.** That's step 6 (design-system).
- **Logo execution.** This step names the visual DIRECTION and the logo POSTURE (clear space, prohibited uses); the actual logo design is a downstream design task informed by this artifact.
- **Marketing copy for landing page / app store / etc.** That's the GTM step (future MCP).
- **Brand consistency audit across channels.** Audit is a recurring downstream activity, not a step-5 mode. Step 5 is the FIRST brand pass on a new product.

## What this step replaces

This template ports the archived `anthill-brand-designer` skill (see `.claude/memory/anthill-archived.md`) — Brand Book section: brand story, personality traits, color palette, typography, logo rules, imagery, voice. The deep port keeps the discipline (every visual choice rooted in a personality trait, "we are / we are not" pairs, prohibited-uses mandate, version control) while reframing for the multi-step pipeline:

- **Mode shift.** Anthill's brand-designer was a single-orchestrator skill (one agent, interview + synthesis + write all in one shape). The MCP port splits it: parent owns the founder dialogue (cannot delegate — it's posture, not writing), sub-agent owns the synthesis (clear template, ideal for delegation). Mirrors the step-4 split.
- **Calibrated interview.** Anthill ran a fixed-shape Step 1 ("read company values, identify personality traits"). The port adds founder-clarity branching — sharp-vision founders get 2–3 deepening probes; no-clarity founders get 7–9 foundational probes. The interview shape adapts to the input.
- **Boundary preservation.** Anthill's brand-book embedded hex codes (`#1A56DB`) and typography scale (`Inter Bold 48px / 56px line-height`) directly in the brand book. The MCP port deliberately defers all of that to step 6 — the brand book names visual direction and color story, step 6 derives the tokens. Cleaner pipeline, no duplication, brand-book stays voice-shaped.
- **Audit mode dropped.** Anthill had a `brand-audit.md` mode for channel-consistency reviews. That's a recurring downstream activity, not a step-5 use. Step 5 is the FIRST brand pass; audits live elsewhere.

Anthill's runtime scaffolding — `.anthill/COMPANY.md` reads, `docs/sdlc/` paths, the deliverable-registry hook — does not port. Resumability is `product_status` + `.state.json`; the halt protocol is the `schema-incomplete` validation error.
