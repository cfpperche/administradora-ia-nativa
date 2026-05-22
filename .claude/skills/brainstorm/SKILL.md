---
name: brainstorm
description: Conduct a divergent ideation session and render the captured material as a self-contained local HTML for human review. Use when the user wants to explore a vague idea (product, strategy, "what if…") that is not yet a spec candidate — sits before /sdd refine in the ideation→spec pipeline. Subcommands - start "<topic>", list, resume <slug-or-filename>, done. State and rendered HTML live under .claude/.brainstorm-state/ (gitignored). See .claude/skills/brainstorm/references/techniques.md for the lens library.
argument-hint: <start "<topic>" | list | resume <slug-or-filename> | done>
license: MIT
compatibility: Designed for Claude Code. Body references `.claude/` conventional paths and CC-specific tools; portable to any runtime that maps a `.claude/`-analog directory and surfaces the referenced tools.
metadata:
  agent0-portability-tier: cc-native
  version: "0.1"
---

# /brainstorm — divergent ideation skill

Conducts a structured-but-flexible brainstorm session and renders the captured material as a single self-contained HTML file for human review. Distinct from `/sdd refine` — that skill **converges** on a spec, this one **diverges** to surface more ideas, perspectives, and open questions. Output is ephemeral by design (lives under `.claude/.brainstorm-state/`, gitignored); the user decides afterwards what to promote into a spec via `/sdd new <slug>`.

See spec `docs/specs/031-brainstorm/spec.md` for the contract.

## Argument parsing

User invokes as `/brainstorm <subcommand> [args]`. The raw argument string is `$ARGUMENTS`. Parse it yourself: split on first whitespace, first token is the subcommand (`start` / `list` / `resume` / `done`), the remainder (which may be a quoted string) is the subcommand arg. Strip surrounding quotes from the topic for `start`. Do not rely on `$1` / `$2` positional substitution — always parse `$ARGUMENTS` yourself.

Raw invocation: `$ARGUMENTS`

## Subcommands

- `start "<topic>"` — open a new session
- `list` — enumerate past sessions
- `resume <slug-or-filename>` — continue an existing session
- `done` — finalise, render HTML, print the local-serve command

## Divergence discipline (cross-cutting)

The job of this skill is to *generate more material*, not to converge. While a session is active:

- **Do not propose solutions in the opening**. Ask, capture, classify, repeat.
- **Do not summarise or critique ideas mid-divergence** unless a lens (Black Hat, Reverse) is being applied. Capture freely; let the lens phases do the squeezing.
- **Do not converge into a spec**. If the user keeps pushing toward a final answer, remind once that this is brainstorm and offer `/brainstorm done → /sdd new <slug>` as the convergence path.
- **One thing at a time**. Ask 1–2 focused questions per turn, not 5. Better to need more turns than to overwhelm.
- **No sycophancy**. "Great idea" is banned. Capture neutrally; tag honestly.

Soft budget: every 5–7 substantive turns, emit a checkpoint (see § *Capture loop and checkpoint*) so the user has a natural exit pulse without an arbitrary token cap.

## Subcommand: `start "<topic>"`

1. **Validate** — if topic is empty or unparseable, refuse with `usage: /brainstorm start "<topic>"`.

2. **Slugify** — kebab-case from the topic, max 40 chars: lowercase, replace non-alphanumeric with `-`, collapse repeats, trim leading/trailing `-`. Example: `"bolsa de startups"` → `bolsa-de-startups`. If the result is empty after slugification, refuse with `topic must contain at least one alphanumeric character`.

3. **Timestamp** — ISO-8601 UTC to the second, with `:` replaced by `-` for filename safety. Example: `2026-05-16T16-42-07Z`.

4. **Create state file** — write `.claude/.brainstorm-state/<slug>-<ts>.json` via `Write` with the initial structure:

