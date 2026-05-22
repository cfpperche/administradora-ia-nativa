# Step 07 — Sitemap-IA schema

## Output file

`<out>/docs/sitemap.yaml`

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `sitemap.yaml` | 2 KB | below this the sitemap is too sparse — likely missed categories |

A uniform 200 KB catastrophe cap applies per `.claude/rules/artifact-budgets.md`.

## Binding schema

The YAML output binds to `.claude/skills/product/references/sitemap-schema.md`. That doc is the canonical schema; this file is the per-step calibration.

## Required top-level keys

| Key | Type | Required | Notes |
|---|---|---|---|
| `slug` | string | yes | kebab-case product slug, matches `<out>/` basename |
| `platform` | string | yes | `web` or `mobile` |
| `stack` | string | yes | `next` or `expo` |
| `required_categories` | list[string] | yes | `[marketing, auth, primary, admin, error]` (verbatim) |
| `routes` | list[object] | yes | per-route entries |
| `deferred_categories` | list[object] | optional | only present if a required category is genuinely out of v1 scope |

## Per-category minimums (HARD)

| Category | Min routes | Required path patterns |
|---|---|---|
| `marketing` | 1 | `/` (landing) |
| `auth` | 3 | `login`, `signup`, `password.*reset` |
| `primary` | 1 | varies (killer-flow) |
| `admin` | 2 | `/settings/*` + one other (team / billing / integrations / audit-log) |
| `error` | 1 | `/not-found` |

Below minimum + not deferred = orchestrator BLOCKS step + re-dispatch.

## Per-route schema

```yaml
- path: <string starting with />
  category: <one of marketing|auth|primary|admin|error>
  states: [<at least 1 state name>]
  covers_us: [<US-NN ref>]
  components: [<PascalCase component name>]
```

## Validation rules (parent-side enforcement)

See `.claude/skills/product/references/sitemap-schema.md` § "Validation rules" for the full 10-rule list. Highlights:

1. Schema parses as valid YAML
2. All 5 required_categories accounted (≥1 route OR deferred with reason)
3. Per-category minimums met (or deferred)
4. Every route has all 5 required fields
5. No duplicate paths
6. covers_us refs are valid US-NN from PRD
7. Every P0/P1 US-NN in PRD has ≥1 covering route (warning if orphan)

## Cross-references

- `prompt.md` — full sub-agent brief
- `.claude/skills/product/references/sitemap-schema.md` — canonical binding schema
- `.claude/skills/product/references/delegation-briefs.md` § Step 07
