import Link from "next/link"

export default function NotFound() {
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "var(--bg)" }}>
      <div style={{ textAlign: "center", padding: "0 20px" }}>
        <div style={{ fontSize: 64, marginBottom: 16 }}>🚧</div>
        <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Página en construcción</h1>
        <p style={{ color: "var(--text-3)", fontSize: 14, marginBottom: 24 }}>
          Esta sección se está migrando a la nueva versión.
        </p>
        <Link href="/dashboard" className="btn primary">← Volver al inicio</Link>
      </div>
    </div>
  )
}

