# Architecture shape — section catalogue + derivation chain

Canonical structure for `system-design.md`. Section-by-section depth guidance, the derivation chain from step 3 → step 9, and the bridge-floor vs canonical-rigor depth ladder.

## The derivation chain (step 3 → step 9)

Step 3 produces `architecture.md` — a **structural skeleton** with four sections:

```
## Module Decomposition
## Data Model
## Key Flows
## Integration Points
```

Step 9 deepens that skeleton into the production design. The same modules, entities, flows, and integration points carry forward — but now with concrete tech choices, deployment shape, non-functional rigor, evaluation, and the alternatives-considered audit trail. Three rules govern the deepening:

1. **Same modules, refined boundaries.** Step 3's "Auth module" might become "API service · `/auth/*` route handlers + session middleware". Module identity is preserved; the boundary shifts from logical (what the code does) to physical (where the code runs, what protocol it speaks).
2. **Same entities, concrete schema.** Step 3's `Task { id, project_id, title, status }` becomes a typed pseudo-schema with PG types, indexes, soft-delete posture, multi-tenancy column if applicable. Adding fields is fine; removing entities is a design defect (step 3 had a feature step 9 forgot).
3. **Same flows, fully traced.** Step 3's "user signs up → email confirmation → first action" becomes a sequence in the architecture.json arrows + a deeper treatment in system-design.md § Services + § APIs. The flow shape from step 3 is the contract; step 9 names every component the flow touches.

