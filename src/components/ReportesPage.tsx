"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

export default function ReportesPage() {
  const [data, setData] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [periodo, setPeriodo] = useState(() => new Date().toISOString().slice(0, 7))

  useEffect(() => {
    const sb = createClient()
    const desde = new Date(periodo + "-01T00:00:00").toISOString()
    const hasta = new Date(new Date(periodo + "-01").setMonth(new Date(periodo + "-01").getMonth() + 1)).toISOString()

    sb.from("solicitudes")
      .select("tipo, status, monto, saldo_pendiente, usuario_id")
      .gte("fecha", desde).lt("fecha", hasta)
      .then(({ data }) => {
        setData(data || [])
        setLoading(false)
      })
  }, [periodo])

  const total = (tipo?: string, status?: string) =>
    data.filter(s => (!tipo || s.tipo === tipo) && (!status || s.status === status))
       .reduce((a, s) => a + (parseFloat(s.monto) || 0), 0)

  const count = (tipo?: string, status?: string) =>
    data.filter(s => (!tipo || s.tipo === tipo) && (!status || s.status === status)).length

  const KPIs = [
    { label: "Anticipos liberados", value: fmtMXN(total("anticipo","liberado")), sub: count("anticipo","liberado") + " solicitudes" },
    { label: "Comprobado", value: fmtMXN(total(undefined,"comprobado")), sub: count(undefined,"comprobado") + " solicitudes" },
    { label: "Reembolsos", value: fmtMXN(total("reembolso")), sub: count("reembolso") + " solicitudes" },
    { label: "Saldo pendiente", value: fmtMXN(data.reduce((a,s)=>a+(parseFloat(s.saldo_pendiente)||0),0)),
      sub: "en anticipos abiertos", color: "var(--warn)" },
    { label: "Rechazadas", value: count(undefined,"rechazado"), sub: "solicitudes" },
    { label: "Total del período", value: fmtMXN(data.reduce((a,s)=>a+(parseFloat(s.monto)||0),0)), sub: data.length + " solicitudes" },
  ]

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Reportes</h1>
          <div className="page-sub">Resumen del período seleccionado</div>
        </div>
        <input className="input" type="month" value={periodo}
          onChange={e => setPeriodo(e.target.value)} style={{ width: 160 }} />
      </div>

      {loading ? (
        <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando…</div>
      ) : (
        <>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px,1fr))", gap: 12, marginBottom: 24 }}>
            {KPIs.map(k => (
              <div key={k.label} className="card" style={{ textAlign: "center" }}>
                <div style={{ fontSize: 22, fontWeight: 700, color: k.color }}>{k.value}</div>
                <div style={{ fontSize: 12, fontWeight: 600, marginTop: 4 }}>{k.label}</div>
                <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>{k.sub}</div>
              </div>
            ))}
          </div>

          {/* By tipo breakdown */}
          <div className="card">
            <div className="card-title" style={{ marginBottom: 14 }}>Desglose por tipo</div>
            <table className="t">
              <thead><tr><th>Tipo</th><th>Status</th><th className="num">Cantidad</th><th className="num">Monto</th></tr></thead>
              <tbody>
                {[
                  { tipo: "anticipo", status: "liberado" },
                  { tipo: "anticipo", status: "autorizado" },
                  { tipo: "comprobacion", status: "comprobado" },
                  { tipo: "comprobacion", status: "autorizado" },
                  { tipo: "reembolso", status: "comprobado" },
                  { tipo: "reembolso", status: "liberado" },
                ].filter(({ tipo, status }) => count(tipo, status) > 0).map(({ tipo, status }) => (
                  <tr key={`${tipo}-${status}`}>
                    <td><span className="badge tipo">{tipo === "anticipo" ? "ANT" : tipo === "comprobacion" ? "CMP" : "REE"}</span></td>
                    <td><span className={`badge ${status}`}>{status}</span></td>
                    <td className="num">{count(tipo, status)}</td>
                    <td className="num">{fmtMXN(total(tipo, status))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </>
  )
}

