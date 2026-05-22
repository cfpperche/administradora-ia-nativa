/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      // The SDD foundation child (002-foundation) translates docs/design-system/tokens.css
      // into the entries below. Expo runs Tailwind 3 via NativeWind 4 (the current stable RN
      // path — NativeWind 5 / Tailwind 4 is pre-release as of 2026-05), so it does NOT consume
      // the v4 @theme tokens.css directly the way the Next stack does. The var(--token, fallback)
      // form lets the skeleton render with the fallback palette until the child fills real values.
      colors: {
        primary: "var(--color-primary, #2563eb)",
        secondary: "var(--color-secondary, #64748b)",
        accent: "var(--color-accent, #f59e0b)",
        background: "var(--color-background, #ffffff)",
        foreground: "var(--color-foreground, #0f172a)",
      },
      spacing: {
        xs: "var(--space-xs, 4px)",
        sm: "var(--space-sm, 8px)",
        md: "var(--space-md, 16px)",
        lg: "var(--space-lg, 24px)",
        xl: "var(--space-xl, 32px)",
      },
    },
  },
  plugins: [],
};
