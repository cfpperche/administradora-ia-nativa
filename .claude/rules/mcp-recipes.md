---
paths:
  - ".mcp.json"
  - ".mcp.json.example"
  - ".claude/hooks/mcp-recipes-hint.sh"
  - ".claude/.browser-state/**"
---

# MCP recipes

A curated, opt-in set of `.mcp.json` server blocks for four mature external MCPs that complement the runtime-introspect capacity. The recipes are documentation + a copy-paste example file at repo root; a `SessionStart` companion hook detects the fork's stack and emits a one-block hint naming the applicable recipes when matches exist. Pure recommendation capacity — no auto-installs, no audit log, no blocks.

## How it works

Three artifacts plus one hook:

- **`.claude/rules/mcp-recipes.md`** (this file) — authoritative per-MCP reference.
- **`.mcp.json.example`** at repo root — copy-paste-ready file with all four blocks commented out by leading `//` markers. Workflow: `cp .mcp.json.example .mcp.json`, then remove `//` lines on the blocks you want active.
- **`.claude/hooks/mcp-recipes-hint.sh`** (`SessionStart`) — runs the signal table below and emits a single `=== mcp-recipes ===` block listing applicable recipes when ≥1 signal fires. Silent when no signals match (Agent0 base case). Honors `CLAUDE_SKIP_MCP_RECIPES=1` to suppress regardless.

The fork chooses what to enable. Recipes recommend; the developer activates with one `cp` + uncomment.

## Stack-detector signal table

The hint hook fires when any signal matches. Multiple signals can fire; the suggestion list is the deduplicated union.

| Stack | Signals (any one is sufficient) | Suggested recipes |
| --- | --- | --- |
| Next.js | `next.config.{js,ts,mjs,cjs}` exists, OR `package.json` has `next` in `dependencies` or `devDependencies` | `next-devtools-mcp` + `playwright-mcp` |
| Browser (non-Next) | `package.json` has any of `react` / `vue` / `svelte` / `vite` / `astro` in deps, AND Next signal is absent | `playwright-mcp` + `chrome-devtools-mcp` |
| DB | Any of `schema.prisma`, `drizzle.config.{js,ts,mjs}`, `alembic.ini`, `database/migrations/`, `db/migrate/` exists, OR `.env.example` has a `^DATABASE_URL=` line | `dbhub` |
| Laravel | `artisan` executable file at root (canonical), OR `composer.json` declares `laravel/framework` in `require` / `require-dev` | `laravel-boost-mcp` + `playwright-mcp` |

The list is deliberately small. Same lesson as the runtime-introspect detector allowlist and the supply-chain manager table: ship a strict shape, extend on real-world signal.

### Walk scope

Detection runs at `$CLAUDE_PROJECT_DIR` root AND one level deep into common monorepo workspace dirs. Default set: `apps packages services workspaces` (covers pnpm workspaces, Turborepo, Nx apps, Yarn workspaces — the dominant JS/TS monorepo conventions). For each workspace dir that exists, the hook walks its direct children (depth-1) and runs the same signal table at each. Workspace-detected signals carry a path prefix (e.g. `apps/web/next.config.js`) so the agent can see which workspace fired; root-detected signals stay bare (e.g. `next.config.js`). Recipe set is the deduplicated union across all walked paths.

Override via `CLAUDE_MCP_RECIPES_WORKSPACE_DIRS` (space-separated, **replaces** the default — does not merge):

| Value | Effect |
| --- | --- |
| Unset | Default set: `apps packages services workspaces` |
| `"modules subprojects"` | Walks `modules/*` and `subprojects/*` only; default set NOT scanned |
| `""` (set, empty) | Walk disabled entirely; root-only detection |

The walk is strictly depth-1: `apps/web/next.config.js` fires; `apps/web/nested/deep/next.config.js` does NOT (forks with deeper nesting point the env var directly at the workspace root). Cargo `crates/` is omitted from the default set in v1; revisit if a real-world Cargo monorepo with JS/Python sub-projects surfaces.

