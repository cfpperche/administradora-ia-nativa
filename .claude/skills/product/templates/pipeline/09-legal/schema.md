# Step 12 — Schema (legal-posture — single artifact)

The submitted `legal-posture.md` MUST contain the level-2 markdown headings below + meet the Layer 1 size/content floor in the JSON fenced block. Both checks fire on submit; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list. Single-artifact step — no `extra_files`.

## Size floor (anti-stub — spec 075; CONDITIONAL model)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains. Legal-posture is unique: its floor is conditional on which sections fire — DPIA (sensitive data categories in `data-flow.json`), AI-Specific (LLM in stack), Regulated Aspects (vertical-specific regimes — HIPAA / LGPD / FINRA / etc).

| Profile | `min_size` floor add | Notes |
|---|---|---|
| **Base** (no conditional fires) | 5 KB | terms + privacy + licensing + sub-processor + open-decisions only |
| **+ DPIA** | +5 KB | when `data-flow.json` declares sensitive categories (PII, PHI, financial, etc) |
| **+ AI-Specific** | +2 KB | when system-design integration list contains LLM provider |
| **+ Regulated Aspects** | +2 KB | when vertical hits a named regime (HIPAA / LGPD / FINRA / PCI-DSS / etc) |

**Computation:** the orchestrator sums the `min_size` floor adds across base + each firing condition to produce the effective floor (e.g. a healthtech product with PII + LLM lands at 5+5+2 = 12 KB floor). The Layer 1 JSON `min_size` below is the OPERATIONAL base floor; the full conditional floor check happens orchestrator-side. A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Required sections (legal-posture.md markdown headings)

Section names slugify by lowercasing + dashing — `## Terms of Service Posture` → `terms-of-service-posture`, `## Open Decisions` → `open-decisions`. Cosmetic variants accepted; slugifier strips them.

- `overview`
- `terms-of-service-posture` (or `terms-posture` — both slugs accepted)
- `privacy-posture`
- `data-handling`
- `licensing`
- `regulated-aspects`
- `open-decisions` (the deciding-signal-bearing decision-surface; mirrors step-9 / 10 / 11)

The escape-clause sits at the TOP as block-quoted prose, NOT as its own `## H2` section — visibility-by-position is the discipline. Layer 1 enforces its presence via the literal-contains anchor (see Layer 1 § `Counsel review is required`).

## Conditional / optional sections

- `ai-specific` — conditional H2 that fires ONLY when AI is in the system-design § Integrations data flow (LLM vendor like OpenAI / Anthropic / Cohere / Mistral, or self-hosted generative model). The prompt's § 2 signal-extraction (signal 4) drives the inclusion. Schema does NOT structurally require this section — its absence is correct when AI is not in the stack.
- `sub-processors` — optional dedicated H2; the sub-processor disclosure table may live inline in § Data Handling (a `### Sub-processor disclosure` sub-section) OR as its own § Sub-Processors H2. Either shape satisfies the schema. Surfacing as its own H2 is recommended when the sub-processor count is ≥6 (the table dominates the section anchored to it).

