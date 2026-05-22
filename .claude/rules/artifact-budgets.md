# Artifact size cap

_(This file keeps its historical name `artifact-budgets.md`; the "budget" cascade it originally carried was retired by spec 075 — see § Why the size budget was retired.)_

Artifact size is **not** a scope or quality signal. A `/product` sub-agent produces an artifact at whatever size its job honestly takes; whether that artifact is correctly scoped, complete, and right-sized is judged by the **quality judge** (`.claude/skills/product/references/quality-judge.md`, spec 075) — not by a byte count.

This rule documents the one thing artifact size is still used for: a **catastrophe cap** — a dumb circuit-breaker against a genuine token runaway.

## The catastrophe cap

A single **uniform absolute cap of 200 KB** applies to any artifact a sub-agent writes. It is not per-step and not a budget — it is the line past which "no legitimate `/product` artifact is ever this large; a sub-agent here is in a runaway" holds. (The largest legitimate artifact observed across the mei-saas dogfood runs was a system-design / functional-spec at ~65 KB; 200 KB is ~3× that — generous headroom by design.)

When a sub-agent's output crosses 200 KB it **stops immediately and emits a partial-result** naming what it was producing. This is a token-runaway kill, not a scope verdict — no trim, no re-emit, no compression. The orchestrator records the partial-result and surfaces it.

The cap is deliberately loose. A false miss — a 180 KB bloated artifact slipping under — is fine: the quality judge catches bloat on scope/quality grounds. The cap and the judge are belt-and-suspenders: the cap is a cheap mid-flight runaway kill; the judge is the post-hoc scope/quality verdict.

## Why the size budget was retired

Earlier versions of this rule declared a per-step KB **budget** with a two-threshold overshoot cascade (`max × 1.2` → partial-result, `max × 1.8` → hard-abort). The mei-saas `/product` dogfood (two runs, 2026-05-19 + 2026-05-21) proved the instrument broken: **every artifact with a meaningful ceiling overshot it** — 10/10 mood screens, plus functional-spec, roadmap, cost-estimate, sitemap, fixture-spec, brand-book — and every sub-agent `oversize_reason` diagnosed "the budget is miscalibrated for this scope", never "I bloated". The cascade fired ~15 times with zero true positives.

Root cause: a KB budget is a **scope-blind fixed constant**. It cannot adapt to a run's declared scope (the mei-saas run requested a full multi-phase product against budgets calibrated for an MVP). Spec 075 retired it and moved scope/quality judgment to a rubric judge, which is inherently scope-aware. See `docs/specs/075-product-quality-audit/`.

## Trim-loop and re-emit are still forbidden

Two antipatterns the original rule banned remain banned. A sub-agent that finds an artifact "too big" must NOT:

- **trim-loop** — rewrite the same artifact path repeatedly, each version smaller (mechanically: same `Write`/`Edit` against one path, multiple times, each smaller);
- **re-emit at smaller scope** — re-run the brief from scratch with a self-narrowed scope.

Both hide signal. With the budget ceiling gone the *incentive* for them largely evaporates — there is no longer a ceiling to compress toward. They stay documented as forbidden because the catastrophe cap could still tempt a sub-agent near 200 KB; the correct response there is the partial-result stop, never a trim.

## Anti-stub floor (unchanged)

A separate mechanism, unaffected by this rule and **retained**: each `/product` step's `templates/pipeline/<step>/schema.md` carries a `min_size` Layer-1 floor. A file below its floor is a stub — "the sub-agent didn't try" — and is rejected at submit. The floor is cheap (`wc -c`), deterministic, and a genuine stub-detector. Only the *ceiling* was an instrument problem; the floor stays.

## Override marker

The project's `# OVERRIDE: <reason ≥10 chars>` grammar still applies, now scoped to the catastrophe cap: a brief carrying `# OVERRIDE: budget-exempt: <reason>` lets a sub-agent ship past 200 KB without the partial-result stop. This is near-never legitimate — 200 KB is already ~3× the largest honest artifact — so the reason text must be a real, greppable justification. "skip" / "bypass" / "ok for now" are not reasons.

## Where this applies

- **`/product` skill** — the only consumer. The catastrophe cap is noted in one line of each brief's CONSTRAINTS and in `references/pipeline-coverage.md`.
- State-file limits (`SESSION.md` ≤ 4 KB, `COMPACT_NOTES.md` 12 turns, `MEMORY.md` ~200 lines) are harness/script limits, not artifact caps — unrelated to this rule.

## Cross-references

- `docs/specs/075-product-quality-audit/` — the spec that retired the budget cascade and added the rubric judge
- `.claude/skills/product/references/quality-judge.md` — how artifact scope/quality is actually judged now
- `.claude/skills/product/references/{delegation-briefs,pipeline-coverage}.md` — where the catastrophe cap is noted per step
- `.claude/rules/delegation.md` — the 5-field handoff; briefs note the cap in CONSTRAINTS
