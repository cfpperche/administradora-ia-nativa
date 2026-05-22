#!/usr/bin/env bash
# .claude/hooks/mcp-recipes-hint.sh
# SessionStart hook — detect fork's stack and emit MCP recipe suggestions.
#
# Pure recommendation: never blocks, never audits, exit 0 always. Honors
# CLAUDE_SKIP_MCP_RECIPES=1 to suppress regardless of stack signals. Silent
# when no signals match (Agent0 base case).
#
# Detection runs at $CLAUDE_PROJECT_DIR root AND (spec 015) one level deep into
# common monorepo workspace dirs (apps/*, packages/*, services/*, workspaces/*).
# Override the workspace set via CLAUDE_MCP_RECIPES_WORKSPACE_DIRS (space-
# separated; replaces default; empty string disables walk entirely).
#
# Signal table (see .claude/rules/mcp-recipes.md for full reference):
#   Next.js   next.config.{js,ts,mjs,cjs} OR package.json next dep
#             -> next-devtools-mcp + playwright-mcp
#   Browser   react / vue / svelte / vite / astro in package.json (no next)
#             -> playwright-mcp + chrome-devtools-mcp
#   DB        schema.prisma / drizzle.config.{js,ts,mjs} / alembic.ini /
#             database/migrations/ / db/migrate/ / DATABASE_URL in .env.example
#             -> dbhub
#
# Reference:
#   .claude/rules/mcp-recipes.md          — full recipes + workflow
#   docs/specs/012-mcp-recipes/           — base spec
#   docs/specs/015-monorepo-stack-detect/ — workspace-walk extension

set -uo pipefail

