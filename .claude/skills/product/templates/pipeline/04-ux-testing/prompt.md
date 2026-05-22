---
mode: draft-after-input
delegable: partial
delegation_hint: "run the heuristic UX audit of the step-2 prototype (Nielsen's 10 + WCAG 2.1 AA, severity-rated findings) and draft validation-report.md in the validation_mode the user already declared; the mode choice + any tested-mode test notes will be in the parent's conversation"
---

# Step 4 — UX Testing

**Goal:** validate the step-2 prototype before crossing into the Identity phase, on two levels. (1) An **expert heuristic audit** — the agent evaluates the prototype against Nielsen's 10 usability heuristics + WCAG 2.1 AA, producing severity-rated findings — runs *every time, regardless of mode*. (2) A **validation-mode declaration** — `tested` / `intuition` / `not-applicable` — records what *user-level* validation exists on top of the expert audit. The mode is written to `.state.json.validation_mode` and gates downstream decisions.

The expert audit is the spine; the mode declares the posture. A thin "we'll test later" note is not this step — the heuristic audit happens no matter which mode the user picks.

**Mode:** `draft-after-input`. The parent MUST conduct the mode-selection dialogue with the user (it's a posture choice, not a writing task) and gather any `tested`-mode test notes. The heuristic audit + report writing can then delegate — a sub-agent reads `docs/` and produces the audit without further user input.

**Output file:** `validation-report.md` in `docs/`. Single artifact. It MUST contain a line of the exact shape `validation_mode: <tested|intuition|not-applicable>` (the MCP regex-extracts this into state — and Layer 1 now enforces its presence).

---

## The three validation modes

| Mode | When to use | Mode-specific evidence (on top of the heuristic audit) |
|---|---|---|
| `tested` | A real UX test was run — 5+ users, prototype clickthrough, structured observations | Test report — recruits, tasks, observed friction, verdict |
| `intuition` | Founder's bet — no users tested yet, but the segment / comparables / differentiation argument is strong enough to proceed and validate post-launch | Articulated bet — which segment, ≥2 named comparables, what makes the differentiation defensible |
| `not-applicable` | Non-software product class where UX testing as conventionally defined doesn't fit (infrastructure tool, API-only product, narrow internal automation) | Why conventional UX testing doesn't fit + what substitute signal validates post-launch |

There is no fourth mode. "Skip" is `not-applicable`; "I'll do it later" is `intuition` (you're betting it works). **None of the three modes skips the heuristic audit** — even a CLI/API product gets an audit against terminal-UX-adapted heuristics (discoverability, error messages, help text).

---

## How to conduct this step

Read `references/heuristics.md` (the Nielsen + WCAG rubric) before auditing. Read `references/anti-patterns.md` and `references/examples.md` for finding quality. Run `references/checklist.md` before submitting. `references/report-template.md` is the full output shape.

### 1. Parent: select the validation mode + gather mode-specific input

Parent asks the user: *"How was this concept validated — `tested` (you ran a real UX test), `intuition` (founder's bet, validate post-launch), or `not-applicable` (non-software-product class where UX testing doesn't fit)?"*

Then, based on mode:

- **`tested`** — ask for the test report contents: number of users, what they were asked to do, what was observed, the verdict. If there's a separate `report.md` or notes file, ask for the path.
- **`intuition`** — ask the user to articulate the bet: which user segment, what comparables exist, what makes the differentiation defensible. Push for specificity — "I think it'll work" is not an articulated bet.
- **`not-applicable`** — ask why conventional testing doesn't fit AND what post-launch signal will validate. ("DAU is meaningless for a CLI library; PyPI download trajectory + GitHub stars in month 1 is the proxy.")

### 2. Define the audit scope

Name what is being audited and through whose eyes:

- **What** — which screens / flows from the step-2 prototype are in scope. For a small prototype, all of them; for a large one, the killer flow + the auth + the empty-first-run.
- **Target user** — the primary persona from the step-1 concept brief. *Every* finding is evaluated through this persona's lens.
- **Audit type** — heuristic evaluation + accessibility review is the default. Note any extra lens (performance, content) if it applies.

### 3. Run the heuristic evaluation (Nielsen's 10)

For each in-scope screen/flow, walk all 10 of Nielsen's heuristics (see `references/heuristics.md`):

1. Visibility of system status · 2. Match between system and the real world · 3. User control and freedom · 4. Consistency and standards · 5. Error prevention · 6. Recognition rather than recall · 7. Flexibility and efficiency of use · 8. Aesthetic and minimalist design · 9. Help users recognize/diagnose/recover from errors · 10. Help and documentation.

Apply **all 10 to every major flow**, not selectively. Audit the error states, empty states, and loading states too — not just the happy path. For a CLI/API product, adapt the heuristics to terminal UX (is the error message actionable? is `--help` discoverable? is the output legible?).

### 4. Run the accessibility review (WCAG 2.1 AA)

Check the in-scope surfaces against WCAG 2.1 AA: colour contrast (4.5:1 body text, 3:1 large text + UI components), keyboard navigation, focus indicators, screen-reader compatibility (semantic structure, alt text, ARIA where needed). Each check gets a `pass` / `warn` / `fail` with the observed evidence. WCAG violations are **severity 3 (major) or higher** — they are not cosmetic.

**The audit method depends on what step 2 produced.** This split is load-bearing — the most common false-confidence failure of this step is auditing-a-spec-as-if-it-were-HTML, marking checks as `warn` when nothing was actually measured.

- **Step 2 output is HTML** (the deep-port norm — `02-prototype/<slug>/direction-*.html`, hi-fi screens, `compare.html`). The audit is **measurable**: open each HTML in a browser (a local HTTP server is fine), sample real rendered text and UI elements through a contrast checker, tab through every interactive control, observe the focus indicator on every focusable element, view-source to verify semantic structure (`<nav>`, `<main>`, headings, ARIA roles). Each check is `pass` / `fail` with a concrete observation — "body text on dark canvas measures 4.8:1 — pass"; "tertiary text on the muted card measures 3.1:1 — fail". `warn` is reserved for **genuinely borderline measurements** (e.g., 4.4:1 against a 4.5:1 floor), never as a hedge for "I didn't open the file".
- **Step 2 output is a markdown spec** (older runs that pre-date the step-2 deep port, forks that haven't deep-ported step 2 yet, or product classes where step 2 produces text only). The audit is **projected**: read the cross-cutting-concerns + per-component descriptions for stated accessibility intent, infer what the rendered surface would do, and mark every check that requires rendering as `warn` with a one-line rationale — "focus indicator not specified in the prototype spec — verify in step 7"; "contrast unverifiable from spec; brief leans dark-mode, dark themes routinely ship secondary text below 4.5:1". In this mode the verdict phrases each `warn` as a **tracked handoff**: it becomes an acceptance criterion on step 14 (design-system) or step 15 (screen-atlas; absorbed step 7 per spec 045), not a finding this audit can resolve.

Mixing the two modes is fine when the step-2 bundle contains both (e.g., the deep-port HTML directions plus a separate textual companion spec). Measure what can be measured, project the rest, and **label each row of the accessibility table with the mode it used** (a `measured` / `projected` column, or the rationale text itself making it obvious). The reader of the report needs to know which is which.

### 5. Write findings — severity-rated, every one actionable

Every issue from steps 3–4 becomes a finding with: the heuristic or WCAG ref violated, a **severity 1–4** (1 cosmetic → 2 minor → 3 major → 4 critical), the location, the issue described concretely, and a **specific, actionable recommendation** — not "should probably be better". Define the severity scale in the report before the findings table so the rating is auditable. Sort findings by severity, not by screen order.

Also document **at least 3 strengths** — what works well and must NOT be changed. An audit that only lists problems leaves the team free to break what was right.

### 6. Record the mode evidence + verdict

- **Evidence** — the mode-specific block from step 1 (`tested` test report / `intuition` bet / `not-applicable` rationale).
- **Verdict** — `tested`: PROCEED / PIVOT / KILL with reasoning. `intuition`: "PROCEED on bet, validate post-launch via <signal>". `not-applicable`: "PROCEED to identity phase; validation deferred to post-launch via <signal>". A critical (severity-4) finding count makes PROCEED hard to justify — say so if it applies.
- **Priority recommendations** — group findings into **named batches** (e.g. `a11y-contrast-token-tune (F-07, F-09)`, `keyboard-focus-restore (F-01)`, `semantic-html-pass (F-12, F-13)`) with a real effort estimate per batch (`~30 min`, `~1 h 30`, `~half-day` — not `TBD`) and a one-line rationale per batch (the shared cause that justifies grouping these findings, e.g. "single token edit cascades to all occurrences"). The batch label is the handoff unit downstream steps consume: a step-6 (design-system) consumer reads `a11y-contrast-token-tune` and knows to act; reading 17 individual finding rows forces them to re-group. This shape mirrors the audit-as-delegation-manifest discipline anthill's `priority_fixes[]` enforced — same intent, markdown-shaped instead of structured-data-shaped (the structured layer arrives with step 6 design's frontmatter pass).
- **Post-launch signal** — the observable metric/behaviour that will retroactively confirm or refute the validation choice. Required for all three modes. Concrete: "DAU > 100 in week 4", "PyPI downloads > 200 in month 1", "5 unsolicited inbound demo requests".

### 7. (Recommended for measurable mode) Emit YAML frontmatter

When the audit ran in branch (i) **measurable** (HTML inputs, real numbers in the accessibility table), emit a YAML frontmatter block at the top of the report carrying `findings[]` + `priority_fixes[]` as structured data — see `schema.md` § "Optional YAML frontmatter — structured findings handoff" for the exact field shape. Step 6 (design-system) and step 15 (screen-atlas; absorbed step 7 per spec 045) read this block to consume the audit programmatically: step 6 picks up findings tagged `fix_skill_hint: "design-system"` and applies token tunes; step 7 picks up `fix_skill_hint: "screen-atlas"` as acceptance criteria for the re-render. The markdown body remains the human-readable view; the frontmatter is the machine-parseable mirror. Skip the frontmatter when the audit ran in branch (ii) projected mode — there's nothing measurable to hand off.

### 8. Submit + gate

The artifact MUST include the `validation_mode:` line on its own line near the top — the MCP regex-extracts it into `.state.json.validation_mode`, and Layer 1 rejects the submission if it's missing. Call `product_step_submit` with `filename: "validation-report.md"`.

Step 4 is the **last step of the Discovery phase**. After a clean submit, calling `product_advance` returns `code: "gate-required", phase: "discovery"`. The parent asks the user to explicitly confirm Discovery is ready to close, calls `product_gate_pass("discovery")`, then `product_advance` again to enter the Identity phase (step 5, brand).

---

## Voice & rigor

- **The heuristic audit is not optional.** Every mode gets one. The categorical upgrade over the pre-port step 4 is exactly this: a real expert UX audit, not a one-paragraph posture note.
- **Be honest about the mode.** Declaring `tested` without real tests is the worst posture — you skip the bet *and* lack the evidence. `intuition` commits the team to a post-launch validation loop; say so.
- **Every finding is actionable.** "Delete button is dangerous" is an observation; "add a confirmation modal requiring the user to type DELETE" is a finding. The recommendation column is mandatory.
- **Severity is defined before it's applied.** Put the 1–4 scale (with criteria) in the report; rate consistently against it.
- **Strengths are findings too.** Name ≥3 things that work — teams need to know what not to touch.
- **For `tested`:** name the recruits' role/context — "5 designers from agencies" beats "5 users". For `intuition`: ≥2 named comparables. For `not-applicable`: name the substitute signal explicitly.

## What this step does NOT do

- **Pick the validation mode FOR the user.** The mode is a posture decision; the user owns it. The agent owns the heuristic audit.
- **Replace real UX testing.** `intuition` mode is legitimate but is a bet — the heuristic audit is expert review, not user evidence.
- **Fix the findings.** Step 4 audits and recommends; remediation is the team's, and the design-system / screen-atlas steps (6, 7) are where the fixes land.
- **Cross the Discovery gate automatically.** `product_advance` after step 4 deliberately requires explicit `product_gate_pass("discovery")` so the phase transition is conscious.

## What this step replaces

This template synthesises the archived `anthill-ux-audit` skill (see `.claude/memory/anthill-archived.md`) with Agent0's three-mode validation posture (introduced in spec 025). `anthill-ux-audit` contributed the audit spine — Nielsen's 10 heuristics, the WCAG 2.1 AA review, the severity-1–4 findings table, the strengths discipline, the "every finding actionable" rule. Agent0's pre-port step 4 contributed the `validation_mode` declaration that the MCP regex-extracts and downstream steps gate on. The deep port keeps both: anthill's `tested` mode was an *expert* audit only — here the expert audit always runs, and the `validation_mode` line declares what *user-level* validation sits on top of it.

Anthill's runtime scaffolding does not port: the `ux-audit.schema.json` YAML-frontmatter contract, the `.anthill/schemas/` validation, the `fix_skill_hint` cross-skill routing, and the deliverable-registry hook are replaced by this MCP's `schema.md` section + Layer 1 checks and the `product_advance` gate.
