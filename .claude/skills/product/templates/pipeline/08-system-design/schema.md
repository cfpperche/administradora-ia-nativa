# Step 9 — Schema (system-design bundle)

Step 9 submits a **three-artifact bundle**: `system-design.md` (primary `content`) plus `architecture.json` and `security.md` (via `extra_files`). Two validation layers fire on `product_step_submit`:

1. **Section check** — the primary `system-design.md` must carry level-2 markdown headings (`## <Title>`) whose slugs match the required-sections list below.
2. **Layer 1** — every file in the bundle must satisfy the `required_files` floor in the JSON fenced block (path present, `min_size`, `contains` substrings).

A failure in either layer produces `code: "schema-incomplete"` with the precise failure list; nothing is written until the whole bundle passes.

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains, enforced at submit by the Layer 1 block below.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `system-design.md` (bridge-floor + RACI + Risk Register) | 15 KB | below this the 11 required sections are not at honest depth |
| `architecture.json` | 256 B | catches `{}` / near-empty graph regressions |
| `security.md` | 3 KB | below this the threat model was punted |

A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Required sections (markdown headings in `system-design.md`)

Section names slugify by lowercasing + dashing the H2 title — `## Data Model` → `data-model`, `## Non-Functional` → `non-functional`. Cosmetic variants (trailing punctuation, parenthetical suffixes) are accepted; slugifier strips them.

- `overview`
- `stack`
- `services`
- `data-model`
- `apis`
- `integrations`
- `deployment`
- `non-functional`
- `evaluation`
- `alternatives-considered`
- `trade-off-triggers-open-decisions` (one H2 with two H3 children: `### Trade-off triggers (digest)` prose digest + `### Open decisions (table)`; Locked-decisions tables are intentionally NOT a sub-section — locked choices live in the running prose of § Stack / § Integrations / § Deployment / § Non-Functional)

## Optional sections (not enforced, produced when applicable)

- `diagrams` — text/mermaid topology diagrams ABOVE the architecture.json component graph; useful for sequence-flow visualisation that the JSON shape doesn't carry
- `compliance-pointers` — when domain regulation (HIPAA, PCI, SOC 2) is in scope; cross-references security.md and step 12 legal-posture
- `migration-plan` — only when the v1 is replacing an existing system (rare for v1; more common for v2 specs that re-enter the pipeline)

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "system-design.md",
      "min_size": 15360,
      "contains": [
        "## Overview",
        "## Stack",
        "## Services",
        "## Data Model",
        "## APIs",
        "## Integrations",
        "## Deployment",
        "## Non-Functional",
        "## Evaluation",
        "## Alternatives Considered",
        "## Trade-off Triggers & Open Decisions",
        "### Trade-off Triggers",
        "### Open Decisions",
        "| Dimension | Assessment | Concern Level |",
        "| Method | Path |",
        "| # | Question | Deciding signal |"
      ],
      "any_of_contains": [
        "Low",
        "Medium",
        "High"
      ]
    },
    {
      "path": "architecture.json",
      "min_size": 256,
      "contains": [
        "\"title\"",
        "\"components\"",
        "\"arrows\"",
        "\"summary_prose\""
      ]
    },
    {
      "path": "security.md",
      "min_size": 3072,
      "contains": [
        "## Threat Model",
        "## Auth",
        "## Data Classification",
        "## Secrets",
        "## Regulated Aspects"
      ]
    }
  ]
}
```

### Notes on the floors

- **`system-design.md` `min_size: 15360` (15 KB)** — lowered from spec 026's 20 KB per spec 056 calibration (dogfood-v3 legitimately landed at 15.2 KB; the old 20-KB floor would have BLOCKED it). Floor anchored against the 11 required sections at honest depth. Step 3's `architecture.md` floor is 4 KB for 4 sections (the *skeleton*); step 9 deepens those 4 sections AND adds 7 new ones (services, APIs, deployment, non-functional, evaluation, alternatives, triggers-and-open-decisions). A 5x multiplier on section count + design rigor (evaluation table, trade-offs, alternatives with reason, decision-triggers digest) lands at 20 KB minimum. SMB SaaS and venture-scale typically 22-28 KB; micro-products may legitimately land under (use the `# OVERRIDE: compact-product: <class>` shape in the prompt's submit context).

- **The literal pipe-delimited row `| Dimension | Assessment | Concern Level |`** — proves the evaluation table carries the canonical 3-column shape from `anthill-principal-engineer § Step 3`. A system-design that ships evaluation as prose bullets (anti-pattern: "**Simplicity**: medium" line-items) trips Layer 1 — the table is the visual contract and forces the agent to put a concern level on every dimension. The literal row only appears as a real markdown table header.

