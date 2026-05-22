# Architecture artifacts — shape & derivation chain

Step 3 ships a **preliminary** architecture skeleton, not a system design. Two artifacts beyond the functional spec:

- `architecture.md` — the structural shape, in prose + tables
- `architecture.html` **or** `architecture.json` — the same shape, rendered or machine-readable

Both are **derived from `functional-spec.md`** — you do not author them in parallel. The derivation chain is what keeps the three files in sync: write the functional spec, read it back, extract the structure once into `architecture.md`, then project `architecture.md` into the html/json view.

```
functional-spec.md  ──derive──>  architecture.md  ──project──>  architecture.{html,json}
   (behavior)                      (structure)                    (diagram / graph)
```

If any downstream file disagrees with its source, that is a defect — re-derive, don't patch.

## Where step 3 stops and step 9 starts

| Concern | Step 3 (`architecture.md`) | Step 9 (`system-design.md`) |
|---|---|---|
| Module / component decomposition | ✅ named, new-vs-extend | ✅ refined, with responsibilities |
| Data model | ✅ entities + relationships + key fields, informal | ✅ full schema, types, indexes, migrations |
| Flows | ✅ the killer flow through modules | ✅ all flows, with failure paths |
| Integrations | ✅ named, what is called, fallback posture | ✅ contracts, rate limits, auth, retries |
| Technology / stack | ❌ — module names, not tech names | ✅ chosen stack, versions, rationale |
| Scale / deployment topology | ❌ → `## Open Architecture Questions` | ✅ |
| Security / threat model | ❌ → `## Open Architecture Questions` | ✅ OWASP, threat model |

Step 3 names *what the parts are*. Step 9 decides *what they are built with and how they run*. The `## Open Architecture Questions` section in `architecture.md` is the explicit handoff — every deferral is listed, so step 9 inherits a checklist, not a guess.

## `architecture.md` structure

Four required H2 sections (all are Layer-1 `contains` anchors — keep the casing) plus one recommended:

```markdown
# {Product Name} — Architecture (preliminary)

**Derived from:** `functional-spec.md` | **Pipeline step:** 3
**Status:** Preliminary skeleton — step 9 (system-design) deepens this

## Module Decomposition

Frontend pages/components → backend modules/services. Mark each new or extend-existing.
Module names, not technology names ("Auth module", not "NextAuth").

| Module | Layer | New / Extend | Responsibility |
|--------|-------|--------------|----------------|
| {Auth} | backend | new | {sign-up, login, session} |
| {ProjectStore} | backend | new | {CRUD for projects} |
| {Dashboard} | frontend | new | {project list + filters} |

## Data Model

Entities, relationships, key fields — informal. No SQL DDL, no Prisma schema, no
migration syntax (that is step 9).

- **{Entity}** — {key fields}; relates to {Entity} as {1:N / N:M}.
- **{Entity}** — {key fields}; owned by {Entity}.

A small ASCII entity sketch is welcome:

\`\`\`
User 1───N Project 1───N Task
\`\`\`

## Key Flows

The killer flow (named in the concept brief / functional spec) traced through the
modules. Numbered steps or a sequence sketch.

1. User submits {form} on {page} → {Module} validates → {Module} persists {Entity}
2. {Module} emits {event} → {Module} updates {surface}
3. ...

## Integration Points

External systems named, what is called, fallback posture.

| System | What we call | Fallback if unavailable |
|--------|--------------|-------------------------|
| {Stripe} | {checkout session} | {queue + retry; block submit} |

## Open Architecture Questions

Everything deferred to step 9 — scale assumptions, deployment topology, stack choice,
security/threat model, caching, background jobs. One bullet each; this is the step-9
handoff checklist.

- [ ] {question deferred to system-design}
```

## `architecture.html` — the rendered view

A single self-contained HTML file that renders the architecture as a diagram. Two acceptable techniques:

**Mermaid** (preferred — concise, diffable source):

```html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>{Product} — Architecture</title></head>
<body>
  <pre class="mermaid">
graph TD
  Dashboard[Dashboard / frontend] --> ProjectStore[ProjectStore / backend]
  ProjectStore --> DB[(Project · Task · User)]
  Auth[Auth / backend] --> DB
  ProjectStore --> Stripe{{Stripe}}
  </pre>
  <script type="module">
    import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
    mermaid.initialize({ startOnLoad: true });
  </script>
</body>
</html>
```

**Inline `<svg>`** — when you want full layout control or want the file to render with no network. Hand-draw module boxes + flow arrows as `<rect>` / `<line>` / `<text>`.

Either way: every module from `architecture.md`'s decomposition table is a node, every entity is a node (or a grouped data store), every key-flow edge is an arrow. A reader opens this file and sees the structure at a glance.

## `architecture.json` — the machine-readable view

When the downstream consumer is tooling rather than a human eye, ship JSON instead of HTML. Shape:

```json
{
  "product": "{slug}",
  "derived_from": "functional-spec.md",
  "modules": [
    { "name": "Auth", "layer": "backend", "status": "new", "responsibility": "sign-up, login, session" },
    { "name": "ProjectStore", "layer": "backend", "status": "new", "responsibility": "CRUD for projects" },
    { "name": "Dashboard", "layer": "frontend", "status": "new", "responsibility": "project list + filters" }
  ],
  "entities": [
    { "name": "User", "key_fields": ["id", "email"], "relations": [{ "to": "Project", "kind": "1:N" }] },
    { "name": "Project", "key_fields": ["id", "name", "status"], "relations": [{ "to": "Task", "kind": "1:N" }] }
  ],
  "flows": [
    { "name": "create-project", "steps": ["Dashboard submits form", "ProjectStore validates", "ProjectStore persists Project"] }
  ],
  "integrations": [
    { "system": "Stripe", "calls": "checkout session", "fallback": "queue + retry" }
  ]
}
```

## Choosing html vs json

- **`architecture.html`** when a human will review the architecture (the common case) — the diagram is the value.
- **`architecture.json`** when a later automated step or external tool will consume the graph — structure over presentation.

Layer 1 requires at least one of them (`required_glob: architecture.[hj][a-z]*`, `min_count: 1`). Shipping both is allowed but not required; if you ship both, they must still agree with `architecture.md`.

## Sync discipline

The three artifacts are one truth in three projections. Concretely:

- Every module in `architecture.html`/`json` appears in `architecture.md`'s decomposition table.
- Every entity in the json `entities` array appears in `architecture.md`'s Data Model.
- Every flow edge in the diagram traces to a step in `architecture.md`'s Key Flows.
- Every module/entity/flow in `architecture.md` traces back to a page, component, or feature in `functional-spec.md`.

A mismatch anywhere means the derivation chain was broken — re-derive from the source, do not hand-reconcile.
