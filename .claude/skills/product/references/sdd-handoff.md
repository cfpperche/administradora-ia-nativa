# SDD handoff — the Phase 5 contract

Per spec 066, `/product` does **not** generate a runnable app. It ends at the **visual contract** (Phase 4 — `screen-atlas.md` + the hi-fi killer-flow mood + `fixture-spec.md`) and then, in Phase 5, **scaffolds the SDD specs the engineering build runs as**. This doc is the contract the orchestrator (`SKILL.md` § Phase 5) executes.

The motivating evidence: the deleted v2/v3 per-route screen-writer fan-out tried to generate ~36 Next.js `page.tsx` files in a blind parallel pass and the output quality collapsed (mei-saas dogfood, 2026-05-19/20). Making a blind fan-out produce responsive, consistent, visually-verified UI is a hard problem the original `/product` design lost. The fix is not a better fan-out — it is to stop fanning out: hand a *contract* to SDD, which is built for deliberate, harness-disciplined, visually-fed implementation. `/product` keeps what it does well (design synthesis → a visual contract) and stops doing what it does badly (generating screens).

## What Phase 5 produces

Two spec directories under `<out>/docs/specs/`, written **directly** (NOT via a `/sdd new` skill-to-skill call — `/sdd new` only does mkdir + template-copy + placeholder substitution; it deliberately does not *fill* `spec.md`, and `/product` must fill from pipeline artifacts):

| Dir | Role | What `/product` fills |
|---|---|---|
| `<out>/docs/specs/001-<slug>/` | **umbrella spec** — tracks the whole v1 build | `spec.md` filled (`**Type:** umbrella` + child-spec matrix + standing constraints); `plan.md` / `tasks.md` / `notes.md` left as `.claude/skills/sdd/templates/*.tmpl` scaffolds (an umbrella ships no code — the matrix in `spec.md` IS its tracking surface) |
| `<out>/docs/specs/002-foundation/` | **child #1 — foundation** (skeleton + tooling + route-group dirs + thin layout shells) | `spec.md` filled (ready to start); `plan.md` / `tasks.md` / `notes.md` left as scaffolds (the founder runs `/sdd plan` then `/sdd tasks` on it) |

Children #2..N are **matrix rows in the umbrella's `spec.md` only** — NOT pre-scaffolded. Eight empty child dirs that sit untouched for months are clutter; the founder materializes each via `/sdd new <phase-slug>` when reaching it (the spec-060 umbrella pattern).

Use `.claude/skills/sdd/templates/{spec,plan,tasks,notes}.md.tmpl` as the base for every file. Substitute `{{NNN}}` / `{{SLUG}}` / `{{DATE}}` as `/sdd new` would; then overwrite the body sections `/product` fills.

## The umbrella spec — `001-<slug>/spec.md`

Header: `# 001 — <slug>`, `**Status:** draft`, `**Type:** umbrella` (the `Type:` line per `.claude/rules/spec-driven.md` § The four artifacts).

Fill each section from the pipeline artifacts:

- **Intent** — one paragraph: this umbrella tracks building the `<product>` v1 app from the `/product` visual contract. Name the inputs by path: `docs/screen-atlas.md` (the navigable contract), `docs/prd/v1.md` (US-NN scope), `docs/sitemap.yaml` (route inventory), `docs/design-system/` (tokens + components), `docs/fixture-spec.md` (shared mock-data contract), `docs/roadmap.md` (the phases this matrix is sliced by). State that the umbrella ships nothing itself — acceptance is the closure of every child row.
- **Acceptance criteria** — the umbrella is `shipped` when every child-matrix row has a `→ NNN` link to a created child spec OR a `closed: <reason>` marker. One plain-bullet criterion per `required_categories` group from the sitemap is a good shape ("every `auth` route from `docs/sitemap.yaml` is owned by a child spec").
- **Non-goals** — implementing any screen in this spec (child specs do that); re-running the `/product` pipeline; shipping v2 surfaces flagged in the atlas § Open Decisions.
- **Open questions** — carry forward the atlas § Open Decisions rows (they are integration-shape decisions the build resolves).
- **Context / references** — links to the five contract artifacts above + `docs/REPORT.md` + this skill's spec lineage.
- **Child-spec matrix** — see below. This is the load-bearing section.
- **Standing constraints** — see below.

### Child-spec matrix

A markdown table, one row per child spec. Child #1 + #2 are fixed; children #3..N are **sliced by the phases in `docs/roadmap.md`** (one child per roadmap phase, scoped to the screens that phase's user stories touch).

```markdown
## Child-spec matrix

| # | Child spec | Scope | Roadmap phase | Status |
|---|---|---|---|---|
| 1 | `002-foundation` | App skeleton + tooling (Biome, tsc, Tailwind + tokens.css wiring) + route-group dirs per sitemap `chrome` + thin `layout.tsx` shells | (pre-phase — unblocks all) | scaffolded → `002-foundation/` |
| 2 | component-library | Build the shared component set from `docs/design-system/components.md` + `tokens.css`; wire components into the foundation's `layout.tsx` shells | (pre-phase — unblocks all) | matrix-only — `/sdd new component-library` |
| 3 | <roadmap phase 1 title> | Screens for the user stories in roadmap phase 1 | Phase 1 | matrix-only — `/sdd new <slug>` |
| 4 | <roadmap phase 2 title> | Screens for roadmap phase 2 | Phase 2 | matrix-only |
| … | … | … | … | … |
```

