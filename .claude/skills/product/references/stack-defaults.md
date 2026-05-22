# Stack defaults — research cache

**Retrieved:** 2026-05-20
**Re-research cadence:** quarterly (next: 2026-08-20)
**Sources consulted:** Next.js 16.2.6 — latest stable/LTS (https://nextjs.org/blog); Expo SDK 55 — latest stable, SDK 56 in beta (https://expo.dev/changelog/sdk-55); React 19.2 + React Native 0.83 — bundled by SDK 55; Tailwind CSS 4.3.0 (https://tailwindcss.com/blog); Biome 2.4 (https://biomejs.dev/guides/upgrade-to-biome-v2/); NativeWind v4 stable / v5 pre-release (https://www.nativewind.dev/v5); TypeScript 6.0 (https://devblogs.microsoft.com/typescript/)

This file is the source of truth for the `/product` skill's stack recommendations. When a founder doesn't supply `--stack=<name>`, Phase 1 discovery recommends per the platform target below. Templates in `templates/app-skeleton/<stack>/` must match the versions + structure documented here; drift means re-snapshot is overdue.

## Recommendation by platform target

| Platform target | Recommended stack | Rationale |
|---|---|---|
| **web** | Next.js 16 + React 19 + Tailwind 4 + Biome | App Router default, Turbopack default bundler, Biome chosen over ESLint for unified format+lint, Tailwind included for fast UI iteration |
| **mobile** | Expo SDK 55 + React Native + expo-router + NativeWind | expo-router is the recommended typed-routes router since SDK 50+; NativeWind brings Tailwind utility-class authoring to RN (community-standard, not officially endorsed by Expo but widely used) |
| **desktop** | Tauri 2 + React + Tailwind (deferred — v1 ships web + mobile only per spec.md non-goal) |
| **CLI** | bun + TypeScript + commander or @clack/prompts (deferred — same) |

## Next.js 16 stack (web)

**Canonical scaffold (use this when bundling templates):**
```bash
pnpm create next-app@latest my-app --yes
# Defaults: TypeScript, Tailwind CSS, ESLint, App Router, Turbopack, AGENTS.md, import alias @/*
```

**Manual scaffold (matches what `templates/app-skeleton/next/` bundles):**
```bash
pnpm i next@latest react@latest react-dom@latest
pnpm i -D typescript @types/react @types/node tailwindcss @tailwindcss/postcss @biomejs/biome
```

**File structure (canonical, app router):**
```
my-app/
├── package.json
├── tsconfig.json
├── next.config.ts            (or .mjs/.js)
├── biome.json
├── postcss.config.mjs        (Tailwind 4 uses this — no separate tailwind.config required for default tokens)
├── app/
│   ├── layout.tsx            (root layout — required, must include <html> + <body>)
│   ├── page.tsx              (home)
│   └── globals.css           (Tailwind imports)
├── public/                   (static assets)
└── README.md
```

**package.json scripts (binding for monorepo `pnpm dev`):**
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit",
    "lint": "biome check .",
    "format": "biome format --write ."
  }
}
```

**Key version notes:**
- Node.js 20.9+ required for Next.js 16 (Expo SDK 55 wants 20.19.4+ — use Node 20.19+ if the two stacks share a toolchain)
- React 19.2 (App Router uses React canary internally; declare `react` and `react-dom` in package.json anyway for tooling compat)
- Next.js 16.2.6 is the current stable (LTS) — no Next.js 17 yet
- Next.js 16: `next build` no longer runs the linter — `pnpm lint` is a separate script call (downstream typecheck+lint verification in spec.md plain bullet "two-stack dogfood verified" depends on this)
- Turbopack is default; Webpack is `next dev --webpack` if needed
- Tailwind 4.3: PostCSS-only setup (no `tailwind.config.ts` required for defaults; only needed for custom theming)
- Biome 2.4: chosen over ESLint (single tool for lint+format, faster). The v2 config differs from v1 — `organizeImports` moved under `assist.actions.source`, and `files.ignore`/`files.include` merged into one `files.includes` (negated `!` globs exclude; no auto `**/` prefix). The bundled `biome.json` files are already v2-shaped; `biome migrate --write` converts a v1 config.
- TypeScript 6.0 is the current stable — a low-friction bridge release toward TS 7.0 (native Go port, ~10× faster), which is in beta

**Why pnpm over npm/yarn/bun:** Workspace support out of the box (matters when scaling beyond 1 package); deterministic lockfile; smaller node_modules via content-addressable store.

## Expo SDK 55 stack (mobile)

**Canonical scaffold:**
```bash
npx create-expo-app@latest my-app
# create-expo-app@latest defaults to the current stable SDK (55).
# SDK 56 is in beta — pass `--template default@sdk-56` only to test it intentionally.
```

**Manual scaffold (matches what `templates/app-skeleton/expo/` bundles):**
```bash
bun add expo react react-native
bun add expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-status-bar
bun add -D typescript @types/react
bun add nativewind tailwindcss@^3  # NativeWind v4 (stable) uses Tailwind 3; v5 (Tailwind 4) is pre-release as of 2026-05 — stay on v4 for production
```

**File structure (canonical, expo-router):**
```
my-app/
├── package.json
├── tsconfig.json             (extends expo/tsconfig.base)
├── app.json
├── babel.config.js
├── nativewind-env.d.ts
├── tailwind.config.js        (NativeWind brings its own config)
├── app/
│   ├── _layout.tsx           (root layout — equivalent of Next.js root layout)
│   └── index.tsx             (home screen)
├── assets/                   (icons, splash, fonts)
└── README.md
```

**package.json scripts (binding for monorepo `bunx expo start` or `pnpm dev` aliased):**
```json
{
  "scripts": {
    "start": "expo start",
    "dev": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "typecheck": "tsc --noEmit",
    "lint": "biome check ."
  }
}
```

**Key configuration:**
- After scaffolding, run `npx expo install --fix` — it aligns every `expo-*` package and SDK-bundled native library (`react-native`, `react-native-screens`, …) to the exact versions Expo SDK 55 requires. The `expo` SDK pin is the source of truth; the individual pins in the bundled `package.json` are SDK-55 baselines, not hand-maintained.
- SDK 55 bundles React 19.2 + React Native 0.83 + expo-router 5; minimum Node is 20.19.4
- `app.json` MUST include `"scheme": "<app-name>"` for deep linking (expo-router requirement)
- `app.json` MUST include `"experiments": { "typedRoutes": true }` for type-safe routes
- For web target: `app.json` needs `"web": { "bundler": "metro" }`
- `tsconfig.json` extends `expo/tsconfig.base`; for `@/*` aliasing, paths map to `./app/*` (or `./src/*` if you use `src/` layout)

**Why bun over npm for Expo:** Faster install, native TS runtime for dev scripts. Expo doesn't have official bun preference but works fine in 2026.

## Brand defaults (when `--skip-brand` is set)

Use `templates/default-tokens.css` — neutral semantic CSS custom properties (`--color-primary`, `--space-md`, `--radius-md`, etc.). Same file is consumed by both stacks: Next.js imports via `app/globals.css`; Expo + NativeWind reads via `tailwind.config.js` extending the same token names.

## Drift signals to watch for

When re-researching quarterly, check (status as of the 2026-05-20 snapshot in parentheses):
- Next.js major version bump (16 → 17 changes default bundler / router conventions) — still 16.x
- Tailwind major version (4 → 5 may change PostCSS setup) — still 4.x (4.3.0)
- Expo SDK numeric bump — SDK 56 is in beta (targeted Q2 2026: RN 0.85, Hermes v1 default); re-snapshot to SDK 56 once it ships stable
- React major version (19 → 20 affects React Native compatibility window) — still 19.x (19.2)
- Biome major version — now on v2.4 (v1 → v2 already migrated; watch for v3)
- NativeWind major version — v4 (Tailwind 3) is the stable line; v5 (Tailwind 4) is pre-release. Move the Expo skeleton to v5 only once it ships stable.
- expo-router major version (typed-routes API can shift) — now v5
- TypeScript major version — now 6.0; TS 7.0 (native Go port, ~10× faster) is in beta

When any of the above changes materially, re-snapshot this file, bump the date stamp, and audit `templates/app-skeleton/<stack>/` for staleness.
