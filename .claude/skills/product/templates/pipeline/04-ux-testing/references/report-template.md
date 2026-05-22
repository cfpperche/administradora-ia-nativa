# `validation-report.md` — output template

The full shape for the step-4 artifact. The H2 titles slugify to the required-sections list in `schema.md`, and several are Layer-1 `contains` anchors — keep the casing exactly as written. The `validation_mode:` line is regex-extracted by the MCP *and* enforced by Layer 1.

```markdown
---
# Optional YAML frontmatter — ONLY emit when audit ran in measurable mode (HTML inputs).
# Skip this entire block when audit ran in projected mode (markdown spec inputs).
# Step 6 (design-system) and step 15 (screen-atlas; absorbed step 7 per spec 045) read this block to consume findings
# programmatically. The markdown body below is the derived human-readable view.
findings:
  - id: F-01
    severity: 4
    heuristic: "A11y 2.4.7 Focus visible"
    location: "screens/05-triage-view.html, screens/07-command-palette.html"
    issue: "Inline <style> omits the :focus-visible rule on triage + palette"
    recommendation: "Add the global :focus-visible { outline: 2px solid var(--primary); ... } rule"
    wcag: "2.4.7"
    fix_skill_hint: "screen-atlas"
    complexity_estimate: "~15 min"
  - id: F-07
    severity: 3
    heuristic: "A11y 1.4.3 Contrast"
    location: "All 8 screens — every use of --foreground-3 on --surface"
    issue: "Tertiary text token measures 3.89:1 — fails the 4.5:1 body floor"
    recommendation: "Brighten --foreground-3 from oklch(0.50 0.010 240) to oklch(0.55 0.010 240)"
    wcag: "1.4.3"
    fix_skill_hint: "design-system"
    complexity_estimate: "~30 min"
priority_fixes:
  - batch: "a11y-contrast-token-tune"
    finding_ids: [F-07, F-09]
    rationale: "single token edit cascades to all 8 screens"
    complexity_estimate: "~30 min"
    when: "before gate"
  - batch: "keyboard-focus-restore"
    finding_ids: [F-01]
    rationale: "copy-paste :focus-visible rule from 6 working screens to the 2 missing ones"
    complexity_estimate: "~15 min"
    when: "before gate"
---
# {Product Name} — UX Validation Report

**Generated:** {date} | **Pipeline step:** 4 (ux-testing) | **Auditor:** product-pipeline step 4
**Source artifact:** `02-prototype/<slug>/`
**Status:** Discovery-phase gate artifact

## Audit Scope

- **What:** {which screens/flows from the step-2 prototype are in scope}
- **Target user:** {the primary persona from the step-1 concept brief — every finding is judged through this lens}
- **Audit type:** heuristic evaluation (Nielsen's 10) + accessibility review (WCAG 2.1 AA){+ any extra lens}

## Validation Mode

validation_mode: {tested|intuition|not-applicable}

{1–2 sentences justifying the choice. The expert heuristic audit below runs regardless of
this mode — the mode declares what *user-level* validation sits on top of it.}

## Heuristic Evaluation

All 10 of Nielsen's heuristics, applied to every in-scope flow. Error / empty / loading
states audited, not just the happy path. (CLI/API products: heuristics adapted to terminal
UX — see `references/heuristics.md`.)

### {Screen / Flow name}

| # | Heuristic | Observation | OK? |
|---|-----------|-------------|-----|
| 1 | Visibility of system status | {what you saw} | ✅ / ⚠️ / ❌ |
| 2 | Match with the real world | {what you saw} | ✅ / ⚠️ / ❌ |
| ... | ... | ... | ... |
| 10 | Help and documentation | {what you saw} | ✅ / ⚠️ / ❌ |

{repeat the ### block for each in-scope screen/flow. Every ❌ / ⚠️ becomes a row in
`## Findings` below.}

## Accessibility Review

WCAG 2.1 AA. Each check `pass` / `warn` / `fail` with observed evidence. Violations are
severity ≥ 3 in the findings table.