## Recipes

### Playwright MCP

**Source:** [github.com/microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp) (Microsoft, 32k★)

**What it provides:** Browser-driving introspection for the agent — navigation, click/fill/type, network mock + inspect, accessibility snapshots, screenshots, trace/video recording. Cross-browser (Chromium / Firefox / WebKit). The dominant choice for E2E and frontend agentic work.

**`.mcp.json` block:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

**Install:** `npx @playwright/mcp@latest` is invoked by Claude Code as needed. Playwright manages its own browser binaries on first run (Chromium / Firefox / WebKit / Chrome / Edge).

**When to enable:** any fork doing browser/frontend/E2E work. Also paired with Next.js (see Next.js DevTools MCP below).

**Runtime requirements:** none beyond Node.js + npm.

**Security:** Playwright can navigate anywhere; the MCP inherits that surface. See upstream's [README § security considerations](https://github.com/microsoft/playwright-mcp#security) before opening it to untrusted prompts.

---

### Chrome DevTools MCP

**Source:** [github.com/ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) (Google, public preview since Sept 2025)

**What it provides:** Debugging-oriented browser introspection — listing network requests (with bodies), console logs preserving the last three navigations, Lighthouse audits, V8 heap snapshots, Core Web Vitals tracing (LCP / INP / CLS). Drives an existing Chrome session rather than automating from scratch.

**`.mcp.json` block:**
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    }
  }
}
```

**Install:** `npx -y chrome-devtools-mcp@latest`.

**When to enable:** debugging an already-running browser session (network, console, perf). Complements Playwright — Playwright drives, DevTools observes.

**Runtime requirements:** **Google Chrome or Chrome for Testing must be installed on the host.** Other Chromium variants are unsupported. Headless CI environments without Chrome will fail at MCP startup.

**Security:** Chrome DevTools Protocol (CDP) is a debugging interface; treat the MCP's exposure to agent prompts the same as opening DevTools in an untrusted session. See upstream's [README](https://github.com/ChromeDevTools/chrome-devtools-mcp#readme) for connection policies.

**Positioning (debug-only complement to Playwright):** Chrome DevTools MCP is the right tool when you need low-level observation of a running browser session — network bodies, console logs, Lighthouse audits, heap snapshots. It is NOT the default for authenticated content access. For routine auth-gated reads, use Playwright MCP's `headed → save → reuse` pattern documented in `## Authenticated workflow` below. When pairing the two, the recommended setup is a **dedicated `--user-data-dir` Chrome profile** containing only the accounts you need — not `--autoConnect`, which attaches to every open tab in your main Chrome and exposes Gmail, banking, and other active sessions to the agent. `--autoConnect` is opt-in for forks that consciously accept that surface; it should NOT appear in a default `.mcp.json` block. See `## Authenticated workflow` for the per-host state directory convention (`.claude/.browser-state/<host>.json`) that applies to both Playwright state files and Chrome profile directories.

---

### DBHub

