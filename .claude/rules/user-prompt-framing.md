# User prompt framing

The delegation gate (`.claude/rules/delegation.md`) enforces a 5-field handoff at the main→sub boundary because under-specified briefs cause sub-agent drift. The same risk exists one level up — at the user→main boundary — where no hook can intervene because the main agent IS the actor being disciplined. This rule encodes the discipline the main agent applies to every incoming prompt: a lightweight 3-question mental check, a threshold that decides whether to act or clarify, and explicit carve-outs so the discipline doesn't burn cycles on prompts that don't need it.

The capacity is rule-only by design — no hook, no audit log. Observability is built when drift has been observed at least three times, not before. If the dogfood window surfaces ≥3 missed-clarification sessions, a `UserPromptSubmit` hook becomes the next step.

## Summary (read this if nothing else)

On receipt of a non-trivial prompt, internally map it onto the 5-field handoff — focusing on three fields:

1. **TASK clear?** — can I name verb + object in one sentence without inventing?
2. **CONTEXT clear?** — do I know which files / concepts to read first, or am I guessing?
3. **DONE clear?** — do I know how to verify completion, or am I inventing the criterion?

| Ambiguities | Response |
|---|---|
| 0 | Act direct. |
| 1 | Act, but explicit the inference in one line before the first acting tool call ("assumindo X porque…"). |
| 2+ | Ask before acting — ideally via `AskUserQuestion`, not open prose. |

CONSTRAINTS and DELIVERABLE are intentionally absent from the check: CONSTRAINTS is usually inferable from `.claude/rules/*`, DELIVERABLE usually collapses into DONE. Three questions stay cheap to apply every turn; five would not.

## Skip categories (do NOT run the 3-question check)

| Category | Example | Why skip |
|---|---|---|
| Path + simple verb | `leia .claude/rules/delegation.md` | Verb + object already concrete, no resolution needed. |
| Explicit command | `rode os testes`, `git status` | The user is naming the action, not asking for one. |
| Factual repo question | `qual o último commit?`, `quantos specs existem?` | Read / search, not work. |
| Short continuation | `continua`, `tenta de novo`, `sim` (≤10 words, no new substantives) | Inherits TASK / CONTEXT / DONE from the prior turn. |
| Greeting / meta | `oi`, `obrigado`, `explica o que você fez` | Conversational, not work-shaped. |

If the prompt fits a skip category, act immediately. Don't pause to "be safe" — the friction would be net-negative.

## Exploratory carve-out (NOT framing — recommendation instead)

Opinion-shaped prompts — `o que você acha de X?`, `como podemos fazer Y?`, `qual a melhor forma de Z?` — bypass the 3-question check and route to the exploratory pattern from CLAUDE.md: respond in 2-3 sentences with a recommendation + main tradeoff, presented as something the user can redirect. The vagueness is the feature: the user wants synthesis, not a deferred decision.

The operational distinction: exploratory prompts ask for **opinion**, substantive prompts ask for **action**. `Como podemos fazer X?` is exploratory. `Faz X` is substantive (and may fail the check).

## Pronoun-resolution carve-out

A pronoun (`isso`, `esse arquivo`, `de novo`, `igual ao outro`) with a clear antecedent in the **immediately prior turn** (last assistant artifact, tool result, or named entity) counts as resolved — the 3 questions are scored against the resolved meaning, not the literal text. Example: after the agent writes a file, `roda isso de novo` resolves `isso` to "the command that produced the file" and TASK / CONTEXT are both clear.

A pronoun without antecedent in the immediate prior turn (or referring to something from a session ago) is a real ambiguity and counts as a failure of CONTEXT.

## Override marker

Mirroring the delegation, governance, secrets-scan, and supply-chain gates: a line `# OVERRIDE: <reason ≥10 chars>` anywhere in the prompt skips the 3-question check. The agent proceeds with whatever inference it has and acknowledges the override in its response (one line — "override noted: <reason>"). The marker is documentation, not just bypass — write a reason a future reader can grep.

The override does NOT silence the discipline elsewhere in the same turn; if the agent later needs more information to complete the work, it still asks. The marker only covers the initial framing check, not subsequent decisions.

## Worked examples

| Prompt | TASK | CONTEXT | DONE | Verdict |
|---|---|---|---|---|
| `leia CLAUDE.md` | ✓ | ✓ | ✓ | **Skip category** (path + verb). Read immediately. |
| `o que você acha de adicionar Redis?` | — | — | — | **Exploratory.** Respond 2-3 sentences with recommendation + tradeoff. |
| `melhora isso` (after agent just edited `foo.ts`) | ✓ (improve) | ✓ (`foo.ts` resolves `isso`) | ✗ (improve in what dimension?) | **1 ambiguity** → act with inference ("assumindo melhoria de legibilidade já que `foo.ts` é OK funcionalmente"). |
| `adiciona auth` | ✓ | ✗ (which surface?) | ✗ (what verifies done?) | **2+ ambiguities** → `AskUserQuestion` with surface + done-criterion options. |
| `faz como o Z faz` | ✗ (do what?) | partial (Z is named, but doing-what is ambiguous) | ✗ | **2+ ambiguities** → ask. |
| `sim` (after a 2-option `AskUserQuestion`) | ✗ (sim to which option?) | ✓ | ✗ | **2 ambiguities** → re-ask. This is the canonical in-conversation instance from the discipline's design session (2026-05-17). |
| `# OVERRIDE: prototyping, improvise se ambíguo`<br>`melhora isso` | ✗ | ✗ | ✗ | **Override.** Skip the check; act on best inference; one-line override acknowledgement in response. |

## Gotchas

- **The actor cannot externally enforce the discipline on itself.** Unlike the delegation gate where a separate hook process blocks an under-specified call, the main agent is the only thing reading and applying this rule. Forgetting to apply it has no automatic detection in v1. The dogfood window (3 weeks) exists to surface drift retroactively; if it's frequent, v2 ships a `UserPromptSubmit` hook.
- **The 2+ threshold is strict on purpose.** Asking at 1 ambiguity would be exhausting; not asking until 3 would let drift accumulate. The asymmetric "act with explicit inference at 1" preserves the conversation's flow while still giving the user a correction surface mid-stream.
- **Rule decay is real.** Rules that aren't cross-referenced rot. This rule is cross-referenced from `.claude/rules/delegation.md` (the symmetric upstream gate) and `.claude/rules/spec-driven.md` § *When SDD applies* (overlapping triggers).
- **Calibration is unknown until used.** No prior data on how often the discipline actually fires. If after 1 week of dogfood the agent is asking on >50% of substantive prompts, the skip categories need to expand or the threshold needs to tighten. If it's never firing, the categories are too broad.
- **First message of a session has weaker pronoun resolution.** No prior turn to anchor `isso` against — first-message pronouns almost always count as CONTEXT failures.

## Cross-references

- `.claude/rules/delegation.md` — the symmetric 5-field handoff at the main→sub boundary; same `# OVERRIDE:` grammar
- `.claude/rules/spec-driven.md` § *When SDD applies* — overlapping trigger set (vague request needing decomposition, 3+ files, public API change)
- `CLAUDE.md` — exploratory-prompt guidance ("respond in 2-3 sentences with a recommendation and the main tradeoff") that the exploratory carve-out preserves
