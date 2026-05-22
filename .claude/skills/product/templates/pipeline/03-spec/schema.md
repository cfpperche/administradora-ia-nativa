# Step 3 — Schema (spec bundle)

Step 3 submits a **three-artifact bundle**: `functional-spec.md` (primary `content`) plus `architecture.md` and one of `architecture.html` / `architecture.json` (via `extra_files`). Two validation layers fire on `product_step_submit`:

1. **Section check** — the primary `functional-spec.md` must carry level-2 markdown headings (`## <Title>`) whose slugs match the required-sections list below.
2. **Layer 1** — every file in the bundle must satisfy the `required_files` / `required_glob` floor in the JSON fenced block (path present, `min_size`, `contains` substrings).

A failure in either layer produces `code: "schema-incomplete"` with the precise failure list; nothing is written until the whole bundle passes.

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains, enforced at submit by the Layer 1 block below.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `functional-spec.md` (combined v3 layout) | 12 KB | below this, pages / states / features are missing |
| `architecture.md` (skeleton) | 4 KB | the skeleton must still cover all four sections |

A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Required sections (markdown headings in `functional-spec.md`)

Each name slugifies by lowercasing + dashing the H2 title — `## Pages & Surfaces` → `pages-surfaces`, `## Cross-Cutting Concerns` → `cross-cutting-concerns`. Match these slugs precisely.

- product-overview
- pages-surfaces
- features
- navigation-map
- cross-cutting-concerns
- acceptance-scenarios
- edge-cases-error-states
- non-goals
- decisions-pending

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "functional-spec.md",
      "min_size": 12288,
      "contains": [
        "## Pages & Surfaces",
        "## Features",
        "## Navigation Map",
        "## Acceptance Scenarios",
        "## Decisions Pending",
        "**Given**",
        "**When**",
        "**Then**",
        "| Component |",
        "| State |"
      ]
    },
    {
      "path": "architecture.md",
      "min_size": 4096,
      "contains": [
        "## Module Decomposition",
        "## Data Model",
        "## Key Flows",
        "## Integration Points"
      ]
    }
  ],
  "required_glob": [
    {
      "pattern": "architecture.[hj][a-z]*",
      "min_count": 1
    }
  ]
}
```

- `functional-spec.md` `min_size: 12288` (12 KB) — lowered from the spec-026 deep-port floor of 15 KB per spec 056 calibration. A non-trivial product's behavioral contract lands well above the new floor once every page has component / interaction / state tables and features carry Gherkin scenarios. A spec under 12 KB is almost certainly missing pages, states, or features. (Empirical: 3-dogfood pass landed 22-65 KB; the old 15-KB floor blocked compact-product variants that genuinely belonged in the 12-15 KB range.)
- `functional-spec.md` `contains` anchors the page-discipline tables (`| Component |`, `| State |`), the Gherkin keywords (`**Given/When/Then**`), and the load-bearing section headings the slug check alone can't pin to a *specific* casing.
- `architecture.md` `min_size: 4096` — the structural skeleton is terse by design (step 9 deepens it) but must still cover all four sections with real content.
- `required_glob` `architecture.[hj][a-z]*` with `min_count: 1` expresses the **"one of"** constraint: the extension must start with `h` or `j` (`[hj]`) followed by ≥1 more letter — matching `architecture.html` *or* `architecture.json` while excluding `architecture.md`. (`[hj]*` does *not* work — a `*` immediately after a `]` is parsed as a char-class quantifier, not a wildcard; the trailing `[a-z]*` is the wildcard.) `min_count: 1` requires at least one rendered-or-machine-readable architecture artifact. No `per_match_contains` because the two file types have categorically different content.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; *depth* is the agent's responsibility, reinforced by `references/`.

### `functional-spec.md`

- **product-overview** — 3–5 sentences: what it does, who it's for, the core value. Traceable to the step-1 concept brief.
- **pages-surfaces** — one subsection per page: name, purpose, entry points, ASCII wireframe, then three tables — Components (`| Component | Type | Description |`), Interactions (`| Component | Trigger | Action | Result |`), States (`| State | Condition | What the user sees |`). Every interactive element listed; every page has at minimum empty/loading/error/populated states.
- **features** — one block per feature: what it does (one sentence), happy-path behavior (sequenced user actions + system responses), edge cases (the ones that *apply*), success criterion (observable). Exhaustive within the prototype's scope; no invented features.
- **navigation-map** — ASCII diagram covering every page transition and its trigger.
- **cross-cutting-concerns** — auth, persistence, a11y, i18n — one paragraph each, only where they apply. Shape, not system design.
- **acceptance-scenarios** — 2–4 `**Given**` / `**When**` / `**Then**` scenarios for each feature with 3+ behavior branches; happy + error + edge minimum. Every `Then` assertion-shaped.
- **edge-cases-error-states** — the cross-page failure / boundary scenarios that actually apply (not a generic checklist).
- **non-goals** — features deliberately out of v1, each with a reason. Traceable to the concept brief's anti-goals.
- **decisions-pending** — `| # | Question | Impact | Default if unresolved |` table (or the explicit empty-state line). The handoff contract step 8 (PRD) parses.

### `architecture.md`

- **Module Decomposition** — frontend pages/components → backend modules/services; mark new vs. extend. Module names, not technology names.
- **Data Model** — entities, relationships, key fields — informal prose/tables, no SQL DDL or migration syntax (that's step 9).
- **Key Flows** — the killer flow traced through the modules, numbered steps or a sequence sketch.
- **Integration Points** — external systems named, what is called, fallback posture.
- **Open Architecture Questions** — what is genuinely deferred to step 9 (scale, deployment, stack-specific choices). Optional heading, recommended — it is the explicit step-9 handoff.

### `architecture.html` / `architecture.json`

Derived from `architecture.md` — same modules, entities, flows. `architecture.html` renders the graph (mermaid block or inline `<svg>`); `architecture.json` is `{ "modules": [...], "entities": [...], "flows": [...], "integrations": [...] }`. Pick whichever serves the downstream reader; both stay in sync with `architecture.md` by derivation.
