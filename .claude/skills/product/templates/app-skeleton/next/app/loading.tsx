export default function Loading() {
  return (
    <div
      role="status"
      aria-label="Loading"
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        background: "var(--color-background)",
        color: "var(--color-foreground-muted)",
        fontFamily: "var(--font-sans)",
      }}
    >
      <div style={{ display: "flex", flexDirection: "column", gap: 12, alignItems: "center" }}>
        <div
          aria-hidden="true"
          style={{
            width: 32,
            height: 32,
            borderRadius: "50%",
            border: "2px solid var(--color-border)",
            borderTopColor: "var(--color-primary)",
            animation: "spin 0.8s linear infinite",
          }}
        />
        <span style={{ fontSize: "var(--text-sm)" }}>Loading…</span>
      </div>
    </div>
  );
}
