---
paths:
  - ".claude/validators/run.sh"
  - "tsconfig.json"
  - "**/tsconfig.json"
  - "**/package.json"
---

# Typecheck advisory

The post-edit validator (`.claude/validators/run.sh`) detects typecheck primitive availability per JS branch and emits a non-blocking `typecheck-advisory:` line on stderr when the fork has neither — instead of hard-failing the pipeline by trying `<runner> run typecheck` against a missing script. Mirrors the lint-validator's manifest-as-intent posture: declared = run, missing = advise, neither = skip. Surfaced via the shrnk-mono dogfood where every sub-agent edit was hard-failing the validator on a fresh fork without typecheck infrastructure.

## What fires per branch

Each JS branch picks the typecheck step based on what's available in the fork. State dispatch:

**bun / pnpm:**
- `tsconfig.json` exists → `<runner> tsc --noEmit` (direct invocation, no script needed)
- `package.json` `.scripts.typecheck` exists → `<runner> [run] typecheck`
- Neither → omit typecheck step entirely + emit `typecheck-advisory:` to stderr

**npm:**
- `package.json` `.scripts.typecheck` exists → `npm run typecheck`
- Otherwise → omit + advisory

The npm branch is conservative — no tsconfig fast-path. `npx tsc --noEmit` would be the bun-equivalent, but `npx` is a separate binary from `npm` and adds resolution surprises (test fixtures shimming `npm` don't catch `npx`; npx-can-prompt-to-install behaviour). Forks on npm declare `typecheck` in scripts; bun/pnpm get the tsconfig fast-path because their runners invoke `node_modules/.bin/tsc` directly.

Python branch (`pytest && mypy . || true`) already uses the `|| true` advisory pattern for mypy specifically — typecheck-advisory does NOT extend to Python (mypy missing is silently tolerated). Go and rust branches use toolchain-bundled typecheckers (`go vet`, `cargo clippy`) that are always available with the language install.

## Advisory format

Single-line stderr message, manager-flavored:

```
typecheck-advisory: no tsconfig.json or 'typecheck' script in package.json — typecheck step skipped (add a tsconfig.json or declare `bun run typecheck` to enable)
typecheck-advisory: no tsconfig.json or 'typecheck' script in package.json — typecheck step skipped (add a tsconfig.json or declare `pnpm typecheck` to enable)
typecheck-advisory: no 'typecheck' script in package.json — typecheck step skipped (declare `npm run typecheck` to enable)
```

Same shape as `lint-advisory:` and `tdd-advisory:` — surfaces via `post-edit-validate.sh`'s separated stderr capture into the agent's next-turn context. Never blocks; never increments delegation loop budget; advisory is the WHOLE signal.

## Non-goals

- **No env-var to silence.** The advisory IS the signal; suppressing it defeats the discipline. To stop the advisory, declare a tsconfig.json or typecheck script — that's the documented path.
- **No tsconfig-content validation.** The validator checks file presence only; an empty `{}` tsconfig.json counts as "yes, has typecheck primitive" even though `tsc --noEmit` may emit no errors and no work happened. Acceptable: signal of intent is "I have a tsconfig", not "I have a meaningful tsconfig". Forks responsible for content.
- **No npm tsconfig fast-path.** Documented choice in `validator/run.sh` comments. If a fork on npm wants direct tsc invocation, they declare a `typecheck` script in package.json (`"typecheck": "tsc --noEmit"`). One indirection; explicit.
- **No multi-stack typecheck.** Single-stack v1 — first lockfile match wins (same constraint as the lint extension). Multi-stack monorepo typecheck inherits when the monorepo-stack-detect walk extends to the validator (currently mcp-recipes-hint only).

## Gotchas

- **`has_typecheck_script` requires `jq` AND a parseable `package.json`.** A malformed package.json silently fails the script check (jq returns non-zero) → falls through to advisory. Acceptable: the fork has bigger problems than typecheck if package.json doesn't parse.
- **`scripts.typecheck` value is NOT validated.** The validator checks for the script's presence, not its content. `"typecheck": "true"` (no-op) passes; the validator runs it and exits 0. Mirrors the lint-validator's "manifest-as-intent" decision — content validation is project responsibility.
- **Multiple advisories can fire in same run.** A fork with biome declared+missing AND no typecheck primitive emits BOTH `lint-advisory:` and `typecheck-advisory:` on stderr — each on its own line. Agent reads both via post-edit-validate.sh's stderr surface.
- **Bun/pnpm fast-path uses `bunx`-equivalent semantics.** `bun tsc --noEmit` and `pnpm tsc --noEmit` invoke the local `node_modules/.bin/tsc`. If TypeScript isn't installed locally (no `typescript` in devDependencies), the inner `tsc` invocation fails and `ok=false`. That's correct behavior — declaring a tsconfig.json without TypeScript installed IS a project setup error worth blocking on. Different from the typecheck-advisory case (where the fork hasn't declared intent at all).
- **Conservative npm path means npm forks need a `typecheck` script even when they have a tsconfig.json.** Surprise for npm-stack forks — by symmetry with bun/pnpm, a tsconfig.json should suffice. Documented in `validator/run.sh` comments. If npm dogfood surfaces this as routine pain, revisit (probably via `npm exec --no -- tsc --noEmit` after sandboxing the npx-prompt risk).
- **No yarn branch.** The validator's stack detector doesn't recognize `yarn.lock` — yarn forks fall through to the npm branch (which `package.json` triggers). Same typecheck advisory applies; the runner naming in the advisory is npm-flavored even on yarn forks. Add `yarn.lock` detection separately when a real yarn fork lands.
