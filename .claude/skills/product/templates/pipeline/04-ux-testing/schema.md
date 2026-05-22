# Step 4 — Schema (validation report)

Step 4 submits a single artifact, `validation-report.md`. Two validation layers fire on `product_step_submit`:

1. **Section check** — the report must carry level-2 markdown headings (`## <Title>`) whose slugs match the required-sections list below.
2. **Layer 1** — the report must satisfy the `required_files` floor (size + `contains` substrings, including the `validation_mode:` line).

Either failure produces `code: "schema-incomplete"` with the precise failure list; nothing is written until both pass.

## Required sections (markdown headings)

Each name slugifies by lowercasing + dashing the H2 title — `## Heuristic Evaluation` → `heuristic-evaluation`, `## Post-Launch Signal` → `post-launch-signal`. Match these slugs precisely.

- audit-scope
- validation-mode
- heuristic-evaluation
- accessibility-review
- findings
- strengths
- evidence
- verdict
- priority-recommendations
- post-launch-signal

## Required line (regex-extracted by MCP)

The report body MUST contain a line matching the pattern:

```
validation_mode: <tested|intuition|not-applicable>
```

Case-insensitive on the key, case-sensitive on the value. Place it near the top of the document (inside or just below `## Validation Mode`) so the MCP's regex finds it reliably. `product_step_submit` extracts the value and stores it in `.state.json.validation_mode` for downstream steps. Layer 1 (`contains: "validation_mode:"`) rejects the submission if the line is absent — the pre-port template only *extracted* the line without enforcing it.

## Optional YAML frontmatter — structured findings handoff

The report MAY open with a YAML frontmatter block (`---` ... `---`) carrying a structured `findings[]` field that downstream steps (step 6 design-system, step 7 screen-atlas) read programmatically. This is the audit-as-delegation-manifest pattern restored from the anthill comparison (the original `anthill-ux-audit` schema-validated its frontmatter; the pre-prepare port had pure markdown). Optional, not required by Layer 1 — but **strongly recommended** when `validation_mode: intuition` or `tested` AND the audit branch is `(i) measurable` (HTML inputs), because that's when the findings have the concrete data downstream consumers can act on.

Frontmatter shape:

```yaml
---
findings:
  - id: F-01
    severity: 4               # integer 1-4
    heuristic: "A11y 2.4.7 Focus visible"
    location: "screens/05-triage-view.html, screens/07-command-palette.html"
    issue: "<one-line concrete description>"
    recommendation: "<specific actionable fix>"
    wcag: "2.4.7"             # optional, only for a11y findings
    fix_skill_hint: "design-system"   # one of: design-system | screen-atlas | deferred
    complexity_estimate: "~30 min"     # rough effort, free-form
priority_fixes:
  - batch: "a11y-contrast-token-tune"
    finding_ids: [F-07, F-09]
    rationale: "single token edit cascades to all 8 screens"
    complexity_estimate: "~30 min"
    when: "before gate"
---
```

**Field meanings (consumer-facing):**

- `findings[].fix_skill_hint` — names which downstream MCP step naturally owns the fix:
  - `"design-system"` — the fix is a token tune (contrast, lightness, semantic-color rebalance). Step 6 reads these and applies them in `tokens.css`, documenting each in `## Audit Response` of `design-system.md`.
  - `"screen-atlas"` — the fix requires re-rendering screens (semantic HTML pass, focus-indicator restore, missing input elements). Step 7 reads these as acceptance criteria.
  - `"deferred"` — the fix is real but not blocking the v1 pipeline (cosmetic polish, WCAG 2.2 readiness, `prefers-reduced-motion` wraps). Surfaced for backlog grooming, not consumed mid-pipeline.
- `priority_fixes[]` — the same named-batch grouping the markdown `## Priority Recommendations` section already requires, mirrored as structured data so consumers can iterate without re-parsing markdown tables. Each batch's `finding_ids` reference the `findings[].id` values; the `batch` slug is the handoff unit.

The markdown body is the human-readable view; the frontmatter is the machine-parseable view. They MUST agree (same finding IDs, same severities, same recommendations) — the `## Findings` table in the body is a derived view of the frontmatter when present. If they diverge, that's a defect.

When the audit is in branch (ii) `projected` mode (markdown-spec input, no measurable findings to hand off), frontmatter is optional and typically omitted — there's nothing structured to consume.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "validation-report.md",
      "min_size": 8192,
      "contains": [
        "validation_mode:",
        "## Heuristic Evaluation",
        "## Accessibility Review",
        "## Findings",
        "## Verdict",
        "Nielsen",
        "WCAG"
      ]
    }
  ]
}
```

- `min_size: 8192` (8 KB) — the deep-port floor. A real heuristic audit (10 Nielsen heuristics walked per in-scope flow + a WCAG 2.1 AA review + a severity-rated findings table + ≥3 strengths + the mode evidence + verdict + recommendations) lands well past 8 KB. The pre-port one-paragraph posture note did not — that gap is exactly what this step closes.
- `contains` anchors the audit spine (`Nielsen`, `WCAG`, the three audit-section headings + `## Verdict`) and the load-bearing `validation_mode:` line. The section-slug check covers the rest.

## Section content guidance (depth, not just presence)

- **audit-scope** — what is being audited (which screens/flows from step 2), the target persona every finding is judged through, the audit type. For a small prototype, all screens; for a large one, the killer flow + auth + empty-first-run.
- **validation-mode** — name the declared mode (`tested` / `intuition` / `not-applicable`) plus 1–2 sentences justifying the choice. Contains the regex-extracted `validation_mode:` line.
- **heuristic-evaluation** — all 10 of Nielsen's heuristics applied to every in-scope flow (error/empty/loading states included, not just the happy path). CLI/API products adapt the heuristics to terminal UX. See `references/heuristics.md`.
- **accessibility-review** — WCAG 2.1 AA checks: colour contrast (4.5:1 body, 3:1 large text + UI), keyboard nav, focus indicators, screen-reader compatibility. Each check `pass`/`warn`/`fail` with observed evidence. Violations are severity ≥ 3.
- **findings** — severity-rated table, every finding actionable. Define the 1–4 severity scale (with criteria) before the table. One finding = heuristic/WCAG ref + severity + location + concrete issue + specific recommendation. Sorted by severity.
- **strengths** — ≥ 3 things that work well and must NOT be changed.
- **evidence** — the mode-specific block: `tested` → recruit profile + tasks + observations + user count; `intuition` → the articulated bet (segment + ≥2 named comparables + differentiation); `not-applicable` → why conventional testing doesn't fit this product class.
- **verdict** — `tested`: PROCEED / PIVOT / KILL + reasoning. `intuition`: "PROCEED on bet, validate post-launch via <signal>". `not-applicable`: "PROCEED to identity phase; validation deferred to post-launch via <signal>". A non-zero severity-4 count makes PROCEED hard to justify — address it.
- **priority-recommendations** — severity × effort batches: fix-before-gate vs. defer. Each batch names the finding IDs it covers.
- **post-launch-signal** — the observable signal (metric, behaviour, market response) that retroactively confirms or refutes the validation choice. Required for all three modes. Concrete: "DAU > 100 in week 4", "PyPI downloads > 200 in month 1", "5 unsolicited inbound demo requests".
