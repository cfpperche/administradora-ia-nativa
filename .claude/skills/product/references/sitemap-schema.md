# sitemap.yaml schema — v3 (load-bearing for Step 07)

The `<out>/docs/sitemap.yaml` file produced by Step 07 (sitemap-IA) drives the Step 15a screen-atlas's § Screens Index + § Sitemap Coverage Cross-Check, and — via the atlas — the route inventory the SDD foundation child creates route-group directories for. **The schema is enforced mechanically by the orchestrator — Step 07 is BLOCKED if `required_categories` not satisfied without explicit deferral.** This is the load-bearing root-cause fix for the Pass-E silent-undercover bug per spec 045 (ported from spec 032 Decision 5 + 13).

## Top-level shape

```yaml
slug: <kebab-case product slug, matches <out>/ basename>
platform: web | mobile
stack: next | expo
required_categories:
  - marketing
  - auth
  - primary
  - admin
  - error
deferred_categories:                # optional — only present when a required category is genuinely out of v1 scope
  - name: marketing
    reason: internal-tool only — no public marketing surface in v1; revisit at v2
routes:
  - path: /
    category: marketing
    states: [default]
    covers_us: ["US-01", "US-02"]
    components: [Hero, FeatureGrid, FooterCTA]
  - path: /auth/login
    category: auth
    states: [default, loading, error]
    covers_us: ["US-03"]
    components: [LoginForm, OAuthButtons]
  - path: /auth/signup
    category: auth
    states: [default, loading, error]
    covers_us: ["US-03", "US-04"]
    components: [SignupForm, OAuthButtons]
  - path: /auth/password-reset
    category: auth
    states: [default, loading, success, error]
    covers_us: ["US-05"]
    components: [PasswordResetForm]
  # ... primary, admin, error categories follow
```

## Required fields per route

| Field | Type | Required | Constraint |
|---|---|---|---|
| `path` | string | yes | starts with `/`; matches stack convention (Next.js `/foo/[id]` for dynamic; Expo `/foo` for static) |
| `category` | string | yes | one of `marketing | auth | primary | admin | error` |
| `states` | list of strings | yes | at least 1; primary routes MUST include `default`, `loading`, `empty`, `error` (orchestrator auto-augments if missing) |
| `covers_us` | list of strings | yes | at least 1; each entry is a US-NN ref from `docs/prd/v1.md` |
| `components` | list of strings | yes | at least 1; PascalCase; screen-writer treats as materialization targets |

## Optional fields per route

| Field | Type | Constraint | When to emit |
|---|---|---|---|
| `primary_metric` | string | Short human-readable label (≤ 32 chars) naming the route's load-bearing operational value | When the route surfaces a hero-level operational number/state the user comes to check — e.g. cashier total, critical-stock count, today's bookings, MRR. The hi-fi mood screen (Step 15b) and the SDD-built screen render it as a hero-level MetricTile, NOT a small corner badge. |
| `deferred_states` | list of `{name, reason}` | Mirrors `deferred_categories` shape (top-level). Each entry must have non-empty `reason` (1 sentence). | When `states[]` declared a state the data model has no degenerate case for — e.g. a billing route declares `empty` but the founder always has at least one invoice. Sub-agent flips the state from `states` to `deferred_states` and the screen-writer skips its render branch. Auto-augmentation for primary routes (forcing `default+loading+empty+error`) still applies, so deferral is the only way to legitimately drop one. |
| `chrome` | enum: `app \| marketing \| booking \| auth \| chromeless` | Drives the Next.js route-group placement (`app/(<chrome>)/<path>/page.tsx`) and which `layout.tsx` the page sits under — the SDD foundation child creates one route-group dir + thin `layout.tsx` shell per distinct `chrome` value | **Emit explicitly when chrome diverges from `category` defaults** (e.g. a tutor-public route filed `category: primary` for PRD coverage but rendered as chromeless white-label `chrome: booking`). New sitemaps SHOULD always emit `chrome` to make the routing decision authoritative at sitemap-write time; legacy sitemaps without `chrome` get default-inference (see table below). The atlas § Screens Index surfaces `chrome` per route; the SDD foundation child consumes it — see `references/sdd-handoff.md § Child #1`. |

### `chrome` — orthogonal to `category` (spec 055)

`category` is the **PRD-coverage semantic** (which surface satisfies which user-story; required schema enforcement for the 5 required_categories). `chrome` is the **runtime layout inheritance** (which `app/(<group>)/layout.tsx` the page sits under in Next.js).

