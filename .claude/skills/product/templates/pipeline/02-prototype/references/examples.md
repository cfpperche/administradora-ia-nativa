# Examples — good vs bad mockup patterns + REPORT walkthrough

Two halves: snippet-level good/bad markup, then a worked example of REPORT.md's 5-dim critique section.

---

## Good vs bad mockup patterns

### Good — realistic dashboard card with brief-sourced data

```html
<div class="metric-card">
  <span class="label">Saldo de Tokens</span>
  <span class="value">12 🪙</span>
  <span class="trend">renovação em 14 dias</span>
</div>
```

Notice: real product surface (token economy), real label in product's language (PT-BR), real measurement, real next-state cue. No filler.

### Bad — generic placeholder

```html
<div class="card">
  <span>Title</span>
  <span>Value</span>
  <span>Change</span>
</div>
```

Notice: "Title" / "Value" / "Change" are placeholder labels with no product context. This is the dominant failure mode of AI-generated mockups — the structure is right but the content is empty calories.

---

### Good — responsive grid using tokens

```css
.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: var(--space-lg, 1.5rem);
  max-width: 1280px;
  margin: 0 auto;
  padding: 0 var(--space-md, 1rem);
}
```

Notice: token references with fallback values, max-width-not-fixed-width, `gap` (not margin) for card spacing.

### Bad — fixed-width layout with hardcoded values

```css
.dashboard-grid {
  width: 1200px;
  display: flex;
  margin: 0;
}
.dashboard-grid > .card {
  width: 280px;
  margin-right: 24px;
}
```

Notice: fixed width breaks responsive, hardcoded margins instead of `gap`, `width: 280px` is not flex-friendly.

---

### Good — Core Value as primitive

A direction's hero copy that grounds in the brief's Core Value layer:

```html
<h1>Caixa de triagem para vagas que valem a pena.</h1>
<p>
  Cole a vaga. Pegue o briefing + 3 pontos de risco em 30 segundos —
  sem otimização de CV automática, sem narrativa motivacional.
</p>
```

Notice: names a primitive ("triage inbox for jobs worth applying to"), not a feature list ("CV optimization, interview prep, salary tracking"). One sentence that defines what the product IS, not what it DOES.

### Bad — feature-soup hero

```html
<h1>The all-in-one platform for your career success.</h1>
<p>
  AI-powered CV optimization, mock interviews, salary insights, company research,
  application tracking, and personalized coaching — everything you need to land your dream job.
</p>
```

Notice: feature dump, generic "all-in-one platform" framing, "AI-powered" without grounding, "dream job" motivational copy. Reads as template-land.

---

## REPORT walkthrough — 5-Dim Critique section

Example shape for `## 5-Dim Critique Pre-Emit Scores`:

```markdown
## 5-Dim Critique Pre-Emit Scores

| Direction | Philosophy | Hierarchy | Execution | Specificity | Restraint | Min |
|-----------|-----------|-----------|-----------|-------------|-----------|-----|
| A — Operador Silencioso | 4/5 | 4/5 | 4/5 | 4/5 | 4/5 | **4** ✓ |
| B — Calma Estratégica | 4/5 | 5/5 | 4/5 | 4/5 | 5/5 | **4** ✓ |
| C — Ferramenta de Precisão | 5/5 | 4/5 | 4/5 | 4/5 | 4/5 | **4** ✓ |

All directions cleared the ≥ 3/5 threshold on all dimensions. No fix pass required before emit.

**Critique notes:**
- **Direction A Execution −1:** dark-mode palette relies on system-font rendering quality; on Windows ClearType the text may feel slightly heavier than intended. Mitigatable in Turn 2 with explicit `font-smoothing: antialiased`.
- **Direction B/C Execution −1:** serif display (Iowan Old Style) is macOS system font; fallback to Georgia on Windows is visually acceptable but not identical. Full Turn 2 pass would load Newsreader from Google Fonts (still optional — system fallback acceptable for mood board).
- **Direction A/C Philosophy 4 (not 5):** both directions sit close to their school (modern-minimal for A, custom Notion×Stripe for C) but neither pushes the school to a novel extreme. A 5 requires the direction to make a statement, not just be competent.
```

The critique notes section is REQUIRED when any score is < 5. They turn the table into a calibrated audit rather than a self-congratulation: "Yes I scored 4/5, here's the specific reason it isn't 5."

---

