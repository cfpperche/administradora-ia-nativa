# Step 8 — Schema (PRD — single artifact)

The submitted `prd.md` MUST contain the level-2 markdown headings below + meet the Layer 1 size/content floor in the JSON fenced block. Both checks fire on submit; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list. Single-artifact step — no `extra_files`.

## Required sections (prd.md markdown headings)

Section names slugify by lowercasing + dashing — `## User Stories` → `user-stories`. Cosmetic variants (trailing punctuation, parenthetical suffixes) are accepted; slugifier strips them.

- `problem-statement`
- `goals`
- `non-goals`
- `user-stories` (carries the US-NN IDs)
- `requirements`
- `success-metrics`
- `acceptance-criteria`
- `audit-response` (mirror of steps 6 + 7 — the step-4 audit-findings routing trail, separate from Backlog; Backlog stays for genuinely-deferred items only)
- `open-questions`
- `backlog`

## Optional sections (not enforced, produced when applicable)

- `target-users` — when persona refinement beyond step 1 is warranted (multi-persona products always include)
- `technical-considerations` — feasibility flags + external dependencies; usually present but compact-mode PRDs may omit
- `timeline` — soft launch target; optional, only when collected during the parent's interview. **When present, prefer phased dates over a single target** — name 2-4 phases with date ranges (e.g. `Build phase 1: 2026-06-01 → 2026-06-30 · Build phase 2: 2026-07-01 → 2026-08-15 · Hardening: 2026-08-16 → 2026-09-14 · Closed beta: 2026-09-15 → 2026-10-14 · Public launch: 2026-10-15`). Engineering leads need the sequencing model, not just the target. A single-date timeline ("public launch 2026-10-15") forces eng to invent the phasing themselves — typically silently — which makes scope-cut conversations downstream harder.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "prd.md",
      "min_size": 6144,
      "contains": [
        "## Problem Statement",
        "## Goals",
        "## Non-Goals",
        "## User Stories",
        "## Requirements",
        "## Success Metrics",
        "## Acceptance Criteria",
        "## Audit Response",
        "## Open Questions",
        "## Backlog",
        "**US-01.**",
        "| # | Requirement | Acceptance Criteria | Source |",
        "| Metric | Baseline | Target | Measurement |"
      ],
      "any_of_contains": [
        "### F-",
        "*Step 4 audit ran without YAML frontmatter",
        "*No step-4 audit findings",
        "*Step 4 emitted structured findings, none routed",
        "step 4 F-"
      ]
    }
  ]
}
```

### Notes on the floors

- **`prd.md` min_size 6144** (6 KB) — covers the 9 required sections at honest depth. An SMB SaaS PRD with 10-20 user stories + P0/P1/P2 tables + 2-4 BDD scenarios per P0 + Backlog with audit-finding back-references lands 12-25 KB. Micro-product compact-mode PRDs (per `prompt.md § 6`) may land at 6-8 KB; the 6 KB floor is the universal sanity line, not the typical-case.

- **`**US-01.**` substring** — the literal `**US-01.**` proves the US-NN ID convention is materialized in user stories. The Markdown bold + dot pattern is unique enough to not collide with other prose. A PRD that uses anthill-style unnumbered "As a..." lines without IDs trips Layer 1 immediately. **Why this specific check matters:** step 13's PRD-coverage scoring depends on stable IDs; if the IDs aren't present at PRD-submit time, downstream coverage scoring breaks silently. The Layer 1 check is the FIRST line of defense; the prompt's voice-rigor guidance (`prompt.md § Voice & rigor` — append-don't-renumber) is the second.

- **The literal pipe-delimited row `| # | Requirement | Acceptance Criteria | Source |`** — proves the requirements tables (P0 / P1 / P2 / Backlog) carry the canonical 4-column shape including the `Source` column (the audit-trail / spec-traceability / prototype-screen-link column — see `prompt.md § 4 item 6` for routing). A PRD that ships requirements without the `Source` column breaks the audit-trail discipline; the literal row enforces it.

- **The success-metrics row `| Metric | Baseline | Target | Measurement |`** — proves the metrics table is structured (not just bullets). The Measurement column is the load-bearing one — without it the metric is "we want activation to go up" rather than "activation rate at day 7 measured via the analytics events `signup_complete` and `first_action_taken` in BigQuery". Layer 1 enforces presence; the prompt's voice rigor enforces concreteness.

