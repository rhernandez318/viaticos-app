import { createClient } from "@/lib/supabase/server"
import { redirect, notFound } from "next/navigation"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import { Stepper } from "@/components/ui/Stepper"
import Link from "next/link"

export default async function DetallePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  const { data: s } = await sb.from("solicitudes")
    .select("*, cfdi:comprobantes_cfdi(*), items:solicitud_items(*)")
    .eq("id", id)
    .single()

  if (!s) notFound()

  const { data: perfil } = await sb.from("usuarios")
    .select("nombre, iniciales, rol").eq("id", s.usuario_id).single()

  const { data: bitacora } = await sb.from("bitacora")
    .select("*, actor:usuarios!usuario_id(nombre)")
    .eq("solicitud_id", id).order("ts", { ascending: true })

  const archivos = (s.cfdi || []).filter((c: any) => c.archivo_url)

  const dates: Record<string, Date | null> = {}
  ;(bitacora || []).forEach((b: any) => { dates[b.accion] = new Date(b.ts) })

  return (
    <div style={{ maxWidth: 780 }}>
      {/* Header */}
      <div className="page-head">
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
            <TipoBadge tipo={s.tipo} />
            <StatusBadge status={s.status} />
            {s.notas?.includes("CIERRE_DEPOSITO") && (
              <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 12,
                background: "var(--accent-soft)", color: "var(--accent)", fontWeight: 600 }}>
                🏦 CIERRE
              </span>
            )}
          </div>
          <h1 className="page-title" style={{ fontSize: 20 }}>{id}</h1>
          <p className="page-sub">{s.concepto}</p>
        </div>
        <Link href="/solicitudes" className="btn ghost">← Mis solicitudes</Link>
      </div>

      {/* Stepper */}
      <div className="card" style={{ marginBottom: 16 }}>
        <Stepper status={s.status} dates={dates} />
      </div>

      {/* Info grid */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16 }}>
          {[
            { label: "Solicitante", value: perfil?.nombre || "—" },
            { label: "Fecha", value: fmtFecha(s.fecha) },
            { label: "Monto", value: fmtMXN(parseFloat(s.monto)) },
            ...(s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0 ? [
              { label: "Saldo pendiente", value: fmtMXN(parseFloat(s.saldo_pendiente)) }
            ] : []),
            ...(s.anticipo_ref ? [{ label: "Anticipo ref.", value: s.anticipo_ref }] : []),
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, color: "var(--text-3)", textTransform: "uppercase",
                letterSpacing: ".05em", marginBottom: 4 }}>{label}</div>
              <div style={{ fontWeight: 600, fontSize: 14 }}>{value}</div>
            </div>
          ))}
        </div>
        {s.motivo_rechazo && (
          <div style={{ marginTop: 14, padding: "10px 12px", borderRadius: 8,
            background: "var(--danger-soft)", color: "var(--danger)", fontSize: 13 }}>
            ✕ Motivo de rechazo: {s.motivo_rechazo}
          </div>
        )}
      </div>

      {/* CFDIs */}
      {s.cfdi && s.cfdi.length > 0 && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div className="card-title" style={{ marginBottom: 12 }}>
            Comprobantes · {s.cfdi.length}
          </div>
          <table className="t">
            <thead>
              <tr>
                <th>UUID</th><th>Emisor</th><th>Cuenta / Nombre</th><th>Comentarios</th>
                <th className="num">Total</th><th>SAT</th><th></th>
              </tr>
            </thead>
            <tbody>
              {s.cfdi.map((cf: any) => (
                <tr key={cf.id}>
                  <td className="mono" style={{ fontSize: 10 }}>
                    {cf.uuid ? cf.uuid.slice(0, 20) + "…" : "—"}
                  </td>
                  <td style={{ fontSize: 12 }}>{cf.emisor || "—"}</td>
                  <td style={{ fontSize: 11 }}>
                    <div className="mono" style={{ color:"var(--text-3)" }}>{cf.cuenta}</div>
                    {cf.nombre_cuenta && <div style={{ fontSize:10, color:"var(--text-3)", marginTop:1 }}>{cf.nombre_cuenta}</div>}
                  </td>
                  <td style={{ fontSize: 11, color: cf.observaciones ? "var(--text-2)" : "var(--text-3)", maxWidth:180 }}>
                    {cf.observaciones || <span className="muted">—</span>}
                  </td>
                  <td className="num">{fmtMXN(parseFloat(cf.total))}</td>
                  <td>
                    {cf.sat_estado && (
                      <span style={{ fontSize: 10, padding: "2px 7px", borderRadius: 10, fontWeight: 600,
                        background: cf.sat_estado === "Vigente" ? "var(--success-soft)" : "var(--warn-soft)",
                        color: cf.sat_estado === "Vigente" ? "var(--success)" : "var(--warn)" }}>
                        {cf.sat_estado}
                      </span>
                    )}
                  </td>
                  <td>
                    {cf.archivo_url && (
                      <a href={cf.archivo_url} target="_blank" rel="noopener"
                        className="btn sm ghost" style={{ fontSize: 11 }}>
                        ↓
                      </a>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Bitácora */}
      {bitacora && bitacora.length > 0 && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div className="card-title" style={{ marginBottom: 14 }}>Línea de tiempo</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 0 }}>
            {bitacora.map((b: any, i: number) => (
              <div key={b.id} style={{ display: "flex", gap: 14, paddingBottom: i < bitacora.length - 1 ? 16 : 0,
                position: "relative" }}>
                {i < bitacora.length - 1 && (
                  <div style={{ position: "absolute", left: 11, top: 24, width: 2,
                    height: "calc(100% - 8px)", background: "var(--border)" }} />
                )}
                <div style={{ width: 24, height: 24, borderRadius: "50%", flexShrink: 0,
                  background: b.accion === "rechazado" ? "var(--danger)" :
                               b.accion === "comprobado" ? "var(--success)" : "var(--accent)",
                  display: "grid", placeItems: "center", fontSize: 10, color: "#111",
                  fontWeight: 700, position: "relative", zIndex: 1 }}>
                  {i + 1}
                </div>
                <div style={{ flex: 1, paddingTop: 3 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, textTransform: "capitalize" }}>
                    {b.accion}
                  </div>
                  <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 1 }}>
                    {b.actor?.nombre || "Sistema"} · {fmtFecha(b.ts)}
                  </div>
                  {b.detalle && (
                    <div style={{ fontSize: 11, color: "var(--text-2)", marginTop: 2 }}>{b.detalle}</div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}


