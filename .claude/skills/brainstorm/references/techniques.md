# Brainstorm lenses

Lazy-read reference loaded by `SKILL.md` when the user (or the maturation heuristic) invokes a specific lens. Each lens has three sub-sections: **Description** (what the lens does in one sentence), **When to apply** (the trigger that justifies suggesting it), **Protocol** (the steps Claude walks through to apply the lens to the existing `ideas[]` in the session state).

A lens *operates on material already captured* — it does not restart the session. After applying, Claude appends the lens name to `lenses_applied[]` and writes new derived ideas / critiques / questions into the state JSON.

---

## SCAMPER

### Description

A seven-axis expansion technique that walks each existing idea through seven prompts: **S**ubstitute, **C**ombine, **A**dapt, **M**odify, **P**ut to another use, **E**liminate, **R**everse. Forces breadth of derivations from each seed idea.

### When to apply

- Session has ≥3 ideas captured and the user wants to expand existing material rather than capture more from scratch.
- Ideas feel "single-dimensional" — Claude observes that several ideas describe the same shape with surface variations.
- User explicitly says "SCAMPER" / "scamper this" / "expand these".
- **Default suggestion trigger** (when maturation heuristic fires): session has ≥10 ideas AND no lens applied yet.

### Protocol

For each existing idea in `ideas[]` (cap at 5 ideas per pass to avoid combinatorial explosion — let user re-invoke for more), walk the seven SCAMPER prompts in order. For each prompt that yields a substantive derivation, capture a new entry into `ideas[]` with:

- `text`: the derived idea
- `tag`: one of `easy | risky | wild | unknown` (Claude tags it; default `unknown` if unsure)
- `derived_from`: id of the seed idea
- `lens`: `"SCAMPER"`
- `axis`: `"substitute" | "combine" | "adapt" | "modify" | "put-to-another-use" | "eliminate" | "reverse"`

Prompts Claude uses internally per axis:

- **Substitute** — what part of the idea could be replaced (component / actor / channel / payment model)?
- **Combine** — which other idea (or external concept) could merge with this?
- **Adapt** — what analogy from another domain fits (other industries, biology, history)?
- **Modify** — what can be scaled up / down / magnified / minified?
- **Put to another use** — same mechanism, different audience or job-to-be-done?
- **Eliminate** — what feature could be removed and still keep the value?
- **Reverse** — what if the assumed direction (buyer/seller, give/take, push/pull) flipped?

Empty axes are fine — not every idea yields seven derivations. Capture 0 if nothing substantive surfaces; do not fabricate.

After the pass, summarise: "SCAMPER yielded N new ideas across M axes. Continue with another lens, more SCAMPER passes, or `/brainstorm done`?"

---

## Six Thinking Hats

### Description

Edward de Bono's six perspectives — each "hat" is a different mode of evaluating the material. Wearing one hat at a time keeps critique, optimism, emotion, and creativity from short-circuiting each other.

### When to apply

- Session has ≥5 ideas and they need stress-testing from multiple angles before committing.
- Ideas are clustered in one emotional register (all enthusiastic, all sceptical) — Claude observes uniform sentiment.
- User explicitly says "6 hats" / "Black Hat this" / a named hat / "let's critique these".
- **Default suggestion trigger**: session has 10+ ideas and user has spent ≥3 turns enthusiastic with no critique surfaced.

### Protocol

The lens has six sub-modes; the user can apply one hat at a time (most common) or run the full sweep. Each hat captures into a structured list in state under `lenses_applied[].six_hats.<hat>`.

| Hat | Mode | Capture |
|---|---|---|
| **White** | Facts, data, what we know vs what we're assuming | For each idea: list the load-bearing assumptions; tag as `verified | unverified | unknown` |
| **Red** | Emotion, gut feeling, intuition | Per idea: one-line "how does this *feel*" (excitement / scepticism / boredom / curiosity); no justification required |
| **Black** | Risks, what could go wrong, failure modes | Per idea: 1–3 specific risks; for each risk, name the assumption that, if false, makes the risk fatal |
| **Yellow** | Benefits, best-case outcome, what works | Per idea: 1–3 specific benefits; if the idea wins, what does the world look like? |
| **Green** | Creativity, alternatives, "what if" | Per idea: 1–2 adjacent variations that change one dimension (audience, mechanism, scale) |
| **Blue** | Process, meta — what should we do next? | Across all ideas: what's the next concrete action? Which idea(s) deserve a prototype? Which should be killed? |

When user says only one hat name (e.g. "Black Hat"), apply just that one. Capture into `lenses_applied[]` even if only one hat — record `hats_applied: ["black"]` so the HTML render knows which sub-tabs to show.