The schema does NOT structurally enforce the product-class calibration (Consumer / B2B SaaS / AI-stack / Regulated Vertical). The prompt's § 5 enforces it discursively — a regulated-vertical product without HIPAA / GLBA / FERPA posture rows in § Regulated Aspects is the regression mode the discipline catches at review time, not at submit time.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "legal-posture.md",
      "min_size": 5120,
      "contains": [
        "## Overview",
        "## Privacy Posture",
        "## Data Handling",
        "## Licensing",
        "## Regulated Aspects",
        "## Open Decisions",
        "Counsel review is required",
        "| Regulation | Trigger | Applicable? |",
        "| Sub-processor |",
        "[counsel-review]",
        "Deciding signal"
      ],
      "any_of_contains": [
        "## Terms of Service Posture",
        "## Terms Posture",
        "## Terms-of-Service Posture"
      ]
    }
  ]
}
```

### Patent posture + IP-assignment anchors (advisory, not Layer-1-enforced)

The step-12 calibration revisions applied 2026-05-16 (per `prompt.md § What this step ports vs diverges § Calibration revisions applied`) introduce two new posture surfaces — **patent strategy** (KEEP 5) and **IP-assignment / PIIA** (KEEP 2) — that the prompt mandates but the Layer 1 schema does NOT enforce as literal-contains anchors. Three reasons for the soft-enforcement choice:

1. **Anchor surface is wide.** Patent posture may legitimately phrase as `Alice/Mayo`, `Alice / Mayo`, `§ 101`, `Section 101`, `no patent filings`, `no software-only patent filings`, `Patent strategy posture`, `Patent posture`, or any English paraphrase. A single literal anchor under-fires; an `any_of_contains` covering all variants would over-fire on cosmetic differences. Hard-coding the variant set risks an arms-race against the agent's phrasing latitude.
2. **The schema parser does not support multiple `any_of_contains` arrays per file.** Only one such array is parsed (see `src/templates.ts:275`), and that slot is already used by the terms-section-variant tolerance check. Adding a second `any_of_contains_patent` field would be silently ignored — the false-confidence anti-pattern.
3. **Soft enforcement matches the discipline.** Patent omission and PIIA-burial are content-shape regressions that surface at counsel-review time (the lawyer notices "the document doesn't mention patents") AND at investor-diligence time (Series A IP-chain-of-title pass surfaces the PIIA gap). The discipline lives in the prompt's § 4 step 5 (Licensing) + § Voice & rigor + the Calibration revisions paragraph, not in a brittle literal-anchor check.

**For agents writing `legal-posture.md`:** the patent-posture line and the IP-assignment posture (with PIIA + Founder IPAA § Open Decisions rows) are MANDATORY per the prompt's § Voice & rigor. The Layer 1 schema check does NOT block submission on their absence; counsel-review at Phase 5 + investor-diligence at Series A will catch the gaps. Treat the prompt's mandate as the binding contract.

**For future schema revisions:** if dogfood evidence shows agents systematically omit patent / IPAA / PIIA surfaces despite the prompt's mandate, the right fix is to extend the parser to support multiple `any_of_contains_*` arrays per file (e.g. `any_of_contains_patent`, `any_of_contains_ip_assignment`) rather than overloading the single existing slot. The slot-extension pattern preserves the OR-semantic-per-concept shape; overloading would conflate concepts.

### Notes on the floors

- **`legal-posture.md` `min_size: 5120` (5 KB)** — lowered from spec 026's 9 KB per spec 056 calibration. The new floor is the **base profile minimum** (no DPIA, no AI, no Regulated). The conditional model in `## Target` above applies the per-section additions (DPIA, AI, Regulated) to produce the effective floor per product. Empirical: dogfood-v3 + dogfood-erp landed at 6.8-6.9 KB on base-only products; the old 9 KB floor would have BLOCKED them despite the docs being honest-depth complete. Floor anchored against the 5 base sections at honest depth. A B2B SaaS posture with 6-row § Privacy regulation matrix, 4-6-row § Data Handling sub-processor table, 3-5 § Regulated Aspects rows, § Licensing with OSS-component table (4-8 rows), § Open Decisions (2-4 rows) lands at 9-11 KB. AI-stack adds ~2 KB for § AI-Specific. Regulated Vertical expands to ~12-15 KB with additional regime rows. Micro-products may legitimately land under 9 KB when § Privacy degenerates (use `# OVERRIDE: compact-product: <class>` shape in submit context); 9 KB is the universal sanity line. The floor is slightly higher than step-11's 8 KB because legal is denser (regulation matrix + sub-processor table + OSS license matrix all carry table content; step-11 ran narrative-shorter).

- **The literal `## Privacy Posture` substring** — proves the privacy section exists as an H2 with the canonical name. The privacy section is the dense load-bearing section; without an H2 anchor, the reader has no scan target.

- **The literal `## Regulated Aspects` substring** — proves the regulated-aspects section exists as an H2 (NOT collapsed inline into § Privacy). The regulated-aspects section MUST be visible at the H2 level because counsel-review reviewers scan for it; collapsing it inline is the regression mode that lets HIPAA / COPPA / PCI / GDPR triggers silently miss surfacing.