| Check | WCAG | Status | Evidence | Fix |
|-------|------|--------|----------|-----|
| Body-text contrast | 1.4.3 | pass / warn / fail | {observed ratio / where} | {remediation or —} |
| Keyboard navigation | 2.1.1 | ... | ... | ... |
| Focus visible | 2.4.7 | ... | ... | ... |
| {…the rest of the WCAG checklist…} | | | | |

## Findings

**Severity scale** (define before the table, apply consistently):

| Severity | Label | Definition |
|----------|-------|-----------|
| 4 | Critical | Blocks task completion for the target persona, or locks out a user group. Fix before the gate. |
| 3 | Major | Significant friction/error, or a WCAG `fail`. Fix before launch. |
| 2 | Minor | Noticeable issue; backlog. |
| 1 | Cosmetic | Polish; fix if time permits. |

| ID | Heuristic / WCAG | Severity | Location | Issue | Recommendation |
|----|------------------|----------|----------|-------|----------------|
| F-01 | 5 Error prevention | 4 | {screen} | {concrete description of the problem} | {specific, actionable fix} |
| F-02 | A11y 1.4.3 | 3 | {screen} | {…} | {…} |

Sorted by severity, highest first. Every row has a recommendation — a finding without a
fix is just a complaint.

## Strengths

At least 3 things that work well and must NOT be changed:

- {strength 1 — what works, why it matters to the persona}
- {strength 2}
- {strength 3}

## Evidence

Mode-specific. Fill the block for the declared `validation_mode`:

- **`tested`** — recruit profile (role/context, not just "5 users"), the tasks they were
  asked to do, the friction observed, the user count.
- **`intuition`** — the articulated bet: which segment, ≥ 2 named comparable products, what
  makes the differentiation defensible. "We're like X but better" is not a bet.
- **`not-applicable`** — why conventional UX testing doesn't fit this product class.

## Verdict

- **`tested`** — PROCEED / PIVOT / KILL, with reasoning.
- **`intuition`** — "PROCEED on bet, validate post-launch via {signal}".
- **`not-applicable`** — "PROCEED to identity phase; validation deferred to post-launch via {signal}".

A non-zero count of severity-4 findings makes PROCEED hard to justify — address it explicitly.

## Priority Recommendations

Group findings into **named batches** by shared cause. Batch label = the handoff unit a downstream step (14 design-system, 15 screen-atlas) consumes; rationale = the one-line reason these findings group (single token edit, focus rule copy-paste, semantic-element pass, etc). Real effort estimates only — `TBD` is not an estimate.

| Batch | Finding IDs | Severity | Effort | When | Rationale |
|-------|-------------|----------|--------|------|-----------|
| `a11y-contrast-token-tune` | F-07, F-09 | 3 | ~30 min | before gate | single `--foreground-3` token edit cascades to all 8 screens |
| `keyboard-focus-restore` | F-01 | 4 | ~15 min | before gate | copy-paste `:focus-visible` rule from 6 working screens to the 2 missing ones |
| `semantic-html-pass` | F-12, F-13 | 3 | ~half-day | step 7 | replace `<span>`-as-input with real `<input>` / `<textarea>` across all interactive surfaces |
| `polish` | F-15, F-16 | 1 | ~15 min | backlog | reduced-motion wrap + hero meta dot color reduction |

## Post-Launch Signal

The observable signal — metric, behaviour, market response — that will retroactively
confirm or refute the validation choice. Required for all three modes. Concrete:
"{DAU > 100 in week 4}" / "{PyPI downloads > 200 in month 1}" / "{5 unsolicited inbound demo requests}".
```

## Notes on using this template

- **The heuristic evaluation + accessibility review run for every mode** — including `not-applicable`. A thin posture note is not this step.
- **`validation_mode:` is a literal line**, lowercase key, on its own line, near the top. The MCP regex-extracts it into `.state.json`; Layer 1 rejects the submission without it.
- **Every finding is actionable** — the recommendation column is mandatory, and it must be specific ("add a confirmation modal requiring the user to type DELETE"), not vague ("make it safer").
- **Define the severity scale before the findings table** so the rating is auditable.
- A real audit fills well past the 8 KB Layer-1 floor once all 10 heuristics are walked per flow and the WCAG checklist is run. Struggling to reach 8 KB means the audit was shallow — re-walk the flows.