- **The literal `| Method | Path |` substring** — proves the APIs section carries a structured endpoint catalog (markdown table with `Method | Path | Contract intent | Source`), not paragraph prose. Without this floor, the section silently degrades into "the app has CRUD endpoints" — useless to engineering. The `Source` column is what cross-references PRD user-story IDs (`US-NN`); a row without a `Source` is a discipline failure caught at the prompt-rigor layer.

- **The literal `| # | Question | Deciding signal |` substring** — proves the Open Decisions sub-section carries the canonical 4-column table shape (`# | Question | Deciding signal | Closes by`) and not loose prose bullets. Open decisions without a `Deciding signal` column are the regression mode this anchor catches — see prompt § 11 for the discipline (every deferred decision names what closes it; rows without a deciding signal are red flags).

- **The H3 anchors `### Trade-off Triggers` and `### Open Decisions`** — prove the digest+table layout for § 11 is honored: the prose Trade-off Triggers digest (4-bullet load-bearing scan) precedes the Open Decisions table (audit-trail receipt). Spec 026 Phase B post-task-18 calibration (2026-05-16) introduced this layout in response to anthill-judge feedback that the MCP's deferral list lacked a scannable digest; the schema enforces presence of both children so the layout doesn't silently regress into "Open table only" (loses the digest) or "Triggers prose only" (loses the audit trail).

