# Delegation briefs — 5-field templates per sub-agent (v0.4.0)

Every `Agent` tool call dispatched by `/product` v0.4.0 MUST use the 5-field handoff per `.claude/rules/delegation.md` (TASK / CONTEXT / CONSTRAINTS / DELIVERABLE / DONE_WHEN). The delegation-gate hook returns exit 2 otherwise.

**Briefs cover every `/product` sub-agent dispatch** — one per pipeline step (Step 02 = direction-writer; Step 15 = the three visual-contract sub-agents 15a-atlas / 15b-hi-fi-mood / 15c-fixture-spec) plus the shared **§ Mood-screen-writer** template, used by Step 02 (lo-fi mode) and Step 15b (hi-fi mode). Per spec 066 the v2/v3 per-route Next.js/Expo `.tsx` screen-writer is **deleted** — `/product` ends at the visual contract; the runnable app is built by the SDD children scaffolded in Phase 5. The **§ Quality judge** brief (spec 075) is dispatched once per judge-unit AFTER the producer returns — an evaluator, not a producer.

**Per-step model assignment** (per spec 036 Q1 resolution preserved in spec 045): Step 01 = `opus` (concept brief multi-source synthesis); Steps 02-15 = `sonnet` (mechanical with dense brief + bundled template). The post-step **§ Quality judge** runs on `opus` (evaluation reasoning + a within-family asymmetry against the `sonnet` producers).

**Substitution placeholders** ({{...}}) are replaced inline by the orchestrator (SKILL.md) before dispatch. The orchestrator reads `<out>/docs/.state.json` for `slug`, `idea`, `out`, `flags.stack`, `target_language` (resolved at Phase 0.5 per spec 054), and the prior-step outputs by path.

**Per spec 054, every brief producing user-facing text MUST receive `{{target_language}}` substitution.** The orchestrator threads `.state.json.target_language` into the brief at dispatch time. Sub-agents read it and match all generated copy (page headings, button labels, microcopy, marketing copy, voice samples, etc) to that language. Code-flavored surfaces (e.g. `/settings/integrations` references to `API`, `OAuth`, etc) may stay English locally; flag those as exceptions in the brand-book `## Glossary § applies_to` column.

## Phase 1 — Discovery

### Step 01 — Ideation (concept brief — extended with market sizing per Decision 6)

**model:** `opus`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce concept-brief.md for the product idea "{{idea}}" — a deep concept brief covering market fit, persona, mechanics, growth, monetization, risks, AND market sizing (TAM/SAM/SOM).

CONTEXT: Read .claude/skills/product/templates/pipeline/01-ideation/prompt.md for the canonical brief structure. Read .claude/skills/product/templates/pipeline/01-ideation/references/concept-brief-template.md for the section shape. Read .claude/skills/product/templates/pipeline/01-ideation/references/discovery-playbook.md for the 5-track market discovery process. Read .claude/skills/product/references/pipeline-coverage.md § "Per-step output + size floors" for the standard-tier calibration. Use WebSearch + WebFetch for 5-8 market discovery searches.

CONSTRAINTS:
- Standard tier: ≥ 4 KB (anti-stub floor — NOT a ceiling; the catastrophe cap below is the only upper bound).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- **Target language: `{{target_language}}`** (BCP-47, resolved at Phase 0.5). All section bodies + persona language + tagline candidates + name candidates in this language; cited sources stay in their original language.
- Cover the standard-tier minimum sections as H2 headings: Hook (problem + audience) / Mechanics (user flow) / Monetization / Growth loop / Competitive positioning / Risks / Anti-goals / JTBD statement / **Market Sizing (TAM/SAM/SOM — 1 paragraph each, desk research with 1-2 cited sources per number, NOT primary research)**. SKIP critique-mode at standard tier.
- Cite at least 5 unique sources with inline [N] references. Market Sizing section cites at minimum 1 source per TAM/SAM/SOM number.
- Name placeholder discipline: if final product name not yet decided, use `**Working name:** <placeholder> (placeholder, never shipped; final at Step 13 brand-book § Product Name)`. Suggest 2-3 candidates.
- Do NOT invent statistics — every claim either cites a source OR is hedged ("anecdotally", "in this researcher's view").
- Write file DIRECTLY to {{out}}/docs/concept-brief.md. Do NOT create extra files.

DELIVERABLE: {{out}}/docs/concept-brief.md

DONE_WHEN: File exists; size ≥ 4 KB (anti-stub floor); all 9 standard-tier sections present (H2 headings including § Market Sizing); ≥ 5 unique [N] source citations; placeholder discipline applied if name not finalized; TAM/SAM/SOM each cite ≥1 source.
```

### Step 02 — Prototype v1 (lo-fi: direction + killer-flow mood screens)

Two sub-agent dispatches: (a) one direction-writer for the visual mood board; (b) N screen-writers for the killer flow.

**(a) Direction writer — model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce direction-a.html — a single HTML mood board proposing the visual direction for "{{idea}}".

CONTEXT: Read concept-brief.md at {{out}}/docs/concept-brief.md for product persona + mechanics. Read .claude/skills/product/templates/pipeline/02-prototype/prompt.md for the canonical mood-board structure (ONE direction at standard tier). Read .claude/skills/product/references/od-catalog-index.json for the 72-vendor catalog; pick 1-2 vendors whose mood matches the product and cite by name + vendor_path. Read .claude/skills/product/templates/pipeline/02-prototype/schema.md for the 8 mandatory sections.

CONSTRAINTS:
- Standard tier: ONE direction only.
- **Target language: `{{target_language}}`** (BCP-47, resolved at Phase 0.5). All user-facing copy in the mood HTML matches this language — section headings, button labels, marketing taglines, voice samples. Code-flavored surfaces stay English locally.
- 8 mandatory sections (palette / type / hero / dashboard / charts / pricing / FooterCTA + DS lineage). Cite 1-2 OD vendors.
- Self-contained HTML — single file, inline styles + SVG.
- CSS :root custom properties (vendor-agnostic names: --color-primary, --background, --foreground).
- Includes "Most Popular" string token + ≥1 `<svg` (catalog citation discipline).
- **Do NOT produce sitemap.yaml** — that's Step 07's deliverable per spec 045 (sitemap-IA promoted to own step).
- Size floor: per `.claude/skills/product/templates/pipeline/02-prototype/schema.md § Size floor` — the `min_size` anti-stub floor (no scope ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write file DIRECTLY to {{out}}/docs/direction-a.html. The 3-5 killer-flow lo-fi mood screens are produced by separate § Mood-screen-writer dispatches in lo-fi mode (sub-agent b — see § Mood-screen-writer below).

DELIVERABLE: {{out}}/docs/direction-a.html (+ killer-flow HTML mood screens at {{out}}/docs/screens/NN-<name>.html produced by sub-agent b in parallel)

DONE_WHEN: File exists; size ≥ the `schema.md § Size floor` `min_size`; contains :root + --background + --foreground + --primary tokens; contains "Most Popular"; ≥1 `<svg`; cites ≥1 OD vendor in HTML comment header.
```

**(b) Mood-screen-writer (lo-fi mode)** — produces the 3-5 killer-flow lo-fi mood screens at `{{out}}/docs/screens/NN-<name>.html`. The same § Mood-screen-writer brief in hi-fi mode produces the Step 15b hi-fi mood. See § Mood-screen-writer below.

