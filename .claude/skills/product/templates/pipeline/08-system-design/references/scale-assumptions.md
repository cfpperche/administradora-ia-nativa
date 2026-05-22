# Scale assumptions — derive from PRD, resist aspirational design

How to size the `## Non-Functional` section in `system-design.md`. PRD's success-metric target is the anchor for v1 concurrency + perf budgets; 10x is the horizon for "does this architecture stretch", NOT the design target.

## The derivation chain (PRD → non-functional)

The PRD's `## Success Metrics` section names ONE primary metric with a target value and measurement window (PRD discipline). That target is the rigor anchor for v1 scale:

```
PRD success metric (example):
- Primary: 500 weekly-active teams at month-3 post-launch
- Supporting (observability): >40% week-1 activation, 12 minutes saved per EM/day
```

From the primary target, derive:

1. **Weekly-active users (WAU).** If teams average N users, WAU = teams × N. For the example: 500 teams × 5 users/team = 2,500 WAU.
2. **Daily-active users (DAU).** DAU is typically 30-60% of WAU for B2B SaaS (higher for consumer; lower for occasional-use tools). Conservative: 40%. For the example: 1,000 DAU.
3. **Peak concurrency.** Peak hour typically holds 20-40% of DAU concurrently (B2B SaaS: workday clustering). Conservative: 25%. For the example: 250 concurrent users at peak.
4. **Requests per second (RPS) at peak.** A typical B2B SaaS user generates 5-15 requests per session-minute (varies by product surface; keyboard-heavy product = more). Conservative: 8 req/min/user. For 250 concurrent: 250 × 8 / 60 ≈ 33 RPS sustained; 3-5x burst → ~150 RPS peak.

Concrete numbers ground the design. "Postgres scales fine" is meaningless; "Postgres handles 150 RPS sustained on a Supabase Small instance (4 vCPU, 8GB RAM); next bottleneck at ~600 RPS" is a load-bearing design statement.

## v1 target vs 10x horizon

The PRD's primary metric is the **v1 target** — the architecture must comfortably serve it with headroom (2-3x). The **10x horizon** is a sanity check — does the architecture stretch to 10x without a fundamental rewrite, or does it dead-end?

| Lens | Anchor | Design intent |
|---|---|---|
| v1 target | PRD primary metric × 2-3x headroom | The architecture must serve this *comfortably* (sub-target latency, no scaling-emergency operational mode) |
| 10x horizon | PRD primary × 10 | Does the architecture *stretch* without rewrite? What's the first bottleneck at 10x? |

A v1 architecture with **no 10x stretch** is a v1 architecture with a v2 rewrite already on the roadmap — fine if scoped honestly ("v1 is a 12-month proof; v2 architecture decided after market signal"), bad if pretended ("we'll scale Postgres single instance to infinity").

A v1 architecture **designed for the 10x horizon as the target** is **resume-driven design** — paying the complexity cost of multi-region, multi-service, multi-DB upfront when the PRD's primary target needs none of it.

## Example: the derivation in practice

```markdown
## Non-Functional (system-design.md § 8 — derivation appendix)

### Performance budgets

- **p95 latency:** 200ms for kanban-view GET endpoint (US-07 success: triage in <5min — single-action <300ms = budget allows perceptible-but-instant feel)
- **p99 latency:** 800ms ceiling
- **Cold load:** <1s
- **Time-to-interactive:** <2s

### Scale assumptions (derived from PRD § Success Metrics row 1)

| Lens | Value | Source |
|---|---|---|
| v1 target | 500 weekly-active teams | PRD § Success Metrics primary |
| v1 WAU | 2,500 (500 × 5 users/team avg) | PRD § Target Users multi-user-per-team |
| v1 DAU | 1,000 (40% of WAU; B2B conservative) | derivation heuristic |
| v1 peak concurrency | 250 (25% of DAU) | derivation heuristic |
| v1 peak RPS | ~33 sustained, ~150 burst | derivation heuristic (8 req/min/user × 250, 4x burst) |
| 10x horizon | 5,000 weekly-active teams | sanity check |
| 10x peak RPS | ~330 sustained, ~1,500 burst | first-bottleneck analysis below |

### First bottleneck at 10x (5,000 teams, ~1,500 burst RPS)

Postgres single instance (Supabase Small: 4 vCPU, 8GB RAM) is the first bottleneck. Symptoms:
- CPU saturation on the kanban-view query (most-frequent read)
- p95 latency creeps from 200ms → 500ms+

Mitigation at 10x (v2 architecture work):
- Upgrade to Supabase Medium (8 vCPU, 32GB) — buys us 2-3x; ~1-week migration
- Add read replica for kanban-view; ~2-3 weeks migration; introduces read-after-write window
- Cache layer (Upstash Redis) for kanban-view; ~1-week implementation; cache invalidation complexity

v1 explicitly does NOT pre-build these. The deciding signal that triggers the work is documented in `## Decisions Locked & Open § Open` row 2.

### Reliability target

