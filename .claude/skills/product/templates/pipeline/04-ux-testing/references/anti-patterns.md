# UX-audit anti-patterns

Ported from `anthill-ux-audit` and augmented for this pipeline's three-mode posture. Each row: the trap, then the fix. Read before auditing.

## Audit-quality traps

| Anti-pattern | Instead |
|---|---|
| No target user defined | State the primary persona (from the step-1 concept brief); evaluate every finding through their lens. |
| Skipping the accessibility review | Run WCAG 2.1 AA against every in-scope screen; treat violations as severity 3 or higher — never cosmetic. |
| Findings without recommendations | Every finding includes a specific, actionable fix — "add a confirmation modal requiring the user to type DELETE", not "make it safer". |
| Severity ratings without criteria | Define the 1–4 severity scale (with definitions) in the report *before* the findings table; apply it consistently. |
| Rating severity by how easy the fix is | Severity is impact on the target persona. Effort belongs in the priority-recommendations batching, not in the severity number. |
| Auditing only the happy path | Audit the error states, empty states, and loading states too — that is where most heuristic violations hide. |
| Ignoring existing strengths | Document ≥ 3 things that work well — teams need to know what NOT to change. |
| Applying heuristics selectively | All 10 of Nielsen's heuristics, every major flow. Cherry-picking the heuristics that confirm a hunch is not an audit. |
| Findings sorted by screen order | Sort by severity, highest first — the reader needs the critical issues at the top. |

## Three-mode posture traps

| Anti-pattern | Instead |
|---|---|
| Treating `not-applicable` as "skip the audit" | `not-applicable` is about *user-level* validation not fitting the product class — the heuristic audit still runs, adapted to terminal/API UX. |
| Declaring `tested` without a real test | The worst posture — you skip the bet *and* lack the evidence. If no users were tested, the honest mode is `intuition`. |
| `intuition` mode with a vague bet | "We're like X but better" is not a bet. Name the segment, ≥ 2 comparables, and the defensible differentiation. |
| Omitting the `validation_mode:` line, or burying it | One literal line, lowercase key, near the top. The MCP regex-extracts it; Layer 1 rejects the submission without it. |
| No post-launch signal because the mode is `tested` | All three modes need a concrete confirming signal — even a tested concept benefits from a post-launch metric. |

## Process traps

| Anti-pattern | Instead |
|---|---|
| The agent picking the validation mode for the user | The mode is the user's posture decision; the parent conducts that dialogue. The agent owns the heuristic audit, not the mode choice. |
| Fixing the findings in this step | Step 4 audits and recommends. Remediation lands in steps 6 (design-system) and 7 (screen-atlas). |
| Auto-crossing the Discovery gate after submit | `product_advance` deliberately returns `gate-required` — the parent confirms with the user and calls `product_gate_pass("discovery")` consciously. |
| A one-paragraph "looks fine, ship it" report | That is the pre-port failure mode this step exists to kill. A real audit walks 10 heuristics × N flows + a WCAG checklist + severity-rated findings. |
