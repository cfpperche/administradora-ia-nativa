# Security section — threat model lens + posture floor

How to write `security.md`. Five required sub-sections (Threat Model · Auth · Data Classification · Secrets · Regulated Aspects), the lenses for each, and the engineering-vs-compliance boundary with step 12.

## Why `security.md` is a sibling, not a section

Step 9's design output is two-file: `system-design.md` (the design itself) plus `security.md` (the security treatment). Three reasons for the split:

1. **Stable contract for step 12 (legal-posture).** The legal step cross-references security.md as the engineering-readable summary of the product's security floor. A stable file path is easier to cite than a section anchor in a larger document.
2. **Section-anchor brittleness.** Inside `system-design.md`, security would be one of 11 H2 sections; a future template edit could rename, split, or reorder it. A sibling file is immune to that drift.
3. **Reviewer attention.** Security warrants careful read; bundling it inside a 20+ KB design document hides it. A separate file forces the reviewer to open it explicitly.

`security.md` is the **engineering-readable** summary — what the threat model is, what auth/authz the system implements, what data classifications and retention windows apply, where secrets live, what regulated aspects are in scope. Step 12 (legal-posture) is the **legal/compliance** treatment of the same surface — full DPA, sub-processor list, customer-facing privacy notice, etc.

## The 5 required sub-sections

The schema enforces presence; depth is the agent's responsibility.

### `## Threat Model`

Use **STRIDE-lite** (Spoofing / Tampering / Repudiation / Information disclosure / Denial of service / Elevation of privilege) OR the **OWASP Top 10** lens — whichever fits the product. For each row, surface the **specific risk for THIS product** + the mitigation posture at v1 (or `accepted` with rationale if v1 deliberately defers).

STRIDE-lite template:

```markdown
## Threat Model

STRIDE-lite analysis. v1 surface: web app + REST API + managed Postgres + Stripe + Supabase Auth + Resend transactional email.

| Threat | Surface | Risk for this product | Mitigation at v1 | Status |
|---|---|---|---|---|
| Spoofing | Auth endpoints | Attacker impersonates a user via stolen session cookie | HTTP-only + Secure + SameSite=Lax cookies; session rotation on privilege elevation | Mitigated |
| Spoofing | Email confirmation | Attacker registers with a victim's email and intercepts confirmation | Confirmation-link single-use + 1h TTL; signing key rotated quarterly | Mitigated |
| Tampering | Task ownership | Member of one org mutates tasks in another org via guessed IDs | App-layer authz middleware checks `org_id` membership on every request; Postgres RLS deferred to v2 | Mitigated (app-layer) |
| Repudiation | Bulk delete | User claims they didn't bulk-delete tasks; no audit trail | `audit_events` table records who/when for delete + bulk-action ops; 90-day retention | Mitigated |
| Information disclosure | Direct DB access | Compromised support-team credentials read all customer data | Read-only support role + audit log on every query; PII columns encrypted at rest | Mitigated |
| Information disclosure | API enumeration | Attacker enumerates task IDs via incrementing integers | UUIDs (not sequential IDs); rate-limit per-IP at 60/min | Mitigated |
| Denial of service | Bulk endpoint | Attacker spams /api/tasks/bulk with max-50 payloads to exhaust DB | Per-user rate-limit: 60 bulk req/hr; query timeout 30s; Vercel's platform-level DDoS protection | Accepted (v1 traffic too small to warrant dedicated WAF) |
| Elevation of privilege | Membership upgrade | Member injects themselves as admin via direct API call | Authz middleware blocks role mutations except by owner; audit_events tracks every role change | Mitigated |
```

Anti-pattern: generic threat-model boilerplate ("we use HTTPS"). The Risk column must be **specific to this product**. A reviewer should be able to read each row and identify the actual attack scenario this v1 is defending against.

If the product is small enough that STRIDE-lite is overkill (micro-product CLI helper with no persisted state), use the OWASP Top 10 lens instead — pick the 3-5 relevant categories and treat each:

```markdown
| OWASP category | Risk for this product | Mitigation at v1 | Status |
|---|---|---|---|
| A01 Broken Access Control | n/a — no multi-user surface | n/a | Accepted |
| A02 Cryptographic Failures | API keys land in CLI config (`~/.config/mytool/config.json`) | Permissions 0600 on config; documented in README | Mitigated |
| A03 Injection | User-supplied path traversal in `--config <path>` flag | Canonicalise and reject `..` segments + abs-paths outside home | Mitigated |
| ... | ... | ... | ... |
```

### `## Auth`

Auth model + authz model + session lifecycle + MFA posture:

