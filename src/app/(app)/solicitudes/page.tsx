"use client"

import { useState, useEffect, useReducer } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import { fmtMXN, fmtFecha } from "@/lib/format"
import type { Solicitud, SolicitudStatus } from "@/types"

export default function MisSolicitudesPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)
  const [filtroTipo, setFiltroTipo] = useState("todos")
  const [filtroStatus, setFiltroStatus] = useState("todos")
  const [busqueda, setBusqueda] = useState("")

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      sb.from("solicitudes")
        .select("*, cfdi:comprobantes_cfdi(id, uuid, emisor, total, cuenta, archivo_url, rfc_emisor, rfc_receptor)")
        .eq("usuario_id", user.id)
        .order("fecha", { ascending: false })
        .then(({ data }) => {
          if (!data) { setLoading(false); return }
          setSolicitudes(data.map(s => ({
            id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
            monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha), status: s.status,
            saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
            anticipoRef: s.anticipo_ref, motivoRechazo: s.motivo_rechazo,
            cfdi: s.cfdi || [],
          })))
          setLoading(false)
        })
    })
  }, [])

  const filtradas = solicitudes
    .filter(s => {
      if (filtroTipo !== "todos" && s.tipo !== filtroTipo) return false
      if (filtroStatus !== "todos" && s.status !== filtroStatus) return false
      if (busqueda.trim()) {
        const q = busqueda.toLowerCase()
        if (!s.id.toLowerCase().includes(q) && !s.concepto.toLowerCase().includes(q)) return false
      }
      return true
    })
    .sort((a, b) => b.fecha.getTime() - a.fecha.getTime())

  const totalAbierto = solicitudes
    .filter(s => ["liberado","parcial"].includes(s.status) && (s.saldoPendiente || 0) > 0)
    .reduce((a, s) => a + (s.saldoPendiente || 0), 0)
  const totalGestionado = solicitudes
    .filter(s => ["liberado","comprobado"].includes(s.status))
    .reduce((a, s) => a + (s.monto || 0), 0)
  const enProceso = solicitudes.filter(s => ["solicitado","autorizado","validado","devuelto"].includes(s.status)).length
  const rechazadas = solicitudes.filter(s => s.status === "rechazado").length

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Mis solicitudes</h1>
          <div className="page-sub">Historial completo · {solicitudes.length} registros</div>
        </div>
        <button className="btn primary" onClick={() => router.push("/solicitudes/anticipo")}>
          + Nuevo anticipo
        </button>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 12, marginBottom: 16 }}>
        {[
          { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : "var(--success)" },
          { label: "En proceso", value: String(enProceso), color: undefined },
          { label: "Rechazadas", value: String(rechazadas), color: rechazadas > 0 ? "var(--danger)" : undefined },
        ].map(k => (
          <div key={k.label} className="card" style={{ textAlign: "center", padding: "14px 12px" }}>
            <div style={{ fontSize: 22, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: k.color }}>{k.value}</div>
            <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
          </div>
        ))}
      </div>

      {/* Filtros */}
      <div className="row" style={{ marginBottom: 14, gap: 8, flexWrap: "wrap" }}>
        <input className="input" style={{ flex: "1 1 160px" }} placeholder="Buscar por folio o concepto…"
          value={busqueda} onChange={e => setBusqueda(e.target.value)} />
        <select className="select" style={{ width: 160 }} value={filtroTipo} onChange={e => setFiltroTipo(e.target.value)}>
          <option value="todos">Todos los tipos</option>
          <option value="anticipo">Anticipos</option>
          <option value="comprobacion">Comprobaciones</option>
          <option value="reembolso">Reembolsos</option>
        </select>
        <select className="select" style={{ width: 160 }} value={filtroStatus} onChange={e => setFiltroStatus(e.target.value)}>
          <option value="todos">Todos los status</option>
          {["solicitado","autorizado","validado","liberado","parcial","comprobado","rechazado","devuelto"].map(s => (
            <option key={s} value={s} style={{ textTransform: "capitalize" }}>{s.charAt(0).toUpperCase()+s.slice(1)}</option>
          ))}
        </select>
      </div>

      {/* Tabla */}
      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando solicitudes…</div>
        ) : filtradas.length === 0 ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Sin solicitudes con ese filtro</div>
        ) : (
          <table className="t">
            <thead>
              <tr>
                <th>Folio</th><th>Tipo</th><th>Concepto</th>
                <th>Fecha</th><th className="num">Monto</th>
                <th className="num">Saldo</th><th>Status</th><th></th>
              </tr>
            </thead>
            <tbody>
              {filtradas.map(s => (
                <tr key={s.id} style={{ cursor: "pointer" }}
                  onClick={() => router.push(`/solicitudes/${s.id}`)}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td><TipoBadge tipo={s.tipo} /></td>
                  <td style={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {s.concepto}
                  </td>
                  <td className="muted mono" style={{ fontSize: 12 }}>{fmtFecha(s.fecha)}</td>
                  <td className="num">{fmtMXN(s.monto)}</td>
                  <td className="num">
                    {s.tipo === "anticipo" && (s.saldoPendiente || 0) > 0
                      ? <span style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(s.saldoPendiente!)}</span>
                      : <span className="muted">—</span>}
                  </td>
                  <td><StatusBadge status={s.status} /></td>
                  <td className="num" onClick={e => e.stopPropagation()}>
                    {s.motivoRechazo && (
                      <span title={s.motivoRechazo} style={{ color: "var(--danger)", fontSize: 12, cursor: "help" }}>⚠</span>
                    )}
                    {["liberado","parcial"].includes(s.status) && s.tipo === "anticipo" && (
                      <>
                        {s.status === "parcial" && (
                          <button className="btn sm ghost" style={{ marginLeft: 4 }}
                            onClick={() => router.push(`/solicitudes/cierre?anticipo=${s.id}`)}>
                            Cerrar
                          </button>
                        )}
                        <button className="btn sm primary" style={{ marginLeft: 4 }}
                          onClick={() => router.push(`/solicitudes/comprobacion?anticipo=${s.id}`)}>
                          Comprobar
                        </button>
                      </>
                    )}
                    {s.tipo === "reembolso" && s.status === "solicitado" && (
                      <button className="btn sm ghost" style={{ marginLeft: 4 }}
                        onClick={() => router.push(`/solicitudes/reembolso?edit=${s.id}`)}>
                        Ver
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}


