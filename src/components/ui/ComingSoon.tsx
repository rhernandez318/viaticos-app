import Link from "next/link"

const PHASE: Record<string, { fase: number; label: string }> = {
  "Bandeja de aprobaciones":    { fase: 3, label: "Flujos de aprobación" },
  "Liberar pagos":              { fase: 3, label: "Flujos de aprobación" },
  "Pagados":                    { fase: 3, label: "Flujos de aprobación" },
  "Deudores":                   { fase: 3, label: "Flujos de aprobación" },
  "Mi equipo":                  { fase: 3, label: "Flujos de aprobación" },
  "Bandeja admin":              { fase: 3, label: "Flujos de aprobación" },
  "Detalle de solicitud":       { fase: 3, label: "Flujos de aprobación" },
  "Cerrar anticipo":            { fase: 2, label: "Solicitudes" },
  "Pólizas contables":          { fase: 4, label: "Contador + Admin" },
  "Trazabilidad de póliza":     { fase: 4, label: "Contador + Admin" },
  "Validación SAT":             { fase: 4, label: "Contador + Admin" },
  "Conciliación SAT":           { fase: 4, label: "Contador + Admin" },
  "Usuarios":                   { fase: 4, label: "Contador + Admin" },
  "Centros de beneficio":       { fase: 4, label: "Contador + Admin" },
  "Catálogo":                   { fase: 4, label: "Contador + Admin" },
  "Catálogo de gastos":         { fase: 4, label: "Contador + Admin" },
  "Mi perfil":                  { fase: 4, label: "Contador + Admin" },
  "Reportes":                   { fase: 4, label: "Contador + Admin" },
}

export function ComingSoon({ title }: { title: string }) {
  const info = PHASE[title]
  return (
    <div style={{ display: "grid", placeItems: "center", minHeight: "60vh" }}>
      <div style={{ textAlign: "center", maxWidth: 400, padding: "0 20px" }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>🚧</div>
        <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 8 }}>{title}</h2>
        <p style={{ color: "var(--text-3)", fontSize: 13.5, lineHeight: 1.6, marginBottom: 20 }}>
          Esta sección está siendo migrada a Next.js.
          {info && (
            <><br />
              <span style={{ color: "var(--accent)", fontWeight: 600 }}>
                Fase {info.fase} — {info.label}
              </span>
            </>
          )}
        </p>
        <div style={{ display:"flex", gap:8, justifyContent:"center", flexWrap:"wrap" }}>
          <Link href="/dashboard" className="btn ghost" style={{ fontSize: 13 }}>
            ← Inicio
          </Link>
          <a href="https://rhernandez318.github.io/Viaticos/"
            target="_blank" rel="noopener"
            className="btn primary" style={{ fontSize: 13 }}>
            Versión actual ↗
          </a>
        </div>
      </div>
    </div>
  )
}