- **The literal `Counsel review is required` substring** — proves the escape clause at the TOP of the document. Without this anchor, the document is structurally indistinguishable from "AI-drafted legal advice" — the anti-pattern the escape clause exists to prevent. The exact phrase `Counsel review is required` is the canonical wording in the prompt's § 3 escape-clause template; cosmetic variants like "counsel review needed" / "lawyer review must happen" do NOT satisfy the literal anchor — the discipline is that the canonical phrase appears verbatim.

- **The literal `| Regulation | Trigger | Applicable? |` substring** — proves the § Privacy Posture § Applicable regulations matrix exists as a structured markdown table. Mirrors step-10's `| # | Assumption |` / step-11's `| Deliverable | Owner | Status |` literal-anchor pattern. The literal table-header substring only appears as a real markdown table — not in prose. Without this anchor, the privacy section silently degrades to "GDPR may apply; CCPA may apply" prose without per-regulation posture commitment, which is the regression mode the discipline catches.

- **The literal `| Sub-processor |` substring** — proves the sub-processor disclosure table exists (whether under § Data Handling § Sub-processor disclosure or under a dedicated § Sub-Processors H2). GDPR Art 28(2) requires prior authorization for EACH sub-processor; vague "we use various third parties" prose fails the requirement. The literal table-column-header substring forces the structured shape.

- **The literal `[counsel-review]` substring** — the calibration anchor inherited from step-11's concern-tag discipline. Proves at least one row (in § Regulated Aspects or § Open Decisions) carries the `[counsel-review]` cross-functional concern tag. Without this anchor, the posture document silently degrades to "looks like compliance" prose without surfacing the outside-counsel-must-sign-off rows — which is the regression mode the discipline catches. The bracket-named tag only appears as a real disciplinary signal.

- **The literal `Deciding signal` substring** — proves at least one § Open Decisions row carries a deciding signal that closes the deferral. Mirrors step-9 / 10 / 11 § Open Decisions § Deciding signal column at the legal-posture layer — every deferred legal decision either HOLDS or FLIPS on a measurable signal (counsel sign-off email, first-EU-customer LOI, regulatory deadline date).

- **`any_of_contains: ["## Terms of Service Posture", "## Terms Posture", "## Terms-of-Service Posture"]`** — the OR-semantic check that catches three valid terms-section H2 shapes: (a) `## Terms of Service Posture` (full canonical), (b) `## Terms Posture` (compact for Consumer Mobile / Micro), (c) `## Terms-of-Service Posture` (hyphenated variant). A posture document that omits all three is one of two things: (i) the terms section was silently dropped (regression mode — every product needs a terms posture, even free / not-for-profit), or (ii) the section was misnamed in a way the slugifier doesn't catch. Layer 1 catches both. Step-9's `any_of_contains` invented-for-step-6/7-Audit-Response is the precedent; step-10 reused it for revenue-vs-NFP; step-11 reused for canonical-vs-bridge; step-12 reuses for terms-section-variant-tolerance.

- **No `required_glob`** — single-artifact step; nothing to glob.

- **Dogfood lesson inherited from steps 7 + 8 + 9 + 10 + 11 (2026-05-15 → 2026-05-16):** loose section-name substrings (`Privacy`, `Regulation`, ...) are silently fakeable from prose. Step 12's Layer 1 uses literal H2 heading anchors (`## Overview`, `## Privacy Posture`, ...) AND the table-header literals (`| Regulation | Trigger | Applicable? |`, `| Sub-processor |`) AND the calibration tag (`[counsel-review]`) AND the escape-clause anchor (`Counsel review is required`). The literal heading + table row + emphasis + bracket-tag blocks only appear as real markdown structure.

## Section content guidance (depth, not just presence)

The schema enforces presence + floor; *depth* is the agent's responsibility, reinforced by `references/privacy-matrix-shape.md` + `references/oss-license-matrix.md` + `references/regulated-aspects-checklist.md`.

### `legal-posture.md`

