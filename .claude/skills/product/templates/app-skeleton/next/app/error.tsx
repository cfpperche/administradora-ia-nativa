"use client";

import { useEffect } from "react";

export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div
      role="alert"
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
          Something went wrong
        </h1>
        <p style={{ color: "var(--color-foreground-muted)", fontSize: "var(--text-sm)" }}>
          {error.message || "An unexpected error occurred."}
        </p>
        <button
          type="button"
          onClick={reset}
          style={{
            background: "var(--color-primary)",
            color: "var(--color-primary-foreground)",
            border: "none",
            padding: "10px 20px",
            borderRadius: "var(--radius-md)",
            fontWeight: "var(--font-weight-medium)",
            cursor: "pointer",
            fontFamily: "inherit",
          }}
        >
          Try again
        </button>
      </div>
    </div>
  );
}
