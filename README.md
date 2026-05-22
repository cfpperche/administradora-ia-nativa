# Administradora IA-nativa

Agentic operator for Brazilian condominium management — AI agents run the *administradora*'s operation (collections, communication, financial reporting, vendor management, compliance) under human supervision, so one team manages an order of magnitude more condominiums.

This is the **product repository**. The pitch, competitive analysis, and strategy live in [`proptech-ia-pitches`](https://github.com/cfpperche/proptech-ia-pitches) — start with the hero pitch, *Administradora IA-nativa*.

## Status

Bootstrap stage. The repository was initialized from **Agent0** and carries its governance harness (`.claude/` — rules, hooks, validators, skills, tests). Carrying that harness is deliberate: the product's moat is *verifiable, auditable AI agents*, and the repo is built under the same discipline the product sells.

Next: scope the v1 demo — the **conversational collections** module (supervised copilot) — as a spec via `/sdd`.

## Layout

```
.claude/      # Agent0 governance harness — rules, hooks, skills, validators, tests
CLAUDE.md     # repo orientation for AI agents working here
.githooks/    # gitleaks pre-commit (activate: git config core.hooksPath .githooks)
```

Product code lands here once the v1 spec is written.