```json
{
  "topic": "<the topic verbatim>",
  "topic_slug": "<slug>",
  "started_at": "<ISO timestamp>",
  "ended_at": null,
  "state": "active",
  "ideas": [],
  "questions_open": [],
  "quotes": [],
  "connections": [],
  "lenses_applied": [],
  "turns": []
}
```

If the directory `.claude/.brainstorm-state/` does not exist yet, create it first via `Bash mkdir -p`.

5. **Open the session** — print a one-line confirmation (`session started — <filename>`) then ask exactly **one** grounding question. Examples (pick the one that fits the topic, do not list all):

   - "what attracts you to this idea — the problem it solves, the shape of the solution, or someone specific who would use it?"
   - "if you had one paragraph to pitch this to a sceptical friend, what would the paragraph say?"
   - "what made you write this down today instead of yesterday or next month?"

   Do NOT propose ideas yourself in the opening. Do NOT list multiple frameworks. Do NOT ask "which technique should we use?". The user names a technique later or you suggest one when the maturation heuristic fires.

## Subcommand: capture loop (during an active session)

After `start`, every subsequent user turn is interpreted as session input. Update state after each substantive turn (use `Edit` rather than `Write` to avoid race-y rewrites — the JSON should be small enough that whole-file rewrite is also fine; pick whichever is more reliable per turn).

### Classification taxonomy

Every substantive user turn yields zero or more entries across these buckets:

| Bucket | Append to | When |
|---|---|---|
| `ideas` | `ideas[]` | user proposes a concrete possibility ("what if we…", "we could…", a named approach) |
| `questions_open` | `questions_open[]` | user surfaces an unknown they cannot answer yet, or asks one of you that you cannot answer without more info |
| `quotes` | `quotes[]` | user says something memorable in their own words that captures the *why* or the *feel* of the topic — keep verbatim |
| `connections` | `connections[]` | user links two ideas, or links the topic to an external thing (a person, a market, a precedent) |

An idea entry has shape:

```json
{
  "id": <integer, monotonic, starting at 1>,
  "text": "<the idea in one sentence>",
  "tag": "easy | risky | wild | unknown",
  "lens": null,
  "derived_from": null,
  "turn": <integer turn number>
}
```

Tag rubric:

- **easy** — clearly doable with what we know; low-risk; incremental
- **risky** — depends on a load-bearing assumption that could be wrong
- **wild** — high payoff if true; uncomfortable to commit to; would surprise people
- **unknown** — not enough info to tag; default when in doubt

Tag honestly. If a user proposes something risky and you tag it `easy` because it sounds nice, you are not doing this job.

A turn-summary is appended to `turns[]` after each substantive turn:

```json
{ "n": <turn number>, "summary": "<one short line: what happened this turn>" }
```

### Checkpoint cadence

Every 5–7 substantive turns, emit a one-line checkpoint with current counts and 3 branches verbatim:

```
checkpoint — <I> ideas (<easy>/<risky>/<wild>/<unknown>) | <Q> open questions | <L> lenses applied
  continue free  |  apply lens (SCAMPER / 6 Hats / Reverse / Crazy 8s)  |  /brainstorm done
```

Do not force a choice — the user can ignore and continue. The checkpoint exists so the user has a natural exit pulse.

### Lens-suggestion heuristic (at checkpoint time)

If any of these conditions hold at a checkpoint, name a specific lens with the one-line reason. Suggest, do not impose:

- `len(ideas) ≥ 10` AND `len(lenses_applied) == 0` → suggest **SCAMPER** ("10 ideas in, no lens applied — SCAMPER would derive variants from each")
- all ideas share one tag → suggest **Reverse** ("all ideas are `easy` — Reverse would force the `wild` quadrant"; substitute the actual mono-tag)
- ≥3 turns of unanimous enthusiasm, no critique surfaced → suggest **Black Hat** (one of Six Thinking Hats) ("3 turns enthusiastic with no critique — Black Hat stress-tests assumptions")
- user keeps elaborating one idea instead of generating new ones, for ≥3 turns → suggest **Crazy 8s** ("you've been deepening one idea — Crazy 8s would force 8 distinctly different ones")