After application, summarise: "Black Hat surfaced N risks across M ideas. Two ideas (X, Y) rely on the same unverified assumption [...]. Continue with another hat, lens, or `/brainstorm done`?"

---

## Reverse Brainstorm

### Description

Asks the opposite of the brainstorm question: "how would we **cause** the problem we're trying to solve?" or "how would we **guarantee** this idea fails?" Surfaces failure modes and hidden constraints that direct ideation hides.

### When to apply

- Session ideas are clustered in the `easy` tag (all incremental, no `wild` quadrant) — Reverse forces the imagination toward extremes.
- User is too attached to a single idea — Reverse breaks the lock-in by exploring how it would die.
- Session has been positive and nothing risky has surfaced — Black Hat is finer-grained, Reverse is broader.
- **Default suggestion trigger**: ≥10 ideas AND all ideas share one tag, OR ≥10 ideas AND `lenses_applied[]` is empty AND the most recent 3 turns were unanimously enthusiastic.

### Protocol

The lens has two modes — pick one based on session shape:

**Mode A — Reverse the goal.** Frame: "instead of solving X, how would we *cause* X?" or "how do we make sure the user *never* gets value here?"

1. State the inverted question explicitly: e.g. session topic is "bolsa de startups" → ask "how would we guarantee a startup investor *loses* money?" / "how do we make founders *never* want to use this?"
2. Generate 5–10 inverted ideas — what an adversary or saboteur would do.
3. For each inverted idea, invert it back: "the protection against this is ___". Capture the protection as a new entry in `ideas[]` with `tag: risky` and `lens: "Reverse"`, `mode: "goal-inversion"`.

**Mode B — Reverse an idea.** For a specific idea the user is locked onto:

1. Restate the idea, then ask: "what would have to be true for this to fail catastrophically?"
2. List 3–5 catastrophic-failure preconditions.
3. For each, ask "do any of these already partially hold?" Mark the ones that do — those are the load-bearing assumptions of the original idea.
4. Capture into `lenses_applied[]` under `reverse_mode_b: { idea_id, failure_modes: [...], load_bearing_assumptions: [...] }`.

After application, summarise: "Reverse surfaced N protections / X load-bearing assumptions. Strongest signal: [...]. Continue with another lens or `/brainstorm done`?"

---

## Crazy 8s

### Description

Time-boxed divergence: generate 8 distinctly different ideas in 8 minutes. The constraint forces breadth — there's no time to deepen any single idea, so the user is pushed to surface variations that would otherwise be filtered out by the inner editor.

### When to apply

- Session is stuck at 3–5 ideas and the user keeps elaborating one of them — needs a hard reset toward breadth.
- Early in a session (right after `start`) when user wants high-velocity divergence before applying any other lens.
- User explicitly says "crazy 8s" / "8 ideas fast" / "give me 8 angles".
- **Default suggestion trigger**: session has ≥5 ideas concentrated in one tag (e.g. all `easy`) and user has been elaborating rather than diverging for ≥3 turns.

### Protocol

Adapted for a chat session (no real timer — the "8 minutes" becomes a turn-count constraint):

1. Restate the brainstorm topic in one sentence.
2. State the goal: generate 8 ideas that are *distinct from each other and from the existing set*. Distinctness rubric: each new idea differs from every other new idea on at least 2 of these axes — *who* (audience), *what* (mechanism / artefact), *how* (channel / interaction), *why* (value proposition).
3. Generate the 8 ideas in batches of 2 turns to stay below context fatigue, prompting the user between batches with "any direction you want me to lean?" Stop at exactly 8 unless the user extends.
4. For each idea, Claude tags it (`easy | risky | wild | unknown`) and writes a one-sentence "differentiator vs the existing set" — what makes this distinct, not just adjacent.
5. Capture into `ideas[]` with `lens: "Crazy 8s"` and `batch: 1..4`.

Distinctness check: if Claude generates an idea ≥80% similar (by lexical or semantic eye-check) to an existing idea, reject and retry the slot. Note the rejection inline so the user sees the discipline working.

After application, summarise: "Crazy 8s yielded 8 new ideas spanning [list of axes touched]. Of these, X are in the `wild` quadrant. Continue with another lens, refine one of these, or `/brainstorm done`?"

---

## Future lens slots (not implemented v1)

The above 4 are the v1 set. Adding a lens later is mechanical — add a section here with the same 3 sub-sections (Description, When to apply, Protocol), and the skill will pick it up next invocation. No SKILL.md change required if the lens name follows the pattern in § *Lens application protocol* of SKILL.md (case-insensitive match on user phrasing). Candidates for v2: **Five Whys** (root cause drilling), **Worst Possible Idea** (deliberate bad ideas → invert), **Analogous Inspiration** (cross-domain pattern transfer), **Pre-mortem** (assume failure happened; explain why).
