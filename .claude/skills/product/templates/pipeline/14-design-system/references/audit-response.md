# Step 6 — Consuming Step-4 Audit Frontmatter

The structured handoff that closes the audit→token-edit loop. When step 4 emits YAML frontmatter (measurable mode, see `04-ux-testing/schema.md` § "Optional YAML frontmatter — structured findings handoff"), step 6 reads it and applies `fix_skill_hint: "design-system"` findings inline. This page is the consumer-side spec.

## What step 4 hands over (the contract)

Step 4's frontmatter shape (when present):

```yaml
---
findings:
  - id: F-01
    severity: 4
    heuristic: "A11y 2.4.7 Focus visible"
    location: "screens/05-triage-view.html"
    issue: "..."
    recommendation: "..."
    wcag: "2.4.7"
    fix_skill_hint: "screen-atlas"        # <-- NOT for step 6
    complexity_estimate: "~15 min"
  - id: F-07
    severity: 3
    heuristic: "A11y 1.4.3 Contrast"
    location: "All 8 screens"
    issue: "Tertiary text 3.89:1 — fails 4.5:1 floor"
    recommendation: "Brighten --foreground-3 to oklch(0.55 …)"
    wcag: "1.4.3"
    fix_skill_hint: "design-system"       # <-- step 6 reads this
    complexity_estimate: "~30 min"
priority_fixes:
  - batch: "a11y-contrast-token-tune"
    finding_ids: [F-07, F-09]
    rationale: "single token edit cascades to all 8 screens"
    complexity_estimate: "~30 min"
    when: "before gate"
---
```

## Procedure

### 1. Detect frontmatter presence

Read `docs/validation-report.md`. If the file opens with `---\n`, parse the YAML block until the closing `---\n`.

- **Frontmatter present** → continue to step 2.
- **Frontmatter absent** → step 4 ran in projected mode (markdown-spec input, nothing measurable). Skip the audit-response loop. Emit `*No design-system-routed findings from step 4 audit (audit ran in projected mode — no structured findings handoff).*` in `## Audit Response`.

### 2. Filter to design-system-routed findings

Keep only findings where `fix_skill_hint == "design-system"`. Typical patterns:

- **Contrast fails** (`heuristic: "A11y 1.4.3"`) — almost always design-system territory (token tune to lift the failing color pair past the floor)
- **Color-on-color hierarchy fails** — same as above; the lightness ratio between two semantic colors needs adjustment
- **Border / divider invisibility** — token tune (border-color stronger; or a deliberate "borders are decorative, not state-bearing" doc decision)

What's NOT design-system territory (leave for step 7 screen-atlas):

- Missing `:focus-visible` rules — that's a CSS rule the rendered HTML needs, not a token
- `<span>`-as-input — semantic HTML, screen-atlas fix
- Skip-link missing — semantic HTML, screen-atlas fix
- Bulk-action without confirmation — interaction design, screen-atlas fix

What's NOT either (deferred):

- Cosmetic findings (severity 1) — backlog, no in-pipeline fix
- WCAG 2.2 readiness — outside v1 scope, document but don't act

### 3. Apply each design-system-routed fix in `tokens.css`

For each `fix_skill_hint: "design-system"` finding:

a. **Identify the affected token(s)** — read the `recommendation` field. It usually names them explicitly ("Brighten `--foreground-3` from `oklch(0.50 …)` to `oklch(0.55 …)`"). When the recommendation names a value but not a token (e.g. "tertiary text contrast must hit 4.5:1"), trace via the brand-book color-story to the canonical token in your `tokens.css`.

b. **Apply the value change** with the originating finding ID in the comment:

```css
/* fix(F-07/F-09): brightened from oklch(0.50 0.010 240) to lift contrast on surface from 3.89:1 → 5.10:1 */
--color-foreground-tertiary: oklch(0.55 0.010 240);
```

When multiple findings are addressed by the same token edit (the F-07/F-09 case — both contrast fails fixed by one token brighten), include all finding IDs in the comment so the audit trail is single-pointable.

c. **Verify the recomputed contrast** for every color pair the changed token participates in. The fix that addresses F-07 must not regress F-04 (some other text-on-surface check). Compute and document in `## Audit Response`.

### 4. Document in `## Audit Response`

Per applied finding, one block:

```markdown
### F-07 — Tertiary text contrast on surface

**Heuristic:** A11y 1.4.3 (Contrast)
**Severity:** 3 (major)
**Before:** `--color-foreground-tertiary` = `oklch(0.50 0.010 240)` → 3.89:1 on `--color-surface`, fails 4.5:1
**After:** `--color-foreground-tertiary` = `oklch(0.55 0.010 240)` → 5.10:1 on `--color-surface`, passes
**Affected pairs verified:** also re-checked against `--color-canvas` (4.11:1 → 5.40:1, was failing F-09, also fixed) and `--color-surface-2` (3.69:1 → 4.84:1, was failing, also fixed)
**Token(s) changed:** `--color-foreground-tertiary` (1 token, cascades to ~20 affected text elements)
```

