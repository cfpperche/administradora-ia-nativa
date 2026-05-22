# Spec anti-patterns

Synthesised from `anthill-spec` and `anthill-feature-refiner` failure catalogs. Each row: the trap, then the fix. Read before drafting `functional-spec.md`.

## Functional-spec traps

| Anti-pattern | Instead |
|---|---|
| Technical jargon in the functional spec — "REST API", "WebSocket", "Redux store", "middleware" | Product language — "sends data to the server", "updates in real time", "remembers your choice". Jargon lives in `architecture.md`, never here. |
| Skipping login / signup / forgot-password pages because they're "obvious" | Always document auth pages — they are part of the user experience and have their own states (error, locked-out, success). |
| One component per page — "the Dashboard shows stuff" | Break the page into every interactive element: sidebar, cards, filters, buttons, empty state. The component table is exhaustive. |
| Missing empty / loading / error states | Every page needs at minimum empty, loading, error, populated. The states table is not optional. |
| Combining pages — "Dashboard and Settings" in one section | One `### {Page}` subsection per page. Scannability is the point. |
| Vague interactions — "user can manage projects" | Concrete trigger / action / result — "click → opens modal → new-project form appears". |
| No navigation map, or a map with orphan pages | ASCII diagram covering every page and every transition trigger. Every page reachable. |
| Acceptance scenarios with unverifiable `Then` clauses — "works correctly", "is fast", "looks good" | Assertion-shaped `Then` — specific visible text, value, status, file. A verifier must be able to check it. |
| Inventing features or pages the prototype never showed | The spec decomposes steps 1+2. If a surface isn't in the concept brief or the prototype, it isn't in the spec — flag the gap to the parent instead. |
| Padding to hit the 15 KB floor | The floor is a symptom check, not a target. A short spec means missing pages/states/features — go find them, don't inflate prose. |

## Feature-decomposition traps

| Anti-pattern | Instead |
|---|---|
| Scope creep dressed as completeness — speccing v2 and v3 features "while we're here" | Spec v1 only. Everything else goes in `## Non-Goals` with a reason. The concept brief's anti-goals are the guardrail. |
| Generic edge-case lists copy-pasted across every feature | List only the edge cases that *actually apply* to that feature. A read-only view has no "validation failure"; a bulk action has no "single-item race". |
| Success criteria that restate the feature — "the feature works" | Observable evidence — "user sees the project in the list within 1s of submitting", "the toast reads 'Saved'". This is the input to step 4's tests. |
| Treating cross-cutting concerns as deep system design | One paragraph of *shape* per concern. Auth model is "login required, two roles"; it is not an RBAC matrix. Depth is step 9. |

## Architecture-artifact traps

| Anti-pattern | Instead |
|---|---|
| Pre-deciding the stack in `architecture.md` — "Postgres + Prisma + Next.js" | Name modules and entities, not technologies. Stack choice is step 9. |
| Writing `architecture.html`/`json` from scratch, in parallel with `architecture.md` | Derive: functional-spec → architecture.md → html/json. Parallel authoring guarantees drift. |
| `architecture.md` that is really a full system design — scale, security, deployment | Step 3 is the *preliminary* skeleton. Defer the deep concerns to `## Open Architecture Questions`. |
| SQL DDL or migration syntax in the Data Model section | Informal entities + relationships + key fields. DDL is step 9. |
| The diagram and the prose disagree — a module in `architecture.html` that isn't in `architecture.md` | One truth, three projections. Every node traces back. A mismatch is a defect, not a variation. |

## Process traps

| Anti-pattern | Instead |
|---|---|
| Fabricating a missing prior artifact instead of stopping | If the concept brief or prototype is missing/thin, say so to the parent and stop. Synthesis needs real inputs. |
| Skipping the `## Decisions Pending` table when there are open questions | Every uncertain choice, every unconfirmed scope-boundary call, goes in the table. Step 8 (PRD) parses it — an omitted decision becomes a silent assumption downstream. |
| Sycophantic framing — "great prototype, speccing it now" | Neutral synthesis. If the prototype has a gap (a page with no empty state, a flow with a dead end), surface it in the spec, don't paper over it. |
