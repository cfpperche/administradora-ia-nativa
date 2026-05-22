# Quality judge — `/product` v0.4.0

The quality judge is an independent-context `opus` sub-agent dispatched **after each pipeline step** to grade the step's artifact(s) against the step's rubric. It is spec 075's replacement for the retired size-budget instrument: it answers *"is this artifact correctly scoped, complete, and coherent for its declared job?"* — the question the KB ceiling was a poor proxy for.

This doc is the judge's operational contract: when it runs, how its rubric is assembled, the verdict it returns, how a verdict routes. The judge's 5-field dispatch brief lives in `delegation-briefs.md § quality-judge`; the rubric content lives in `quality-checklist.md`.

## What the judge is

- **Independent context.** A fresh sub-agent per judge-unit — it does not share context with the step's producer. Generation and evaluation are separate (LLM-as-judge best practice: a producer grading its own work is biased toward its own choices).
- **`opus`.** A stronger reasoner for evaluation, and a within-family asymmetry against the `sonnet` step producers. `sonnet` is the documented cost knob (§ Cost).
- **Pointwise, chain-of-thought.** The judge grades one artifact-set against one rubric, reasoning criterion-by-criterion (G-Eval style). It never compares or ranks two artifacts — pointwise grading sidesteps position bias and makes self-preference bias bland.
- **Advisory, never a hard gate.** Its strongest action is to pre-populate a phase gate's `iterate` recommendation (§ Verdict → gate routing). It never autonomously BLOCKs or aborts — deterministic structural BLOCK/abort stays the `schema.md` Layer 1 job.

The step producers' briefs deliberately do **not** mention the judge. The judge evaluates after the fact; telling a producer it will be judged invites writing-to-the-judge bias.

## When the judge runs — and when it is skipped

After a step's producer returns, the orchestrator (`SKILL.md`):

1. **Anti-stub pre-filter.** `wc -c` each artifact against the step's `schema.md § Size floor` `min_size`. If any required artifact is below its floor it is a **stub** — the producer did not try. The orchestrator skips the judge call (judging a stub wastes an `opus` call) and re-dispatches the producer with a brief naming the stubbed artifact.
2. **Dispatch the judge** on the artifacts that cleared the floor.
3. **Record the verdict** to `.state.json` `quality_verdicts` and route it (§ Verdict → gate routing).

The catastrophe cap (200 KB, `artifact-budgets.md`) sits upstream of all this: a runaway producer is circuit-broken mid-flight and emits a partial-result — the judge never receives a 200 KB artifact.

## Judge-units

The judge runs once per **judge-unit**:

- **Steps 01-14** — one judge-unit per step, keyed by step label (`01-ideation` … `14-design-system`).
- **Step 15** — three judge-units, `15a-screen-atlas` / `15b-hifi-mood` / `15c-fixture-spec`, dispatched after their three sub-agents return. They already carry separate gates (`quality-checklist.md § Visual-contract rubric criteria`), so they are judged separately.

## Rubric assembly

For a judge-unit the rubric is **assembled, not authored** — spec 075 authors no new rubric. Three sources:

1. **`quality-checklist.md` per-step criteria** — the gradeable semantic criteria, each with a stable `id`. The judge grades each as a *semantic* read — "is this section substantive and load-bearing", not "does the string exist". Some steps (e.g. 07 Sitemap-IA) have no semantic criterion; their rubric is right-sizing + schema context only.
2. **`schema.md` — as context, not a re-graded checklist.** The judge reads the step's `schema.md` (required sections, `contains`-anchors, `§ Size floor`) and `prompt.md` to know the artifact's required shape and job. The deterministic "does the anchor exist" check is already enforced at submit by `schema.md` Layer 1 — the judge does **not** re-run it. Schema is the judge's *brief*: the source of "what this artifact is for".
3. **The right-sizing criterion** (below) — appended to every judge-unit's rubric.

So a verdict's `criteria[]` = the step's `quality-checklist.md` criteria + `right-sizing`.

## The right-sizing criterion

`id: right-sizing`. Appended to every judge-unit. This is the criterion that replaces the size budget — it judges *scope fit*, not bytes.

> **right-sizing** — Is every section of the artifact pulling weight for the artifact's declared job at *this run's* product scope? Judge against the run's **declared scope** — the `idea`, the invocation flags, and (where the step has it as input) the roadmap's phase count — **not** a fixed size. Return:
> - `pass` — the artifact's depth matches its declared scope. **A correctly-scoped large artifact for a large declared product is a `pass`.**
> - `concern` / `fail` — a section covers detail the job does not require (genuine **bloat** — name the section and why it is surplus), OR a section is too thin to do its job (**under-developed** — name the gap).
>
> **Do not reward length.** A longer artifact is not a better artifact. A padded artifact for a small product is a `fail`; a lean artifact that fully covers a small product is a `pass`. The `note` MUST name the specific section and dimension — never just "too long" or "too short".

The "do not reward length" line is the verbosity-bias mitigation: an ungoverned LLM judge tends to score longer outputs higher. The criterion is scope-aware *by construction* — it has no constant to compare against, only the run's declared scope — which is exactly why it cannot rot the way the fixed KB ceiling did.

## The verdict

The judge returns one verdict object per judge-unit:

