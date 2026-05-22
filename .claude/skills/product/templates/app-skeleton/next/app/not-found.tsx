import Link from "next/link";

export default function NotFound() {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        background: "var(--color-background)",
        color: "var(--color-foreground)",
        fontFamily: "var(--font-sans)",
        padding: 24,
      }}
    >
      <div style={{ maxWidth: 480, textAlign: "center", display: "flex", flexDirection: "column", gap: 16 }}>
        <h1 style={{ fontSize: "var(--text-2xl)", fontWeight: "var(--font-weight-bold)" }}>
          Page not found
        </h1>
        <p style={{ color: "var(--color-foreground-muted)", fontSize: "var(--text-sm)" }}>
          The page you're looking for doesn't exist or has moved.
        </p>
        <Link
          href="/"
          style={{
            background: "var(--color-primary)",
            color: "var(--color-primary-foreground)",
            padding: "10px 20px",
            borderRadius: "var(--radius-md)",
            fontWeight: "var(--font-weight-medium)",
            textDecoration: "none",
            display: "inline-block",
            width: "fit-content",
            margin: "0 auto",
          }}
        >
          Go home
        </Link>
      </div>
    </div>
  );
}