- **Child #1 = foundation** — always. Scaffolded by `/product`.
- **Child #2 = component-library** — always. Its input spec is `docs/design-system/components.md` + `tokens.css` (so `components.md` becomes a real upstream spec, not a decorative doc — this closes F5). It wires the components into child #1's `layout.tsx` shells, so the shared chrome (sidebar, topbar, marketing header) lives in ONE child rather than being re-invented per screen (closes F4).
- **Children #3..N** — one per `docs/roadmap.md` phase. Each owns the screens whose `covers_us` (from `docs/sitemap.yaml`) maps to that phase's user stories.

### Standing constraints

Every child spec inherits these — state them once in the umbrella's `## Standing constraints` section so each `/sdd new <child>` reads them as the build contract:

- **Styling: Tailwind utility classes** (the declared stack). The token source is `docs/design-system/tokens.css` (a Tailwind v4 `@theme` block). **Next stack:** Tailwind v4 — `app/globals.css` `@import`s `tokens.css` directly, so the `@theme` block resolves to real utilities (`bg-primary` / `p-md`). **Expo stack:** Tailwind v3 via NativeWind v4 — the current stable React Native path (NativeWind v5 / Tailwind v4 is pre-release as of 2026-05); the foundation child translates `tokens.css`'s token values into `tailwind.config.js` `theme.extend`, because NativeWind 4 cannot consume a v4 `@theme` file directly. Either way the utility names are the same. **No inline `style={{}}` for layout or positioning** — inline style cannot carry a breakpoint and is how mobile-first dies. (A single dynamic value — a computed bar width — is the lone exception.) This closes F1 (mobile-first) and F2 (sanctioned inline style) at the build layer.
- **Mobile-first.** Author for the 375 px viewport; layer wider layouts via Tailwind responsive prefixes (`sm:` / `md:` / `lg:`). Every screen reflows with no horizontal overflow at 375 px. The hi-fi mood screens at `docs/screens/hifi/` are the rendered mobile-first reference.
- **Fixture coherence.** Every screen imports the ONE shared fixture set the foundation child implements as `lib/mock-data.ts` from `docs/fixture-spec.md`. No screen invents its own mock data (closes F9).
- **Visual verification.** Each child verifies its screens against the atlas + hi-fi mood with the Playwright MCP (seeded into `<out>/.mcp.json` at Phase 0). Screenshot at 375 px + 1280 px; check horizontal overflow.

## Child #1 — `002-foundation/spec.md`

Header: `# 002 — foundation`, `**Status:** draft` (no `Type:` line — it is a normal feature spec).

- **Intent** — scaffold the runnable skeleton so the component-library and per-phase children have a place to land: the Next.js (or Expo) app skeleton, the tooling (Biome, `tsc`, and Tailwind wired to `docs/design-system/tokens.css` — Next `@import`s the v4 `@theme` file directly, Expo translates it into `tailwind.config.js`; see § Standing constraints), the route-group directories (one `app/(<chrome>)/` per distinct `chrome` value in `docs/sitemap.yaml`), and **thin** `layout.tsx` shells per route group (structural placeholders — the real shared chrome components are child #2's job; child #2 wires them into these shells).
- **Acceptance criteria** — Given/When/Then scenarios + static facts:
  - `pnpm install && pnpm dev` starts the dev server clean; `tsc --noEmit` and `biome check .` both exit 0.
  - Token wiring resolves — Next: `app/globals.css` imports `docs/design-system/tokens.css` and a token utility (`bg-primary`) resolves; Expo: `tailwind.config.js` carries the translated token values and a token utility (`bg-primary`) resolves.
  - One `app/(<chrome>)/` directory exists per distinct `chrome` value in `docs/sitemap.yaml`; each has a thin `layout.tsx` Server Component shell.
  - `lib/mock-data.ts` implements the `docs/fixture-spec.md` entity set.
- **Non-goals** — the shared chrome *components* (sidebar, topbar, marketing header) — those belong to child #2; the feature screens — those belong to children #3..N.
- **Context / references** — the bundled skeleton at `.claude/skills/product/templates/app-skeleton/<stack>/`, `docs/sitemap.yaml`, `docs/design-system/tokens.css`, `docs/fixture-spec.md`. Scaffold the app at the `<out>/` root (sibling to `docs/`) so the skeleton's `app/globals.css` relative `@import "../docs/design-system/tokens.css"` resolves.

`plan.md` / `tasks.md` / `notes.md` for child #1 stay as template scaffolds — the founder runs `/sdd plan` then `/sdd tasks` to fill them. (`/product` fills `spec.md` only because intent is the part that derives mechanically from the pipeline artifacts; the *how* is the founder's engineering judgment.)

## Fallback — roadmap has no usable phase structure

`docs/roadmap.md` normally defines 3 phases (MVP / Growth / Polish) with user-flow-shaped titles — those become children #3, #4, #5. If the roadmap is degenerate (no phases, or one undifferentiated blob), do NOT invent phases. Emit a **single** child #3 named `app-build` scoping every non-foundation, non-component-library screen, and note in the umbrella `## Child-spec matrix` that the roadmap lacked phase structure so the build is one child. The founder can split it later via `/sdd new`.

## Numbering

`<out>/docs/specs/` is a fresh tree (created by Phase 0). The umbrella is `001-<slug>`, foundation is `002-foundation`. Children #3..N are matrix rows — when the founder runs `/sdd new <slug>` for one, `/sdd` assigns the next `NNN` automatically. The matrix rows do not need pre-assigned numbers; they carry slugs.

## Cross-references

- `SKILL.md` § Phase 5 — the orchestration body that executes this contract
- `.claude/rules/spec-driven.md` § The four artifacts — the `**Type:** umbrella` convention
- `docs/specs/060-harness-gaps-2026/` — the canonical umbrella + child-matrix example
- `docs/specs/066-product-ui-quality/` — the spec that introduced this handoff
- `.claude/skills/sdd/templates/` — the four template files used as the scaffold base
