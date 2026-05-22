# The audit rubric — Nielsen's 10 + WCAG 2.1 AA

The evaluation spine for step 4. Read before auditing. Apply **all 10 Nielsen heuristics to every in-scope flow** (not selectively), then run the WCAG 2.1 AA review. Audit the error / empty / loading states, not just the happy path.

## Nielsen's 10 usability heuristics

For each in-scope screen/flow, ask the question in the right column. A "no" is a finding.

| # | Heuristic | Audit question |
|---|-----------|----------------|
| 1 | Visibility of system status | Does the UI tell the user what is happening? Loading shown? Action confirmed? Current location obvious? |
| 2 | Match between system and the real world | Does the language match the user's vocabulary, not the system's? Are concepts ordered the way the user expects? |
| 3 | User control and freedom | Is there an "emergency exit" — undo, cancel, back — from every state? Can the user leave a flow without committing? |
| 4 | Consistency and standards | Do the same words, icons, and actions mean the same thing everywhere? Does it follow platform conventions? |
| 5 | Error prevention | Is the design built so the error can't happen — confirmation on destructive actions, constrained inputs, sensible defaults? |
| 6 | Recognition rather than recall | Are options, actions, and information visible — or does the user have to remember them from a previous screen? |
| 7 | Flexibility and efficiency of use | Are there accelerators for experienced users (shortcuts, bulk actions) that don't get in a novice's way? |
| 8 | Aesthetic and minimalist design | Does every element earn its place? Is there competing or irrelevant information diluting the important content? |
| 9 | Help users recognize, diagnose, recover from errors | Are error messages in plain language, precise about the problem, and do they suggest a fix? |
| 10 | Help and documentation | Where help is needed, is it discoverable, task-focused, concrete, and not too long? |

### Adapting for CLI / API / non-GUI products

A `not-applicable` validation mode does **not** mean "no audit". Adapt the heuristics to terminal UX:

- **Status (1)** — does a long-running command show progress? Does it confirm success?
- **Real-world match (2)** — do flag and subcommand names match the user's mental model?
- **Control & freedom (3)** — is there a dry-run? a confirmation prompt before destructive ops? a clean `Ctrl-C`?
- **Consistency (4)** — do flags behave the same across subcommands? Does it follow POSIX/`--help` conventions?
- **Error prevention & recovery (5, 9)** — are error messages actionable ("missing `--token`; pass it or set `FOO_TOKEN`") rather than a stack trace?
- **Recognition & help (6, 10)** — is `--help` discoverable and useful? Are examples shown?

## WCAG 2.1 AA accessibility review

Run these on every in-scope screen (GUI products). Each gets `pass` / `warn` / `fail` with the observed evidence. **WCAG violations are severity 3 (major) or 4 (critical) — never severity 1–2.**

| Check | AA criterion | What to verify |
|-------|-------------|----------------|
| Colour contrast — body text | 1.4.3 | ≥ 4.5:1 against its background |
| Colour contrast — large text & UI | 1.4.3 / 1.4.11 | ≥ 3:1 for large text (≥ 18.66px bold / 24px), icons, borders, focus rings |
| Colour not sole signal | 1.4.1 | State (error, selected, required) is conveyed by more than colour alone |
| Keyboard navigation | 2.1.1 | Every interactive element reachable and operable by keyboard; no traps |
| Focus visible | 2.4.7 | A clear focus indicator on every focusable element |
| Focus order | 2.4.3 | Tab order follows reading/visual order |
| Semantic structure | 1.3.1 | Headings, lists, landmarks, tables marked up semantically — not faked with styling |
| Text alternatives | 1.1.1 | Meaningful images have alt text; decorative ones are hidden from AT |
| Labels & instructions | 3.3.2 | Every form input has a programmatic label; required fields and formats are stated |
| Error identification | 3.3.1 | Errors are identified in text, not colour alone, and describe the fix |
| Target size | 2.5.5 (AAA, but check) | Touch targets are comfortably tappable (~44×44px) |

## Severity scale (define it in the report, apply it consistently)

| Severity | Label | Definition |
|----------|-------|-----------|
| 4 | Critical | Blocks task completion for the target persona, or a WCAG failure that locks out a user group. Must fix before the Discovery gate. |
| 3 | Major | Causes significant friction, error, or a WCAG `fail`. Fix before launch. |
| 2 | Minor | Noticeable usability issue; schedule for the backlog. |
| 1 | Cosmetic | Polish item; fix if time permits. |

Rate by impact on the **target persona from the step-1 concept brief** — not by how easy the fix is. Effort belongs in the priority-recommendations batching, not in the severity number.
