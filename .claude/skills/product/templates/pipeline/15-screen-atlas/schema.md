# Step 15a — Schema (screen-atlas.md)

`screen-atlas.md` is the single deliverable of Step 15a. This schema is the size-budget + required-section reference; the Step 15a brief's `DONE_WHEN` points here. Per spec 066 the atlas is a **prose-only markdown contract** — no embedded screens, no `extra_files`, no `app/`.

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `screen-atlas.md` | 10 KB | below this the 8 contract sections are not at honest depth |

A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Required sections

8 H2 headers — verbatim, in order (see `prompt.md` for per-section depth):

- `## Overview`
- `## Screens Index`
- `## Sitemap Coverage Cross-Check`
- `## PRD Coverage Matrix`
- `## Design Fidelity`
- `## States Coverage Matrix`
- `## User Flow Walkthrough`
- `## Open Decisions`

## Structural anchors (literal substrings a reviewer greps for)

- `| Route | Category | Chrome | Covers (US-NN) | States | Screen intent |` — proves § Screens Index is a real markdown table, not prose.
- `| US-NN | Priority |` — proves § PRD Coverage Matrix is a table with the US-NN column header.
- `## PRD coverage:` — the `X/Y` summary line closing § PRD Coverage Matrix.
- `Closed-beta partner` — proves § User Flow Walkthrough carries the named-human acceptance clause (CI-only "opens in a browser" acceptance is necessary-but-not-sufficient).
- `Deciding signal` — proves § Open Decisions rows carry a deciding signal.

## What this schema does NOT enforce

Step 15a writes ONE markdown file. There is no `required_glob` for a `screens/*.html` set and no `extra_files` REPORT.md bundle — per spec 066:

- The hi-fi killer-flow mood screens are Step 15b's output (`docs/screens/hifi/<NN>-<name>.html`), produced by the separate § Mood-screen-writer sub-agent.
- The fixture spec is Step 15c's output (`docs/fixture-spec.md`).
- `REPORT.md` is authored by the orchestrator at Phase 4 step 4 (from `templates/report.md.tmpl`), not by this sub-agent.

A Step 15a sub-agent that writes any `app/`, `.tsx`, `.html`, or layout file has overstepped its brief — the atlas is markdown only.