These are intentionally orthogonal: dogfood-2 (Vetro) had `/[clinicSlug]/agendar` + `/[clinicSlug]/portal` as `category: primary` (covered the booking-flow US-NN entries; satisfied schema) but the runtime chrome was the booking white-label shell (`app/(booking)/layout.tsx`). Conflating them forced the sub-agent screen-writer to either (a) violate PRD coverage by filing as `booking` non-required-category, or (b) violate route-group placement by writing under `app/(app)/`. Splitting the concerns resolves the false choice.

#### Enum closure (v1)

`{app, marketing, booking, auth, chromeless}` — closed for v1. A future product needing `embed`, `print`, or other chrome would bump a spec; the closure is deliberate to prevent enum-sprawl.

| Chrome value | Layout file (Next.js) | Use case |
|---|---|---|
| `app` | `app/(app)/layout.tsx` | shared sidebar + topbar shell for authenticated product surfaces (primary + admin routes typically inherit this) |
| `marketing` | `app/(marketing)/layout.tsx` | public marketing nav (header + footer); written when ≥1 route has `chrome: marketing` |
| `booking` | `app/(booking)/layout.tsx` | minimal/no-chrome public funnel — booking, white-label tutor portals, etc; clinic-branded or product-branded but NOT the authenticated app shell |
| `auth` | `app/(auth)/layout.tsx` | consistent auth shell (logo, language switcher, "back to marketing" link); written when ≥1 route has `chrome: auth` |
| `chromeless` | (no layout file) | flat `app/<path>/page.tsx` with no shared shell (root marketing `/`, error pages, etc) |

#### Default-inference fallback (back-compat ONLY)

For sitemaps without explicit `chrome:` field on each route, the orchestrator applies this default-inference table at Step 15 atlas time:

| `category` | inferred `chrome` |
|---|---|
| `primary` | `app` |
| `admin` | `app` |
| `marketing` | `marketing` |
| `auth` | `auth` |
| `error` | `chromeless` |

**This fallback exists for back-compat with sitemaps generated before spec 055.** New sitemaps SHOULD emit `chrome` explicitly on every route — the default-inference table is mechanical and cannot decide booking-vs-app correctly without help (Vetro evidence: 2 routes filed `primary` were actually `booking`, default-inference would have placed them wrong). The Step 07 prompt instructs sub-agents to always emit `chrome`; the fallback is for resuming/iterating legacy sitemaps.

#### Example with explicit `chrome` divergence

```yaml
# Tutor-public booking route — covers a primary US-NN for PRD purposes but
# rendered as the clinic-branded white-label booking shell, NOT the app shell.
- path: /[clinicSlug]/agendar
  category: primary
  chrome: booking
  states: [default, loading, success, error]
  covers_us: [US-21]
  components: [ClinicHeader, AppointmentTypePicker, DatePicker, TimeSlots, ConfirmDialog]
  primary_metric: Próximo horário disponível

- path: /[clinicSlug]/portal
  category: primary
  chrome: booking
  states: [default, loading, empty, error]
  covers_us: [US-22]
  components: [ClinicHeader, AppointmentList, BookingCTA]
```

### `primary_metric` semantic notes