When `architecture.md` is missing (step 3 skipped or not yet ported in the fork's pipeline state), the agent reads `functional-spec.md` directly and synthesises the architecture from there. Call this out in `## Decisions Locked & Open § Open` as a discipline note.

## The two-floor depth ladder

The template merges two anthill skills behind one adaptive depth model:

### Bridge-floor (the minimum every system-design.md must cover)

Inherited from `anthill-system-design-bridge`. Six sub-section concepts that consolidate decisions already locked in the PRD:

- **Stack** — language, framework, runtime, hosting, deployment target (already named in PRD § Technical Considerations)
- **Integrations** — 3rd-party APIs, payment, auth, observability vendors (already enumerated in PRD § Technical Considerations + § User Stories)
- **Data Model** — entities + relationships (already implied by PRD § User Stories surface)
- **Decisions Locked** — Open Questions the PRD resolved during interview / spec-decisions inline-resolution (PRD § 4.5)
- **Security & Privacy** — auth model + data classification (already in PRD § Technical Considerations or hinted in § Acceptance Criteria)
- **Observability** — error tracking + analytics (already in PRD § Success Metrics measurement column)

The bridge-floor is **mechanical consolidation, not design synthesis** — it extracts what the PRD already decided. If a bridge section has no PRD substance, emit `*Not declared in PRD; deferred to implementation (see Open Decisions § N).*` rather than fabricating.

### Canonical-rigor (the 20 KB target for v1 SMB SaaS and larger)

Inherited from `anthill-principal-engineer`. Five additional rigor layers on top of the bridge-floor:

1. **Service decomposition** with comms protocol — monolith / modular / multi-service; protocol per boundary (REST / RPC / events / shared DB)
2. **Full API endpoint catalog** — every public + internal endpoint with contract intent (NOT OpenAPI; just the *intent* table)
3. **Deployment topology** — host, CI/CD shape, region posture, observability tiers
4. **Non-functional budgets** — perf (p95/p99 latency), scale (target concurrent users), reliability (uptime, RTO/RPO), accessibility floor (inherited from step 4)
5. **Evaluation + alternatives + trade-offs** — the principal-engineer assessment table (5×3 Dimension × Concern), per-major-choice alternatives considered, trade-offs surfaced explicitly

Compact-mode micro-products may skip the trade-offs treatment and land closer to bridge-floor depth (~12 KB). The 20 KB Layer-1 floor is the universal sanity line for v1 SMB SaaS and venture-scale; compact-mode micro-products that legitimately land under should document the compact-mode decision in `## Overview` opening sentence + use the `# OVERRIDE: compact-product: <class>` shape in submit context.

## Section-by-section depth guidance

### `## Overview`

One paragraph. Three load-bearing sentences:

```markdown
## Overview

v1 system design for an SMB SaaS keyboard-first task management product targeting engineering managers at 5-30 person squads. Full template depth applied. The system runs on Vercel (web + API) backed by Supabase (Postgres + Auth + Storage), with Stripe handling payments and Resend handling transactional email.
```

The product class declaration ("SMB SaaS", "Micro-Product CLI helper", "Venture-Scale Marketplace") tells the reader which calibration row from § 6 applied — depth expectations follow.

### `## Stack`

Concrete language + framework + database + ORM + frontend with version MAJOR (not minor/patch). One sentence rationale per choice anchored to a specific PRD constraint:

```markdown
## Stack

- **Language: TypeScript 5.4.** Chosen for shared types across web + API (US-19 keyboard-shortcut feature ships from web; US-23 bulk-action API ships from API; type-safety across the boundary prevents the regression mode where shortcuts and API drift).
- **Framework: Next.js 15 App Router.** Chosen for the React Server Components model that fits the keyboard-first triage flow (US-07, US-12) — server-rendered list with client-island interactions keeps the cold-load <1s on the EM persona's typical hardware.
- **Database: Postgres 16 (Supabase managed).** Chosen for transactional consistency on the task-completion event (US-07, US-12) which needs atomic write across `tasks.status` and `analytics_events` table. Supabase's managed posture removes the v1 ops burden.
- **ORM: Prisma 5.** Chosen for migration ergonomics + type generation. Drizzle's edge-runtime story is stronger but Prisma's mature migrations + Supabase integration matter more at v1 (see § Alternatives Considered).
- **Frontend: React 19.** Inherited from Next.js 15. No client-side state library at v1 (server components + URL state cover US-07 through US-19).
```

Anti-pattern: vague rationale ("reliable", "fast", "modern"). Good rationale always cites a user story, success metric, or v1 constraint.

### `## Services`

State plainly: monolith vs modular monolith vs multi-service. Most v1s are monoliths.

```markdown
## Services

v1 is a **modular monolith**. Two logical modules with shared deployment:

- **Web module** — Next.js Server Components + Route Handlers. Owns the keyboard-first UI, session middleware, and the `/api/*` Route Handlers.
- **Worker module** — Vercel Cron + queue-backed background jobs (analytics rollup, email batches). Same Next.js project; different invocation path.

Communication: shared Postgres database (no service-to-service network calls at v1). Worker reads/writes the same schema as Web; reliability comes from short transactions + idempotency keys on event-driven rows.

**Why not microservices?** PRD scale target is 500 weekly-active teams at v1 (success-metric § 1). A 2-service decomposition is overkill at that scale; the cost of service-boundary ceremony (deployment coordination, inter-service contracts, distributed tracing) is paid before the scale demands it. v2 may carve out an `ml-service` if US-23 (sentiment analysis backlog) lands.

**The 2 modules above are behavioural boundaries within a single deploy unit — not service boundaries.** Junior engineers reading the step-3 architecture skeleton may misread named-module decomposition as a service map; the v1 monolith ships as one deploy.
```

Always include the disclaimer-sentence above when v1 is a monolith named with multiple internal modules. The single sentence prevents a high-frequency reading regression — step-3 skeletons routinely name 10-20 modules to capture *behavioural* decomposition, which gets misread as a service map without the explicit "single deploy unit" framing. Skip the disclaimer ONLY when v1 truly is multi-service.

### `## Data Model`

Typed pseudo-schema with explicit user-story cross-references. Key indexes are load-bearing for v1 perf:

```markdown
## Data Model

### Entities

```
User {
  id: uuid (pk)
  email: text (unique)
  name: text
  created_at: timestamptz
  deleted_at: timestamptz (nullable, soft-delete posture)
}  // needed for US-01, US-08, US-15

Org {
  id: uuid (pk)
  name: text
  owner_id: uuid (fk → User)
  created_at: timestamptz
}  // needed for US-03, US-08, US-15

Membership {
  user_id: uuid (fk → User)
  org_id: uuid (fk → Org)
  role: enum('owner' | 'admin' | 'member')
  PRIMARY KEY (user_id, org_id)
}  // needed for US-03 (org switching), US-15 (role-based authz)

Task {
  id: uuid (pk)
  org_id: uuid (fk → Org)        -- multi-tenancy column
  project_id: uuid (fk → Project)
  title: text
  status: enum('backlog' | 'in_progress' | 'done')
  assignee_id: uuid (fk → User, nullable)
  position: integer               -- kanban order within column
  created_at, updated_at: timestamptz
  completed_at: timestamptz (nullable)
}  // needed for US-07, US-12, US-19
```

### Indexes (load-bearing for v1)

- `tasks(org_id, status, position)` — drives the kanban-view query (US-07, US-12)
- `tasks(assignee_id, status)` — drives "my tasks" view (US-19)
- `analytics_events(org_id, occurred_at)` — drives the success-metric measurement (PRD § Success Metrics row 1)

### Multi-tenancy

Org-scoped via `org_id` column on every tenant-owned table. Row-level security NOT enabled at v1 (Postgres RLS adds query-plan complexity at our scale; application-level authz in middleware suffices). v2 may flip to RLS if we onboard regulated-data customers (US-31 backlog).

### Soft-delete posture

Users + Orgs soft-delete (regulatory: 30-day data-recovery window per LGPD posture in `security.md`). Tasks hard-delete (no compliance requirement; soft-delete bloats the kanban-view query). Memberships hard-delete (membership history isn't queried).
```

### `## APIs`

Markdown table. One row per endpoint. Source column cross-references `US-NN`.

```markdown
## APIs

### Public API (consumed by web)

| Method | Path | Contract intent | Source |
|---|---|---|---|
| POST | /api/auth/sign-in | Session creation; sets HTTP-only cookie | US-01 |
| POST | /api/tasks | Create task; returns Task object with id + position | US-07 |
| POST | /api/tasks/:id/complete | Move task to `done`; emit `task.completed` event | US-07 |
| PATCH | /api/tasks/:id/move | Reorder within column (drag); update `position` | US-12 |
| POST | /api/tasks/bulk | Bulk-assign or bulk-status update; max 50 ids/request | US-19 |
| GET | /api/orgs/:id/board | Kanban-view payload; org-scoped; cached 5s | US-07 |

### Internal (worker-only)

| Method | Path | Contract intent | Source |
|---|---|---|---|
| (cron) | /api/cron/analytics-rollup | Daily rollup of `analytics_events` → `metrics_daily` | PRD § Success Metrics |
| (cron) | /api/cron/email-digest | Weekly digest email per active user | US-23 (backlog) |
```

The table forces structured thinking. A row without a `Source` is a discipline failure — every endpoint must trace to a user story, spec section, or audit finding.

### `## Integrations`

Per integration: what + alternative rejected + lock-in posture.

```markdown
## Integrations

### Stripe — payments
- **Used for:** subscription billing (US-25, US-28); per-seat metering against `Membership` count
- **Alternative considered + rejected:** Paddle — slightly better global tax handling, but Stripe's API maturity and Next.js SDK integration are stronger for v1 dev velocity
- **Lock-in posture:** Sticky. Customer-id + subscription-id are in our DB; migrating away requires a 2-week port (acceptable risk at v1)

### Supabase Auth — auth
- **Used for:** email/password + OAuth (Google) (US-01, US-03)
- **Alternative considered + rejected:** Auth0 — feature-richer, but $240/mo at the v1 user tier vs Supabase's bundled $25/mo. Cost-benefit doesn't justify Auth0 until enterprise SSO (post-v1)
- **Lock-in posture:** Replaceable. Auth0/Clerk/Cognito are all swap-in options; user data lives in our Postgres (Supabase's auth schema is in the same DB)

### Resend — transactional email
- **Used for:** sign-up confirmation, password reset, weekly digest (US-23 backlog)
- **Alternative considered + rejected:** Postmark — both are equivalent; Resend's React-email integration and free-tier (3K emails/mo) fit v1 better
- **Lock-in posture:** Replaceable. Swap surface is the `sendEmail()` helper — 1 day of work
```

### `## Deployment`

Host + CI/CD + secrets + observability:

```markdown
## Deployment

- **Host:** Vercel (web + API + cron). Edge regions: iad1 (US east) primary; pdx1 (US west) failover. EU region (fra1) deferred to v2 when EU customers materialise.
- **Database host:** Supabase managed Postgres, us-east-1.
- **CI/CD:** GitHub Actions. Three workflows: PR checks (lint + tsc + tests), main branch deploy (Vercel auto-deploy on push), nightly E2E (Playwright).
- **Secrets:** Vercel encrypted env vars (production + preview); local dev uses `.env.local` (gitignored). No HashiCorp Vault at v1 — Vercel's env-var surface is sufficient. Rotation posture: manual on credential leak; quarterly review.
- **Observability:**
  - Logs: Vercel runtime logs + Logtail for retention (30 days)
  - Metrics: Vercel Analytics (web vitals) + custom rollups in `metrics_daily` table
  - Tracing: NOT deployed at v1 (single-service deployment doesn't need distributed tracing; revisit at multi-service)
  - Error tracking: Sentry, free tier
```

### `## Non-Functional`

Perf + scale + reliability + accessibility:

```markdown
## Non-Functional

### Performance budgets

- **p95 latency:** 200ms for kanban-view GET (US-07 success criterion: triage in <5min implies single-action <300ms)
- **p99 latency:** 800ms ceiling; alert if exceeded for 5+ minutes
- **Cold load:** < 1s on the EM persona's hardware (M-series Mac, gigabit broadband)
- **Time-to-interactive:** < 2s on first paint

### Scale assumptions

- **v1 target:** 500 weekly-active teams (≈2,500 weekly-active users at 5 users/team avg)
- **Peak concurrency:** 250 concurrent users at peak (US-east working hours)
- **10x scale (v2 horizon):** 5,000 weekly-active teams — same architecture stretches; Postgres single instance is the first bottleneck
- **Derivation:** PRD success metric target is 500 weekly-active teams at month-3 post-launch (PRD § Success Metrics row 1). Scale-assumptions sized to the target, NOT to aspirational 10x — see `references/scale-assumptions.md` for the over-engineering guard rail

### Reliability

- **Uptime target:** 99.5% (≈3.6h/month allowed downtime; SLA-less at v1 — appropriate for a launch product)
- **RTO (recovery time objective):** 30 min — backed by Supabase PITR + Vercel's instant rollback
- **RPO (recovery point objective):** 5 min — Supabase WAL-archived continuously

### Accessibility

WCAG 2.1 AA inherited from step 4 audit. Step 6 (design-system) + step 7 (prototype-v2) carried the floor through to render-time; no new accessibility decisions at the system-design layer.
```

### `## Evaluation`

The principal-engineer assessment table — honest, not aspirational:

```markdown
## Evaluation

| Dimension | Assessment | Concern Level |
|---|---|---|
| Simplicity | Modular monolith on managed services; 4 vendor integrations; ~3 person-month build estimate | Low |
| Reliability | Single Postgres instance (no read replica) — recovery via Supabase PITR with 30min RTO; SPOF accepted at v1 scale | Medium |
| Scalability | Stretches to 5K weekly-active teams without architecture change; Postgres single instance is first bottleneck at ~10K WAU | Medium |
| Operability | Vercel + Supabase + Sentry + Stripe all have managed dashboards; no on-call rotation at v1 (founder + 1 covers business hours) | Low |
| Security | Threat model in security.md; auth via Supabase; PII tier identified; STRIDE-lite mitigations documented; no penetration test at v1 (deferred to pre-Series-A) | Medium |
```

Concern levels are HONEST. A v1 with a single Postgres and no HA is `Reliability: Medium` (single point of failure, accepted at v1 scale) — not `Low` (which would imply HA setup that doesn't exist) and not `High` (we have PITR + 30min RTO, the risk is bounded).

### `## Alternatives Considered`

Per major choice (stack, DB, deployment, auth, payment), 1-2 alternatives rejected with one-line reason. The catch for resume-driven design.

```markdown
## Alternatives Considered

### Stack: chose Next.js + Postgres + Prisma
- **Rejected: Remix + Postgres + Drizzle.** Remix's nested-route model is a better fit for nested resources but adds learning cost for the EM persona who's used to App Router. Drizzle's edge-runtime story is stronger but Prisma's mature migrations matter more at v1.
- **Rejected: T3 stack (Next + tRPC + Prisma).** tRPC's type-safety is appealing but commits us to TypeScript on both ends; we want the option to add a Python ML service later (US-23 — sentiment analysis backlog).

### Database: chose Postgres (Supabase managed)
- **Rejected: MySQL (PlanetScale).** PlanetScale's branching workflow is appealing for migration ergonomics but MySQL lacks Postgres's `jsonb` and partial-index features that simplify our analytics-event ingestion (US-12).
- **Rejected: SQLite (Turso edge).** Turso's edge-replication is interesting but SQLite's concurrent-write limit becomes an issue at our projected concurrent-user count (250 peak).

### Auth: chose Supabase Auth
- **Rejected: Clerk.** Better DX, slicker UI components, but $25/mo vs Supabase's bundled. Cost-benefit doesn't justify until we need enterprise SSO (post-v1).
- **Rejected: NextAuth.js.** No managed posture; the self-hosted maintenance overhead at v1 isn't worth the cost savings.
```

### `## Trade-off Triggers & Open Decisions`

H2 with two H3 children. The triggers-digest sub-section is the 30-second-scan; the Open Decisions table is the audit-trail receipt.

```markdown
## Trade-off Triggers & Open Decisions

### Trade-off Triggers (digest)

Recommendation changes if:
- **Stripe Checkout conversion drops below 70%** — switch to Stripe Elements for in-context flow (Open #4)
- **First 10 EU customers materialise pre-public-launch** — fra1 region work moves before US-east hardening (Open #3)
- **Postgres CPU breaches 70% sustained for 1h** — read-replica work pulls forward to v1.1 (Open #2)
- **First enterprise prospect raises RLS in security review** — RLS migration becomes P0 (Open #6)

### Open Decisions (table)

| # | Question | Deciding signal | Closes by |
|---|---|---|---|
| 1 | Background job queue (BullMQ vs SQS vs Inngest) | Actual job volume in week 2 of beta | Pre-launch + 2 weeks |
| 2 | Read replica posture | Postgres CPU >70% sustained for 1h | Triggers v1.1 architecture review |
| 3 | Region expansion to fra1 | First 10 EU customers signed | Quarterly check post-launch |
| 4 | Stripe Checkout vs Elements | Checkout conversion <70% in first 4 weeks of beta | 4 weeks post closed-beta |
| 5 | Migration to Drizzle | Prisma migration ergonomics painpoint reaches 1d/sprint | Quarterly review |
| 6 | Postgres RLS migration | First enterprise prospect raises RLS in security review OR SOC 2 audit recommends it | Pre-Series-A |
```

The digest sub-section is the load-bearing scan; pick the 3-4 highest-stakes triggers from the Open table (NOT every row — just the ones most likely to fire in the first 3 months or that have the biggest blast radius). The table is the audit-trail receipt where every deferred decision gets a row with a deciding signal.

**Locked decisions are intentionally NOT a sub-section.** The bridge-skill's PRD-decision extraction lands NATURALLY in:
- `## Stack` (auth provider, framework, language all named once and committed)
- `## Integrations` (payment processor, transactional email all named once and committed)
- `## Deployment` (host platform, CI/CD all named once and committed)
- `## Non-Functional` (uptime target, perf budgets all named once and committed)

Re-tabling these as a separate Locked sub-section duplicates the running commitment; a Source-column on running prose entries (`Source: PRD § Technical Considerations`) carries the same audit trail at lower meta-table cost. Spec 026 Phase B judge-feedback (2026-05-16) against the anthill source confirmed the running-prose pattern; the Locked-table sub-section was cut as part of the post-task-18 calibration. See `## Voice & anti-patterns` below for the meta-commentary discipline.

Open decisions without a deciding signal are red flags — the design owes the founder a trigger.

## JSON-to-HTML refinement deferred

Spec 026 ships `architecture.json` only. The anthill source (`anthill-principal-engineer § Step 5c`) emits a sibling `<slug>-architecture.html` via `.anthill/scripts/render-architecture-diagram.mjs` (Cocoon-AI-derived, MIT). The MCP port defers the HTML rendering to a post-spec-026 refinement:

- **Why deferred:** spec 026 V5 accepts "one of `architecture.json` / `architecture.html`" — JSON-only satisfies acceptance. Vendoring the renderer (or replicating it) is a 1-2 day chore that doesn't unlock new pipeline capability (the JSON is the load-bearing artifact; HTML is presentation).
- **What the refinement would do:** vendor `render-architecture-diagram.mjs` into `.claude/skills/product/scripts/`, schema-validate the JSON against the vendored schema, emit HTML next to the JSON at submit time, surface the file path so the parent can ping the user with the rendered diagram (Layer 3 visual checkpoint).
- **Forward-compat:** the JSON shape this template emits is a strict subset of anthill's schema (`title`, `summary_prose`, `components[]`, `arrows[]`, optional `zones[]`, optional `summary_cards[]`). The renderer when vendored will accept these graphs unchanged.

## Voice & anti-patterns

- **Justify every choice against the PRD, not abstract preference.** "Postgres because we need transactional consistency on the task-completion event (US-07, US-12)" beats "Postgres because it's reliable".
- **Resist over-engineering.** v1 with 5 microservices that talk over Kafka is wrong unless the PRD's scale assumptions demand it. The PRD's primary success metric is the rigor anchor.
- **Alternatives considered with reason.** Per major choice, 1-2 rejected with one-line reason. Catches resume-driven design AND surfaces tradeoffs for review.
- **Concern levels are HONEST.** A single-instance Postgres with PITR is `Reliability: Medium`, not aspirational `Low`.
- **Name uncertainty explicitly.** "Background job queue: TBD between BullMQ and SQS — decide when actual job volume is known" is honest; pretending the queue choice is locked when it isn't is the regression mode.
- **PRD `US-NN` IDs cross-reference the design.** Every entity, API, integration cites the user story that needs it. This makes step 13 (prototype-v3) PRD-coverage scoring honest.
- **No meta-commentary about the document's own discipline.** Do NOT write a section like `## Notes on this design's audit-trail discipline` or `## How to read this document` explaining how `Source` columns / `US-NN` refs / deciding-signal columns work. The discipline IS the artifact (Source columns + US-NN refs + deciding-signal columns); a section *about* the discipline is meta noise. A reader who needs the audit trail explained doesn't need the explanation — they need the audit trail to work. Spec 026 Phase B judge-feedback (2026-05-16) flagged this anti-pattern in the first dogfood run; the rule exists to prevent recurrence.