- **Uptime:** 99.5% (3.6h/month allowed downtime; SLA-less at v1)
- **RTO:** 30 min — Supabase PITR + Vercel rollback
- **RPO:** 5 min — Supabase WAL-archived continuously
- **DR drill:** annually (post-launch ops capacity)
```

The table makes the derivation auditable. A reviewer can question any heuristic value (e.g., "is 40% DAU/WAU realistic for an EM-persona triage tool?") and the agent can revise without rewriting the section.

## Heuristic ratios (calibrated for the spec 026 default product class)

These are starting points; the agent should adjust for product-class signal from the brief:

| Ratio | B2B SaaS (default) | Consumer | Dev tool / CLI |
|---|---|---|---|
| DAU / WAU | 40% | 60-70% | 20-30% (CLI = occasional) |
| Peak concurrent / DAU | 25% | 30-40% | 10-15% |
| Req/min/user (sustained) | 8 | 15-30 | 2-5 (CLI batch) |
| Burst multiplier | 4x | 2-3x | 6-10x (CLI: scripted bursts) |

When the brief is silent or ambiguous, default to B2B SaaS. Document the chosen calibration in the derivation table so a reviewer can challenge it.

## Over-engineering anti-pattern catalog

The regression mode this reference exists to prevent. Each anti-pattern names the design choice + the rigor that catches it:

### 1. The microservices-for-v1 trap

**Symptom:** 5 services with REST/gRPC contracts between them; deployment requires CI orchestration across services; observability needs distributed tracing.

**Rigor check:** PRD primary metric × concurrency derivation = ? If sustained RPS < 500, a modular monolith is sufficient. Microservices' overhead (service boundary maintenance, contract testing, deployment coordination) eats more dev velocity than it returns until ~5K WAU.

**The honest design:** monolith with module boundaries. If the founder argues "we need microservices for scale", the design's job is to name the *trigger* for service decomposition (e.g., "carve out ML service when US-23 sentiment analysis lands and the inference latency exceeds the web request budget").

### 2. The multi-region preemptive build

**Symptom:** v1 has fra1 + iad1 + apac edge regions; data replication strategy invented; cross-region consistency model debated.

**Rigor check:** PRD's target market is geographically what? If the founder is solo-Brazilian and first customers will be Brazilian, fra1 is theatre.

**The honest design:** one region. Document the trigger for region expansion ("EU customer #10 triggers fra1 design work"). If GDPR data-residency is a customer-specific contract requirement, that's the trigger — but it's a customer-driven trigger, not a launch-day requirement.

### 3. The Kafka-for-event-driven trap

**Symptom:** v1 has Kafka or Redpanda for "the analytics events"; an event-sourcing posture is discussed; CQRS is on the architecture diagram.

**Rigor check:** event volume × consumer count? If both are <50K events/day and 1 consumer (analytics rollup), Kafka is theatre. Postgres LISTEN/NOTIFY or a simple jobs table covers v1.

**The honest design:** `analytics_events` table in Postgres; a daily rollup cron. Kafka lands when the consumer count crosses ~5 OR the daily volume crosses ~500K events.

### 4. The HA Postgres / read replica preemptive build

**Symptom:** v1 has primary + 2 read replicas with read-routing middleware; failover drills are part of the launch checklist.

**Rigor check:** PRD's uptime target? 99.5% is achievable on a single managed Postgres + PITR. 99.95% needs HA. The PRD almost never demands 99.95% at v1.

**The honest design:** single Supabase managed Postgres with PITR + Vercel's instant rollback. Read replica lands when CPU > 70% sustained for 1h+ (the deciding signal).

### 5. The premature observability stack

**Symptom:** v1 has Prometheus + Grafana + Loki + Tempo + Jaeger; OpenTelemetry instrumented everywhere; dashboards built for KPIs that don't exist.

**Rigor check:** what's the operational team size? Founder-only or founder + 1? At that size, Sentry (errors) + Vercel Analytics (vitals) + Logtail (logs) + custom rollups in a `metrics_daily` table is the entire stack.

**The honest design:** managed observability primitives + a single `metrics_daily` table for product metrics. Prometheus/Grafana lands when operational team crosses 3 (someone has to own the alerting on-call rotation).

### 6. The "we'll need GraphQL" trap

**Symptom:** v1 ships with Apollo Server + GraphQL schema; the frontend's components fetch via GraphQL queries; Hasura sits behind it for codegen.

**Rigor check:** what's the consumer count? Web + maybe mobile + maybe third-party API? If consumer count is 1-2 and the surface is CRUD-ish, REST is simpler — less infra, less learning curve, easier debugging.

**The honest design:** REST for v1 with explicit endpoint table (`## APIs` section in system-design.md). GraphQL lands when the consumer count crosses 3 OR the over-fetching cost is measurable.

## The "what triggers the upgrade" discipline

For every over-engineering pattern v1 deliberately avoids, the design names the **trigger** that closes the deferral. This is what `## Decisions Locked & Open § Open` carries. The discipline:

- ❌ "Microservices: deferred to v2"
- ✅ "Microservices: deferred to v2; triggered when ML inference latency exceeds the web request budget OR when team grows past 5 engineers"
- ❌ "Read replica: deferred"
- ✅ "Read replica: deferred; triggered when Postgres CPU >70% sustained for 1h OR p95 latency exceeds 500ms for 24h"
- ❌ "Distributed tracing: not at v1"
- ✅ "Distributed tracing: not at v1; triggered when first multi-service split happens (likely US-23 ML service) OR when ops team crosses 3"

The deciding signal makes the deferral honest — the design isn't saying "never", it's saying "later, with a measurable trigger". A reviewer can challenge the trigger if it's too lax or too strict.

## Cross-references

- **PRD's primary success metric** is the v1 target anchor — see `08-prd/references/prd-format.md § Success metrics`
- **Step 10 cost-estimate** reads the scale assumptions from this section to model infra cost. Per-RPS cost-modeling depends on accurate concurrency derivation
- **Step 11 roadmap** consumes the "deciding signals" from `## Decisions Locked & Open § Open` — each open decision typically lands as a roadmap milestone with the trigger as the entry criterion
