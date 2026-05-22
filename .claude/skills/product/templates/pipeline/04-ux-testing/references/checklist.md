# Step-4 self-review checklist

Run before calling `product_step_submit`. Ported from `anthill-ux-audit` and augmented for this pipeline's three-mode posture + Layer 1. Some items are enforced mechanically (section check, Layer 1) — most are quality gaps only this review catches.

## Scope & inputs

- [ ] Read the step-2 prototype (`docs/`) — all in-scope screens/flows
- [ ] Audit scope defined: which flows/screens are in scope
- [ ] Target user persona stated (from the step-1 concept brief) — every finding judged through their lens
- [ ] Validation mode declared by the user (the parent ran that dialogue, not the agent)

## Heuristic evaluation

- [ ] All 10 of Nielsen's heuristics applied to *every* in-scope flow — not selectively
- [ ] Error states, empty states, and loading states audited — not just the happy path
- [ ] CLI/API products: heuristics adapted to terminal UX (discoverability, error messages, help text)
- [ ] Every ❌/⚠️ observation became a row in the findings table

## Accessibility review

- [ ] WCAG 2.1 AA review completed for every in-scope screen
- [ ] Colour contrast checked — body text (4.5:1) and large text + UI components (3:1)
- [ ] Keyboard navigation tested for all interactive elements; focus indicators verified
- [ ] Semantic structure, text alternatives, form labels, error identification checked
- [ ] Each check has a `pass`/`warn`/`fail` status with observed evidence
- [ ] WCAG violations rated severity 3 or 4 — never 1–2

## Findings

- [ ] Severity scale (1–4, with definitions) stated in the report before the findings table
- [ ] Every finding has: heuristic/WCAG ref, severity, location, concrete issue, actionable recommendation
- [ ] Severity rated by impact on the target persona — not by fix effort
- [ ] Findings sorted by severity, highest first
- [ ] At least 3 strengths documented (what works and must NOT change)

## Mode, verdict & signal

- [ ] `validation_mode:` line present — lowercase key, on its own line, near the top
- [ ] `## Validation Mode` section justifies the choice in 1–2 sentences
- [ ] Evidence block matches the declared mode (`tested` recruits+tasks+observations / `intuition` bet with ≥2 comparables / `not-applicable` rationale)
- [ ] Verdict stated in the mode-appropriate shape (PROCEED/PIVOT/KILL or "PROCEED on bet…" or "PROCEED…deferred…")
- [ ] A non-zero severity-4 count is addressed explicitly in the verdict
- [ ] Priority recommendations batched by severity × effort (fix-before-gate vs. defer)
- [ ] Post-launch signal is concrete (a number + a timeframe), and present for all three modes

## Floor & integrity

- [ ] All 10 required H2 sections present (the section check enforces this)
- [ ] Report is ≥ 8 KB and got there by audit depth, not padding
- [ ] The agent did not pick the validation mode, and did not fix the findings (that's steps 6–7)
- [ ] Submitted as one `product_step_submit` call with `filename: "validation-report.md"`