**Source:** [github.com/bytebase/dbhub](https://github.com/bytebase/dbhub) (Bytebase)

**What it provides:** Multi-engine database introspection gateway. Supports PostgreSQL / MySQL / SQL Server / MariaDB / SQLite. Tools: `search_objects` for progressive schema exploration (tables, columns, indexes, stored procedures), `execute_sql` with transaction support and readonly-by-default safety, custom reusable queries via `dbhub.toml`. Replaces the now-archived per-engine official MCPs.

**`.mcp.json` block** (inferred — upstream README does not pin one shape; verify against [dbhub.ai/installation](https://dbhub.ai/installation) if upstream evolves):

```json
{
  "mcpServers": {
    "dbhub": {
      "command": "npx",
      "args": ["@bytebase/dbhub@latest"],
      "env": {
        "DATABASE_URL": "postgres://user:password@localhost:5432/dbname?sslmode=disable"
      }
    }
  }
}
```

**Install:** `npx @bytebase/dbhub@latest`. Docker image also available (`bytebase/dbhub`) for containerised deployments — use when the agent host can't run Node directly.

**When to enable:** any fork with a real database (Prisma / Drizzle / Alembic / Rails migrations / a `DATABASE_URL` in `.env.example`).

**Runtime requirements:** `DATABASE_URL` env var with a valid DSN. The connection string controls which engine is targeted (driver prefix). Readonly mode is the default; write-mode is opt-in via config.

**Security:** readonly default is the safety floor — keep it. Connection strings ARE secrets; do NOT commit a populated `DATABASE_URL` in `.mcp.json` to git. Use `.env` files + harness env-var injection, or set the variable in your shell before `claude` launches. See upstream's security section before enabling write mode.

---

### Laravel Boost MCP

**Source:** [github.com/laravel/boost](https://github.com/laravel/boost) (Laravel official, MIT)

**What it provides:** Laravel-specific framework introspection — Application Info (PHP & Laravel versions, DB engine, ecosystem packages with versions, Eloquent models); Browser Logs (errors + logs from the browser); Database Connections / Schema / Query (inspect connections, read schema, execute queries); Last Error / Read Log Entries (Laravel application log inspection); Search Docs (semantic search across 17,000+ pieces of Laravel documentation). Closest equivalent to next-devtools-mcp for Laravel projects.

**`.mcp.json` block:**

```json
{
  "mcpServers": {
    "laravel-boost": {
      "command": "php",
      "args": ["artisan", "boost:mcp"]
    }
  }
}
```

**Install:** Two steps inside the Laravel project:

```bash
composer require laravel/boost --dev
php artisan boost:install
```

The first installs the package; the second wires up the `boost:mcp` artisan command. Alternative one-shot registration with Claude Code: `claude mcp add -s local -t stdio laravel-boost php artisan boost:mcp`.

**When to enable:** any Laravel fork (Laravel 10.x / 11.x / 12.x / 13.x). The agent gets ergonomic access to Eloquent models, DB schema, app logs, and Laravel docs without grepping the codebase manually.

**Runtime requirements:**

- PHP installed on the host (the command uses the `php` binary).
- Laravel project directory with `artisan` available — the MCP runs `php artisan boost:mcp` inside that working dir.
- `composer require laravel/boost --dev` ran successfully (so the artisan command is registered).

**Security:** local-only (introspects the Laravel project, no remote endpoints). Tools include `Database Query` which can execute arbitrary SQL — treat this MCP's exposure to agent prompts the same as giving the agent a Laravel tinker session. Boost can be configured to disable specific tools; see upstream README for the toolset config.

---

### Next.js DevTools MCP

**Source:** [github.com/vercel/next-devtools-mcp](https://github.com/vercel/next-devtools-mcp) (Vercel, MIT)

**What it provides:** Next.js-specific framework introspection — real-time build/runtime errors, route listing, component metadata, server-action introspection, dev-server log file via `get_logs`, `browser_eval` over Playwright. The closest equivalent to zydrex's `laravel-boost` MCP in the JS/TS world.

**`.mcp.json` block:**
```json
{
  "mcpServers": {
    "next-devtools": {
      "command": "npx",
      "args": ["-y", "next-devtools-mcp@latest"]
    }
  }
}
```

**Install:** `npx -y next-devtools-mcp@latest`.

**When to enable:** any Next.js fork (Next 16+ supported). Pairs naturally with Playwright for E2E.

**Runtime requirements:**
- Node.js v20.19 LTS or later.
- A running `next dev` server on the host. The MCP auto-discovers Next dev servers and connects via `/_next/mcp`. Without a running dev server, the MCP fires but most tools return empty.

**Security:** local-only (the MCP introspects the dev server, no remote endpoints). See upstream README for the dev-only positioning — do not run against production builds.

## Hint output shape

When ≥1 stack signal matches and `CLAUDE_SKIP_MCP_RECIPES` is unset, the SessionStart hook emits a single block:

```
=== mcp-recipes ===
Stack signals detected: next.config.js apps/web/next.config.js apps/api/schema.prisma
Suggested MCP recipes (copy + uncomment from .mcp.json.example):
  - next-devtools-mcp  Next.js framework introspection (build errors, routes, server actions)
  - playwright-mcp     browser observation (DOM, console, network, screenshots)
  - dbhub              multi-engine DB schema + safe query exec
See .claude/rules/mcp-recipes.md for full recipes (install commands, runtime requirements, security).
=== end mcp-recipes ===
```

Signal labels are bare for root-detected files (`next.config.js`) and workspace-prefixed for files found under the depth-1 walk (`apps/web/next.config.js`, `apps/api/schema.prisma`). When no signals match, the block is NOT emitted (silent).

## Escape hatch

- **`CLAUDE_SKIP_MCP_RECIPES=1`** — suppresses the hint block regardless of stack signals. Use in throwaway scratch sessions or when the suggestions are noise.

That's the only env var for this capacity. No `BLOCK` / `ADVISE_ON_EDIT` variants — pure recommendation has nothing to gate.

## Activation workflow

For a fork:

1. Start a session in the fork's repo. The mcp-recipes hint surfaces in additional-context if stack signals match.
2. `cp .mcp.json.example .mcp.json` (or merge into existing `.mcp.json`).
3. Open `.mcp.json` and remove `//` lines on the recipe blocks you want active.
4. For DBHub: also set `DATABASE_URL` in your shell or `.env` (never commit it).
5. For Chrome DevTools: confirm Chrome is installed (`which google-chrome` or `which chrome`).
6. Restart the Claude Code session — `.mcp.json` is loaded at session start.

## Authenticated workflow

Many sites require a logged-in session to return meaningful content. `WebFetch` hits HTTP 401, 402, 403, or 999 (LinkedIn-style anti-bot), or the page silently redirects to a login wall. This section documents the standard workflow for reading auth-gated content using Playwright MCP, the signaling convention that bridges the human login step, and the X/Twitter shortcut that avoids the full auth path for a common case.

### Prerequisites — activating Playwright MCP

The Playwright MCP recipe ships as `.mcp.json.example` — opt-in by design. Forks that have never enabled it will see the agent emit `BROWSER_AUTH_REQUIRED: <host>` correctly, but the suggested next step ("open Playwright MCP in headed mode") cannot run until the MCP is wired up. One-time setup per fork:

```bash
cp .mcp.json.example .mcp.json
# edit .mcp.json — remove the leading `//` markers from the `playwright` block
# (keep the other blocks commented unless you need them)
# then RESTART the Claude Code session — MCPs are loaded at session start, not hot-reloaded
```

After restart, the agent has `mcp__playwright__*` tools available and can drive the headed-login flow described below. The state files produced by `browser_storage_state` persist across sessions; activation is a one-time cost per fork.

Diagnostic: if a session shows `BROWSER_AUTH_REQUIRED` but the agent has no `mcp__playwright__*` tools listed, the prerequisite is incomplete — complete activation first, then re-issue the request in a fresh session.

### X/Twitter shortcut (try first)

Before invoking the full auth workflow for an X/Twitter URL of the form `x.com/<user>/status/<id>` or `twitter.com/<user>/status/<id>`, try the public thread-reader services first. Nitter is dead in 2026; use:

1. **Primary:** `https://unrollnow.com/status/<id>` — fetch via `WebFetch`. If the response body is non-empty and contains the thread text, the read succeeds without any auth step.
2. **Backup:** `https://threadreaderapp.com/thread/<id>.html` — same `WebFetch` approach. Use when unrollnow returns empty or an error.

Only if both fail (empty body, HTTP error, or no thread content) fall back to the `BROWSER_AUTH_REQUIRED` signal below. **The shortcut covers the original-poster's thread continuation only** — it does NOT include replies from other users, quote-tweets, or any sub-thread by a different author. If the request needs replies (e.g. "ler post AND replies"), the shortcut is insufficient and the auth flow is required even for public posts. Other paths the shortcut does NOT cover: locked accounts, DM-only content, threadreaderapp returning login page for threads it has not indexed yet (verified empirically 2026-05).

**Reply-set virtualization gotcha (auth flow path).** Once authenticated, X.com renders the reply list with virtualized scrolling — `browser_snapshot` captures only the ~10 replies in the current viewport, NOT the full reply set (a post with `37 replies` shown in the metric may surface only 8-10 in a single snapshot). To collect all replies, drive `browser_press_key("PageDown")` (or `browser_evaluate("() => window.scrollBy(0, 2000)")`) in a loop and snapshot between scrolls until no new article refs appear. Same shape applies to Twitter's quote-tweet feed.

### Signaling convention — `BROWSER_AUTH_REQUIRED: <host>`

When the agent encounters a URL that requires authentication and no saved state exists for that host, it emits the following phrase to the chat:

```
BROWSER_AUTH_REQUIRED: <host>
```

where `<host>` is the bare hostname (e.g. `x.com`, `linkedin.com`). The agent follows the phrase with a one-line next step pointing the human at this section and naming the exact save command. Example:

```
BROWSER_AUTH_REQUIRED: x.com
Next step: open Playwright MCP in headed mode, log in at x.com, then run
  browser_run_code_unsafe with `page.context().storageState({ path: '...' })`
  to save state to .claude/.browser-state/x.com.json.
See .claude/rules/mcp-recipes.md § Authenticated workflow.
```

The phrase is all-caps with a colon-space separator — agents and humans alike can grep for it. The agent does NOT retry the same host until the human signals the state was saved (e.g. by replying "done" or by the agent detecting the state file exists on disk).

### Storage state — `.claude/.browser-state/<host>.json`

Session state is stored one file per host under `.claude/.browser-state/`. The directory ships as an empty scaffold (`.gitkeep` sentinel committed); individual state files are gitignored because they contain session cookies and localStorage — equivalent blast radius to a leaked password. Convention:

- Filename: lowercase hostname, `.json` extension. Examples: `x.com.json`, `linkedin.com.json`, `github.com.json`.
- Path: `.claude/.browser-state/<host>.json` relative to the project root.
- Never commit these files. The `.gitignore` entry `.claude/.browser-state/*.json` excludes the state files while leaving the `.gitkeep` sentinel tracked (the sentinel does not match `*.json`, so no `!`-exclusion is needed). See `.claude/rules/secrets-scan.md` for the credential-class framing.

### Playwright MCP — headed login, then headless reuse

The full auth lifecycle with Playwright MCP is three steps:

**Step 1 — headed login (human action required)**

Launch Playwright in headed mode so the human can interact with the login form. The MCP block does not need modification; headed vs headless is a per-invocation argument:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--headed"]
    }
  }
}
```

Navigate to the target site, complete the login flow in the browser window. The agent waits for the human to signal completion.

**Step 2 — save state**

Once the human is logged in, ask the agent to capture the Playwright context's storage state. `@playwright/mcp@latest` (verified 2026-05) does NOT expose a dedicated `browser_storage_state` tool — the only access path is `browser_run_code_unsafe`, which runs an arbitrary `async (page) => ...` function in the Playwright server process and gives access to `page.context()`. Playwright's `context.storageState({ path })` writes the full state (including `httpOnly` cookies like `li_at` / `JSESSIONID`) to disk natively:

```js
async (page) => {
  const state = await page.context().storageState({
    path: '/absolute/path/.claude/.browser-state/<host>.json'
  });
  return { cookies: state.cookies.length, origins: state.origins.length };
}
```

Pass that as the `code` argument to `mcp__playwright__browser_run_code_unsafe`. Use the ABSOLUTE path (Playwright MCP's sandbox restricts file paths to allowed roots and rejects `/tmp/*` etc; the project root is allowed). Verify by checking the file size (~10-30 KB typical) and grepping for the auth cookie (`li_at` for LinkedIn, `auth_token` for X, etc.).

**`browser_run_code_unsafe` is RCE-equivalent** — the description warns it executes arbitrary JavaScript in the Playwright server process. The save step is one of the legitimate uses; do NOT pass user-supplied or web-derived strings as code. The narrow, single-purpose `storageState({ path })` invocation above is the only shape recommended for routine use.

**Step 3 — headless reuse**

Two reuse paths, depending on whether the fork wants a static one-host setup or dynamic multi-host:

*Single-host static reuse:* add `--storage-state=<absolute path>` to the Playwright MCP startup args in `.mcp.json`:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--storage-state=/abs/.claude/.browser-state/<host>.json"]
    }
  }
}
```

This loads the state at MCP boot; subsequent `browser_navigate` calls reach the host already authenticated. Restart the session after editing `.mcp.json` — MCPs load at SessionStart, not hot-reloaded.

*Dynamic multi-host reuse:* use `browser_run_code_unsafe` to load state mid-session:

```js
async (page) => {
  // Note: addCookies + localStorage hydration via context; for httpOnly cookies
  // the --storage-state startup flag remains the more reliable path because
  // re-attaching httpOnly cookies on an already-running context requires
  // navigation to the target origin to bind them.
  const fs = await import('node:fs/promises'); // may be blocked by sandbox
  const state = JSON.parse(await fs.readFile('/abs/.claude/.browser-state/<host>.json', 'utf8'));
  await page.context().addCookies(state.cookies);
  return 'cookies loaded';
}
```

Caveat: the Playwright MCP sandbox may block `node:fs` imports (verified empirically — both `require('fs/promises')` and `await import('fs/promises')` failed in this dogfood pass on 2026-05). When `fs` is unavailable, the only viable reuse path is the `--storage-state` startup flag. The multi-host workflow then needs to either (a) merge multiple `<host>.json` files into one combined storage-state JSON at fork-prep time, or (b) restart the session each time a different host is needed.

The reuse step is silent: when `.claude/.browser-state/<host>.json` exists and is loaded (either via `--storage-state` or via mid-session injection), the agent navigates as authenticated and `BROWSER_AUTH_REQUIRED: <host>` is NOT emitted.

### Expired-state recovery

Storage state expires when the site rotates session tokens — typically within days to weeks depending on the site. The agent recognises expiry when a navigation that previously succeeded now returns 401, 403, or redirects to a login page. On detection:

1. Delete or archive the stale state file: `rm .claude/.browser-state/<host>.json`.
2. Re-emit `BROWSER_AUTH_REQUIRED: <host>` to the chat.
3. Repeat the headed-login → save cycle.

The agent does NOT retry silently or guess at token refresh; re-authentication requires the human. This is by design — session cookies are credentials, not config.

### When to reach for Chrome DevTools MCP instead

Chrome DevTools MCP is the right choice when you need **observation**, not **driving**: watching network requests during a Playwright-driven session, capturing console logs, running Lighthouse audits, or taking heap snapshots. It is NOT the default for authenticated content reads. When you need both (drive + observe), run Playwright MCP as the driver and Chrome DevTools MCP as the observer, using a **dedicated `--user-data-dir` Chrome profile** that contains only the accounts relevant to the task. Avoid `--autoConnect` — see the positioning note in `### Chrome DevTools MCP` above.

## Gotchas

- **`.mcp.json.example` is JSON-with-comments.** Strict JSON parsers reject `//` line comments. The `.example` suffix is the universal "this is a template, do not parse directly" signal. The header comment in the file explicitly says: copy, rename, remove `//` markers before activation. Do NOT just `mv .mcp.json.example .mcp.json` — the result wouldn't parse.
- **Package-name drift.** MCP packages are early-stage (most v0.x). A package can rename or restructure across minor releases. Each recipe section links to the upstream's source-of-truth README; if your `.mcp.json` block stops working after `@latest` resolves to a newer version, **check the upstream README first**, then update the recipe block. v1 of this spec uses `@latest` throughout; forks that hit churn pain can pin manually (e.g. `@playwright/mcp@0.0.30`) — Agent0 does not maintain a version manifest.
- **Monorepo walk is depth-1 only.** The stack detector scans `CLAUDE_PROJECT_DIR` at the top level AND walks depth-1 into the workspace dirs listed in § Walk scope (default `apps packages services workspaces`). A file at depth-2+ — e.g. `apps/web/nested/deep/next.config.js` — does NOT trigger the hint. Workarounds for deeply nested setups: (a) symlink the relevant config up to a depth-1 child, (b) point `CLAUDE_PROJECT_DIR` at the workspace you're actively working in, (c) `CLAUDE_MCP_RECIPES_WORKSPACE_DIRS="<deeper-roots>"` if the deep parent is a stable convention. The depth cap is intentional — arbitrary tree walks scale poorly on large repos.
- **Workspace-walk default set is JS/TS-flavored.** Default `apps packages services workspaces` covers pnpm/Turborepo/Nx/Yarn conventions but not Cargo (`crates/`), Python `src/<pkg>/` layouts, or Bazel `//...` paths. Forks with non-JS monorepos point `CLAUDE_MCP_RECIPES_WORKSPACE_DIRS` at their convention. Revisit the default set when/if a Cargo monorepo with embedded JS/Python sub-projects surfaces — until then, scope creep deferred.
- **Bring-your-own-bundler blind spot.** A fork using esbuild / rollup / parcel / swc without React / Vue / Svelte / Vite / Astro deps in `package.json` won't trigger the "browser-stack non-Next" branch. Acceptable — the recipe doc is one click away. The hint is a convenience, not a contract.
- **Chrome DevTools MCP needs Chrome installed.** Headless CI runners and minimal Linux containers usually lack it. The hint blindly suggests the recipe based on stack; if your environment can't run Chrome, ignore the suggestion and stick with Playwright (which manages its own binaries).
- **DBHub `DATABASE_URL` false-positive.** A fork with `DATABASE_URL=` only in `.env.example` for documentation purposes may not actually use a database yet. The hint will still suggest DBHub. Acceptable since the hint is *suggestion*, not auto-activation — you decide whether to copy the block.
- **`.mcp.json` is a secret-adjacent file.** DBHub's `DATABASE_URL` is the obvious case, but other MCPs may grow env-var requirements. Treat `.mcp.json` like `.env`: never commit a populated copy with credentials. Use env-var indirection (`"env": {"DATABASE_URL": "${DATABASE_URL}"}` when supported, or set the variable in your shell before launching `claude`).
- **Settings.json mutation surface.** Forks that have already customised `.claude/settings.json` may hit merge conflicts when adopting this spec via `git pull`. The diff is small (one SessionStart entry); the conflict is mechanical. Same caveat as every other hook-shipping spec.
- **Recipe security docs are NOT duplicated here.** Each MCP has its own security stance (Playwright navigation policy, Chrome CDP scope, DBHub readonly default, Next dev-only positioning). The recipe sections link to upstream; Agent0 does NOT re-summarise (those summaries would rot). A fork enabling an MCP should read the linked upstream section.
- **No new audit log.** This capacity is pure recommendation. The supply-chain / secrets / delegation / runtime-introspect capacities all write JSONL audit lines for their decisions; mcp-recipes writes nothing. If forensic analysis of "which MCPs forks have enabled" ever becomes a real need, that's a follow-up spec.
