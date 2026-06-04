import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { fmtMXN } from "@/lib/format"
import { NotifButton } from "@/components/ui/NotifButton"

export default async function PerfilPage() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  const [{ data: u }, { data: sols }] = await Promise.all([
    sb.from("usuarios").select("*, centro:centros(*), gerente:usuarios!gerente_id(nombre)").eq("id", user.id).single(),
    sb.from("solicitudes").select("id, tipo, status, monto, saldo_pendiente").eq("usuario_id", user.id),
  ])

  if (!u) redirect("/login")

  const totalAbierto = (sols || [])
    .filter(s => ["liberado","parcial"].includes(s.status) && parseFloat(s.saldo_pendiente) > 0)
    .reduce((a, s) => a + parseFloat(s.saldo_pendiente), 0)

  const ROL_COLOR: Record<string, string> = {
    admin: "var(--accent)", gerente: "var(--success)", tesoreria: "#60a5fa",
    contador: "#c084fc", usuario: "var(--text-3)",
  }

  return (
    <div style={{ maxWidth: 620 }}>
      <div className="page-head">
        <h1 className="page-title">Mi perfil</h1>
      </div>

      {/* Avatar + name */}
      <div className="card" style={{ textAlign: "center", marginBottom: 16, padding: "28px 20px" }}>
        <div style={{ width: 68, height: 68, borderRadius: "50%", margin: "0 auto 14px",
          background: "var(--accent-soft)", color: "var(--accent)",
          display: "grid", placeItems: "center", fontSize: 24, fontWeight: 700 }}>
          {u.iniciales}
        </div>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 4 }}>{u.nombre}</div>
        <div style={{ fontSize: 13, color: "var(--text-3)", marginBottom: 10 }}>{u.correo}</div>
        <span style={{ fontSize: 12, padding: "3px 14px", borderRadius: 20, fontWeight: 600,
          background: ROL_COLOR[u.rol] + "22", color: ROL_COLOR[u.rol] }}>
          {u.rol}
        </span>
      </div>

      {/* Info */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Cuenta</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
          {[
            { label: "Centro de beneficio", value: u.centro ? `${u.centro.id} · ${u.centro.nombre}` : "—" },
            { label: "Departamento", value: u.centro?.depto || "—" },
            { label: "Gerente", value: (u.gerente as any)?.nombre || "—" },
            { label: "División SAP", value: u.division || "4105" },
            { label: "Banco", value: u.banco || "—" },
            { label: "CLABE", value: u.clabe ? "•••• " + u.clabe.slice(-4) : "—" },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, color: "var(--text-3)", textTransform: "uppercase",
                letterSpacing: ".05em", marginBottom: 3 }}>{label}</div>
              <div style={{ fontSize: 13, fontWeight: 500 }}>{value}</div>
            </div>
          ))}
        </div>
        <div style={{ marginTop: 10, fontSize: 11.5, color: "var(--text-3)", fontStyle: "italic" }}>
          Para cambiar CLABE o banco, contacta a Tesorería.
        </div>
        <div style={{ marginTop: 16, paddingTop: 14, borderTop: "1px solid var(--border)" }}>
          <NotifButton/>
        </div>
        <div style={{ marginTop: 14, paddingTop: 12, borderTop: "1px solid var(--border)", fontSize: 12, color: "var(--text-3)" }}>
          Las notificaciones push se activan automáticamente al usar la app.
          Si no las recibiste, cierra y vuelve a abrir la app para ver el banner.
        </div>
      </div>

      {/* Activity summary */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Resumen de actividad</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12 }}>
          {[
            { label: "Total solicitudes", value: (sols || []).length },
            { label: "Anticipos abiertos", value: (sols || []).filter(s => s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0).length },
            { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : undefined },
          ].map(k => (
            <div key={k.label} className="card" style={{ margin: 0, textAlign: "center", padding: "12px 8px" }}>
              <div style={{ fontSize: 18, fontWeight: 700, color: k.color }}>{k.value}</div>
              <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