Only fire one suggestion per checkpoint. If multiple conditions match, pick the most-aligned with the immediate session shape.

## Subcommand: lens application

Triggers:

- User says any of: `apply SCAMPER` / `SCAMPER this` / `scamper` / `6 hats` / `six hats` / `<color> hat` (white/red/black/yellow/green/blue) / `reverse` / `reverso` / `reverso this` / `crazy 8s` / `crazy eights` / `8 ideas fast`
- User accepts a skill-initiated suggestion ("yes go with SCAMPER")

When fired:

1. **Match the lens** — case-insensitive against the lens names in `references/techniques.md`. If a single-hat phrase is matched (e.g. "Black Hat"), record that the lens is **Six Thinking Hats** with `hats_applied: ["black"]` only.

2. **Read the lens spec** — `Read` `.claude/skills/brainstorm/references/techniques.md`, scroll to the matching section. Follow its **Protocol** sub-section verbatim. Do not invent variants.

3. **Walk the existing material** — apply the protocol to the ideas already in `ideas[]` (cap at 5 ideas per pass for SCAMPER to avoid context explosion; whole-set is fine for Six Hats and Reverse since their output per idea is small).

4. **Capture derivations** — each derived idea gets appended to `ideas[]` with `lens: "<LensName>"`, `axis` or sub-mode where the protocol defines it, `derived_from: <seed_idea_id>`. New questions go to `questions_open[]`.

5. **Append to `lenses_applied[]`** — an entry with shape:

```json
{
  "name": "SCAMPER | Six Thinking Hats | Reverse | Crazy 8s",
  "applied_at": "<ISO timestamp>",
  "summary": "<one-line: N derived ideas, M new questions>",
  "hats_applied": ["black", ...]    // only for Six Thinking Hats
}
```

6. **Summarise** — emit one line per the lens's protocol (e.g. "SCAMPER yielded 8 new ideas across 4 axes"). Then re-offer the 3 branches.

**Composability**: v1 does not compose lenses in one prompt. If the user says "SCAMPER through Black Hat lens", treat as ambiguous and ask which to apply first. Chain manually by re-invoking after each completes.

## Subcommand: `done`

1. **Finalise state** — `Edit` the JSON: set `ended_at = <ISO now>` and `state = "done"`.

2. **Pre-render the dynamic placeholders** — read the template at `.claude/skills/brainstorm/templates/render.html.tmpl`. Substitute these placeholders against the state:

   - `{{TOPIC}}` → the verbatim topic string
   - `{{TIMESTAMP}}` → `<started_at> → <ended_at>` (human-readable; trim seconds if too long)
   - `{{IDEAS_COUNT}}` → `len(ideas)`
   - `{{QUESTIONS_COUNT}}` → `len(questions_open)`
   - `{{LENSES_COUNT}}` → `len(lenses_applied)`
   - `{{MINDMAP_MARKDOWN}}` → a markdown outline for markmap: top heading is the topic; first-level children are the tag buckets (`easy`, `risky`, `wild`, `unknown`); second-level children are the idea texts (truncated to 80 chars for readability); third-level children, where applicable, are derived-from links rendered as `↳ via <lens>`. Skip empty buckets.
   - `{{LENS_TABS_HTML}}` → one `<button data-tab="lens-<slug>">LensName</button>` per entry in `lenses_applied[]`. Use the lens name's lowercase-kebab as `<slug>` (e.g. `SCAMPER` → `scamper`, `Six Thinking Hats` → `six-thinking-hats`). The tab label is **just the name** — no inline badge. The colour-coded badge lives inside the panel header instead, so the tab bar stays terse.
   - `{{LENS_PANELS_HTML}}` → one `<div class="panel" data-panel="lens-<slug>">` per lens, each containing a `<section><h2>LensName <span class="lens-badge <css-slug>">{name}</span> — derived ideas</h2><div class="kanban" id="kanban-<slug>"></div></section>` plus any lens-specific structured blocks (e.g. for Six Thinking Hats, render one sub-section per applied hat listing its captures from `lenses_applied[].six_hats.<hat>` if present). The `<css-slug>` aliases the kebab slug to the CSS class set in the template: `scamper` / `six-hats` (alias for `six-thinking-hats`) / `reverse` / `crazy-8s`.
   - `{{TIMELINE_MERMAID}}` → a mermaid `timeline` block populated from `turns[]`. Shape:
     ```
     timeline
       title brainstorm session
       turn 1 : <summary>
       turn 2 : <summary>
       ...
     ```
     Truncate each summary to 60 chars.
   - `{{STATE_JSON}}` → the full state JSON object, embedded as a JS literal (must be valid JSON that JavaScript can parse — use `JSON.stringify` mental model, escape `</` inside strings as `<\/` to avoid script-tag breakout).