- **`any_of_contains: ["Low", "Medium", "High"]`** — at least one concern level must appear in the file (cheap presence check for the evaluation table's third column). If the agent ships the table headers without filling the Concern Level cells, this fires.

- **`architecture.json` `min_size: 256`** — a minimal valid component graph with title + summary_prose + 3 components + 2 arrows lands around 400-600 bytes. The 256-byte floor catches "agent emitted `{}`" or "agent emitted `{\"title\":\"x\"}`" regressions while accommodating compact-product graphs (4 components total). `contains` enforces the four top-level keys (`title`, `components`, `arrows`, `summary_prose`); a graph missing any of these fails Layer 1 before downstream tooling (or the future HTML renderer) trips on it.

- **`security.md` `min_size: 3072` (3 KB)** — anchored against the 5 required sub-sections at honest depth. Threat model alone (STRIDE-lite × this product's surface) is 4-6 paragraphs; auth/authz + data classification + secrets handling + regulated aspects together carry the rest. A `security.md` under 3 KB is almost certainly a bullet-skeleton that punted on the threat model. SMB SaaS and venture-scale typically 5-10 KB; micro-products may legitimately land at 3-4 KB.

- **No `required_glob`** — three exact-path files; no globbed artifact sets in this step.

- **Dogfood lesson inherited from steps 7 + 8 (2026-05-15/16):** loose section-name substrings (`Threat`, `Auth`, ...) are silently fakeable from prose. Step 9's Layer 1 uses the literal H2 heading anchors (`## Threat Model`, `## Auth`, ...) — mirrors step 7's `| Token | Voice | ...` fix and step 8's `## Audit Response` discipline. The literal heading only appears as a real markdown section header.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; *depth* is the agent's responsibility, reinforced by `references/architecture-shape.md`.

### `system-design.md`

- **Overview** — one paragraph: what's being built, who it serves, where it runs, what product class (micro / mobile / dev-tool / SMB SaaS / venture-scale) the depth calibration is applied for. The product class is load-bearing — readers infer the rigor floor from it.
- **Stack** — concrete language + framework + database + ORM + frontend with version MAJOR. One sentence rationale per choice, anchored to PRD success metric or v1 constraint. Anti-pattern: "Postgres because reliable". Good: "Postgres because US-07 task-completion + US-12 analytics write need transactional consistency".
- **Services** — monolith / modular monolith / multi-service — state plainly. If multi-service: name each service + responsibility + comms protocol (REST / RPC / events / shared DB). v1s default to monolith unless PRD complexity demands otherwise.
- **Data Model** — entities + relationships in typed pseudo-schema. Key indexes. Soft-delete posture. Multi-tenancy strategy if applicable. Cross-references PRD `US-NN` IDs per entity ("`Task` — needed for US-07, US-12, US-19").
- **APIs** — markdown table per surface: `| Method | Path | Contract intent | Source |`. `Source` column cross-references `US-NN` or spec section. One line per endpoint. NOT OpenAPI — that's implementation.
- **Integrations** — third-party services. Per integration: what it's used for + alternative considered + rejected with reason + vendor lock-in posture (replaceable / sticky / load-bearing).
- **Deployment** — host platform, CI/CD shape, secrets management, observability floor (logs / metrics / tracing tiered). Region posture if compliance demands. Cost-model pointers belong in step 10.
- **Non-Functional** — perf budgets (p95 latency target, p99 ceiling). Scale assumptions (target concurrent users for v1) derived from PRD success metric. Reliability posture (uptime target, RTO/RPO if data is precious). Accessibility floor (inherited from step 4 audit). See `references/scale-assumptions.md` for the derivation rules.
- **Evaluation** — the 5×3 assessment table. Honest concern levels, not aspirational. Per-row Assessment is ONE specific sentence, not abstract praise.
- **Alternatives Considered** — per major choice (stack, DB, deployment, auth, payment), 1-2 rejected alternatives with one-line reason. Catches resume-driven design.
- **Trade-off Triggers & Open Decisions** — H2 with two H3 children.
  - `### Trade-off Triggers (digest)` — ONE prose paragraph (3-5 bullets max) naming the 3-4 highest-stakes triggers from § Open below. The load-bearing "Recommendation changes if (a)(b)(c)(d)" framing in a form a reader scans in 30 seconds. NOT every row from the Open table — just the load-bearing few.
  - `### Open Decisions (table)` — markdown table `# | Question | Deciding signal | Closes by`. Things this step deferred to implementation OR genuinely unresolved. Rows without a Deciding signal are red flags.
  - **Locked decisions are intentionally NOT a sub-section** — the bridge-skill's PRD-decision extraction lands NATURALLY in § Stack (auth provider, framework), § Integrations (payment processor), § Deployment (host platform), § Non-Functional (uptime target). Re-tabling them as a separate Locked sub-section duplicates the running commitment; spec 026 Phase B judge-feedback (2026-05-16) confirmed the running-prose pattern carries the audit trail without the meta-table.

### `architecture.json`

JSON object with required keys (Layer-1-enforced):

- **`title`** (string, required) — "<Product Name> — System Architecture v1"
- **`summary_prose`** (string, required) — 1-3 sentences in plain language; becomes `<figcaption>` when rendered (WCAG 1.1.1 alignment)
- **`components`** (array of objects, required) — each has `id` (kebab-case unique), `label` (display name), `type` (enum: `frontend | backend | db | cloud | security | bus | external`), optional `sublabel` (one-line technology hint, "Next.js 15 App Router")
- **`arrows`** (array of objects, required) — each has `from` (component id), `to` (component id), optional `label` (protocol hint, "REST", "events", "Prisma")
- **`zones`** (array of objects, optional) — visual grouping for the future renderer; one per logical zone (Frontend / Backend / Data / Infrastructure). Skipped in spec 026 (JSON-only consumers don't need them); kept in the optional surface so a fork can populate ahead of the HTML renderer landing.
- **`summary_cards`** (array of objects, optional, max 4) — short cards summarising the diagram; same deferral as `zones`.

**`arrows[].from` and `.to` MUST reference component IDs that exist in `components[]`.** A mismatch is a discipline failure caught at agent self-review; Layer 1 doesn't structurally validate this (substring check only) because the failure shape is rare enough to not warrant a custom validator.

### `security.md`

- **Threat Model** — STRIDE-lite or OWASP top-10. For each row, the relevant risk for THIS product + the mitigation posture at v1 (or `accepted` with rationale if v1 deliberately defers). Tables work well: `| Threat | Surface | Mitigation | Status |`.
- **Auth** — auth model (session / JWT / OAuth provider), authz model (role-based / per-resource / org-scoped), session lifecycle, MFA posture. Cross-references the PRD's persona + scale class.
- **Data Classification** — what data is collected, classification tier (public / internal / PII / regulated), retention window per tier, deletion posture (hard / soft / anonymised). GDPR/LGPD posture if PII is collected.
- **Secrets** — where secrets live (env vars / vault / cloud KMS), rotation posture, exposure surface (which secrets land in which deployment artifact).
- **Regulated Aspects** — flag domain-specific regulation (HIPAA / PCI / SOC 2 / AI governance). Cross-reference step 12 (legal-posture) for full compliance treatment.

## Atomic write semantics

`product_step_submit` validates all three files against both layers (section presence on the primary, Layer 1 contains/size on every file) before writing. On any failure, response is `{ code: "schema-incomplete", failures: [...] }` and nothing persists. On success, each file writes via mktemp+rename — atomic, or absent. Either the entire bundle lands or none of it does.
