# Writing skill descriptions — best practices

Condensed from https://agentskills.io/skill-creation/best-practices and the broader agentskills.io best-practices guidance, tailored for Agent0. Keep this file local so the rules are available offline and stay frozen against the upstream version Agent0 adopted on 2026-05-17.

## The description carries discovery weight

When an agent starts a session, it loads only the `name` and `description` of every available skill — roughly 100 tokens per skill. The body is loaded only after the agent decides the skill is relevant. So the description does two jobs simultaneously: it tells a reader **what the skill does**, and it gives the agent **enough signal to match it to a user prompt**.

Both jobs matter. A description that explains the skill perfectly to a human but lacks keywords the user is likely to say will fail to trigger when it should.

## The two-part shape

Effective descriptions follow a "what + when" structure:

> **`<what the skill does>`. Use when `<the trigger condition: keywords, user phrasings, task patterns>`.**

**Good example** (from the agentskills.io quickstart):

> Roll dice using a random number generator. Use when asked to roll a die (d6, d20, etc.), roll dice, or generate a random dice roll.

**Good example** (PDF processing):

> Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs. Use when working with PDF documents or when the user mentions PDFs, forms, or document extraction.

**Poor example** (no trigger signal, no specifics):

> Helps with PDFs.

The poor example fails both jobs: a reader doesn't know what specifically it helps with, and the agent has no keywords to match against.

## Concrete rules

### 1. Lead with the verb-object

Start with what the skill produces or accomplishes. "Extracts text", "Drafts a plan", "Validates frontmatter". Not "A skill that helps with…" — wastes tokens, says nothing.

### 2. Name the artifacts

If the skill produces or operates on specific files, formats, or systems, name them. "Drafts `plan.md` from `spec.md`" beats "Drafts planning documents".

### 3. Include the user's words

Think about how the user phrases the task they want the skill to handle. Include those phrasings as triggers — "Use when the user says X, Y, or Z" — not just the engineer's framing.

### 4. List subcommands when present

For skills with subcommands (like `/sdd`, `/remind`, `/brainstorm`), enumerate them in the description so the agent knows which prompts each subcommand serves. The 1024-char cap is generous enough to fit a subcommand list for most skills.

### 5. Reference the rule/spec file at the end (Agent0 convention)

When the skill ships with a deeper rule doc (`.claude/rules/<topic>.md` or a spec under `docs/specs/`), name it at the end of the description: `See <path> for boundary cases.` The agent uses this as a discovery anchor when deciding whether to read more.

### 6. Stay under 1024 characters

This is the hard cap. Agent0's existing skills (`remind` ~620 chars, `sdd` ~430, `brainstorm` ~480) sit comfortably under it; the cap is the budget, not the target. If you blow past 1024 your `SKILL.md` will fail validation.

## Anti-patterns to avoid

### Sycophancy / marketing language

> Empowers the agent to expertly handle the most challenging…

Cut. The agent does not care about adjectives; the user reads the description rarely and skips fluff. State the function.

### Restating the skill name

> ## `/sdd`
>
> description: The `/sdd` slash command for SDD workflows.

The name is already loaded; the description repeats no signal. Use the bytes for trigger keywords instead.

### Vague triggers

> Use when working on stuff related to data.

"Stuff" matches every prompt. "Use when the user mentions CSV files, schemas, or asks to query a database" doesn't.

### Omitting the "when"

> Drafts plan documents from spec documents.

Tells what, not when. The agent reads the description and has to *infer* when this applies — and may guess wrong. Add: `Use when a spec.md exists and the user says "plan", "design the approach", or "what's next".`

## How to iterate

The agentskills.io guidance recommends a **refine with real execution** loop:

1. Write the first draft, ship it.
2. Watch real agent activations: when does the skill trigger that you didn't want? when does it fail to trigger when you did want?
3. False positives → tighten the trigger language (remove ambiguous keywords).
4. False negatives → add the user's actual phrasing as new trigger keywords.

This is iterative — single-shot description authoring rarely produces something well-tuned. The bench for this loop is also from the spec author's own use; Agent0 doesn't yet have an automated activation-trace analyzer (the upstream `optimizing-descriptions` page describes one).

## Where to read more

- **Live**: https://agentskills.io/skill-creation/best-practices, https://agentskills.io/skill-creation/optimizing-descriptions, https://agentskills.io/skill-creation/evaluating-skills
- **Frozen reference here**: `references/spec-snapshot.md` for the binding rules; `references/frontmatter-validation-rules.md` for the validator's check list

The live links are the authority; this file is the Agent0-tailored offline cheat sheet.