3. **Write the HTML file** — `Write` the substituted content to `.claude/.brainstorm-state/<slug>-<ts>.html`.

4. **Print the local-serve instructions**:

```
✓ brainstorm session done

  state:  .claude/.brainstorm-state/<slug>-<ts>.json
  render: .claude/.brainstorm-state/<slug>-<ts>.html

  open in browser:
    python3 -m http.server 8765 -d .claude/.brainstorm-state
    → http://localhost:8765/<slug>-<ts>.html

  (file:// also works but the Copy-as-markdown button may be blocked by the clipboard API
  without a localhost / https origin — http.server is the safest path.)
```

## Subcommand: `resume <slug-or-filename>`

1. **Resolve target** — search `.claude/.brainstorm-state/` for `*.json`. Match against the arg:
   - If exact filename match → use it
   - Else if a single file's name *starts with* the arg → use it
   - Else if a single file's name *contains* the arg → use it
   - Else list candidates and refuse with `ambiguous; pick one of: <list>`

2. **Load state** — `Read` the JSON file.

3. **Refuse cleanly if `state == "done"`** — print `session already done; rendered HTML at <path>` and exit. Do not re-open finalised sessions; if the user wants more material, they `/brainstorm start` a fresh session referencing the prior HTML.

4. **Continue** — emit a 2-line summary: `resumed: <topic> (<I> ideas, <Q> questions, <L> lenses)` then re-emit the checkpoint and the 3 branches. The session now continues as if it had not been interrupted.

## Subcommand: `list`

1. **Glob** — read `.claude/.brainstorm-state/*.json`. If none, print `no brainstorm sessions yet — try /brainstorm start "<topic>"`.

2. **Emit one line per session**, sorted by `started_at` descending:

```
<topic-slug>  <ISO-ts>  <I> ideas  <L> lenses  [active | done]
```

3. **No filters / flags v1** — keep it terse. If users hit volume issues, revisit.

## Unknown subcommand

If the first token is missing or not one of `start` / `list` / `resume` / `done`, refuse with a one-line usage hint:

```
/brainstorm <start "<topic>" | list | resume <slug-or-filename> | done>
```

## Notes

- This skill **does not write to `docs/specs/`**. Promotion into a spec is the user's decision — they call `/sdd new <slug>` separately after reviewing the HTML.
- The rendered HTML has a `Copy as markdown for /sdd new` button in the footer that yields a structured markdown block — paste that into the new spec's `spec.md` as starting material.
- Lens library lives in `references/techniques.md`. Adding a lens later is mechanical: append a new section there with the 3 sub-sections (Description, When to apply, Protocol) and the skill picks it up next invocation.
- Never persist to git from this skill. `.claude/.brainstorm-state/` is gitignored by design.