### Step 03 — Spec (functional + architecture; extended with problem-validation interviews per Decision 6)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce functional-spec.md decomposing "{{idea}}" into pages, components, interactions, states, features with Gherkin acceptance scenarios + preliminary architecture skeleton + problem-validation interview summaries (seeds OST at Step 06).

CONTEXT: Read concept-brief.md at {{out}}/docs/concept-brief.md for product scope. Read direction-a.html at {{out}}/docs/direction-a.html + screens at {{out}}/docs/screens/ for surface inventory. Read .claude/skills/product/templates/pipeline/03-spec/prompt.md for canonical structure (standard tier combines spec + architecture into a single file). Read .claude/skills/product/templates/pipeline/03-spec/schema.md § Size floor for the `min_size` anti-stub floor + required sections.

CONSTRAINTS:
- Standard tier: combined functional-spec.md (skip separate architecture.md). Size floor: per `schema.md § Size floor` — the `min_size` anti-stub floor (no scope ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- **Target language: `{{target_language}}`** (BCP-47). All section bodies, page descriptions, Gherkin scenario text + acceptance prose in this language. Technical terms (HTTP, JSON, OAuth, etc) stay English. User-story summaries match the language.
- Sections required (H2): Product Overview / Pages & Surfaces (table per page) / Features (with Gherkin) / Navigation Map / Cross-cutting concerns / Acceptance Scenarios / Edge Cases / Non-goals / Decisions Pending / Preliminary Architecture / **Problem-Validation Interviews (3-5 summaries seeding OST; synthetic-OK at standard tier — clearly marked as synthetic vs sourced from real interviews)**.
- Scale depth to surface importance; killer flow gets full treatment; trivial pages collapse to 2-4 table rows.
- Every "Decisions Pending" row has either a source citation OR a default value.
- ≥ 3 Gherkin scenarios.
- Write file DIRECTLY to {{out}}/docs/functional-spec.md.

DELIVERABLE: {{out}}/docs/functional-spec.md

DONE_WHEN: File exists; size ≥ the `schema.md § Size floor` `min_size`; contains **Given** / **When** / **Then** keywords; contains "Pages & Surfaces" + "Features" + "Preliminary Architecture" + "Problem-Validation Interviews" section headers; ≥ 3 Gherkin scenarios; ≥ 3 interview summaries.
```

### Step 04 — UX Testing (heuristic audit)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce validation-report.md — heuristic audit (Nielsen's 10 + WCAG 2.1 AA) on the Phase 1 prototype surfaces + validation mode declaration.

CONTEXT: Read direction-a.html at {{out}}/docs/direction-a.html + screens at {{out}}/docs/screens/ for rendered surfaces (PROJECTED-mode audit at standard tier). Read functional-spec.md at {{out}}/docs/functional-spec.md for declared behavior. Read .claude/skills/product/templates/pipeline/04-ux-testing/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: PROJECTED mode. Audit infers contrast / tab order / a11y from spec + HTML inspection.
- Heuristic-only — Nielsen 10 + WCAG 2.1 AA top issues.
- validation_mode: `tested` / `intuition` / `not-applicable` — default `intuition`.
- YAML frontmatter: `findings[]` with `{id, severity 1-4, heuristic, location, issue, recommendation, fix_skill_hint}` where fix_skill_hint ∈ `{design-system, screen-atlas, deferred}` (note: `prototype-v2` removed per spec 045 — Step 7 deleted; fixes that were `prototype-v2` now route to `screen-atlas`).
- ≥ 3 findings minimum.
- ≥ 5 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write file DIRECTLY to {{out}}/docs/validation-report.md.

DELIVERABLE: {{out}}/docs/validation-report.md (with YAML frontmatter)

DONE_WHEN: File exists; size ≥ 5 KB (anti-stub floor); contains `Nielsen` + `WCAG`; contains `validation_mode: intuition` (or other valid value); YAML frontmatter parses with ≥ 3 findings entries each carrying severity + fix_skill_hint ∈ {design-system, screen-atlas, deferred}.
```

## Phase 2 — Specification

### Step 05 — PRD 1-pager (Lenny hybrid per Decision 1 + 15)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce prd.md — Lenny Rachitsky 1-pager hybrid for "{{idea}}". This is a TIGHT 1-pager, NOT a multi-page PRD.

CONTEXT: Read concept-brief.md + functional-spec.md + validation-report.md frontmatter + direction-a.html + screens at {{out}}/docs/ for product scope. Read .claude/skills/product/templates/pipeline/05-prd/prompt.md + schema.md for the Lenny hybrid shape.

CONSTRAINTS:
- ≥ 4 KB (anti-stub floor; no ceiling). Each section ≤3 bullets to preserve 1-pager honesty.
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- **Target language: `{{target_language}}`** (BCP-47). All H2 body text + user-story summaries + acceptance criteria in this language. H2 section headers themselves stay English-canonical (Problem / Why now / Success metrics / etc) because they ARE the Lenny 1-pager template — match the source attribution.
- Lenny bones (H2 in this order): Problem · Why now · Success metrics · Solution sketch · User stories · Anti-goals.
- Plus 3 our-specific sections (H2 after Lenny bones): Release scope (v1 vs v2 vs vN scoped) · NSM (dedicated slot — ONE primary metric, never two equal-priority) · Upstream/downstream refs (links to concept-brief + functional-spec + downstream sitemap/system-design slots).
- User-story IDs: zero-padded sequential US-01, US-02, ..., US-NN. APPEND-don't-renumber discipline (Step 07 sitemap-IA + Step 15 atlas coverage matrix both depend on stable IDs).
- P0/P1/P2 tiering — hard cut. Everything else is § Backlog (within Solution sketch section) or explicit § Anti-goals.
- NSM is ONE primary metric in its dedicated slot; supporting observability metrics optional, listed as read-only follow-ons.
- Spec-Pending decisions from Step 03 RESOLVED INLINE: founder-locked → apply; spec-default applies → state reason; genuinely open → § Upstream/downstream refs as "open: see followup".
- Attribution: header comment "PRD shape based on Lenny Rachitsky's 1-pager template (lennysnewsletter.com/p/prds-1-pagers-examples) — hybrid w/ Steward-specific Release scope · NSM · Upstream refs sections per spec 045 Decision 15".
- Write file DIRECTLY to {{out}}/docs/prd/v1.md.

DELIVERABLE: {{out}}/docs/prd/v1.md

DONE_WHEN: File exists; size ≥ 4 KB (anti-stub floor); contains literal table-row `| US-NN |` (at least one); contains all 9 H2 sections (6 Lenny bones + 3 our-specific); ONE NSM in dedicated slot (NOT two equal); P0/P1/P2 tiers visible in table; attribution comment present.
```

### Step 06 — OST (Opportunity Solution Tree — new per Decision 12)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce ost.md — Opportunity Solution Tree (Teresa Torres methodology) for "{{idea}}", consuming Step 05's PRD NSM as the desired outcome root.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md for NSM (desired outcome) + user stories + anti-goals. Read functional-spec.md at {{out}}/docs/functional-spec.md § Problem-Validation Interviews for raw problem signal. Read concept-brief.md at {{out}}/docs/concept-brief.md for persona context. Read .claude/skills/product/templates/pipeline/06-ost/prompt.md for canonical OST shape. Reference: Teresa Torres, Continuous Discovery Habits (Product Talk Academy).

CONSTRAINTS:
- Standard tier: 1 desired outcome root (NSM from Step 05) → 3-5 opportunities (user problems discovered/inferred) → 2-3 solutions per opportunity.
- Each opportunity ties back to a specific Problem-Validation Interview summary OR a hedged "inferred from persona" attribution.
- Each solution is a high-level approach, NOT an implementation detail. E.g. "Inline override-reason input gating" (solution), NOT "React modal with useState" (implementation).
- Mark solutions with status: `explored` (already in scope) / `to-test` (next interview cycle) / `parked` (out of v1).
- Tree rendered as nested markdown bullets OR mermaid diagram (sub-agent's choice based on visual clarity at this depth).
- ≥ 3 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write file DIRECTLY to {{out}}/docs/ost.md.

DELIVERABLE: {{out}}/docs/ost.md

DONE_WHEN: File exists; size ≥ 3 KB (anti-stub floor); tree structure with 1 outcome → 3-5 opportunities → 2-3 solutions per opportunity; every solution carries status {explored | to-test | parked}; opportunities reference Step 03 interviews OR persona inferences.
```

### Step 07 — Sitemap-IA (per Decision 5 + 13 — load-bearing root-cause fix)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce sitemap.yaml — full screen inventory + IA decomposition for "{{idea}}", schema-bound to references/sitemap-schema.md's required_categories enforcement.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md for US-NN inventory. Read functional-spec.md at {{out}}/docs/functional-spec.md § Pages & Surfaces for surface inventory. Read concept-brief.md at {{out}}/docs/concept-brief.md for product class (B2C / B2B / internal-tool / etc — drives which required_categories apply). Read .claude/skills/product/references/sitemap-schema.md for the binding schema. Read .claude/skills/product/templates/pipeline/07-sitemap-ia/prompt.md + schema.md for canonical shape.

CONSTRAINTS:
- YAML output. Top-level keys: `slug`, `platform`, `stack`, `required_categories`, `routes`, `deferred_categories` (optional).
- `required_categories: [marketing, auth, primary, admin, error]` — every member MUST have ≥1 route OR be listed in `deferred_categories: [{name, reason}]`.
- For B2C SaaS / B2B SaaS: all 5 required. For internal-tool/CLI/back-office-only: `marketing` may be deferred with reason "internal-tool, no marketing surface".
- Per-route fields: `path` (string) · `category` (one of required_categories) · `states` (array — default/loading/empty/error/disabled/success as applicable) · `covers_us` (array of US-NN refs from PRD) · `components` (array of component names — for downstream Step 15 wiring).
- Auth category MUST include AT MINIMUM: login + signup + password-reset (3 routes). Optionally: invite-accept, email-verify, oauth-callback.
- Admin category MUST include AT MINIMUM: org-settings + team-management (2 routes). Optionally: billing, audit-log, integrations.
- Error category MUST include AT MINIMUM: not-found (1 route). Optionally: server-error (500), forbidden (403), maintenance.
- Primary category covers the killer-flow screens from Step 02 + any other user-facing primary surfaces from PRD user stories.
- Marketing category covers landing + pricing + feature pages.
- If `deferred_categories` is used, each entry MUST include `reason` (1-2 sentences explaining why category is out of v1 scope).
- ≥ 2 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write file DIRECTLY to {{out}}/docs/sitemap.yaml.

DELIVERABLE: {{out}}/docs/sitemap.yaml

DONE_WHEN: File exists; valid YAML; size ≥ 2 KB (anti-stub floor); required_categories enforced per schema (every category has ≥1 route OR is in deferred_categories with reason); ≥3 auth routes; ≥2 admin routes; ≥1 error route; every route has all required fields; covers_us refs are valid US-NN from prd.md.

NOTE: Orchestrator parses this YAML after sub-agent returns and BLOCKS step + re-dispatches with augmented brief naming the missing category(ies) if required_categories not satisfied without deferral. See SKILL.md § Phase 2 Step 07 acceptance check.
```

### Step 08 — System Design (extended with RACI + risk + data-flow per Decision 10)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce system-design.md + security.md + data-flow.json for "{{idea}}". System-design includes RACI matrix + risk register per spec 045. Data-flow.json is the structured inventory consumed by Step 09 legal for DPIA trigger.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (scope drives scale assumption) + sitemap.yaml at {{out}}/docs/sitemap.yaml (route inventory drives integration list + auth requirements) + functional-spec.md at {{out}}/docs/functional-spec.md (preliminary architecture) + concept-brief.md at {{out}}/docs/concept-brief.md (product class + audience). Read .claude/skills/product/templates/pipeline/08-system-design/prompt.md + schema.md.

CONSTRAINTS:
- system-design.md: BRIDGE-FLOOR (6+ sections H2): Stack / Integrations / Data Model / Decisions Locked / Security / Observability / **RACI Matrix** / **Risk Register**. Size floor: per `.claude/skills/product/templates/pipeline/08-system-design/schema.md § Size floor` — the `min_size` anti-stub floor (no scope ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- RACI Matrix: 5-10 key roles (founder/engineer/designer/data/legal/...) × 5-10 key activities (auth/payments/audit-trail/...). Each cell: R/A/C/I or blank.
- Risk Register: 5-10 risks with columns: ID · description · probability (L/M/H) · impact (L/M/H) · mitigation · owner.
- Stack baseline (adapt per product needs): Next.js 16 (matches prototype) + Postgres + Redis + Slack Bot SDK + LLM API (if needed) + S3-compatible blob.
- Integrations table: name · purpose · sub-processor? · data-flow direction · v1-vs-v2.
- Decisions Locked: 6-10 architectural decisions with one-line rationale.
- security.md: STRIDE-lite threat model + auth/authz + data classification + secrets handling + AI-specific section if LLM in stack. Size floor: per `schema.md § Size floor` (no scope ceiling).
- **data-flow.json: structured machine-readable inventory.** Schema: `{"flows": [{"from": "<source>", "to": "<sink>", "data_categories": ["pii" | "health" | "minors" | "financial" | "behavioral" | "credentials" | "session" | "telemetry"], "encryption_at_rest": bool, "encryption_in_transit": bool, "retention_days": int | null, "sub_processor": string | null}]}`. Cover ALL data flows the system handles. Consumed by Step 09 legal — if ANY flow includes `pii | health | minors | financial`, Step 09 fires DPIA section as mandatory.
- Write 3 files DIRECTLY to {{out}}/docs/: 08-system-design.md + 08-security.md + 08-data-flow.json.

DELIVERABLE: 3 files: {{out}}/docs/system-design.md + {{out}}/docs/security.md + {{out}}/docs/data-flow.json

DONE_WHEN: system-design.md meets the `08-system-design/schema.md § Size floor` `min_size` + 8 H2 sections present (including RACI Matrix + Risk Register); security.md meets its `§ Size floor` `min_size` + contains "Threat Model" + "Auth" + "Data Classification" + "Secrets" section headers; data-flow.json valid JSON parses cleanly with `flows` array containing ≥3 entries.
```

### Step 09 — Legal posture (shift-left per Decision 4 — DPIA-triggered by Step 08)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce legal-posture.md — founder's articulated legal posture briefing for v1 of "{{idea}}". This is BRIEFING for counsel, NOT the actual Terms/Privacy/DPA documents. Includes DPIA section IF Step 08 data-flow includes sensitive categories.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (audience drives jurisdiction exposure) + system-design.md at {{out}}/docs/system-design.md (Integrations name every sub-processor) + **data-flow.json at {{out}}/docs/data-flow.json (parses flows[]; if any flow has data_categories ⊃ {pii, health, minors, financial}, DPIA section is MANDATORY)** + concept-brief.md at {{out}}/docs/concept-brief.md (audience). Read .claude/skills/product/templates/pipeline/09-legal/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: BRIEF CHECKLIST + POSTURE. Size floor: per `.claude/skills/product/templates/pipeline/09-legal/schema.md § Size floor` — the conditional `min_size` model (base floor plus an additional floor per triggered conditional section); no scope ceiling.
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- TOP-OF-DOCUMENT escape clause (line 1-5): "This is founder's posture, NOT legal advice. Counsel review required before launch."
- Sections required (H2): Terms Model / Privacy Posture (regulation applicability checklist GDPR/LGPD/CCPA Yes/No based on audience) / Data Handling Snapshot / Licensing (product license + OSS compatibility flag) / Sub-Processor Disclosure (extracted from system-design § Integrations — count must match) / IP Assignment Posture / Open Decisions.
- **§ DPIA (conditional — fires if data-flow.json contains sensitive categories):** Required when Step 08 data-flow has any `data_categories ⊃ {pii, health, minors, financial}`. Lists each sensitive data flow, the legal basis (consent/contract/legitimate-interest/legal-obligation/vital-interest/public-task), the data subject rights affected (access/erasure/portability/restriction), and the risk-mitigation posture. **DPIA-shift-left per GDPR Art 25 + IAPP guidance** — counsel reviews DPIA section in 1-pager form BEFORE coding starts, not after launch.
- § AI-Specific (conditional — fires if system-design Integrations includes LLM API): agent-data ingestion classification, model-provider relay disclosure, opt-in/opt-out posture, model retention by provider.
- § Regulated Aspects (conditional — fires if PRD audience touches health/minors/payment/enterprise/etc).
- If a conditional section's trigger isn't met, OMIT entirely (do NOT emit as "N/A").
- Default posture: MIT for OSS harness; SaaS ToS for hosted; standard DPA for paying customers; AGPL not chosen; CLA optional v1.
- Write file DIRECTLY to {{out}}/docs/legal-posture.md.

DELIVERABLE: {{out}}/docs/legal-posture.md

DONE_WHEN: File exists; size ≥ the `schema.md § Size floor` conditional `min_size`; escape clause at TOP (line 1-5); contains "Terms" + "Privacy" + "Licensing" + "Sub-Processor" + "Open Decisions" section headers; § DPIA present IF data-flow.json contains sensitive categories; § AI-Specific present IF LLM in Integrations; sub-processor count matches system-design integration count.
```

### Step 10 — Roadmap (defines phases for Step 11 cost — per spec 045 cost↔roadmap swap)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce roadmap.md — 3-phase MVP/Growth/Polish sketch for v1 of "{{idea}}". Phase boundaries defined HERE drive Step 11's per-phase cost calculation.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (user stories + priorities) + system-design.md at {{out}}/docs/system-design.md (dependencies + integrations driving build sequence) + concept-brief.md at {{out}}/docs/concept-brief.md (product class) + validation-report.md at {{out}}/docs/validation-report.md (validation_mode drives canonical-vs-bridge mode). Read .claude/skills/product/templates/pipeline/10-roadmap/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: 3-phase sketch (MVP / Growth / Polish) with phase titles USER-FLOW SHAPED (e.g. "Install harness, see first override-marker hit") NOT label-shaped ("Foundation").
- Mode by validation_mode: `tested` → canonical timeline-aware (week ranges + milestones + buffer); `intuition`/`not-applicable` → bridge mode (priority-tier grouping P0→MVP, P1→Growth, P2→Polish, no week commitments).
- Slices end-to-end user value (Shape Up style) — NO horizontal layers like "Phase 1: all backend".
- Deliverables table per phase: rows reference Step-05 US-NN.
- Milestones are observable end-of-phase deliverables.
- § Overview 2-3 one-liners. § Horizon (duration estimate + team shape). § Open Decisions table.
- Size floor: per `.claude/skills/product/templates/pipeline/10-roadmap/schema.md § Size floor` — the `min_size` anti-stub floor (no scope ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write file DIRECTLY to {{out}}/docs/roadmap.md.

DELIVERABLE: {{out}}/docs/roadmap.md

DONE_WHEN: File exists; size ≥ the `schema.md § Size floor` `min_size`; 3 phase headers present + each phase has 1-3 milestones + deliverables table per phase + § Open Decisions section; phase titles are user-flow-shaped (NOT generic labels like "Foundation").
```

### Step 11 — Cost Estimate (per-phase using Step 10's roadmap — spec 045 swap)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce cost-estimate.md — single-scenario burn rate + run-cost line items for v1 of "{{idea}}", calculated PER PHASE using Step 10's roadmap phase boundaries (spec 045 cost↔roadmap swap).

CONTEXT: Read **roadmap.md at {{out}}/docs/roadmap.md (phase boundaries drive cost calculation — load-bearing for per-phase breakdown)** + system-design.md at {{out}}/docs/system-design.md (stack + integrations drive line items) + legal-posture.md at {{out}}/docs/legal-posture.md (DPIA + counsel review budget) + prd.md at {{out}}/docs/prd/v1.md (success metric drives scale assumption). Read .claude/skills/product/templates/pipeline/11-cost-estimate/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: SINGLE-SCENARIO only. ≥ 5 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Build cost as a RANGE per phase from Step 10 roadmap (Phase 1 / Phase 2 / Phase 3 user-flow titles). Includes hourly/weekly rate assumption with source/confidence. Default $150-200/hr senior IC range with "indie founder-rate" caveat.
- Run cost line items at v1 scale: tabular per vendor (vendor / tier / monthly cost / source). Count must match system-design § Integrations list (audit discipline).
- **Legal review + audit costs in their own table row** — pulls from Step 09 legal posture (counsel-review hours estimate + SOC 2 audit if applicable).
- Assumptions table required — every input has source + confidence (high/med/low).
- Top 5 financial risks (one-liner each).
- 3-5 Recommendations with action verbs + "flip if" deciding signal.
- SKIP unit economics + sensitivity analysis + scenario analysis.
- Required H2 sections: Assumptions / Build Cost / Run Cost / Legal & Audit Budget / Risks / Recommendations.
- Write file DIRECTLY to {{out}}/docs/cost-estimate.md.

DELIVERABLE: {{out}}/docs/cost-estimate.md

DONE_WHEN: File exists; size ≥ 5 KB (anti-stub floor); contains "Assumptions" + "Build Cost" + "Run Cost" + "Legal & Audit Budget" + "Recommendations" section headers; build cost rows reference Step 10 roadmap phase names; run-cost vendor count matches system-design integration count.
```

### Step 12 — GTM-launch (new per Decision 7 — positioning + launch + pricing)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce gtm-launch.md — positioning canvas (April Dunford methodology) + 4-week launch plan sketch + pricing strategy for v1 of "{{idea}}".

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (NSM + audience for positioning) + concept-brief.md at {{out}}/docs/concept-brief.md (competitive positioning + monetization tier hints) + roadmap.md at {{out}}/docs/roadmap.md (launch timing aligns with roadmap Phase 1 close) + legal-posture.md at {{out}}/docs/legal-posture.md (compliance signals affect launch claims). Read .claude/skills/product/templates/pipeline/12-gtm-launch/prompt.md + schema.md. Reference: April Dunford, Obviously Awesome.

CONSTRAINTS:
- Standard tier: ≥ 4 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- **Target language: `{{target_language}}`** (BCP-47). Positioning Canvas body lines + launch plan milestones + pricing tier descriptions in this language. The 5 canvas line-labels (`For:`, `Who:`, `We are:`, `Unlike:`, `Our product:`) stay English per Dunford template.
- Required H2 sections: Positioning Canvas / Launch Plan / Pricing Strategy / Open Decisions.
- **Positioning Canvas** (Dunford-lite, 3 lines minimum):
  - For: [target customer]
  - Who: [problem statement — what they're trying to do]
  - We are: [category] that [unique value]
  - Unlike: [primary alternative — competitor OR status quo / DIY]
  - Our product: [primary differentiator]
- **Launch Plan**: 4-week sketch (week-by-week milestones — e.g. week 1 = soft launch waitlist, week 2 = ProductHunt, week 3 = founder content amplification, week 4 = paid acquisition test). Each milestone has 1-3 deliverables + measurement.
- **Pricing Strategy**: tier shape (free/standard/pro structure if relevant; usage-based vs seat-based decision; freemium-vs-trial decision). Reference concept-brief monetization tiers.
- SKIP full launch playbook (post-PMF concern); skip funnel modeling (insufficient data at v1).
- Write file DIRECTLY to {{out}}/docs/gtm-launch.md.

DELIVERABLE: {{out}}/docs/gtm-launch.md

DONE_WHEN: File exists; size ≥ 4 KB (anti-stub floor); contains all 4 H2 sections; positioning canvas has all 5 lines (For/Who/We-are/Unlike/Our-product); launch plan has 4 week-numbered milestones; pricing strategy declares tier shape.
```

## Phase 3 — Identity

### Step 13 — Brand book (moved after Specification per Decision 3 — PRD-first)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce brand-book.md — voice + visual direction posture + we-are/we-are-not contrast pair for "{{idea}}".

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (finalized scope + NSM + persona) + gtm-launch.md at {{out}}/docs/gtm-launch.md (positioning canvas already locked — brand voice should reinforce, not contradict) + concept-brief.md at {{out}}/docs/concept-brief.md (audience + product class) + direction-a.html at {{out}}/docs/direction-a.html (visual lineage). Read .claude/skills/product/templates/pipeline/13-brand/prompt.md for canonical 7-section structure (we target 2-3 section snapshot at standard tier).

CONSTRAINTS:
- Standard tier: voice (1-2 paragraphs) + voice samples + ONE "We are / We are not" pair minimum + **`## Language` section (spec 054)** + **`## Glossary` section (spec 054)** + Visual Direction posture + Logo Direction (clear-space + min-size + ≥3 prohibited uses) + Color Story + Anti-Patterns.
- **Target language: `{{target_language}}`** (BCP-47, from `.state.json.target_language` resolved at Phase 0.5). All voice samples, "We are / We are not" pairs, anti-pattern bullets, color-story prose, and other brand prose in this language. The `## Language` section declares this target as a machine-readable `**target_language:** <bcp47>` line.
- **Glossary obligation (spec 054):** the `## Glossary` H2 has two sub-sections — `### We say` (preferred terms / phrasing the brand favors) and `### We don't say` (avoided terms with native replacement, reason, and applies_to scope). 4-column table format: `| Term | Replacement | Reason | Applies to |`. Cap ≤ 20 entries per sub-section. Identify entries ORGANICALLY from concept-brief + positioning + product domain — domain jargon the founder uses naturally, voice traps the comparables fall into, anglicisms the brand should localize. **DO NOT auto-derive from positioning Unlike-clause** (positioning is product-vs-product level; glossary is copy-trap level; mechanical translation produces noise). Downstream Step 15 screen-writers consume `### We don't say` as a string-replace lookup.
- Voice samples: 3 minimum (one-liner per surface type — headline, microcopy, CTA label).
- Visual Direction names the feel (e.g. "Cool Brutalist", "Warm Premium") + 2-3 posture decisions (e.g. "hairline 1px borders only" / "monospace dominant" / "single saturated accent"). NO hex codes (Step 14 handles).
- "We are / We are not" pair: contrast — NOT a flat adjective list.
- **Product Name decision** required — pick one of the candidates from concept-brief OR propose better with rationale. THIS is the moment to finalize the name (Step 15 atlas + downstream artifacts propagate).
- Voice must REINFORCE Step 12 positioning canvas (e.g. if positioning says "Unlike: enterprise sales-cycle vendors" → brand voice must NOT sound corporate-sales).
- Header includes **Version:** 0.1 and **Date:** <today>.
- ≥ 4 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write file DIRECTLY to {{out}}/docs/brand-book.md.

DELIVERABLE: {{out}}/docs/brand-book.md

DONE_WHEN: File exists; size ≥ 4 KB (anti-stub floor); contains **Version:** + **Date:** + `## Language` H2 + `**target_language:**` declaration + **We are** + **We are not** + 3+ voice samples + `## Glossary` H2 with both `### We say` + `### We don't say` sub-sections (each carrying a 4-column table with ≥1 entry) + visual-direction posture (named feel + 2+ posture decisions) + Product Name decision; voice alignment with Step 12 positioning is stated (1 sentence cross-ref).
```

### Step 14 — Design System (renamed from v2 Step 06; tokens path changed)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce tokens.css + components.md + README.md (3 files inside `{{out}}/docs/design-system/`) applying the brand-book to concrete semantic design tokens for "{{idea}}". Catalog-path PREFERRED (cite 1-2 OD vendors).

CONTEXT: Read brand-book.md at {{out}}/docs/brand-book.md for posture + voice. Read sitemap.yaml at {{out}}/docs/sitemap.yaml for component scope (what surfaces need styling). Read concept-brief.md at {{out}}/docs/concept-brief.md for product class. Read .claude/skills/product/references/od-catalog-index.json for the 72-vendor catalog — pick 1-2 vendors whose mood + category match the brand-book; their DESIGN.md path (vendor_path field) is the lineage citation source. Read validation-report.md at {{out}}/docs/validation-report.md frontmatter `findings[]` and filter `fix_skill_hint: "design-system"` — these are token tunes to apply. Read .claude/skills/product/templates/pipeline/14-design-system/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: catalog path PREFERRED — if 1-2 vendors match, inherit their tokens with brand-tuned overrides. Custom path fallback only.
- Semantic token names ONLY — `--color-primary` not `--color-blue-500`; `--space-md` not `--space-12`. NO visual naming.
- **tokens.css written to {{out}}/docs/design-system/tokens.css** (NOT root — root reserved for runtime per spec 036 finding #7 iter-2). The skeleton's `app/globals.css` imports it relative as `@import "../docs/design-system/tokens.css"`.
- **tokens.css registers tokens under a Tailwind v4 `@theme` block (spec 066)** — NOT only a bare `:root` block. The `@theme` directive is what makes the tokens generate real utility classes (`bg-primary`, `text-fg`, `p-md`, `rounded-lg`, `font-sans`) — the downstream component-library SDD child consumes utilities, not raw vars. Use Tailwind v4 theme namespaces: `--color-*` (colors), `--text-*` (font sizes), `--radius-*` (radii), `--font-*` (families), `--spacing` / `--spacing-*` (scale). Dark-first posture unchanged: declare the dark values inside `@theme`; the light-mode `@media (prefers-color-scheme: light)` block overrides the `--color-*` vars in a following `:root` (Tailwind v4's theme-override pattern). Token coverage: color (8-14) + spacing (5-7 scale) + radius (3) + font (sans + mono + 5-7 size scale).
- tokens.css opens with a one-line comment `/* Tailwind v4 @theme — import after `@import "tailwindcss"` in the app's globals.css */` so the foundation SDD child wires the import order correctly.
- components.md: per-component anatomy + variants + states for at least Button / Input / Card / Table / Badge / Dialog / EmptyState. 3+ KB.
- README.md (design-system overview): overview + tokens narrative + audit-response section (which step-04 findings applied as token tunes) + catalog lineage citations. 8+ KB. Required H2: "Audit Response".
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope). The per-file `min_size` floors remain enforced via schema Layer 1.
- Write 3 files DIRECTLY to {{out}}/docs/design-system/: tokens.css + components.md + README.md.

DELIVERABLE: 3 files at {{out}}/docs/design-system/: tokens.css + components.md + README.md

DONE_WHEN: tokens.css ≥ 1.5 KB valid CSS with a Tailwind v4 `@theme` block (registering `--color-*` / `--text-*` / `--radius-*` / `--font-*` tokens) + a light-mode `@media (prefers-color-scheme: light)` override; components.md ≥ 3 KB; README.md ≥ 8 KB + contains "Audit Response" section header + cites OD vendor name + vendor_path.
```

## Phase 4 — Visual contract

Phase 4 is Step 15 — the **visual contract**. Per spec 066 the v2/v3 per-route screen-writer fan-out is **deleted**: `/product` no longer generates an `app/**/page.tsx` screen set, writes no route-group layouts, runs no build verification. The runnable app is built by the SDD children scaffolded in Phase 5. Step 15 dispatches **three sub-agents — parallelizable in ONE message** (all inputs are on disk from Phases 1-3, distinct output paths, no FS race): (15a) the atlas-writer, (15b) the hi-fi mood-screen-writer, (15c) the fixture-spec-writer.

### Step 15a — Screen atlas (the navigable visual contract)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce screen-atlas.md — the navigable visual-contract document for the complete v1 surface of "{{idea}}". The atlas is a MARKDOWN INDEX. Write NO `app/` files, NO layout.tsx, NO page.tsx, NO HTML — the atlas DESCRIBES the screens the SDD children will build; it does not build them.

CONTEXT: Read ALL prior artifacts at {{out}}/docs/ (semantic-named per spec 048; pipeline order via REPORT.md):
- Phase 1 (Discovery): concept-brief.md, functional-spec.md, validation-report.md, direction-a.html + screens/ (lo-fi mood — visual lineage)
- Phase 2 (Specification): prd/v1.md (US-NN inventory — load-bearing for PRD coverage), ost.md, sitemap.yaml (route inventory — load-bearing for the Screens Index), system-design.md + security.md + data-flow.json, legal-posture.md (legal-mandatory surfaces — consent dialog if DPIA fires), roadmap.md, cost-estimate.md, gtm-launch.md
- Phase 3 (Identity): brand-book.md, design-system/tokens.css, design-system/components.md, design-system/README.md
Read .claude/skills/product/templates/pipeline/15-screen-atlas/prompt.md + schema.md + references/ for the atlas shape.
The hi-fi killer-flow mood screens at {{out}}/docs/screens/hifi/ (Step 15b, produced in parallel) are the RENDERED half of this contract — reference them in § Design Fidelity, do not reproduce their markup.

CONSTRAINTS:
- **The atlas markdown file is the ONLY deliverable. Write NO `app/`, NO `.tsx`, NO `.html`.** The atlas is a contract document, not an implementation.
- Size floor: per `.claude/skills/product/templates/pipeline/15-screen-atlas/schema.md § Size floor` — the `min_size` anti-stub floor (no scope ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- **Target language: `{{target_language}}`** (BCP-47). All prose, screen descriptions, and the user-flow walkthrough in this language; H2 section headers stay English-canonical.
- Required H2 sections (verbatim, in order): Overview / Screens Index / Sitemap Coverage Cross-Check / PRD Coverage Matrix / Design Fidelity / States Coverage Matrix / User Flow Walkthrough / Open Decisions.
- **Screens Index** — markdown table covering EVERY route in sitemap.yaml: `| Route | Category | Chrome | Covers (US-NN) | States | Screen intent |`. One row per route — this is the full inventory the SDD children build against.
- **Sitemap Coverage Cross-Check** — confirm every sitemap.yaml route appears in the Screens Index; confirm every `required_categories` member is represented; list any gap.
- **PRD Coverage Matrix** — markdown table listing EVERY US-NN from prd.md: `| US-NN | Priority | Screen(s) | Status |`. Each US-NN is `covered → <route(s)>` or `deferred — <reason>`. Silent omission is the regression mode the matrix exists to catch.
- **Design Fidelity** — for the 3-5 killer-flow screens, name the matching `docs/screens/hifi/<NN>-<name>.html` as the rendered fidelity reference; for every other route, state the intended fidelity in prose (tokens from `design-system/tokens.css` applied, brand voice from `brand-book.md`, components reused from `design-system/components.md`). NO numeric per-screen scoring table — there are no built screens to score.
- **States Coverage Matrix** — markdown table, routes × {loading/empty/error/disabled/success}; cells ✓ (required) / — (n/a) / `[gap]`.
- **User Flow Walkthrough** — the killer flow end-to-end with copy snippets at each step, anchored to a named persona from concept-brief.md. Carry the literal phrase "Closed-beta partner" in the named-human acceptance clause.
- **Open Decisions** — 2-5 integration-shape decisions the SDD children resolve at build time; each row carries a deciding signal.
- Write the atlas DIRECTLY to {{out}}/docs/screen-atlas.md. ONE file. Nothing else.

DELIVERABLE: {{out}}/docs/screen-atlas.md

DONE_WHEN: File exists; size ≥ the `schema.md § Size floor` `min_size`; contains all 8 required H2 headers verbatim; Screens Index table has one row per sitemap.yaml route; PRD Coverage Matrix lists every US-NN from prd.md; § User Flow Walkthrough contains the literal "Closed-beta partner"; NO `app/` / `.tsx` / `.html` file was written.
```

### Step 15b — Hi-fi killer-flow mood

The hi-fi mood is 3-5 brand+tokens-applied killer-flow screens as self-contained mobile-first static HTML — the **rendered half** of the visual contract (the atlas being the prose half). Dispatch the **§ Mood-screen-writer** brief (below) in **hi-fi mode**: `{{mood_tier}} = hi-fi`, the screens being the same killer-flow surfaces Step 02's lo-fi mood selected. See § Mood-screen-writer for the brief body.

### Step 15c — Fixture spec

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce fixture-spec.md — the single coherent mock-data contract for "{{idea}}". Every SDD-built screen will import ONE shared fixture set (foundation child implements it as `lib/mock-data.ts`); this spec defines it so no screen invents its own incoherent data.

CONTEXT: Read concept-brief.md at {{out}}/docs/concept-brief.md for the primary persona. Read system-design.md at {{out}}/docs/system-design.md § Data Model for the entity set + relationships. Read prd/v1.md at {{out}}/docs/prd/v1.md for the user-story surfaces the data must populate. Read sitemap.yaml at {{out}}/docs/sitemap.yaml for which screens consume which entities.

CONSTRAINTS:
- ONE persona (the primary persona from concept-brief.md — name, role, the account they own) — every screen renders that one persona's view.
- ONE coherent entity set: for each entity in system-design § Data Model, define 2-5 example records with realistic, internally-consistent field values.
- **Internal consistency is the whole point.** Dates form a plausible timeline (a record's `created_at` precedes its `updated_at`; an invoice's due date follows its issue date). Foreign keys resolve (every record referencing the persona's account uses the same account id). Money/counts/statuses across screens tell ONE story — a dashboard total equals the sum of the line items a detail screen shows.
- **Target language: `{{target_language}}`** (BCP-47). Persona name, entity labels, and all example string values in this language.
- ≥ 2 KB (anti-stub floor; no ceiling).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Required H2 sections: Persona / Entities (one H3 per entity, each with an example-records table) / Cross-Screen Consistency Notes (the timeline + the totals that must agree across screens).
- Write file DIRECTLY to {{out}}/docs/fixture-spec.md.

DELIVERABLE: {{out}}/docs/fixture-spec.md

DONE_WHEN: File exists; size ≥ 2 KB (anti-stub floor); contains "## Persona" + "## Entities" + "## Cross-Screen Consistency Notes"; every system-design § Data Model entity has an example-records table; one persona only; dates and foreign keys are internally consistent.
```

## Mood-screen-writer (lo-fi mood for Step 02 · hi-fi mood for Step 15b)

ONE brief, two modes. Produces self-contained static HTML **mood screens** — a rendered visual exploration of the killer flow. Per spec 066 this REPLACES the deleted per-route Next.js/Expo `.tsx` screen-writer: `/product` produces mood HTML, never an `app/**/page.tsx` screen set. Dispatched per screen, capped at 5 concurrent (see § Concurrency cap). The orchestrator substitutes `{{mood_tier}}` (`lo-fi` or `hi-fi`), the per-screen `{{NN}}` / `{{name}}` / `{{screen_intent}}`, and the output path before dispatch.

| Mode | Step | Pre/post brand | Output path | Tokens source |
|---|---|---|---|---|
| `lo-fi` | 02 | pre-brand exploration | `{{out}}/docs/screens/{{NN}}-{{name}}.html` | exploratory `:root` custom properties copied from `direction-a.html` |
| `hi-fi` | 15b | brand+tokens applied | `{{out}}/docs/screens/hifi/{{NN}}-{{name}}.html` | `:root` block copied verbatim from `docs/design-system/tokens.css`; brand voice from `docs/brand-book.md` |

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Write the {{mood_tier}} mood screen `{{NN}}-{{name}}.html` for "{{idea}}" — a self-contained static HTML rendering of the "{{screen_intent}}" surface.

CONTEXT:
- Mode: {{mood_tier}}. lo-fi = Step 02 pre-brand visual exploration; hi-fi = Step 15b brand+tokens-applied killer-flow screen (the rendered half of the visual contract).
- concept-brief.md at {{out}}/docs/concept-brief.md — product persona + mechanics + the killer flow.
- direction-a.html at {{out}}/docs/direction-a.html — the picked visual direction (lo-fi: copy its `:root` tokens; hi-fi: visual lineage only).
- hi-fi mode ALSO reads: design-system/tokens.css at {{out}}/docs/design-system/tokens.css (copy the `:root` token VALUES verbatim into this screen's `<style>` so it renders self-contained); brand-book.md at {{out}}/docs/brand-book.md (`## Language` for target language + `## Glossary` for the `We don't say` term-replacement lookup + voice samples for copy); design-system/components.md for component anatomy; fixture-spec.md at {{out}}/docs/fixture-spec.md for the mock data this screen renders.
- Step 02 template references: .claude/skills/product/templates/pipeline/02-prototype/references/{visual-constraints,a11y-checklist,anti-patterns}.md.

CONSTRAINTS:
- **Self-contained static HTML** — single file, one `<style>` block in `<head>`, inline `<svg>` for any chart/icon. NO external CSS/JS, NO build step, NO framework. The file opens directly via `file://`.
- **MOBILE-FIRST IS MANDATORY (spec 066 — closes F1).** Author the base CSS for the 375 px viewport; layer wider layouts via `@media (min-width: …)` breakpoints inside the `<style>` block. The screen MUST reflow with NO horizontal overflow at 375 px AND read correctly at 1280 px.
- **NEVER use `style=` attributes for layout/positioning.** All layout (flex, grid, spacing, sizing) lives in the `<style>` block as classes — an inline `style=` cannot carry a media query, which is exactly why it breaks mobile-first. A `style=` attribute carrying `display` / `width` / `margin` / `padding` / `position` is a hard violation. (A `style=` carrying ONLY a single dynamic value — e.g. a progress-bar `width` — is the lone tolerated exception.)
- **Tokens, not raw values.** Declare a `:root` block. lo-fi: exploratory custom properties from `direction-a.html`. hi-fi: copy the `:root` values verbatim from `design-system/tokens.css`. Every color / spacing / radius / font reads `var(--token)` — no bare `#hex`, no hard-coded `px` for layout (1px borders are the idiomatic exception).
- **hi-fi copy is real, on-brand, fixture-grounded.** Every user-facing string matches `brand-book.md` voice and respects `## Glossary § We don't say`. Every datum (names, numbers, dates) comes from `fixture-spec.md` — no lorem ipsum, no invented incoherent data. **Target language: `{{target_language}}`.**
- Buttons carry an explicit `type` attribute; every `<input>` / `<select>` has a matching `<label for>`; interactive elements get a `:focus-visible` outline.
- Size floor: each mood screen ≥ 4 KB (anti-stub floor — below this is a stub screen); no scope ceiling.
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — if output crosses it, STOP and emit a partial-result naming what was being produced (a token-runaway circuit-breaker, NOT a scope budget; no trim-loop, no re-emit-at-smaller-scope).
- Write the file DIRECTLY to the output path the orchestrator named.

DELIVERABLE: the {{mood_tier}} mood screen HTML file at the orchestrator-named path.

DONE_WHEN: File exists; valid self-contained HTML with one `<style>` block + a `:root` token block; size ≥ the 4 KB anti-stub floor; the `<style>` block carries ≥1 `@media (min-width: …)` breakpoint and the base CSS targets 375 px (mobile-first); NO `style=` layout attributes; no horizontal overflow at 375 px; hi-fi screens read `var(--token)` from tokens.css + render `fixture-spec.md` data + carry on-brand copy.
```

## Quality judge (dispatched after every step — spec 075)

ONE brief, one dispatch per **judge-unit** (steps 01-14 = the step; Step 15 = `15a-screen-atlas` / `15b-hifi-mood` / `15c-fixture-spec`, judged separately). Dispatched by the orchestrator AFTER a step's producer returns and the `wc -c` anti-stub pre-filter passes — an independent-context sub-agent that grades the step's artifact(s) against the step's rubric and emits a structured verdict. It is spec 075's replacement for the retired size-budget instrument. The full operational contract — rubric assembly, the verdict shape, the verdict→gate routing — is `references/quality-judge.md`; this is the dispatch template. The orchestrator substitutes `{{step_label}}`, `{{artifact_paths}}`, `{{schema_dir}}`, `{{rubric_section}}`, `{{verdict_path}}`, `{{out}}` before dispatch.

The step producers' briefs deliberately do **not** mention the judge — telling a producer it will be graded invites writing-to-the-judge bias. The judge evaluates after the fact.

**model:** `opus`  ·  **subagent_type:** `general-purpose`

```
TASK: Grade the artifact(s) of pipeline judge-unit "{{step_label}}" against the step's rubric and emit a structured quality verdict. You are an evaluator only — you do NOT edit the artifact, BLOCK, or abort.

CONTEXT:
- The artifact(s) to grade: {{artifact_paths}}.
- .claude/skills/product/references/quality-judge.md — the operational contract: rubric assembly, the right-sizing criterion, the verdict JSON shape, the routing. READ THIS FIRST.
- .claude/skills/product/references/quality-checklist.md {{rubric_section}} — the per-step semantic criteria (each a stable `id`) that form the rubric's semantic layer. Some steps have none — then the rubric is right-sizing + schema context only.
- {{schema_dir}}schema.md + {{schema_dir}}prompt.md — the step's required shape + job; CONTEXT for "what this artifact is for", NOT a checklist to re-run (the deterministic anchor check already ran at submit).
- {{out}}/docs/.state.json — the run's declared scope: `idea`, `flags`, and the roadmap phase count where present. The right-sizing criterion is judged against THIS, not a fixed size.

CONSTRAINTS:
- Pointwise, chain-of-thought. Grade ONE artifact-set against ONE rubric; reason criterion-by-criterion before emitting each `verdict`. Never compare or rank two artifacts.
- The rubric = the `quality-checklist.md {{rubric_section}}` criteria + the universal `right-sizing` criterion. Grade each `pass` / `concern` / `fail` with a one-line `note`. On `concern`/`fail` the `note` MUST name the section + dimension — never just "missing" or "too long".
- **right-sizing — the anti-verbosity criterion. DO NOT REWARD LENGTH.** A longer artifact is not a better artifact. Judge whether every section pulls weight for the artifact's declared job at THIS run's declared scope (read `.state.json`). A correctly-scoped large artifact for a large declared product is `pass`; a padded artifact for a small one is `fail`; a section too thin for its job is `fail`. Grade scope-fit, never byte count. Full criterion text: `quality-judge.md § The right-sizing criterion`.
- Grade quality, not presence. The `schema.md` anchors were already deterministically checked at submit — your job is whether the present sections are substantive and load-bearing.
- You NEVER BLOCK, abort, trim, or edit the artifact. Your strongest signal is `outcome: "fail"`, which the orchestrator routes to a phase-gate `iterate` recommendation — the human decides. Deterministic BLOCK/abort is not yours.
- Emit the verdict in the exact JSON shape of `quality-judge.md § The verdict`: `step` / `judged_at` (UTC ISO-8601) / `model` (`opus`) / `criteria[]` / `scope_assessment` / `outcome`. `outcome` = max-severity rollup (`fail` > `concern` > `pass`).
- Catastrophe cap per `.claude/rules/artifact-budgets.md`: a uniform 200 KB ceiling — a verdict never approaches it; if you somehow do, STOP and emit a partial-result.

DELIVERABLE: the verdict JSON object written to {{verdict_path}}; plus a 1-2 line plain-text summary as your final message (the human-readable trace — `outcome` + `scope_assessment`).

DONE_WHEN: {{verdict_path}} exists and parses as JSON; carries `step` = "{{step_label}}", `criteria[]` with one row per rubric criterion (each `id` + `verdict` ∈ pass/concern/fail + `note`), a `right-sizing` criterion, a one-line `scope_assessment`, and `outcome` = the max-severity rollup; no artifact file was modified.
```

## Concurrency cap

The Step 02 lo-fi mood-screen-writers and the Step 15b hi-fi mood-screen-writers fan out: **MAX 5 concurrent `Agent` calls** each. Both phases produce 3-5 mood screens (killer flow only), so the cap is rarely hit — it stands as the guardrail. Step 15a (atlas) + 15b (hi-fi mood) + 15c (fixture-spec) are three distinct sub-agents dispatched together in one message; that trio plus a 5-screen 15b fan-out is well within the cap.

**Cap=5 was proven non-OOM** on spec 034's 17-route dogfood (2026-05-17).

## Failure handling

Per spec 045 (port of spec 036 Q4 resolution), updated for the spec 066 restructure:

- **Step 01 BLOCKED** → ABORT the entire run (upstream-of-everything).
- **Step 15a (atlas) BLOCKED** → ABORT the entire run (the atlas IS the visual contract; Phase 5's SDD handoff has nothing to hand off without it).
- **Step 07 BLOCKED** via schema enforcement → AUTO-RETRY with augmented brief naming missing required_categories. Up to 2 retries before falling through to user `iterate` at Phase 2 gate.
- **Step 15b (hi-fi mood) or 15c (fixture-spec) BLOCKED** → degrade gracefully: log to REPORT.md `## Blocked steps`; Phase 5 still runs (the atlas alone is a usable contract; a missing hi-fi mood or fixture-spec is a documented gap, not an abort).
- **Any other step BLOCKED** → degrade gracefully: append `{step_label, reason, artifacts_partial}` to `.state.json.blocked_steps`; log to REPORT.md `## Blocked steps`; continue.

Mood-screen-writer (per-screen) failures within Step 02 or Step 15b: mark the specific screen BLOCKED in `.state.json`; continue with the remaining screens. The whole step does NOT fail on one bad screen.

## Cross-references

- `pipeline-coverage.md` — phase/step map + per-step output + size floors (15 steps)
- `state-machine.md` — `.state.json` v5 shape + gate semantics + resume support
- `sitemap-schema.md` — Step 07's load-bearing required_categories enforcement
- `sdd-handoff.md` — the Phase 5 umbrella + foundation-child scaffold contract
- `quality-checklist.md` — the quality judge's semantic rubric (per-step + visual-contract criteria) + the deterministic orchestrator gates
- `SKILL.md` — orchestration body that dispatches these briefs
- `.claude/rules/delegation.md` — 5-field handoff discipline
- `templates/pipeline/<step>/prompt.md` — canonical step brief (sub-agents read this directly)
- `docs/specs/066-product-ui-quality/` — the restructure spec (delete the screen-writer fan-out; end at the visual contract + SDD handoff)
- `docs/specs/045-prototype-skill-pipeline-realign/` — pipeline lineage
- `docs/specs/032-pipeline-industry-alignment/` — parent industry-alignment (17 decisions ported here)