- The value is a **label**, not a value source — sub-agent decides the value (from sitemap `components[]` + route's data-model context). Spec 053 ships this as a string-label v1; if downstream sub-agents prove ambiguous ("which number is that?"), a v2 may richen to `{ label, source, format }`.
- Optional: routes without an operational hero value (e.g. marketing landing, settings, auth screens) leave it unset.
- One per route at most. Routes with multiple metrics list the most-glanced one — secondary metrics render as supporting MetricTile siblings or rows in a table, sub-agent's call.

### `deferred_states` example

```yaml
- path: /faturamento
  category: primary
  states: [default, loading, error]
  deferred_states:
    - name: empty
      reason: founder always has ≥1 invoice in v1; no legitimate zero-state at launch
  covers_us: [US-12]
  components: [InvoiceTable, FilterBar]
  primary_metric: MRR atual
```

## Required categories enforcement (the load-bearing mechanical fix)

`required_categories: [marketing, auth, primary, admin, error]` — orchestrator parses sitemap.yaml after Step 07 returns and enforces:

**Every category in `required_categories` MUST have ≥1 route OR be listed in top-level `deferred_categories: [{name, reason}]` with a non-empty reason string.**

### Per-category minimums (within required categories)

Beyond presence (≥1 route), schema enforces minimums per category:

| Category | Minimum routes | Required path patterns |
|---|---|---|
| `marketing` | 1 | `/` (landing) at minimum |
| `auth` | 3 | `/auth/login`, `/auth/signup`, `/auth/password-reset` (or equivalent paths — fuzzy match on `login`, `signup`, `password.*reset` keywords) |
| `primary` | 1 | (varies — application-specific killer-flow routes) |
| `admin` | 2 | At minimum `/settings/*` (org or account settings) + one other admin surface (team-management, billing, integrations, audit-log) |
| `error` | 1 | `/not-found` (Next.js convention `app/not-found.tsx`) at minimum |

If a category is in `required_categories` AND has fewer routes than its minimum AND has no explicit deferral, Step 07 is BLOCKED with error message naming the gap (e.g. "auth category has only 1 route (signup) but minimum is 3 — add login + password-reset, OR add to deferred_categories with reason").

### `deferred_categories` escape clause

Genuinely-out-of-v1 categories can be deferred per category:

```yaml
deferred_categories:
  - name: marketing
    reason: internal-tool only, no public marketing surface; revisit at v2 if open-sourcing
  - name: admin
    reason: single-tenant v1, no admin role distinct from primary user; multi-tenant deferred to v2
```

Each deferred entry MUST have `reason` (non-empty, 1-2 sentences). Orchestrator emits this as `## Deferred Categories` block in REPORT.md's coverage section so the founder sees the conscious tradeoff.

## Validation rules (post-Step-07 return — orchestrator-enforced, BLOCKS step on failure)

The skill runs these checks before allowing Step 07 to be marked complete:

1. **Schema parses** — valid YAML, top-level keys match shape
2. **`slug` matches** — `slug` field equals the slug derived from `--out` basename
3. **`platform` + `stack` match `--stack` flag** — sanity check
4. **5 categories accounted for** — every entry in `required_categories` has either ≥minimum routes OR is in `deferred_categories` with reason
5. **Per-route fields complete** — every route has all 5 required fields with valid types
6. **`category` values valid** — every route's `category` ∈ `[marketing, auth, primary, admin, error]`
7. **Path uniqueness** — no duplicate `path` values
8. **Component name validity** — `components` entries match `^[A-Z][A-Za-z0-9]*$`
9. **`covers_us` refs are valid US-NN** — each entry matches `^US-\d+$` and corresponds to an actual US-NN in `docs/prd/v1.md` (parse PRD's user-story table; emit warning if covers_us references an US-NN not in PRD)
10. **No PRD US-NN orphan** — every US-NN with priority P0 or P1 in PRD MUST appear in some route's `covers_us` (P2 may be deferred). Orphan US-NN = warning, not BLOCK (founder may have intentionally deferred a screen).

## Parent-side validation pseudocode

```python
# Reference implementation orchestrator follows after Step 07 sub-agent returns
sitemap = yaml.safe_load(open(f"{out}/docs/sitemap.yaml"))
deferred = {d['name']: d['reason'] for d in sitemap.get('deferred_categories', [])}
errors = []

for required in ['marketing', 'auth', 'primary', 'admin', 'error']:
    routes_in_cat = [r for r in sitemap['routes'] if r['category'] == required]
    min_count = {'marketing': 1, 'auth': 3, 'primary': 1, 'admin': 2, 'error': 1}[required]
    if len(routes_in_cat) < min_count:
        if required in deferred:
            continue  # explicitly deferred with reason
        else:
            errors.append(f"{required} has {len(routes_in_cat)} routes, minimum {min_count} — add routes OR add to deferred_categories with reason")

if errors:
    # BLOCK Step 07; re-dispatch with augmented brief naming each missing category
    re_dispatch_with(brief + "\n\nADDITIONAL CONSTRAINT: " + " | ".join(errors))
```

## Why this schema (and not just freeform)

The 5-category requirement forces the agent to think about ALL surfaces (not just the "happy path screens" a founder mentions). Real apps have marketing pages, auth flows, primary feature surfaces, admin/settings, AND error states; omitting any of these is the most common prototype gap.

**Pass-E demonstrated this concretely** (spec 036 dogfood at `/tmp/dogfood-v2/`): Steward shipped without `auth` (the sitemap.yaml had ZERO auth routes), without `admin` beyond `/settings/policy` (no billing/team-management/org-settings), and without `error` beyond `/not-found`. Atlas declared "PRD coverage 14/15" — but the silent gap was the ENTIRE auth category. Spec 045's enforcement makes that bug structurally impossible.

Industry validation: Eleken / Slickplan / Raw.Studio / Nielsen Norman Group all enforce this category set in their sitemap deliverables. Spec 032 research (48 sources, 2026-05-17) treated sitemap-IA as own step + schema enforcement as the root-cause fix for the "atlas under-cover" symptom.

## Cross-references

- `delegation-briefs.md` § Step 07 — sub-agent brief
- `pipeline-coverage.md` § Step 07 — size targets
- `state-machine.md` § Failure handling — orchestrator retry behavior
- `SKILL.md` § Phase 2 — Specification, Step 07 acceptance check
- `docs/specs/045-prototype-skill-pipeline-realign/spec.md` § Acceptance criteria B.scenario "sitemap-IA enforces categories"
