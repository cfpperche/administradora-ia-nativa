# Step 2 — Schema (prototype HTML mood boards + REPORT + hi-fi screens)

The submitted `REPORT.md` MUST contain the level-2 markdown headings below + meet the Layer 1 size/content floor in the JSON fenced block. All listed files must be persisted via the `extra_files` parameter on `product_step_submit`. Both checks fire on submit; missing sections OR Layer 1 failures produce `code: "schema-incomplete"` with the failure list.

## Size floor (anti-stub — spec 075)

Per spec 075 the size **ceiling** is retired — artifact scope is judged by the quality judge (`references/quality-judge.md`), not a byte count. Only the `min_size` **floor** remains, as a cheap anti-stub check enforced at submit by the Layer 1 block below.

| Artifact | `min_size` floor | Floor rationale |
|---|---|---|
| `direction-a.html` (standard tier) | 10 KB | below this is a stub — missing token system or surfaces |
| `direction-{b,c}.html` (legacy 3-direction mode) | 10 KB | same as `-a` |
| `screens/*.html` (per file, mood-tier) | 4 KB | below this is a stub screen |
| `REPORT.md` | 6 KB | below this Turn 1 sections are missing |

A uniform 200 KB catastrophe cap (token-runaway circuit-breaker, not a budget) applies per `.claude/rules/artifact-budgets.md`.

## Required sections (REPORT.md markdown headings)

Section names slugify by lowercasing + dashing — `## 3 Direction Summaries` → `3-direction-summaries`. Cosmetic variants are accepted (trailing punctuation, "Pre-Emit" suffix, etc.); slugifier strips them.

- `run-summary`
- `design-systems-consulted`
- `3-direction-summaries`
- `5-dim-critique` (full title may read `5-Dim Critique Pre-Emit Scores`; slugifier accepts the prefix match)
- `anti-ai-slop-audit` (accepts `anti-slop-audit`)
- `brief-compliance` (accepts `brief-compliance-check`)
- `turn-2-plan` (required after Turn 1 emit)
- `turn-2-hi-fi-screens` (REQUIRED on final submit — added after user picks direction and Turn 2 completes; section heading is `## Turn 2 — Hi-Fi Screens`, count-agnostic since N is product-calibrated per prompt.md § 9. Accepts the historical `turn-2-8-screens-hi-fi` slug for backwards-compat with pre-Gap-D submissions.)

The Identity block (codename, palette tokens, type stack, citation chain per direction) lives inside `3-direction-summaries` — it is enforced via the `contains` substrings in the Layer 1 fenced block below, not as separate headings.

## Layer 1 — file-level floor

```required_files
{
  "required_files": [
    {
      "path": "direction-a.html",
      "min_size": 10240,
      "contains": ["<!DOCTYPE html", "<style", ":root", "--background", "--foreground", "--primary", "Most Popular", "<svg"]
    },
    {
      "path": "direction-b.html",
      "min_size": 10240,
      "contains": ["<!DOCTYPE html", "<style", ":root", "--background", "--foreground", "--primary", "Most Popular", "<svg"]
    },
    {
      "path": "direction-c.html",
      "min_size": 10240,
      "contains": ["<!DOCTYPE html", "<style", ":root", "--background", "--foreground", "--primary", "Most Popular", "<svg"]
    },
    {
      "path": "compare.html",
      "min_size": 4096,
      "contains": ["<!DOCTYPE html", "direction-a", "direction-b", "direction-c", ">Palette", ">School", "Anti-AI-slop"],
      "any_of_contains": ["✓ PASS", "PASS ✓"]
    },
    {
      "path": "REPORT.md",
      "min_size": 6144,
      "contains": [
        "## Run Summary",
        "## Design Systems Consulted",
        "## 3 Direction Summaries",
        "## 5-Dim Critique",
        "## Anti-AI-Slop Audit",
        "## Brief Compliance",
        "| Philosophy | Hierarchy | Execution | Specificity | Restraint |",
        "design-systems/"
      ]
    }
  ],
  "required_glob": [
    {
      "pattern": "screens/[0-9][0-9]-*.html",
      "min_count": 3,
      "per_match_min_size": 4096,
      "per_match_contains": ["<!DOCTYPE html", "<style", ":root"]
    }
  ]
}
```

### Notes on the floors