# ---------------------------------------------------------------------------
# Phase 1: User-facing escape hatch
# ---------------------------------------------------------------------------
if [ "${CLAUDE_SKIP_MCP_RECIPES:-0}" = "1" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# ---------------------------------------------------------------------------
# Phase 2: Stack signal detection
# ---------------------------------------------------------------------------
signals=""             # human-readable signal labels (for hint header)
have_next=0
have_browser=0         # react/vue/svelte/vite/astro
have_db=0
have_laravel=0         # artisan file OR composer.json with laravel/framework

# detect_at <abs_path> [<label_prefix>]
#
# Scans a single directory for stack signals and mutates the globals
# `signals`, `have_next`, `have_browser`, `have_db`. The `<label_prefix>` is
# prepended to each emitted signal label (e.g. "apps/web/" so the user can
# see which workspace fired). Empty prefix → bare labels (root case).
#
# Per-call locality: the "is this dir Next?" check is local so a non-Next
# workspace (e.g. `apps/api/` with just react) still flips `have_browser`
# globally even when another workspace already set `have_next` to 1.
detect_at() {
  local path="$1"
  local prefix="${2:-}"
  local local_have_next=0
  local f d dep next_dep match

  # --- Next.js signal: config files ---
  for f in next.config.js next.config.ts next.config.mjs next.config.cjs; do
    if [ -f "$path/$f" ]; then
      have_next=1
      local_have_next=1
      signals="$signals ${prefix}$f"
      break
    fi
  done

  # --- package.json dep checks (jq-free fallback) ---
  local pkg="$path/package.json"
  if [ -f "$pkg" ]; then
    if command -v jq >/dev/null 2>&1; then
      next_dep="$(jq -r '(.dependencies // {} | keys[]?), (.devDependencies // {} | keys[]?)' "$pkg" 2>/dev/null | grep -Fx 'next' | head -1)"
      if [ -n "$next_dep" ] && [ "$local_have_next" -eq 0 ]; then
        have_next=1
        local_have_next=1
        signals="$signals ${prefix}package.json:next"
      fi
      if [ "$local_have_next" -eq 0 ]; then
        for dep in react vue svelte vite astro; do
          match="$(jq -r '(.dependencies // {} | keys[]?), (.devDependencies // {} | keys[]?)' "$pkg" 2>/dev/null | grep -Fx "$dep" | head -1)"
          if [ -n "$match" ]; then
            have_browser=1
            signals="$signals ${prefix}package.json:$dep"
            break
          fi
        done
      fi
    else
      if [ "$local_have_next" -eq 0 ] && grep -qE '"next"[[:space:]]*:' "$pkg"; then
        have_next=1
        local_have_next=1
        signals="$signals ${prefix}package.json:next"
      fi
      if [ "$local_have_next" -eq 0 ]; then
        for dep in react vue svelte vite astro; do
          if grep -qE "\"$dep\"[[:space:]]*:" "$pkg"; then
            have_browser=1
            signals="$signals ${prefix}package.json:$dep"
            break
          fi
        done
      fi
    fi
  fi

  # --- DB signal: prisma / drizzle / alembic / migrations dirs / env DATABASE_URL ---
  local local_have_db=0
  for f in schema.prisma alembic.ini; do
    if [ -f "$path/$f" ]; then
      have_db=1
      local_have_db=1
      signals="$signals ${prefix}$f"
      break
    fi
  done

  if [ "$local_have_db" -eq 0 ]; then
    for f in drizzle.config.js drizzle.config.ts drizzle.config.mjs; do
      if [ -f "$path/$f" ]; then
        have_db=1
        local_have_db=1
        signals="$signals ${prefix}$f"
        break
      fi
    done
  fi

  if [ "$local_have_db" -eq 0 ]; then
    for d in database/migrations db/migrate; do
      if [ -d "$path/$d" ]; then
        have_db=1
        local_have_db=1
        signals="$signals ${prefix}$d/"
        break
      fi
    done
  fi

  if [ "$local_have_db" -eq 0 ] && [ -f "$path/.env.example" ]; then
    if grep -qE '^DATABASE_URL=' "$path/.env.example"; then
      have_db=1
      signals="$signals ${prefix}.env.example:DATABASE_URL"
    fi
  fi

  # --- Laravel signal: artisan file (canonical) OR composer.json with laravel/framework ---
  local local_have_laravel=0
  if [ -f "$path/artisan" ]; then
    have_laravel=1
    local_have_laravel=1
    signals="$signals ${prefix}artisan"
  fi
  if [ "$local_have_laravel" -eq 0 ] && [ -f "$path/composer.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      laravel_dep="$(jq -r '(.require // {} | keys[]?), (.["require-dev"] // {} | keys[]?)' "$path/composer.json" 2>/dev/null | grep -Fx 'laravel/framework' | head -1)"
      if [ -n "$laravel_dep" ]; then
        have_laravel=1
        signals="$signals ${prefix}composer.json:laravel/framework"
      fi
    else
      if grep -qE '"laravel/framework"[[:space:]]*:' "$path/composer.json"; then
        have_laravel=1
        signals="$signals ${prefix}composer.json:laravel/framework"
      fi
    fi
  fi
}

# Root scan — preserves spec 012 behaviour (bare signal labels, no prefix).
detect_at "$PROJECT_DIR" ""

# Workspace walk (spec 015) — depth-1 scan into common monorepo layouts.
# Default set: apps packages services workspaces.
# CLAUDE_MCP_RECIPES_WORKSPACE_DIRS overrides (space-separated; empty string
# disables walk entirely so root-only detection mirrors spec 012's pre-015
# behaviour).
if [ -n "${CLAUDE_MCP_RECIPES_WORKSPACE_DIRS+set}" ]; then
  workspace_dirs="$CLAUDE_MCP_RECIPES_WORKSPACE_DIRS"
else
  workspace_dirs="apps packages services workspaces"
fi

if [ -n "$workspace_dirs" ]; then
  for ws in $workspace_dirs; do
    ws_root="$PROJECT_DIR/$ws"
    [ -d "$ws_root" ] || continue
    for child in "$ws_root"/*/; do
      [ -d "$child" ] || continue
      child_abs="${child%/}"
      child_name="$(basename "$child_abs")"
      detect_at "$child_abs" "$ws/$child_name/"
    done
  done
fi

# ---------------------------------------------------------------------------
# Phase 3: Build the suggested-recipes list (deduplicated union)
# ---------------------------------------------------------------------------
recipes=""

add_recipe() {
  local name="$1"
  case " $recipes " in
    *" $name "*) return ;;
  esac
  if [ -z "$recipes" ]; then
    recipes="$name"
  else
    recipes="$recipes $name"
  fi
}

if [ "$have_next" -eq 1 ]; then
  add_recipe "next-devtools-mcp"
  add_recipe "playwright-mcp"
fi
if [ "$have_browser" -eq 1 ]; then
  add_recipe "playwright-mcp"
  add_recipe "chrome-devtools-mcp"
fi
if [ "$have_db" -eq 1 ]; then
  add_recipe "dbhub"
fi
if [ "$have_laravel" -eq 1 ]; then
  add_recipe "laravel-boost-mcp"
  add_recipe "playwright-mcp"
fi

# No recipes -> silent.
[ -z "$recipes" ] && exit 0

# ---------------------------------------------------------------------------
# Phase 4: Emit the hint block
# ---------------------------------------------------------------------------
signals_trim="${signals# }"

printf '\n=== mcp-recipes ===\n'
printf 'Stack signals detected: %s\n' "$signals_trim"
printf 'Suggested MCP recipes (copy + uncomment from .mcp.json.example):\n'
for r in $recipes; do
  case "$r" in
    next-devtools-mcp)
      printf '  - next-devtools-mcp  Next.js framework introspection (build errors, routes, server actions)\n' ;;
    playwright-mcp)
      printf '  - playwright-mcp     browser observation (DOM, console, network, screenshots)\n' ;;
    chrome-devtools-mcp)
      printf '  - chrome-devtools-mcp  Chrome DevTools (network, console, Lighthouse, V8 heap)\n' ;;
    dbhub)
      printf '  - dbhub              multi-engine DB schema + safe query exec\n' ;;
    laravel-boost-mcp)
      printf '  - laravel-boost-mcp  Laravel framework introspection (Eloquent models, DB schema, logs, docs)\n' ;;
  esac
done
printf 'See .claude/rules/mcp-recipes.md for full recipes (install commands, runtime requirements, security).\n'
printf '=== end mcp-recipes ===\n'

exit 0
