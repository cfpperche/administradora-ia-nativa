---
mode: synthesis
delegable: true
delegation_hint: "produce sitemap.yaml — full screen inventory + IA decomposition — schema-bound to references/sitemap-schema.md's required_categories enforcement (marketing, auth, primary, admin, error); load-bearing root-cause fix for atlas under-cover bug; YAML output 2-5 KB; orchestrator parses + BLOCKS step if required_categories not satisfied without deferred_categories declaration; fully delegable from PRD + functional-spec + concept-brief"
---

# Step 07 — Sitemap-IA (full screen inventory; root-cause fix for atlas under-cover)

**Goal:** produce `<out>/docs/sitemap.yaml` — the canonical screen inventory for the product. This file is **load-bearing** for Step 15 atlas (drives N screen-writer dispatches) AND **enforced mechanically** by the orchestrator (parses YAML, BLOCKS step if `required_categories` not satisfied without `deferred_categories` declaration).

Per spec 045 Decision 5 + 13 (ported from spec 032): sitemap-IA is its own step (was inline in v2 Step 02 direction-writer). The dedicated step + schema enforcement is the **load-bearing mechanical fix** for the Pass-E silent-undercover bug — Steward shipped without `auth` / `admin` deeper / `error` beyond 404 because no step enforced category coverage.

**Mode:** `synthesis` with `delegable: true`. Sub-agent reads PRD + functional-spec + concept-brief and produces YAML output mechanically.

## Output

| File | Role | Floor | Ceiling |
|---|---|---|---|
| `<out>/docs/sitemap.yaml` | full screen inventory, schema-enforced category coverage | 2 KB | 5 KB |

## Inputs (read first)

- `<out>/docs/prd/v1.md` § User stories — every P0/P1 US-NN MUST map to ≥1 route (P2 may defer)
- `<out>/docs/functional-spec.md` § Pages & Surfaces — surface inventory hints
- `<out>/docs/concept-brief.md` — product class (B2C / B2B / internal-tool / etc) drives which `required_categories` apply
- `.claude/skills/product/references/sitemap-schema.md` — the binding schema (read this CLOSELY; orchestrator enforces it post-return)

## YAML shape (schema-bound)

```yaml
slug: <kebab-case product slug>
platform: web | mobile
stack: next | expo

required_categories:
  - marketing
  - auth
  - primary
  - admin
  - error

# Optional — only when a required category is genuinely out of v1 scope
deferred_categories:
  - name: marketing
    reason: <1-2 sentences explaining why category is out of v1 scope>

routes:
  - path: /
    category: marketing
    chrome: chromeless          # root marketing — flat app/page.tsx (no shared shell)
    states: [default]
    covers_us: [US-01, US-02]
    components: [Hero, FeatureGrid, PricingPreview, FooterCTA]

  - path: /pricing
    category: marketing
    chrome: marketing           # under app/(marketing)/layout.tsx — header + footer
    states: [default]
    covers_us: [US-02]
    components: [PricingTable, FAQAccordion, FooterCTA]

  - path: /auth/login
    category: auth
    chrome: auth                # under app/(auth)/layout.tsx — logo + lang switcher
    states: [default, loading, error]
    covers_us: [US-03]
    components: [LoginForm, OAuthButtons]

  - path: /auth/signup
    category: auth
    states: [default, loading, error]
    covers_us: [US-03, US-04]
    components: [SignupForm, OAuthButtons]

  - path: /auth/password-reset
    category: auth
    states: [default, loading, success, error]
    covers_us: [US-05]
    components: [PasswordResetForm]

  # ... primary routes (killer flow + other user-facing surfaces) ...
  # Example with optional primary_metric — route surfaces a hero-level value:
  - path: /caixa
    category: primary
    chrome: app                 # under app/(app)/layout.tsx — authenticated shell
    states: [default, loading, empty, error]
    covers_us: [US-07]
    components: [MetricTile, CashSessionForm, RecentTransactions]
    primary_metric: Caixa atual
  # Example with deferred_states — empty has no legitimate degenerate case:
  - path: /faturamento
    category: primary
    chrome: app
    states: [default, loading, error]
    deferred_states:
      - name: empty
        reason: founder always has ≥1 invoice in v1; no legitimate zero-state
    covers_us: [US-12]
    components: [InvoiceTable, FilterBar]
    primary_metric: MRR atual
  # Example with chrome diverging from category default (Vetro pattern):
  # PRD coverage says category: primary; runtime chrome is the booking shell
  # (clinic-branded white-label, NOT the authenticated app shell).
  - path: /[clinicSlug]/agendar
    category: primary
    chrome: booking             # under app/(booking)/layout.tsx — minimal white-label
    states: [default, loading, success, error]
    covers_us: [US-21]
    components: [ClinicHeader, AppointmentTypePicker, DatePicker, TimeSlots, ConfirmDialog]

  - path: /settings/account
    category: admin
    chrome: app                 # admin inherits app shell
    states: [default, saving, error]
    covers_us: [US-09]
    components: [AccountForm]

  - path: /settings/team
    category: admin
    chrome: app
    states: [default, loading, empty, error]
    covers_us: [US-10]
    components: [TeamMembersTable, InviteForm]

  - path: /not-found
    category: error
    states: [default]
    covers_us: []
    components: [NotFoundMessage, BackToHomeCTA]
```