```markdown
## Auth

### Auth model

- **Primary:** Email + password via Supabase Auth.
- **Social:** Google OAuth (US-01 — `/signup` carries the "Continue with Google" option).
- **Magic link:** Deferred to v2 (US-31 backlog — Magic-link sign-in).

### Authz model

Role-based, org-scoped. Three roles in `Membership.role`:

- **owner** — billing access, member management, full org data read+write
- **admin** — member management, full org data read+write (no billing)
- **member** — own-task write, all-task read within org

Authz enforced at the API middleware layer (`requireRole('admin')` decorator). Postgres Row-Level Security deferred to v2 — application-layer authz is faster to ship and easier to reason about at v1 scale.

### Session lifecycle

- **Cookie:** HTTP-only, Secure, SameSite=Lax, 7-day TTL with sliding refresh on activity
- **Rotation:** New session-id on every login + on every role change
- **Logout:** Server-side session invalidation (Supabase Auth's revoke endpoint); client-side cookie clearance
- **Inactive timeout:** 30 days of no activity → session expires, user re-prompted for password
- **Concurrent sessions:** Allowed (no single-session enforcement at v1)

### MFA posture

**Deferred to v2.** Founder + early customers don't have enterprise SSO + MFA requirements yet (PRD § Open Questions resolved by founder · 2026-05-16). When the first enterprise customer asks (or US-31 backlog "Enterprise SSO" is pulled), MFA via TOTP lands.
```

### `## Data Classification`

What's collected, how it's classified, retention, deletion:

```markdown
## Data Classification

### Classification tiers

| Tier | What | Examples in this product |
|---|---|---|
| Public | Marketable / non-confidential | Org names (when org opts into public directory — US-29 backlog, not v1) |
| Internal | Operational | Aggregate analytics, error logs, audit_events |
| PII | Personally identifiable | `User.email`, `User.name`, OAuth tokens (Supabase Auth manages) |
| Regulated | Domain-specific compliance | None at v1 — no PHI, no PCI cardholder data (Stripe holds; we hold `stripe_customer_id` only) |

### Retention

| Data | Retention window | Deletion posture |
|---|---|---|
| `User` (after account deletion) | 30 days (LGPD recovery window) | Soft-delete + scheduled hard-delete cron |
| `Org` (after deletion) | 30 days | Soft-delete + scheduled hard-delete cron |
| `Task`, `Project` | Indefinite while org active | Hard-delete on user-initiated delete (no soft-delete) |
| `analytics_events` (raw) | 90 days | Rolled up daily into `metrics_daily`; raw events purged after 90 days |
| `metrics_daily` (rollup) | Indefinite | Aggregate; no PII |
| `audit_events` | 90 days | Hard-delete after 90 days (compliance requirement: SOC 2 needs 90 days minimum) |
| `sessions` | 7 days (TTL) | Auto-expire |

### Deletion posture

User-initiated account deletion:
1. Immediate: `User.deleted_at` set, all sessions revoked, all PII columns nulled-out except `id` (FK integrity)
2. Day 30: scheduled cron purges the `User` row entirely + cascades to `Memberships` (hard-delete)
3. Anonymisation alternative: `analytics_events.user_id` set to NULL (event remains for aggregate; identity is erased)

GDPR/LGPD posture: data subject access requests (DSAR) handled manually at v1 — founder + 1 covers the volume. Automated DSAR is deferred (US-30 backlog). Privacy notice generation deferred to step 12.
```

### `## Secrets`

Where secrets live, rotation, exposure surface:

```markdown
## Secrets

### Storage

- **Production secrets:** Vercel encrypted env vars (separate scopes for production + preview + development)
- **Local dev secrets:** `.env.local` (gitignored; never committed). `.env.example` documents the variable names (no values)
- **Database connection string:** Supabase managed — pooled connection URL via Vercel env var
- **Stripe webhook signing secret:** Vercel env var; webhook endpoint validates signature on every event
- **OAuth client secrets (Google):** Vercel env var

### No HashiCorp Vault / cloud KMS at v1

Vercel's env-var surface + Supabase's managed secrets are sufficient for v1's surface area (~10 secrets). Vault adds operational complexity disproportionate to v1 scale; revisit at v2 when secret count crosses ~30 or when an enterprise customer requires BYOK.

### Rotation posture

- **Manual on credential leak** (gitleaks pre-commit hook catches local mistakes; CI catches anything that slips through)
- **Quarterly review** — every 90 days, founder rotates: Supabase service-role key, Stripe restricted API key, Resend API key, Google OAuth client secret
- **Automatic rotation:** Supabase Auth's JWT signing key rotates every 60 days (Supabase manages); session tokens auto-invalidate

### Exposure surface

- **Build artifacts (Vercel deployment bundles):** server-side env vars NOT leaked to client bundle (Next.js `NEXT_PUBLIC_*` discipline enforced by build-time linter)
- **Client bundle:** only `NEXT_PUBLIC_SUPABASE_ANON_KEY` + `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` (both public-safe by design)
- **Logs:** sensitive headers (`Authorization`, `Cookie`) redacted in Sentry + Logtail integrations; explicit denylist
- **Stack traces:** error messages stripped of env-var values before client emission

### Sensitive secret rotation drill

Documented in internal runbook (post-launch; not v1 surface). Drill cadence: annually.
```

