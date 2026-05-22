# Memory placement

When saving a learning, fact, or rule, route it by **what kind of knowledge** it is and **who/what should see it**. Three buckets, each with distinct propagation properties:

## The 3 buckets

### 1. CC per-user memory — `~/.claude/projects/<path>/memory/`

**For:** preferences, style, personal context that wouldn't help anyone else. Per-user, per-machine, **not git-tracked**. Lost when you switch machines — by design.

**Use when:** the knowledge is genuinely about THIS user (language, response terseness, "I prefer X over Y"). Anything that reads like a profile attribute or interaction style.

**Do NOT use for:** anything substantive about the project itself. If another Agent0 contributor would benefit from knowing this fact, it does not belong here. The "memoria do projeto" naming in CC's UI is misleading: it's memory of the user *about* the project, not of the project itself.

**Concrete example currently in this bucket:** `user_language.md` — "native Portuguese, fluent English; chat in Portuguese by default but repo artifacts stay English". Genuine per-user preference; another developer cloning Agent0 has their own language preference.

### 2. Project memory — `.claude/memory/<topic>.md`

**For:** factual cross-cutting knowledge about THE PROJECT — platform constraints, prior decisions and their reasoning, architectural gotchas discovered through dogfooding, references to canonical external sources. Git-tracked, **propagates between contributors of THE SAME project via PR/clone** but **NOT shipped between projects** via sync-harness manifest. The empty scaffold (`.claude/memory/.gitkeep`) IS shipped so every fork gets its own bucket — but memory content is project-local, never cross-pollinated.

**For forks of Agent0:** this same rule applies. Each fork has its own `.claude/memory/` that accumulates its own factual knowledge (e.g. pyshrnk might memorize "Starlette form parsing without python-multipart uses urllib.parse.parse_qs"). Agent0's memory entries (about CC platform internals, sync-harness design rationale, etc.) do NOT travel to forks — and reciprocally, fork-specific memories do NOT propagate back upstream. The sync tool is one-way for capacities; memory content is one-source.

**Use when:** the knowledge is project-specific factual reference, not behavioral mandate. "Claude Code has 29 hook events", "we chose hash-compare because alternatives X/Y had problems Z". The agent reads these on demand when starting relevant work — discovery is via the `## Memory` block in CLAUDE.md (lazy-read of `.claude/memory/MEMORY.md` index).

**Do NOT use for:** behavioral mandates ("the agent must do X") — those are rules. Capacity operational documentation ("how the supply-chain hook works") — those are rules. Work-specific design context — that lives in the corresponding `docs/specs/NNN-*/` dir.

**One narrow exception** to "no behavioral mandates here": a mandate that binds the Agent0 *maintainer* rather than the agent working in any fork. Rules ship to forks, so a maintainer-only discipline placed in a rule would be inert cruft in every fork that consumes the harness but never extends it. Such disciplines route to project memory despite being mandate-shaped — `propagation-hygiene.md` (how fork-bound files must be written so they carry no Agent0-internal pointers) is the canonical case; `agent0-purpose.md` is a softer precedent.

**Concrete examples currently in this bucket:** `agent0-purpose.md` (Agent0 is a template-forever project; do not list empty placeholders as gaps), `visibility-intent.md` (next visibility wedge is agent-self-debug, not human dashboards), `cc-platform-hooks.md` (the canonical 29 events of the CC platform).

### 3. Project rules — `.claude/rules/<topic>.md`

**For:** behavioral mandates the agent SHOULD comply with, plus operational documentation of the project's capacities (hooks, validators, tools). Git-tracked AND **shipped to forks** via sync-harness manifest — the rules ride with the capacities they govern.

**Use when:** the knowledge is "the agent must follow X when working in this project" or "here's how capacity Y works in any fork that adopts it". Path-scoped variants of these rules use a `paths:` frontmatter to restrict where they apply.

**Do NOT use for:** factual reference data that's Agent0-design-internal (CC platform knowledge, why-we-chose-X decisions). Those are project memory, not rules — they'd noisily ship to every fork that doesn't extend the harness.

**Concrete examples currently in this bucket:** `delegation.md` (5-field handoff mandate), `secrets-scan.md` (gitleaks behavior + override grammar), `runtime-introspect.md` (probe.sh capacity operational docs).

## Routing decision tree

```
Is the knowledge a user-specific preference (language, style)?
  Yes → CC per-user memory (~/.claude/projects/<path>/memory/)
  No  → continue

Is the knowledge a behavioral mandate or capacity operational doc?
  Yes → .claude/rules/<topic>.md (will ship to forks)
  No  → continue

Is the knowledge factual project reference (platform constraint, prior decision, gotcha)?
  Yes → .claude/memory/<topic>.md (git-tracked, NOT shipped to forks)
  No  → reconsider; the knowledge probably belongs elsewhere (CLAUDE.md for orientation, SESSION.md for WIP, docs/specs/ for work-unit design memory)
```

When in doubt, route to project memory (`.claude/memory/`). Demoting from rule → memory later is easy; promoting from per-user → project requires migration.

## Quick reference table

| Bucket | Path | Git-tracked? | Ships to forks? | Auto-loaded? | Best for |
| --- | --- | --- | --- | --- | --- |
| CC per-user memory | `~/.claude/projects/<path>/memory/` | No | No | Yes (MEMORY.md, capped) | Preferences only |
| Project memory | `.claude/memory/<topic>.md` | **Yes** | **Empty scaffold only** (`.gitkeep`); content stays project-local | No (lazy-read via CLAUDE.md `## Memory`) | Factual project knowledge — each project accumulates its own |
| Project rules | `.claude/rules/<topic>.md` | **Yes** | **Yes** | On demand (CLAUDE.md mentions) | Behavioral mandates + capacity docs |

## Cross-cutting artifacts (not buckets, but related)

- **`CLAUDE.md`** — first-contact orientation, capacity inventory, always loaded. Points at memory/rules/specs as needed.
- **`SESSION.md`** — short-term WIP handoff, ~2KB budget, replaced rather than appended. Always loaded.
- **`docs/specs/NNN-*/`** — design memory for specific work units. Not auto-loaded; referenced when relevant.

## Why three buckets, not two

The previous version of this rule had only two buckets: project-shared (rules) and per-user (preferences). That model conflates two distinct kinds of project-shared knowledge: behavioral mandates that should ride with capacities into forks, and factual reference that's Agent0-internal design context. The empirical trigger for the split was discovering that Claude Code has 29 hook events (not the ~9 originally assumed). That knowledge:
- Is project-shared (other Agent0 contributors benefit)
- Is NOT a behavioral mandate (it's reference data)
- Should NOT ship to forks (forks consume capacities, they don't extend the harness)

No existing bucket fit. The new `.claude/memory/` bucket covers this gap.
