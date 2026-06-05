"use client"

import { useState, useEffect, useMemo } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { generarPolizas, agruparPorPoliza } from "@/lib/polizas"
import { useCatalogos } from "@/hooks/useCatalogos"
import type { Solicitud, PolizaLinea } from "@/types"

export default function ContadorPolizasPage() {
  const { catalogoGastos, centros, usuarios, loaded } = useCatalogos()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loadingData, setLoadingData] = useState(true)
  const [expanded, setExpanded] = useState<string | null>(null)

  const hoy = new Date()
  const primerDiaMes = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, "0")}-01`
  const hoyStr = hoy.toISOString().slice(0, 10)

  const [fechaIni, setFechaIni] = useState(primerDiaMes)
  const [fechaFin, setFechaFin] = useState(hoyStr)
  const [centro, setCentro] = useState("todos")

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("*, cfdi:comprobantes_cfdi(*), items:solicitud_items(*)")
      .not("status", "in", '("solicitado","rechazado")')
      .order("fecha", { ascending: false })
      .then(({ data }) => {
        const mapped: Solicitud[] = (data || []).map((s: any) => ({
          id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
          monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
          status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
          anticipoRef: s.anticipo_ref, notas: s.notas,
          esCierre: !!(s.notas && s.notas.includes("CIERRE_DEPOSITO")),
          cfdi: (s.cfdi || []).map((c: any) => ({
            uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
            total: parseFloat(c.total) || 0, cuenta: c.cuenta,
            archivoUrl: c.archivo_url, rfcEmisor: c.rfc_emisor, rfcReceptor: c.rfc_receptor,
          })),
          items: (s.items || []).map((i: any) => ({
            cuenta: i.cuenta, desc: i.descripcion, monto: parseFloat(i.monto) || 0,
          })),
        }))
        setSolicitudes(mapped)
        setLoadingData(false)
      })
  }, [])

  const polizas = useMemo(() => {
    if (!loaded || loadingData) return []
    return agruparPorPoliza(generarPolizas(solicitudes, usuarios, centros, catalogoGastos, {
      desde: new Date(fechaIni + "T00:00:00"),
      hasta: new Date(fechaFin + "T23:59:59"),
      centro,
    }))
  }, [solicitudes, usuarios, centros, catalogoGastos, fechaIni, fechaFin, centro, loaded, loadingData])

  const exportarCSV = () => {
    const headers = ["Póliza","Folio","Fecha","Centro","División","Cuenta","Nombre Cuenta","T/D","Debe","Haber","Concepto","Proveedor"]
    const rows = polizas.flatMap(p => p.movs.map((l: PolizaLinea) => [
      l.poliza, l.folio, l.fecha, l.centro, l.division,
      l.cuenta, l.nombreCuenta, l.tipo === "C" ? "Cargo" : "Abono",
      l.debe || "", l.haber || "", l.concepto, l.proveedor,
    ]))
    const csv = [headers, ...rows].map(r => r.map(v => `"${v}"`).join(",")).join("\n")
    const a = document.createElement("a")
    a.href = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }))
    a.download = `polizas_${fechaIni}_${fechaFin}.csv`
    a.click()
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Pólizas contables</h1>
          <div className="page-sub">Asientos para carga en SAP (RFBIBL00)</div>
        </div>
        <button className="btn primary" onClick={exportarCSV} disabled={polizas.length === 0}>
          ↓ Exportar CSV
        </button>
      </div>

      {/* Filters */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          {[
            { label: "Desde", value: fechaIni, set: setFechaIni },
            { label: "Hasta", value: fechaFin, set: setFechaFin },
          ].map(({ label, value, set }) => (
            <div key={label}>
              <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>{label}</label>
              <input className="input" type="date" value={value} onChange={e => set(e.target.value)}
                style={{ width: 160 }} />
            </div>
          ))}
          <div>
            <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>Centro</label>
            <select className="select" value={centro} onChange={e => setCentro(e.target.value)} style={{ width: 200 }}>
              <option value="todos">Todos los centros</option>
              {centros.map(c => <option key={c.id} value={c.id}>{c.id} · {c.nombre}</option>)}
            </select>
          </div>
        </div>
      </div>

      {/* Summary */}
      {polizas.length > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 12, marginBottom: 16 }}>
          {[
            { label: "Pólizas", value: polizas.length },
            { label: "Total debe", value: fmtMXN(polizas.reduce((a, p) => a + p.debe, 0)) },
            { label: "Total haber", value: fmtMXN(polizas.reduce((a, p) => a + p.haber, 0)) },
          ].map(k => (
            <div key={k.label} className="card" style={{ textAlign: "center", padding: "12px" }}>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{k.value}</div>
              <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>{k.label}</div>
            </div>
          ))}
        </div>
      )}

      {/* Polizas list */}
      {loadingData || !loaded ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>
          Cargando datos…
        </div>
      ) : polizas.length === 0 ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>
          Sin pólizas en el período seleccionado
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {polizas.map(p => {
            const cuadrada = Math.abs(p.debe - p.haber) < 0.01
            const isOpen = expanded === p.ref
            return (
              <div key={p.ref} className="card" style={{ padding: 0, overflow: "auto" }}>
                {/* Header */}
                <div style={{ padding: "12px 16px", display: "flex", alignItems: "center",
                  gap: 12, cursor: "pointer" }}
                  onClick={() => setExpanded(isOpen ? null : p.ref)}>
                  <span className="mono" style={{ fontSize: 12, fontWeight: 700, color: "var(--accent)" }}>
                    {p.ref}
                  </span>
                  <span className="mono" style={{ fontSize: 11, color: "var(--text-3)" }}>{p.folio}</span>
                  <span style={{ fontSize: 12, flex: 1 }}>{p.fecha}</span>
                  <span style={{ fontWeight: 600 }}>{fmtMXN(p.debe)}</span>
                  <span style={{ fontSize: 10, padding: "2px 8px", borderRadius: 10, fontWeight: 600,
                    background: cuadrada ? "var(--success-soft)" : "var(--danger-soft)",
                    color: cuadrada ? "var(--success)" : "var(--danger)" }}>
                    {cuadrada ? "✓ Cuadrada" : "⚠ Descuadrada"}
                  </span>
                  <span style={{ color: "var(--text-3)", fontSize: 12 }}>{isOpen ? "▲" : "▼"}</span>
                </div>

                {/* Movimientos */}
                {isOpen && (
                  <div style={{ borderTop: "1px solid var(--border)" }}>
                    <table className="t">
                      <thead>
                        <tr>
                          <th>Cuenta</th><th>Descripción</th><th>T/D</th>
                          <th className="num">Debe</th><th className="num">Haber</th>
                          <th>Concepto</th>
                        </tr>
                      </thead>
                      <tbody>
                        {p.movs.map((l: PolizaLinea, i: number) => (
                          <tr key={i} style={{
                            background: l.tipo === "C" ? "rgba(100,200,100,.03)" : "rgba(100,150,255,.03)"
                          }}>
                            <td className="mono" style={{ fontSize: 11 }}>{l.cuenta}</td>
                            <td style={{ fontSize: 12 }}>{l.nombreCuenta}</td>
                            <td style={{ fontSize: 11, fontWeight: 600,
                              color: l.tipo === "C" ? "var(--success)" : "var(--accent)" }}>
                              {l.tipo === "C" ? "Cargo" : "Abono"}
                            </td>
                            <td className="num">{l.debe > 0 ? fmtMXN(l.debe) : "—"}</td>
                            <td className="num">{l.haber > 0 ? fmtMXN(l.haber) : "—"}</td>
                            <td style={{ fontSize: 11, maxWidth: 200, overflow: "hidden",
                              textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{l.concepto}</td>
                          </tr>
                        ))}
                      </tbody>
                      <tfoot>
                        <tr style={{ fontWeight: 700, borderTop: "2px solid var(--border)" }}>
                          <td colSpan={3} style={{ textAlign: "right", padding: "8px 12px", fontSize: 12 }}>Total</td>
                          <td className="num">{fmtMXN(p.debe)}</td>
                          <td className="num">{fmtMXN(p.haber)}</td>
                          <td />
                        </tr>
                      </tfoot>
                    </table>

                    {/* Adjuntos */}
                    {(() => {
                      const archivos = p.movs.flatMap((l: PolizaLinea) => l._archivos || [])
                        .filter((a: any) => a.url)
                        .filter((a: any, i: number, arr: any[]) => arr.findIndex((x: any) => x.url === a.url) === i)
                      if (!archivos.length) return null
                      return (
                        <div style={{ padding: "12px 16px", borderTop: "1px solid var(--border)",
                          background: "var(--surface-2)" }}>
                          <div style={{ fontSize: 11, fontWeight: 600, textTransform: "uppercase",
                            letterSpacing: ".06em", color: "var(--text-3)", marginBottom: 8 }}>
                            Comprobantes · {archivos.length}
                          </div>
                          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                            {archivos.map((a: any, i: number) => (
                              <a key={i} href={a.url} target="_blank" rel="noopener"
                                className="btn sm ghost" style={{ fontSize: 11 }}>
                                ↓ {a.emisor || a.nombre || `Archivo ${i + 1}`}
                              </a>
                            ))}
                          </div>
                        </div>
                      )
                    })()}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}


