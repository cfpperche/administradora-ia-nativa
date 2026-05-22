# Accessibility floor (generator-level defaults)

Five items. All required before the 5-dim critique pass. Each has the rule, the snippet, and the WCAG citation. The `.sr-only` + `.sr-only-focusable` utility classes (at the bottom of this file) MUST be included in every direction HTML's `<style>` block.

This is the FLOOR — not the ceiling. Direction-specific a11y additions (high-contrast variant, reduced-motion media query, etc.) are encouraged on top.

---

## 1. Form label / input association

**Rule:** Every `<input>`, `<select>`, and `<textarea>` must have a `<label>` whose `for=` matches the input's `id`.

```html
<label for="email">Email address</label>
<input type="email" id="email" name="email" autocomplete="email" />
```

**Why:** WCAG 1.3.1 (Info and Relationships) + 4.1.2 (Name, Role, Value). Screen readers announce the label when the input receives focus. Implicit label nesting (`<label><input></label>`) is acceptable but `for=`/`id=` is the canonical form and works with split layouts.

---

## 2. Focus-visible style on interactive elements

**Rule:** Buttons, links, and custom controls must show a visible focus ring distinct from the browser default.

```css
button:focus-visible,
a:focus-visible,
[role="button"]:focus-visible,
input:focus-visible,
select:focus-visible,
textarea:focus-visible {
  outline: 2px solid var(--accent, oklch(63% 0.18 250));
  outline-offset: 2px;
}
```

**Why:** WCAG 2.4.7 (Focus Visible). Keyboard-only users need to know which element is active. `:focus-visible` (not `:focus`) avoids the visual noise of clicks while preserving keyboard affordance.

---

## 3. Live / streaming regions

**Rule:** Any element that updates its content without a page reload (event streams, notification panels, live counters, AI streaming output) must carry `role="log"` and `aria-live="polite"`.

```html
<div role="log" aria-live="polite" aria-label="Recent activity">
  <!-- dynamically inserted items -->
</div>
```

**Why:** WCAG 4.1.3 (Status Messages). Assistive technology announces updates only when the live-region role is present. `polite` defers to active speech; `assertive` is reserved for genuinely interruptive alerts.

---

## 4. Charts and data visualizations

**Rule:** Every chart or graph must be wrapped in a `<figure>` with a `<figcaption>` (or an `aria-label` on the container) that summarises the trend in plain prose.

```html
<figure>
  <div class="chart" aria-hidden="true"><!-- canvas or SVG --></div>
  <figcaption>Monthly revenue grew 18 % from January to March 2026, peaking at $42 k in March.</figcaption>
</figure>
```

**Why:** WCAG 1.1.1 (Non-text Content). Visual-only charts are opaque to screen readers and keyboard users. The caption is also legible to sighted users who can't read the chart's encoding (color-blind users on a red/green chart).

For mood-board / mockup-level prototypes, the chart's `<div>` is usually a CSS-art placeholder — the `aria-hidden="true"` is correct, the caption is what carries the information.

---

## 5. Skip-to-content link

**Rule:** The first focusable element after `<body>` must be a skip link that targets `id="main"` on the primary content container.

```html
<body>
  <a href="#main" class="sr-only-focusable">Skip to content</a>
  <!-- nav / header -->
  <main id="main">
    <!-- primary content -->
  </main>
</body>
```

**Why:** WCAG 2.4.1 (Bypass Blocks). Keyboard users skip repetitive navigation on every page load. Without the link, every keyboard user tabs through the entire nav before reaching content — friction that compounds across screens.

---

## Utility CSS (include in every HTML direction file)

```css
/* Screen-reader only — visually hidden, available to AT */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* Visible on focus — used for skip links and sr-only controls */
.sr-only-focusable:focus {
  position: static;
  width: auto;
  height: auto;
  padding: 0.25rem 0.5rem;
  margin: 0;
  overflow: visible;
  clip: auto;
  white-space: normal;
  background: var(--background);
  color: var(--foreground);
  border: 1px solid var(--border);
  z-index: 100;
}
```

---

## Pre-emit a11y verification

Before submitting any direction file, verify ALL of the following pass:

- [ ] Every `<input>`/`<select>`/`<textarea>` has a matching `<label for>` (1.3.1)
- [ ] `:focus-visible` outline rule exists in CSS, applies to buttons + links + custom controls + form controls (2.4.7)
- [ ] Any live / streaming region uses `role="log" aria-live="polite"` (4.1.3)
- [ ] Charts wrapped in `<figure>` with `<figcaption>` prose summary (1.1.1)
- [ ] Skip link `<a href="#main" class="sr-only-focusable">` as first focusable child of `<body>` (2.4.1)
- [ ] `.sr-only` and `.sr-only-focusable` utility classes present in `<style>`
- [ ] Text contrast on background ≥ 4.5:1 (WCAG AA — check the palette tokens, not just one paragraph)

Failing any of these blocks emit. Re-run after fix.
