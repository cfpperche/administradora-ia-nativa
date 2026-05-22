# `functional-spec.md` — output template

The full shape for the primary step-3 artifact. Every section traces to the concept brief (step 1) or the prototype directions (step 2) — do not invent surfaces, components, or features the prior artifacts did not establish. Section headings are load-bearing: the H2 titles below slugify to the required-sections list in `schema.md`, and several are also `contains` anchors in Layer 1. Keep the casing exactly as written.

```markdown
# {Product Name} — Functional Spec

**Generated:** {date} | **Pipeline step:** 3 (spec) | **Mode:** synthesis
**Source artifacts:** `01-ideation/04-concept-brief.md`, `02-prototype/<slug>/`
**Status:** Draft — behavioral contract for steps 4 (ux-testing) + 8 (PRD)

## Product Overview

{3–5 sentences. What the product does, who it is for, the core value. A non-technical
stakeholder reads this and understands the product. Traceable to the concept brief's
JTBD and target persona — no drift.}

## Pages & Surfaces

One subsection per distinct page/screen/surface. Include the easy-to-forget ones:
landing/marketing, auth (login, signup, forgot-password), settings/profile,
admin/backoffice, the empty first-run state.

### {Page Name}

**Purpose:** {one sentence — why this page exists}
**Entry points:** {how the user gets here — nav link, button, redirect, deep link}

**Wireframe:**

\`\`\`
+--------------------------------------------------+
| {ASCII layout sketch — header, sidebar, main,   }|
| {regions named. Rough is fine; it anchors the   }|
| {component table below to a spatial model.      }|
+--------------------------------------------------+
\`\`\`

**Components:**

| Component | Type | Description |
|-----------|------|-------------|
| {Sidebar} | navigation | {what it contains, where it links} |
| {ProjectList} | data-display | {what data, what shape} |
| {CreateButton} | action | {what it triggers} |
| {SearchBar} | input | {what it filters/searches} |
| {EmptyState} | feedback | {what it shows when there is no data} |

Type ∈ `navigation` · `data-display` · `action` · `input` · `feedback` · `modal` · `form` · `media`.
List **every** interactive element, including the "obvious" ones.

**Interactions:**

| Component | Trigger | Action | Result |
|-----------|---------|--------|--------|
| {CreateButton} | click | opens modal | {new-project form appears} |
| {ProjectCard} | click | navigates | {opens Project Detail} |
| {SearchBar} | type | filters list | {ProjectList updates in real time} |
| {DeleteButton} | click | confirmation | {"Are you sure?" dialog appears} |

Trigger / action / result all concrete. Never "user can manage projects".

**States:**

| State | Condition | What the user sees |
|-------|-----------|-------------------|
| Empty | no data yet | {illustration + call-to-action} |
| Loading | fetching | {skeleton cards / shimmer} |
| Error | load failed | {error message + retry} |
| Populated | data present | {normal content} |
| {Filtered-empty} | filter has no matches | {"no matches" + clear-filter} |

Minimum empty / loading / error / populated for every page. Add filtered-empty,
permission-denied, offline where they apply.

{repeat the ### {Page Name} block for every page}

## Features

One block per feature. A feature is "user can do X in context Y producing outcome Z".
Be exhaustive within the prototype's complexity budget; no invented features.

### {Feature name}

- **What it does:** {one sentence}
- **Happy path:** {sequenced — 1. user action → system response; 2. …}
- **Edge cases:** {only the ones that actually apply — empty input, validation
  failure, network failure, race condition, permission denial, oversized input}
- **Success criterion:** {observable evidence the feature works — feeds step 4 tests
  and step 8 PRD acceptance criteria}

{repeat for every feature}

## Navigation Map

\`\`\`
Landing
   | (sign up / log in)
Dashboard <--> Settings
   | (click project)
Project Detail <--> Project Settings
\`\`\`

ASCII diagram covering every page transition and its trigger. No orphan pages.

## Cross-Cutting Concerns

One paragraph each, only for the concerns that apply:

- **Auth model** — anonymous / login / roles+RBAC; what gates what.
- **Data persistence** — local / remote / sync semantics / offline behavior.
- **Accessibility** — screen-reader expectations, keyboard navigation, focus order.
- **Internationalization** — if the product ships in more than one language.

Shape, not system design — the deep treatment is step 9.

## Acceptance Scenarios

For every feature with 3+ behavior branches, 2–4 Gherkin scenarios — happy + error +
edge minimum. Keywords bolded so the section is greppable.

### Scenario: {short title}

- **Given** {precondition — state that holds}
- **When** {action that triggers the behavior}
- **Then** {observable, assertion-shaped outcome — specific text/value/status/file}

{repeat — every Then must be checkable by a verifier; "works correctly" is not a Then}

## Edge Cases & Error States

Cross-page failure / boundary scenarios that apply to this product specifically — not
a generic checklist. Each: the trigger, what the user sees, the recovery path.

## Non-Goals

Features deliberately out of v1, each with a one-line reason. Traceable to the concept
brief's anti-goals. "NOT {x} — because {why this would hurt v1}".

## Decisions Pending

| # | Question | Impact | Default if unresolved |
|---|----------|--------|----------------------|
| 1 | {open product question in plain language} | {which pages/flows affected} | {what step 8 should assume} |

If there are genuinely no open decisions, write instead:

> No open decisions — all design choices are resolved in this spec.

This table is the handoff contract `anthill-prd`'s successor (step 8) consumes — each row
becomes a resolved requirement with a `from spec decision #N` back-reference.
```

## Notes on using this template

- **Write the functional spec first, then derive `architecture.md` from it.** The architecture artifacts are extractions, not parallel authoring — see `architecture-shape.md`.
- **Product language here.** "Saves your changes", "updates in real time", "remembers your choice" — never "POSTs to the API", "writes to the store", "middleware". Technical vocabulary belongs in `architecture.md`.
- **One section per page** — never "Dashboard and Settings" combined. Scannability is the point.
- **The `## Decisions Pending` table is mandatory** even when empty — the empty-state line is a deliberate signal, not an omission.
- A non-trivial product fills well past the 15 KB Layer-1 floor once every page carries three tables and every multi-branch feature carries Gherkin scenarios. If you are struggling to reach 15 KB, you are probably missing pages, states, or features — re-read step 2's screens.
