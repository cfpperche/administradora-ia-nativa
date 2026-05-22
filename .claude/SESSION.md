# Session handoff

Read at the start of every session; captures WIP that wouldn't otherwise survive. See `.claude/rules/session-handoff.md`.

---

## Current state

**Bootstrap stage.** Repo initialized from Agent0 on 2026-05-22 — harness synced via `sync-harness.sh`, validated clean (33/33 harness-sync tests, idempotent, exec bits preserved). Public at `github.com/cfpperche/administradora-ia-nativa`. **No product code yet** — only the Agent0 harness and the orientation docs (`CLAUDE.md`, `README.md`).

This is the **product repo**. The pitch and strategy live in a separate repo, `proptech-ia-pitches` (`github.com/cfpperche/proptech-ia-pitches`) — read the hero pitch `pitches/00-administradora-ia-nativa.md` and the wedge module `pitches/02-cobranca-conversacional-ia.md`.

## The thesis (summary — full version in pitch 00)

Agentic operator for condominium management: AI agents execute the *administradora*'s work, humans supervise (services-as-software). Autonomy ladder: **v1 supervised copilot** → v2 supervised autonomy → v3 autonomous operator. The moat is the **control plane** — the verification + audit-trail layer that makes autonomy trustworthy. Golden rule: **empower the administradora, never replace her** (she is Group Software's paying customer). The pitch targets Group Software's Startup Academy (CEO Rodrigo Monteiro).

## Next steps

1. **Scope the v1 demo via `/sdd new`.** Chosen wedge module: **conversational collections** (pitch 02). The demo's job: turn the pitch from promise into proof — something that runs and shows in ~2 minutes.
2. The demo MUST put the **control plane** on screen: agent negotiates → human approves → action logged/auditable. Not an "assistance" demo (a chatbot that answers) — a "supervised execution" demo. That contrast is the differentiator.
3. Pick the stack in the `/sdd` plan phase (pitch 00 guessed TypeScript/Node — not locked).

## Decisions & gotchas

- **Wedge = collections (02), not financial reporting (03).** Collections has the most quantified pain (~13% delinquency), demos well (it is a conversation), and its differentiator — writing the negotiated agreement back into the ERP under human approval — makes the control plane visible. Pitch 03 would be faster to build but is an assistance demo, not execution.
- **The repo carries the full Agent0 harness** (~600 files) — deliberate: the product's moat is AI-agent governance, so the repo is built under the same discipline the product sells.
- `core.hooksPath` is already activated — the gitleaks pre-commit hook is live.
- **`.gitignore` is stack-agnostic.** Uncomment the chosen stack's patterns (`node_modules/`, etc.) once the stack is set, or the harness validator chokes on untracked noise.
- Keep the harness current later with `sync-harness.sh --agent0-path=<agent0-path> --check` run from the Agent0 repo (the source path is always required — see `.claude/rules/harness-sync.md`).

## Carryover

- A `sync-harness` doc bug surfaced in Agent0 during this bootstrap (§ What fires examples contradicted the code) — already fixed and committed in the Agent0 repo. Not a pending item here.