Single-token-fix-cascading-to-N-findings is common (the F-07 / F-09 / [implicit F-on-surface-2] case). Document the cascade explicitly.

### 5. Document priority_fixes batches the design-system cycle resolved

After per-finding blocks, summarize which `priority_fixes` batches are now resolved by step 6's edits:

```markdown
### Batches resolved this step

- `a11y-contrast-token-tune` (F-07, F-09, plus implicit surface-2 finding) — RESOLVED via single `--color-foreground-tertiary` token edit. Total effort: ~30 min, matches the `complexity_estimate` from step 4.

### Batches deferred to step 7

- `keyboard-focus-restore` (F-01) — `fix_skill_hint: "screen-atlas"`, not actionable at the token layer.
- `semantic-html-pass` (F-12, F-13) — `fix_skill_hint: "screen-atlas"`, deferred.
```

### 5b. Doc-only fixes (policy added, no token edit)

Some `fix_skill_hint: "design-system"` findings have no token-value change attached — they're *policy* fixes that the design-system documents but doesn't materialize as a token edit. Common cases:

- `--accent` color passes contrast at the token layer but only at ≥ 16 px; the fix is a documented usage rule (`--accent` only at ≥ 16 px or ≥ 14 px bold), not a token value change.
- Borders sit below the 3:1 UI floor but are decorative-not-state-bearing; the fix is a documented "borders never carry state alone" policy, not a token change.

For these, the per-finding block in `## Audit Response` uses a slightly different shape:

```markdown
### F-10 — Hairline borders below 3:1 UI floor

**Heuristic:** A11y 1.4.11
**Severity:** 2 (minor)
**Resolution:** policy added — borders are decorative, never the sole carrier of state.
**Documented in:** § Accessibility Floor § Border discipline (`design-system.md`).
**Token(s) changed:** none — `--color-border` and `--color-border-2` retain their below-floor values intentionally.
```

`Token(s) changed: none — ...` is the canonical phrasing. The "Documented in" line points at where in `design-system.md` the policy lives so a reader of `## Audit Response` can navigate to the actual rule.

### 6. Typical case (some applied, some routed elsewhere)

The most common case: step 4 emits N findings, M of them routed to design-system (apply + document per § 3-5b above), the remaining N-M routed to step 7 / deferred / outside scope. The `## Audit Response` section MUST acknowledge the routed-elsewhere findings explicitly — silently dropping them gives the reader no way to tell whether step 6 ignored them or saw them and consciously routed them. After the per-finding blocks for the M applied findings + the `### Batches resolved this step` summary + `### Batches deferred to step 7` summary (per § 5), close with a short reviewed-not-actioned list:

```markdown
### Findings reviewed (not actioned at design-system layer)

- F-01 (keyboard focus visible) → routed to step 7 (rendering concern, not token)
- F-02 (bulk-delete confirmation) → routed to step 7 (interaction design)
- F-12 (palette span-as-input) → routed to step 7 (semantic HTML)
- F-13 (form fields not real inputs) → routed to step 7 (semantic HTML)
- F-15 (reduced-motion wrap) → deferred to backlog (cosmetic, AAA-only)
```

One bullet per non-applied finding. Each bullet names the finding ID + one-line summary + the routing destination + a one-line "why-not-here" justification. This is the audit trail that proves the design-system cycle DID consume the audit, even when most findings landed elsewhere.

### 7. Empty case (no design-system-routed findings)

When step 4 frontmatter exists but no findings have `fix_skill_hint: "design-system"`:

```markdown
## Audit Response

*Step 4 emitted structured findings, none routed to design-system. All findings deferred to step 15 (screen-atlas; absorbed step 7 per spec 045) or marked deferred for backlog. No token edits applied this step.*

### Findings reviewed (not actioned)

- F-01 (keyboard focus) → step 7
- F-12 (palette span-as-input) → step 7
- F-13 (form fields not real inputs) → step 7
- F-15 (reduced-motion wrap) → deferred (cosmetic)
```

The reviewed-not-actioned list documents that the design-system cycle DID read the frontmatter, even though nothing landed at the token layer. Without it, a reader can't tell whether step 6 ignored step 4 or step 4 had nothing to give.

### 8. No-frontmatter case (step 4 ran in projected mode)

```markdown
## Audit Response

*No design-system-routed findings from step 4 audit (audit ran in projected mode — markdown spec input, no measurable findings to hand off). Token-level accessibility decisions made from first principles in this step's `## Accessibility Floor`.*
```

The explicit empty-state line is the contract. Skipping the section silently is the regression mode.

## Why this contract matters

Without the structured handoff, the audit→fix loop is the human's job. A real consumer reading the audit, finding a contrast fail, mapping it to the right token, applying the value change, re-checking the cascade — and remembering to do this for every finding. The frontmatter + this consumption pattern automates the routing and makes the application trace-able. This is the audit-as-delegation-manifest pattern from the anthill comparison, restored in the MCP port.