- **`direction-{a,b,c}.html` min_size 10240** (10 KB) — bumped from 8 KB after adding the charts & sparklines section in refinement v4. Pivota's anthill reference landed at 17-20 KB; benchmark runs land at 33-47 KB. A 10 KB floor catches stubs while allowing terse variants
- Each direction file's `contains` enforces:
  - The `:root` token system + 3 canonical token names (`--background` / `--foreground` / `--primary`) — agents that forget the token system trip Layer 1 immediately
  - The substring `Most Popular` — proxy for the required **pricing tile grid** surface (see prompt.md § 4 section #7). The "Most Popular" badge convention is universal across SaaS pricing surfaces; if a product's tier structure uses a different highlight word (e.g., "Recommended", "Featured", or "Free Forever" for a free-only product), the agent should include the literal substring `Most Popular` in a comment (`<!-- Most Popular tier: rendered as "Recommended" because <reason> -->`) or as the emphasis label, to pass the check
  - The substring `<svg` — proxy for the required **charts & sparklines sample** surface (see prompt.md § 4 section #6). Inline SVG is the canonical way to render charts in self-contained HTML; agents that skip the charts section trip Layer 1 immediately. CSS-only chart treatments (e.g., a `<div>` height-grid bar chart) that don't use `<svg` should include the substring `<svg` in a comment (`<!-- chart rendered as CSS grid; no SVG used -->`) to pass
- **`compare.html` min_size 4096** + structural substrings — bumped from 2 KB after step 2 benchmark showed both producers landing at 25-32 KB on a real compare surface. The contains list now uses **HTML-tag-content anchors** (`>Palette`, `>School`) instead of bare-word substrings (`Palette`, `School`) — bare words are silently fakeable from prose-discussion text; tag-content anchors force the comparison-table cell shape. The `any_of_contains: ["✓ PASS", "PASS ✓"]` accepts both canonical anti-AI-slop badge orderings (OR-semantics added in 2026-05; the loose `"PASS"` substring previously matched any prose use of the word)
- **`REPORT.md` min_size 6144** (6 KB) — covers Turn 1 sections at honest depth. The dimension-label check is now the **literal pipe-delimited table-row** `| Philosophy | Hierarchy | Execution | Specificity | Restraint |` rather than bare dimension words (Philosophy / Hierarchy / etc) — bare words appear in prose discussion throughout REPORT.md, so the original substrings were silently fakeable. The literal row fragment only appears as a real markdown table header, restoring the structural floor. Turn 2 section grows the file further on resubmit; pivota's REPORT landed at ~16 KB after Turn 2; step 2 bench showed producers landing 21-27 KB on Turn 1 alone
- **`screens/[0-9][0-9]-*.html` glob** — `01-`, `02-`, ..., `NN-` shape, where N is calibrated per product (see `prompt.md` § 9). `min_count: 3` is the **universal sanity floor** — below 3 is "I didn't try" (1 screen is a stub, 2 is barely a flow). Product-class calibration (how many screens are *right* for THIS product) lives in `prompt.md` § 9's calibration table — a SMB SaaS lands at 6-10, a micro-product at 3-5, a marketplace at 10-15. The schema enforces the floor; the prompt enforces the calibration. `per_match_min_size: 4096` filters stubs. Each screen MUST carry `:root` declaration (verbatim copy of picked direction's tokens) — `per_match_contains` enforces

## Section content guidance (depth, not just presence)

The schema enforces presence and floors; *depth* is the agent's responsibility. Quality cues per section:

- **Run Summary** — discovery answers (or "brief pre-answered direction count"); mode (`html-mockup` always at this step); output paths surfaced as `file://` URLs
- **Design Systems Consulted** — table: System / **vendored `DESIGN.md` path** / Used in Direction. Cite ≥ 3 distinct vendored systems across the 3 directions, **each with its `design-systems/<system>/DESIGN.md` path** (the path looked up in `.claude/skills/product/references/od-catalog-index.json` — name-drop without the path is not a citation). If a direction blends 2 systems (e.g., Notion × Stripe), list both rows. This is the citation chain that grounds direction picks in real, vendored product references rather than invented vibes. The Layer 1 `contains` check on `design-systems/` enforces that at least one such path is present
- **3 Direction Summaries** — per direction, in this order: codename, file path, visual DNA (palette + type + layout posture), DS composite, direction-library match (one of the 5 schools or "custom — justified by [reason]"), personality blurb, key brief-compliance highlights, key anti-slop checks passed
- **5-Dim Critique** — table: Direction | Philosophy | Hierarchy | Execution | Specificity | Restraint | Min. The `Min` column carries the gate-pass indicator (✓ if ≥ 3). Any score < 3 should have been fixed in a pre-emit pass — if it lands in the final report, the agent has a discipline failure to explain in the next "Critique notes" subsection
- **Anti-AI-Slop Audit** — table of all P0 rules × A/B/C with ✓ or specific note. PT-BR / Pix / LGPD rows only when product is Brazilian
- **Brief Compliance** — table: Brief requirement / Addressed (which direction). Source requirements from the concept brief's identity block + mechanics-breakdown + risks. If a brief requirement is unaddressed across all 3 directions, call it out — do NOT silently skip
- **Turn 2 Plan** — bullet list of 8 screens that would render for whichever direction the user picks. Map to brief's mechanics-breakdown when possible; default set is `landing / onboarding / dashboard / <mechanic> / <mechanic> / <workflow> / settings / empty-error`
- **Turn 2 — 8 Screens Hi-Fi** (final submit only) — per-screen one-line summary + 5-dim scores per screen + anti-slop re-audit + any deviations from brief noted

## Citations and named systems

DS-by-name citation is **mandatory**: every direction names the vendored design systems it composes from, and `REPORT.md` § "Design Systems Consulted" cites each one with its `design-systems/<system>/DESIGN.md` path (looked up in `.claude/skills/product/references/od-catalog-index.json`). The Layer 1 `contains` check on the substring `design-systems/` is the machine-enforced floor — a REPORT with zero vendored-path citations trips `schema-incomplete`.

Beyond presence, the citation should be specific enough that a reader holding the brief and the vendored `DESIGN.md` can verify the visual claim. "Composed from `design-systems/linear-app/DESIGN.md`" is the floor; "Composed from Linear's hairline borders + tight letter-spacing + near-black canvas with cobalt accent — `design-systems/linear-app/DESIGN.md`" is better and reads as a real reference rather than a name-drop. The 5-dim Specificity score is partially derived from how concrete these citations are.

When the OD vendor is genuinely missing on disk — `.claude/skills/product/design-systems/` directory absent or empty — the skill itself is broken (reinstall or check `git status`). The manual-escape path (`references/pipeline.md` § "Manual escape — OD vendor unavailable") still cites named systems, but without vendored paths the `design-systems/` Layer 1 check cannot pass. In that case the agent includes the substring `design-systems/` in a comment documenting the escape (`<!-- od-vendor-missing: directions grounded in training-data knowledge of design-systems/; see pipeline.md § Manual escape -->`) so the escape is visible rather than silent.
