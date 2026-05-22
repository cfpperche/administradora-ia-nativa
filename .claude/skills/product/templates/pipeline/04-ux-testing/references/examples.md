# UX-audit examples — good vs bad

Concrete contrasts for the load-bearing shapes in `validation-report.md`. Ported from `anthill-ux-audit` and augmented. The pattern in every pair: specific and actionable wins, vague loses.

## Finding entry

**Good — heuristic named, severity rated, concrete issue, actionable fix:**

```markdown
| ID | Heuristic / WCAG | Severity | Location | Issue | Recommendation |
|----|------------------|----------|----------|-------|----------------|
| F-04 | 5 Error prevention | 4 | Account settings | The "Delete account" action fires immediately on click — a mis-click is unrecoverable. | Add a confirmation modal requiring the user to type "DELETE" before the action executes. |
```

**Bad — no heuristic, no severity criteria, no actionable fix:**

```markdown
| Finding | Notes |
|---------|-------|
| Delete button is dangerous | Should probably have a warning |
```

## Severity scale

**Good — defined criteria, rated by persona impact:**

```markdown
| Severity | Label | Definition |
|----------|-------|-----------|
| 4 | Critical | Blocks task completion for the target persona, or locks out a user group. Fix before the gate. |
| 3 | Major | Significant friction/error, or a WCAG `fail`. Fix before launch. |
| 2 | Minor | Noticeable issue; backlog. |
| 1 | Cosmetic | Polish; fix if time permits. |
```

**Bad — no criteria, rated by vibe:**

```markdown
Severity: High (this seems pretty bad)
```

## Heuristic observation

**Good — what was seen, on which screen, with a verdict:**

```markdown
| # | Heuristic | Observation | OK? |
|---|-----------|-------------|-----|
| 1 | Visibility of system status | Submitting the project form shows no spinner or disabled state — the user can double-submit. | ❌ |
| 9 | Error recovery | The 404 page reads "Error 404" with no link back or search — a dead end. | ❌ |
| 4 | Consistency | Primary buttons are teal on every screen; icon set is uniform. | ✅ |
```

**Bad — generic, no screen, no verdict:**

```markdown
- Visibility: could be better
- Errors: some issues
- Consistency: mostly fine
```

## Accessibility check

**Good — WCAG criterion, status, observed evidence, fix:**

```markdown
| Check | WCAG | Status | Evidence | Fix |
|-------|------|--------|----------|-----|
| Body-text contrast | 1.4.3 | fail | Secondary text #9CA3AF on #FFFFFF measures 2.8:1 (needs 4.5:1) | Darken secondary text to #6B7280 (5.1:1) |
| Keyboard navigation | 2.1.1 | warn | Modal traps focus but the close button is not in tab order | Add the close button to the focusable sequence |
```

**Bad — no criterion, no evidence:**

```markdown
- Accessibility: looks okay
- Contrast: fine probably
```

## Validation-mode evidence

**Good — `intuition` mode, an articulated bet:**

```markdown
validation_mode: intuition

The bet: indie iOS developers (1–3 person teams) currently stitch together App Store
Connect + a spreadsheet + Slack for release tracking. Comparables — App Radar and
Appfigures — both index on ASO/keywords, not release-ops. The defensible differentiation
is the release-checklist + crash-triage loop, which neither comparable touches. No users
tested yet; validating post-launch.
```

**Bad — `intuition` mode, not a bet:**

```markdown
validation_mode: intuition

I think developers will like this. It's similar to other tools but better.
```

## Verdict

**Good — mode-shaped, addresses the critical findings:**

```markdown
PROCEED with reservations. The heuristic audit surfaced 1 severity-4 finding (F-04,
unconfirmed account deletion) and 2 severity-3 a11y failures (F-02, F-07). F-04 must be
fixed before the Discovery gate; the a11y failures are batched for step 14 (design-system).
No structural redesign needed — the killer flow tested clean.
```

**Bad — verdict with no reasoning, ignores the findings:**

```markdown
PROCEED. Looks good.
```
