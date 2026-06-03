import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"

export default async function DashboardPage() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  // Load dashboard data server-side
  const [solicitudesRes, usuarioRes] = await Promise.all([
    sb.from("solicitudes")
      .select("id, tipo, status, monto, fecha, concepto")
      .eq("usuario_id", user.id)
      .order("fecha", { ascending: false })
      .limit(10),
    sb.from("usuarios").select("nombre, rol, iniciales").eq("id", user.id).single(),
  ])

  const solicitudes = solicitudesRes.data || []
  const perfil = usuarioRes.data

  return (
    <div>
      <div className="page-head">
        <div>
          <h1 className="page-title">Buenos días, {perfil?.nombre?.split(" ")[0]} 👋</h1>
          <p className="page-sub">Aquí está el resumen de tu actividad</p>
        </div>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 12, marginBottom: 24 }}>
        {[
          { label: "Activas", value: solicitudes.filter(s => ["solicitado","autorizado","liberado","parcial"].includes(s.status)).length, color: "var(--accent)" },
          { label: "Comprobadas", value: solicitudes.filter(s => s.status === "comprobado").length, color: "var(--success)" },
          { label: "Rechazadas", value: solicitudes.filter(s => s.status === "rechazado").length, color: "var(--danger)" },
        ].map(({ label, value, color }) => (
          <div key={label} className="card" style={{ textAlign: "center" }}>
            <div style={{ fontSize: 32, fontWeight: 700, color }}>{value}</div>
            <div style={{ fontSize: 12, color: "var(--text-3)", marginTop: 4 }}>{label}</div>
          </div>
        ))}
      </div>

      {/* Recent solicitudes */}
      <div className="card">
        <div className="card-title" style={{ marginBottom: 12 }}>Solicitudes recientes</div>
        {solicitudes.length === 0 ? (
          <div style={{ padding: "32px 0", textAlign: "center", color: "var(--text-3)" }}>
            Sin solicitudes registradas
          </div>
        ) : (
          <table className="t">
            <thead>
              <tr>
                <th>Folio</th>
                <th>Concepto</th>
                <th>Tipo</th>
                <th>Estado</th>
                <th className="num">Monto</th>
              </tr>
            </thead>
            <tbody>
              {solicitudes.map((s) => (
                <tr key={s.id}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td>{s.concepto}</td>
                  <td><span className="badge">{s.tipo}</span></td>
                  <td><span className={`badge ${s.status}`}>{s.status}</span></td>
                  <td className="num">
                    {new Intl.NumberFormat("es-MX", { style: "currency", currency: "MXN" }).format(s.monto)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