- **No `required_glob`** — single-artifact step; nothing to glob.

- **Dogfood lesson from step 7 (2026-05-15):** loose dimension-name substrings (`Token`, `Voice`, ...) are silently fakeable from prose. Step 8's Layer 1 uses the literal full table-header row trick (mirrored from step 7's `| Token | Voice | Component | Audit-fix | Specificity |` fix). The literal pipe-delimited row only appears as a real markdown table header, restoring the structural floor.

## Section content guidance (depth, not just presence)

- **Problem Statement** — concrete user pain with evidence. Specific number / quote / observed behavior from step 1's brief or step 4's audit. Anti-pattern: "the experience could be better". Good: "EM persona spends 12 min on Jira triage daily; spec 026 dogfood persona quote: *'loves Linear's UX but balks at the per-seat price'*."
- **Goals** — 3-5 outcome-oriented bullets. "User triages a sprint in <5 min" not "Build triage view".
- **Non-Goals** — explicit out-of-scope, one-line reason each. Empty Non-Goals = scope creep waiting to happen; the parent's interview at `prompt.md § 2` should produce 3-5 explicit non-goals.
- **User Stories** — every story carries `**US-NN.**` (zero-padded, sequential). Format: `**US-NN.** As a <role>, I want <action> so that <benefit>.` Append-don't-renumber discipline (see `references/prd-format.md § ID stability`).
- **Requirements** — three priority tiers (`### Must Have (P0)`, `### Should Have (P1)`, `### Nice to Have (P2)`) + Backlog (own H2 below) — each as a markdown table with `# | Requirement | Acceptance Criteria | Source`. Source column links: `US-NN` for user-story origin, `spec § <name>` for spec section, `prototype-v2 screens/<NN>-<name>.html` for visual proof, `step 4 F-NN` for audit-driven items.
- **Success Metrics** — ONE primary metric row carrying baseline + target + measurement window. Optional supporting observability metrics in a clearly-labeled sub-table (`### Observability metrics (read-only — not optimization targets)`). The primary row is non-negotiable; observability is calibrated.
- **Acceptance Criteria** — BDD Given/When/Then **per P0-routed user story** (2-4 scenarios each; reference the prototype-v2 screen filename when behavior is screen-specific). Stories routed to P1 / P2 / Backlog inherit their acceptance from the `Acceptance Criteria` column of their requirement row — that's sufficient at the PRD layer; full BDD on P1+ is optional and is the step-9 system-design's prerogative when engineering needs the behavioral contract sharpened. Forcing BDD on P2 / Backlog at the PRD layer is over-prescription (the items may never ship; writing full BDD is wasted effort).
- **Open Questions** — what's not yet decided. Each has an owner (`@founder`, `@cto-tbd`, `@design`) OR a downstream step (`→ step 9 system-design`, `→ step 10 cost-estimate`). Questions without resolution path are red flags — the founder owes a decision.
- **Backlog** — markdown table: `# | Title | Source | Why deferred`. Routes step 4 deferred findings, prototype-v2 deviations, post-v1 spec items. Empty Backlog with no commentary = scope smaller than v1 deserves; empty Backlog with `*v1 is genuinely complete; no post-v1 items surfaced.*` is honest.

## Citation discipline

Every requirement row's `Source` column has a clickable / greppable origin:

- `US-01` → user-story origin (same PRD, scroll up)
- `spec § Killer flow` → step 3 functional-spec section
- `prototype-v2 screens/05-triage-view.html` → step 7 screen filename (verifiable by `file://` open)
- `step 4 F-01` → step 4 audit finding ID
- `founder · 2026-05-16` → captured during step 8 interview, with date

A row without a `Source` reference is a discipline failure — every requirement in v1 must trace to one of the prior artifacts or to the founder's interview. Inventing requirements mid-PRD is the regression mode this column prevents.

## Atomic write semantics

`product_step_submit` validates `prd.md` against both layers (section presence + Layer 1 contains/size) before writing. On any failure, response is `{ code: "schema-incomplete", failures: [...] }` and nothing persists. On success, the file writes via mktemp+rename — atomic, or absent.