### `## Regulated Aspects`

Flag domain regulation if any applies. Cross-reference step 12.

```markdown
## Regulated Aspects

### Not in scope at v1

- **HIPAA** — no health data collected
- **PCI DSS** — Stripe holds cardholder data; we hold `stripe_customer_id` and `stripe_subscription_id` only (PCI SAQ A scope, minimal compliance burden)
- **SOC 2 Type 2** — deferred to enterprise-tier launch (post-v1); current customer base doesn't require it. Pre-work (audit_events table, 90-day log retention) is in place
- **HIPAA BAA** — n/a
- **GxP / FedRAMP / FERPA** — out of product scope

### In scope at v1

- **LGPD (Brazil)** — applicable due to founder being Brazilian + likely first customers being Brazilian. Posture:
  - Data subject access requests (DSAR): manual handling, 15-day response window per LGPD article 19
  - Right to deletion: 30-day soft-delete + cascade hard-delete (above § Data Classification)
  - Consent: granular consent for analytics + marketing collected at signup; revocable
  - Data processing agreement (DPA): templated; available on request (step 12 produces canonical version)
- **GDPR (EU)** — applicable when EU customers materialise (deferred per § Decisions Open #3 in system-design.md)
- **AI governance (OECD AI Principles, EU AI Act draft)** — applicable IF AI features land (US-23 sentiment analysis backlog). Not v1. Pre-emptive design note: when AI lands, surface user-visible disclosure + opt-out

### Cross-reference

Full compliance treatment (DPA, sub-processor list, customer-facing privacy notice, AI-specific governance posture, terms of service) is the canonical output of **step 12 (legal-posture)**. This `security.md` is the engineering-readable summary of the surface step 12 elaborates.
```

## Depth ladder

The 3 KB Layer-1 floor is anchored to the 5 sub-sections at honest depth.

- **Micro-product CLI helper** — security.md typically lands 3-4 KB. Threat model is OWASP top-10 lens with 3-5 relevant rows (path traversal, secrets in config, dependency-confusion). Auth section may be one paragraph ("no multi-user surface; binary auths via OS-level perms on config file"). Regulated aspects almost always empty.
- **Mobile app** — 4-6 KB. Threat model adds mobile-specific rows (jailbreak / root detection? deep-link spoofing? app-store binary tampering?). Auth section covers mobile session lifecycle (refresh token rotation, biometric unlock). Regulated aspects may include COPPA if kid-targeted.
- **Developer tool / API-first** — 5-8 KB. Threat model emphasises API-specific (rate-limit bypass, replay, SSRF via user-supplied URLs). Auth section covers API-key vs session-token tradeoffs.
- **SMB SaaS (spec 026 default)** — 5-8 KB. Full STRIDE-lite + standard auth/authz treatment. LGPD + GDPR posture documented.
- **Venture-scale / multi-persona** — 8-12 KB. Per-persona authz rules expanded. Multi-region data residency. SOC 2 pre-work. Possibly HIPAA BAA discussion if health-adjacent.

A `security.md` under 3 KB is almost certainly a bullet-skeleton that punted on the threat model — typical regression mode is "STRIDE: ✓ HTTPS, ✓ Auth, ✓ Validated input" without naming the specific risks for THIS product. The 3 KB floor catches that.

## Voice & anti-patterns

- **Threat-model rows are SPECIFIC to this product.** Generic boilerplate ("we use HTTPS") is the regression mode. Each row names the actual attack scenario.
- **Concern Levels in security are HONEST.** A v1 without WAF + with rate-limiting at the platform layer (Vercel) is `Denial of service: Accepted (v1 traffic too small to warrant dedicated WAF)` — not aspirationally `Mitigated`.
- **Cross-reference step 12 for compliance.** This file is the engineering summary; the full legal posture lives in step 12.
- **Deferral with a deciding signal.** "MFA: deferred to v2" alone is weak; "MFA: deferred to v2 (lands when first enterprise customer asks or US-31 backlog Enterprise SSO is pulled)" is honest.
- **Cite PRD user stories per auth/authz rule.** "Role-based authz: owner / admin / member (US-15 multi-role org)" cross-references the requirement; bare "role-based authz" doesn't anchor to anything.