```json
{
  "step": "08-system-design",
  "judged_at": "2026-05-22T16:40:00Z",
  "model": "opus",
  "criteria": [
    { "id": "structure",    "verdict": "pass",    "note": "all 8 required H2 present incl RACI + Risk Register" },
    { "id": "security-doc", "verdict": "pass",    "note": "security.md present and substantive" },
    { "id": "data-flow",    "verdict": "pass",    "note": "data-flow.json valid, 5 flows" },
    { "id": "right-sizing", "verdict": "concern", "note": "§ Risk Register restates the security.md threat model — ~2 KB duplication" }
  ],
  "scope_assessment": "Correctly scoped for a full multi-phase ERP; the lone concern is internal duplication, not over-scope.",
  "outcome": "concern"
}
```

| Field | Meaning |
|---|---|
| `step` | judge-unit label (`01-ideation` … `15c-fixture-spec`) |
| `judged_at` | UTC ISO-8601 |
| `model` | judge model actually used (`opus` default; `sonnet` if the cost knob was pulled) |
| `criteria[]` | one row per assembled rubric criterion — `id` + `verdict` ∈ `pass`/`concern`/`fail` + a one-line `note`. On `concern`/`fail` the `note` MUST name the section + dimension (the actionable signal). |
| `scope_assessment` | top-level one-line whole-artifact scope headline — lands in `REPORT.md § Quality concerns` and the gate summary |
| `outcome` | max-severity rollup: `fail` if any criterion `fail`, else `concern` if any `concern`, else `pass` |

A judge `fail` is **not** a BLOCKED. BLOCKED is deterministic — DELIVERABLE not met, or the producer explicitly couldn't proceed (`state-machine.md § Failure handling`). A judge `fail` means the artifact is *present and DELIVERABLE-complete* but quality-deficient. The two tracks are orthogonal: a step in `completed_steps` can carry a `fail` verdict; that does NOT move it to `blocked_steps`. `completed_steps` / `blocked_steps` / `quality_verdicts` are three independent records.

## Verdict → gate routing

Routing is a **global rule**, tied to the `state-machine.md` phase→gate progression — not per-step opt-in.

- **`outcome: pass`** — recorded to `quality_verdicts`. No further action.
- **`outcome: concern`** — *advisory*. Recorded; surfaced in `REPORT.md § Quality concerns`. No gate action — a `concern` is a note for the human, not a recommendation to iterate.
- **`outcome: fail`** — *gate-flag*. Recorded; surfaced in `REPORT.md § Quality concerns`; AND routed to the phase's downstream gate:

| Phase | Steps | Gate | A `fail` here … |
|---|---|---|---|
| 1 discovery | 01-04 | `gate_discovery` | pre-populates the gate's recommended option as **`iterate`**, citing the failed step + criterion |
| 2 specification | 05-12 | `gate_specification` | same |
| 3 identity | 13-14 | `gate_identity` | same |
| 4 visual-contract | 15a/15b/15c | *(no gate)* | surfaced in the terminal handoff message + `REPORT.md § Quality concerns` |

At a phase gate the orchestrator collects every `quality_verdicts` entry for that phase's steps. If any has `outcome: fail`, the `AskUserQuestion` gate's **recommended** option is `iterate`, pre-filled with the failed steps and their failed criteria; the human still chooses `continue` / `iterate` / `abort` — the judge never decides (`state-machine.md § Gate UX`). If none failed, the recommended option stays `continue`. The existing iteration soft-cap (`state-machine.md § Gate UX` — warn at `iterations.<phase> >= 3`, force-abort at `>= 5`) still applies: a judge that keeps flagging `fail` cannot drive an infinite iterate loop.

Phase 4 (step 15) has no gate — a `15a/15b/15c` `fail` cannot pre-populate anything, so it surfaces in the Phase 5 terminal handoff message and the `REPORT.md § Quality concerns` section, where the human sees it before acting on the SDD handoff.

## What the judge never does

- **Never autonomously BLOCKs or aborts.** Its ceiling is the gate `iterate` recommendation. Deterministic structural BLOCK/abort is `schema.md` Layer 1's job; run-aborting on a Step 01 / 15a block is the orchestrator's (`state-machine.md § Failure handling`).
- **Never grades size in bytes.** `min_size` is the `wc -c` anti-stub pre-filter; the 200 KB catastrophe cap is a runaway circuit-breaker. The judge grades scope fit (`right-sizing`), never byte count.
- **Never authors rubric.** It grades the assembled rubric (§ Rubric assembly). If a step's rubric feels wrong, fix `quality-checklist.md` / `schema.md` — not the judge.

## Cost

~17 `opus` judge calls per full run (steps 01-14 + 15a/15b/15c) — marginal against a 35-55 min run, but real. The documented knob: dispatch the judge on `sonnet` instead (the brief's `model` field). A `sonnet` judge is cheaper and faster; it trades some evaluation depth and removes the within-family asymmetry. Pull the knob if judge cost bites; the verdict shape is identical (`model` records which ran).

## Cross-references

- `quality-checklist.md` — the per-step semantic rubric criteria the judge grades
- `delegation-briefs.md § quality-judge` — the judge sub-agent's 5-field dispatch brief
- `state-machine.md` — `.state.json` `quality_verdicts`, the phase→gate progression the routing feeds, `§ Gate UX`, `§ Failure handling`
- `templates/pipeline/<NN-step>/schema.md` — the per-step structural context + `§ Size floor` `min_size`
- `.claude/rules/artifact-budgets.md` — the retired size budget + the 200 KB catastrophe cap
- `templates/report.md.tmpl § Quality concerns` — where `concern` / `fail` verdicts surface
- `docs/specs/075-product-quality-audit/` — the spec; `notes.md` carries the verdict-shape + v5-additive decision trail