## REPORT walkthrough — Anti-AI-Slop Audit section

Example shape for a Brazilian token-economy product:

```markdown
## Anti-AI-Slop Audit

| Rule | A | B | C |
|------|---|---|---|
| No aggressive purple/violet gradient bg | ✓ | ✓ | ✓ |
| No generic emoji feature icons (✨ 🚀 🎯) | ✓ | ✓ | ✓ |
| No rounded card with left-border accent as default | ✓ | ✓ | ✓ |
| No hand-drawn SVG humans | ✓ | ✓ | ✓ |
| Inter/Roboto/Arial as body only, not display | ✓ | ✓ | ✓ |
| No invented metrics without brief source | ✓ | ✓ | ✓ |
| No filler copy (lorem / "Feature One") | ✓ | ✓ | ✓ |
| No motivational copy ("campeão" / "você consegue") | ✓ | ✓ | ✓ |
| Pix QR Code prominent (BR fintech) | ✓ | ✓ | ✓ |
| LGPD footer link present | ✓ | ✓ | ✓ |
| Token cost badge on actions (`X · 3🪙`) | ✓ | ✓ | ✓ |

All 11 anti-slop checks pass across all 3 directions.
```

Rules 9-11 are conditional (Brazilian / token-economy). For a non-Brazilian non-token product, those rows are absent from the table entirely.

---

## REPORT walkthrough — Brief Compliance Check

Example for a fintech-adjacent product brief:

```markdown
## Brief Compliance Check

| Brief requirement | Addressed |
|-------------------|-----------|
| Dark-default + light toggle | Dark native in A; light native in B/C; toggle is Turn 2 fidelity work |
| Saldo sempre visível no header | ✓ all 3 — amber pill in topbar |
| Custo visível antes do clique | ✓ all 3 — action badges on cards |
| Mobile-first layout | ✓ — responsive grid, `@media` collapse at 640–700 px |
| Pix-first payment (branding) | ✓ — hero trust row + footer mention Pix |
| LGPD link | ✓ all 3 — footer |
| Verde-musgo palette (Direction B specifically) | ✓ — `oklch(52% 0.14 145)` maps to brief's `#2D5C3F` range |
| Âmbar accent for tokens | ✓ all 3 |
| PT-BR copy | ✓ — all text in PT-BR |
| No "Vamos lá, campeão!" copy | ✓ — neutral, direct copy throughout |
```

Every brief requirement maps to specific evidence ("amber pill in topbar", "footer trust row"). Generic checks ("yes, mobile-responsive") fail this section — the auditor wants the breadcrumb.

---

## REPORT walkthrough — Turn 2 Plan

Example for a job-application-tracking product:

```markdown
## Turn 2 Plan

The 8 hi-fi screens that will render for whichever direction the user picks:

1. `01-landing.html` — full marketing landing: hero "caixa de triagem para vagas que valem a pena" + 3 value sections (com mockup do dashboard live) + pricing table (R$ 19,90 / 49,90 / 99,90) + FAQ (6 itens) + LGPD footer
2. `02-onboarding.html` — wizard 4 etapas: situação (1) → cargo-alvo (2) → upload CV (3) → localização (4) → tela final com 5 🪙 grátis
3. `03-dashboard.html` — kanban de 5 colunas (Inbox / Avaliando / Aplicado / Entrevista / Resultado) com cards mostrando aderência, salário, modalidade, ações com custo em tokens
4. `04-wallet.html` — saldo + gráfico 30 dias + 3 pacotes (Pix QR inline) + histórico 8 linhas
5. `05-cv-editor.html` — side-by-side diff (adições vs remoções) + keyword chips + 3 gap warnings + export
6. `06-interview.html` — Modo Briefing (4 blocos STAR) + Modo Role-play (conversa 5 turnos) + feedback card
7. `07-company-research.html` — resumo da empresa + 3 fatos recentes + cultura tags + 3 sinais de alerta + 3 perguntas inteligentes
8. `08-tracker.html` — timeline table de vagas + reminders strip + calendário do mês

Each screen exercises a specific mechanic from the concept brief's `## Mechanics Breakdown` (Core Value layer covers screens 03/05/06; Growth layer covers 01/02; Moat layer covers 07/08).
```

The Turn 2 plan ties screens to brief mechanics. Generic "we'll do a landing, dashboard, settings" plans don't pass this section — the auditor wants the brief-source for each screen.