- **Overview** — short paragraph + biggest-legal-risk one-liner + counsel-review-timing one-liner. Names product class (consumer / B2B SaaS / dev-tool / AI-stack / regulated-vertical) + jurisdiction exposure + AI-stack signal so depth calibration is visible. Mirrors step-9 / 10 / 11 § Overview shape.
- **Terms of Service Posture** — acceptance model (clickwrap vs scroll-wrap) + governing law + acceptable use + payment/cancellation posture + limitation of liability cap. NOT the actual ToS. Counsel-review checkpoint named.
- **Privacy Posture** — applicable regulations matrix table (GDPR / LGPD / CCPA / PIPEDA / COPPA / HIPAA / FERPA per applicability) + controller-vs-processor declaration per-flow + data-categories table with legal-basis + retention + deletion mechanism + data-subject-rights procedure + cross-border-transfer mechanism (SCCs / adequacy / BCRs) + DPIA trigger flag when applicable.
- **Data Handling** — encryption posture (at-rest + in-transit) + backup retention + breach notification commitment (72-hour GDPR Art 33 + ANPD LGPD + state US laws) + access controls + sub-processor disclosure table (`| Sub-processor | Purpose | Data Categories | DPA Reference | Cross-Border Mechanism |`).
- **Licensing** — product's own license + rationale + OSS component compatibility table (`| Component | License | Version | Use | Distribution Model | Copyleft Risk | Action Required |`). AGPL components in SaaS stacks flagged `Critical — network copyleft triggered`. License-choice rationale paragraph mandatory.
- **Regulated Aspects** — conditional rows per applicable regime (HIPAA / COPPA / PCI DSS / SOC 2 / GLBA / FERPA / AI Act / state-employment-privacy / trade-secret / trademark). Each row carries a posture sentence + a counsel-review trigger.
- **AI-Specific** (conditional — fires only when AI-in-stack) — training-data provenance + model-output-liability disclaimer posture + user disclosure of AI involvement + opt-out from model improvement + vendor sub-processor disclosure (LLM vendors) + output filtering posture.
- **Open Decisions** — 2-4 deferred legal-posture decisions. Markdown table `| # | Decision | Default if no decision by | Deciding signal | Concern |`. Mirrors step-9 / 10 / 11 § Open Decisions discipline. Concern column uses step-11 tag allow-list extended with `[counsel-review]`.

### Operating mode (declared inline; NOT a separate section)

The agent declares product class + AI-stack signal at top of `legal-posture.md` in § Overview opening sentence: `**v1 legal posture for a B2B SaaS with AI-stack (full template applied; § AI-Specific fires).**` Visible to downstream consumers (step 13 reads to size the prototype-v3 compliance UI surface — privacy-notice screens, consent dialogs, terms-acceptance flows).

When product class is Micro-Product or Consumer-with-no-PII-collection, § Privacy + § Data Handling + § Sub-Processors degrade explicitly:
- § Privacy → `*No PII collected; section degenerates per Compact calibration*` (still emits the H2 so schema check passes)
- § Data Handling → `*No PII stored; § Data Handling degenerates to license + ToS posture only*`

Schema does NOT structurally validate degeneration shape — the prompt's § 5 product-class calibration ladder enforces it discursively.

## Atomic write semantics

`product_step_submit` validates `legal-posture.md` against both layers (section presence + Layer 1 contains/size) before writing. On any failure, response is `{ code: "schema-incomplete", failures: [...] }` and nothing persists. On success, the file writes via mktemp+rename — atomic, or absent.

## Gate behavior (step 12 closes Specification)

Step 12 is a **gate-closer**. Per `src/pipeline.ts` § `GATE_AFTER = [4, 7, 12]`: after a clean `product_step_submit` for step 12, calling `product_advance` returns `code: "gate-required", phase: "specification"`. The parent confirms with the user that Specification phase is ready to close, calls `product_gate_pass("specification")`, then `product_advance` again to enter step 13 (prototype-v3 — the visual contract). Step 12 is NOT the final step — step 13 closes the pipeline (per `src/pipeline.ts` § comment: step 13 is the in-phase final deliverable of specification; `product_advance` after step 13 fires `pipeline-complete`).