## Per-category minimums (HARD — orchestrator enforces)

| Category | Min routes | Required path patterns (fuzzy keyword match) |
|---|---|---|
| `marketing` | 1 | `/` (landing) |
| `auth` | 3 | `login`, `signup`, `password.*reset` |
| `primary` | 1 | (varies — killer-flow routes from PRD) |
| `admin` | 2 | `/settings/*` + at least one other admin surface (team-management, billing, integrations, audit-log) |
| `error` | 1 | `/not-found` (Next.js `app/not-found.tsx`) |

If a `required_categories` member has fewer routes than its minimum AND is NOT in `deferred_categories`, orchestrator BLOCKS Step 07 and re-dispatches with augmented brief naming the gap.

## `deferred_categories` escape clause

Genuinely-out-of-v1 categories MUST be deferred explicitly with a reason:

```yaml
deferred_categories:
  - name: marketing
    reason: internal-tool only, no public marketing surface in v1; revisit at v2 if open-sourcing
  - name: admin
    reason: single-tenant v1, no admin role distinct from primary user; multi-tenant deferred to v2
```

Each entry MUST have `reason` (non-empty, 1-2 sentences). The deferral becomes an explicit decision in `<out>/docs/REPORT.md § Deferred Categories` so the founder sees the conscious tradeoff.

## Per-route field requirements

| Field | Type | Required | Notes |
|---|---|---|---|
| `path` | string | yes | starts with `/`; Next.js dynamic syntax `[id]`; Expo static |
| `category` | string | yes | one of `marketing | auth | primary | admin | error` |
| `states` | list[string] | yes | ≥1; primary routes MUST include `default`, `loading`, `empty`, `error` (orchestrator auto-augments if missing) |
| `covers_us` | list[string] | yes | ≥0; entries match `^US-\d+$`; orphan US-NN refs (not in PRD) emit warning |
| `components` | list[string] | yes | ≥1; PascalCase; screen-writer treats as materialization targets |
| `primary_metric` | string | **optional** | Short label (≤ 32 chars) naming the route's load-bearing operational value (e.g. `Caixa atual`, `Estoque crítico`, `Agendamentos hoje`, `MRR atual`). EMIT when the route surfaces a number/state the user comes to check at-a-glance; OMIT when there is none (marketing, settings, auth). Drives MetricTile/hero render in Step 15 (per `sitemap-schema.md § Optional fields`). |
| `deferred_states` | list[{name, reason}] | optional | Use when a declared state has no legitimate degenerate case (e.g. `empty` on a route where the founder always has ≥1 row). Each entry needs `reason` (1 sentence). Auto-augmented `default+loading+empty+error` on primary routes can ONLY be dropped via this. |
| `chrome` | enum: `app \| marketing \| booking \| auth \| chromeless` | **optional but RECOMMENDED on every route** | Drives the route-group placement at Step 15 (`app/(<chrome>)/<path>/page.tsx`) — orthogonal to `category`. EMIT explicitly on every route (avoids relying on the default-inference fallback which can't decide booking-vs-app correctly). See `sitemap-schema.md § chrome — orthogonal to category` for the enum + default-inference table. |

## Constraints

- 2-5 KB hard ceiling.
- Valid YAML (parses with `yaml.safe_load`).
- All required_categories accounted for (≥1 route OR deferred with reason).
- Per-category minimums met (or deferred).
- Every route has all 5 required fields.
- No duplicate paths.
- All `covers_us` entries are valid US-NN refs from PRD (warning if orphan).
- Every PRD US-NN with priority P0 OR P1 appears in ≥1 route's `covers_us` (warning if orphan US-NN).
- Top of file comment: `# Sitemap schema per spec 045 Decision 13 — enforced by orchestrator after Step 07 returns`.

## Validation flow (orchestrator side — informational; not in sub-agent's hands)

```
1. parse docs/sitemap.yaml
2. for category in [marketing, auth, primary, admin, error]:
     routes_in_cat = filter routes by category
     min = {marketing:1, auth:3, primary:1, admin:2, error:1}[category]
     if len(routes_in_cat) < min:
       if category in deferred_categories AND has reason:
         continue  # explicitly deferred
       else:
         BLOCK Step 07; re-dispatch with augmented brief naming the gap
3. emit REPORT.md § Sitemap Coverage with per-category counts + deferrals
```

## Why this step is load-bearing

Pass-E (spec 036 dogfood 2026-05-18) demonstrated the bug: Steward's sitemap.yaml (produced inline in old Step 02) listed only 5 routes — zero auth, only `/settings/policy` for admin, only `/not-found` for error. The atlas declared "PRD coverage 14/15" — but the silent gap was the ENTIRE auth category. Spec 045's promotion of sitemap-IA to own step + schema enforcement makes that bug structurally impossible.

## Cross-references

- `.claude/skills/product/references/sitemap-schema.md` — binding schema (full validation rules)
- `.claude/skills/product/references/delegation-briefs.md` § Step 07 — full sub-agent brief
- `.claude/skills/product/references/pipeline-coverage.md` § Step 07 — size targets + lightening
- `docs/specs/045-prototype-skill-pipeline-realign/spec.md` § Acceptance B.scenario "sitemap-IA enforces categories"
- `docs/specs/032-pipeline-industry-alignment/spec.md` § Decisions 5 + 13 — industry rationale
