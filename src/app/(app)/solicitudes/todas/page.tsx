"use client"

import { useState, useEffect, useMemo } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"

type SortField = "fecha" | "monto" | "status" | "usuario"
type SortDir   = "asc" | "desc"

export default function TodasSolicitudesPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [usuarios,    setUsuarios]    = useState<Record<string, any>>({})
  const [loading,     setLoading]     = useState(true)

  // Filtros
  const [q,           setQ]           = useState("")
  const [filtroStatus,setFiltroStatus]= useState("todos")
  const [filtroTipo,  setFiltroTipo]  = useState("todos")
  const [filtroUser,  setFiltroUser]  = useState("todos")
  const [filtroDivision, setFiltroDivision] = useState("todos")
  const [fechaIni,    setFechaIni]    = useState("")
  const [fechaFin,    setFechaFin]    = useState("")
  const [sortField,   setSortField]   = useState<SortField>("fecha")
  const [sortDir,     setSortDir]     = useState<SortDir>("desc")

  useEffect(() => {
    const sb = createClient()
    Promise.all([
      sb.from("solicitudes")
        .select("id,tipo,concepto,monto,fecha,status,usuario_id,saldo_pendiente,anticipo_ref,comprobantes")
        .order("fecha", { ascending: false })
        .limit(1000),
      sb.from("usuarios").select("id,nombre,iniciales,rol,division,centro_id"),
    ]).then(([s, u]) => {
      const map: Record<string, any> = {}
      ;(u.data || []).forEach((usr: any) => { map[usr.id] = usr })
      setUsuarios(map)
      setSolicitudes(s.data || [])
      setLoading(false)
    })
  }, [])

  const handleSort = (field: SortField) => {
    if (sortField === field) setSortDir(d => d === "asc" ? "desc" : "asc")
    else { setSortField(field); setSortDir("desc") }
  }

  const filtradas = useMemo(() => {
    let list = [...solicitudes]

    if (q.trim()) {
      const qlo = q.toLowerCase()
      list = list.filter(s => {
        const u = usuarios[s.usuario_id]
        return s.id.toLowerCase().includes(qlo) ||
          s.concepto?.toLowerCase().includes(qlo) ||
          u?.nombre?.toLowerCase().includes(qlo)
      })
    }
    if (filtroStatus   !== "todos") list = list.filter(s => s.status === filtroStatus)
    if (filtroTipo     !== "todos") list = list.filter(s => s.tipo === filtroTipo)
    if (filtroUser     !== "todos") list = list.filter(s => s.usuario_id === filtroUser)
    if (filtroDivision !== "todos") list = list.filter(s => usuarios[s.usuario_id]?.division === filtroDivision)
    if (fechaIni) list = list.filter(s => new Date(s.fecha) >= new Date(fechaIni))
    if (fechaFin) list = list.filter(s => new Date(s.fecha) <= new Date(fechaFin + "T23:59:59"))

    // Sort
    list.sort((a, b) => {
      let av: any, bv: any
      if (sortField === "fecha")   { av = new Date(a.fecha).getTime(); bv = new Date(b.fecha).getTime() }
      if (sortField === "monto")   { av = parseFloat(a.monto); bv = parseFloat(b.monto) }
      if (sortField === "status")  { av = a.status; bv = b.status }
      if (sortField === "usuario") { av = usuarios[a.usuario_id]?.nombre || ""; bv = usuarios[b.usuario_id]?.nombre || "" }
      if (sortDir === "asc") return av > bv ? 1 : -1
      return av < bv ? 1 : -1
    })

    return list
  }, [solicitudes, usuarios, q, filtroStatus, filtroTipo, filtroUser, filtroDivision, fechaIni, fechaFin, sortField, sortDir])

  const totalFiltrado = filtradas.reduce((a, s) => a + parseFloat(s.monto || 0), 0)
  const saldoPendiente = filtradas
    .filter(s => s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0)
    .reduce((a, s) => a + parseFloat(s.saldo_pendiente), 0)

  const SortIcon = ({ field }: { field: SortField }) =>
    sortField === field ? (sortDir === "asc" ? " ↑" : " ↓") : " ·"

  const resetFiltros = () => {
    setQ(""); setFiltroStatus("todos"); setFiltroTipo("todos")
    setFiltroUser("todos"); setFiltroDivision("todos")
    setFechaIni(""); setFechaFin("")
  }

  const uniqueUsuarios = Object.values(usuarios).sort((a: any, b: any) => a.nombre.localeCompare(b.nombre))

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Todas las solicitudes</h1>
          <div className="page-sub">
            {loading ? "Cargando…" : `${filtradas.length} de ${solicitudes.length} solicitudes`}
          </div>
        </div>
        {/* KPIs rápidos */}
        {!loading && (
          <div style={{ display: "flex", gap: 16, alignItems: "flex-end", flexWrap: "wrap" }}>
            <div style={{ textAlign: "right" }}>
              <div style={{ fontSize: 18, fontWeight: 700 }}>{fmtMXN(totalFiltrado)}</div>
              <div style={{ fontSize: 11, color: "var(--text-3)" }}>monto total</div>
            </div>
            {saldoPendiente > 0 && (
              <div style={{ textAlign: "right" }}>
                <div style={{ fontSize: 18, fontWeight: 700, color: "var(--warn)" }}>
                  {fmtMXN(saldoPendiente)}
                </div>
                <div style={{ fontSize: 11, color: "var(--text-3)" }}>saldo pendiente</div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Filtros ── */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 10 }}>
          {/* Búsqueda */}
          <div style={{ gridColumn: "1 / -1" }}>
            <input className="input" placeholder="🔍 Buscar por folio, concepto o nombre…"
              value={q} onChange={e => setQ(e.target.value)} />
          </div>
          {/* Status */}
          <select className="select" value={filtroStatus} onChange={e => setFiltroStatus(e.target.value)}>
            <option value="todos">Todos los status</option>
            {["solicitado","autorizado","validado","liberado","parcial","comprobado","rechazado"].map(s => (
              <option key={s} value={s} style={{ textTransform: "capitalize" }}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </option>
            ))}
          </select>
          {/* Tipo */}
          <select className="select" value={filtroTipo} onChange={e => setFiltroTipo(e.target.value)}>
            <option value="todos">Todos los tipos</option>
            <option value="anticipo">Anticipo</option>
            <option value="comprobacion">Comprobación</option>
            <option value="reembolso">Reembolso</option>
          </select>
          {/* Usuario */}
          <select className="select" value={filtroUser} onChange={e => setFiltroUser(e.target.value)}>
            <option value="todos">Todos los usuarios</option>
            {uniqueUsuarios.map((u: any) => (
              <option key={u.id} value={u.id}>{u.nombre}</option>
            ))}
          </select>
          {/* División */}
          <select className="select" value={filtroDivision} onChange={e => setFiltroDivision(e.target.value)}>
            <option value="todos">Todas las divisiones</option>
            {["4105","4106","4111","4113"].map(d => <option key={d}>{d}</option>)}
          </select>
          {/* Fechas */}
          <input className="input" type="date" value={fechaIni} onChange={e => setFechaIni(e.target.value)}
            placeholder="Desde" title="Fecha inicio" />
          <input className="input" type="date" value={fechaFin} onChange={e => setFechaFin(e.target.value)}
            placeholder="Hasta" title="Fecha fin" />
          {/* Reset */}
          <button className="btn ghost" onClick={resetFiltros} style={{ fontSize: 12 }}>
            ↺ Limpiar filtros
          </button>
        </div>
      </div>

      {/* ── Tabla ── */}
      <div className="card" style={{ padding: 0, overflow: "auto" }}>
        {loading ? (
          <div style={{ padding: 48, textAlign: "center", color: "var(--text-3)" }}>
            Cargando solicitudes…
          </div>
        ) : filtradas.length === 0 ? (
          <div style={{ padding: 48, textAlign: "center", color: "var(--text-3)" }}>
            Sin resultados con ese filtro
          </div>
        ) : (
          <table className="t" style={{ minWidth: 860 }}>
            <thead>
              <tr>
                <th>Folio</th>
                <th style={{ cursor: "pointer" }} onClick={() => handleSort("usuario")}>
                  Usuario{SortIcon({ field: "usuario" })}
                </th>
                <th>Tipo</th>
                <th>Concepto</th>
                <th style={{ cursor: "pointer" }} onClick={() => handleSort("fecha")}>
                  Fecha{SortIcon({ field: "fecha" })}
                </th>
                <th style={{ cursor: "pointer", textAlign: "right" }} onClick={() => handleSort("monto")}>
                  Monto{SortIcon({ field: "monto" })}
                </th>
                <th className="num">Saldo</th>
                <th style={{ cursor: "pointer" }} onClick={() => handleSort("status")}>
                  Status{SortIcon({ field: "status" })}
                </th>
                <th>Div.</th>
              </tr>
            </thead>
            <tbody>
              {filtradas.map(s => {
                const u = usuarios[s.usuario_id]
                const saldo = parseFloat(s.saldo_pendiente || 0)
                return (
                  <tr key={s.id} style={{ cursor: "pointer" }}
                    onClick={() => router.push(`/solicitudes/${s.id}`)}>
                    <td className="mono" style={{ fontSize: 11, whiteSpace: "nowrap" }}>{s.id}</td>
                    <td>
                      {u ? (
                        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                          <div style={{
                            width: 26, height: 26, borderRadius: "50%", flexShrink: 0,
                            background: "var(--surface-2)", border: "1px solid var(--border)",
                            display: "grid", placeItems: "center", fontSize: 9, fontWeight: 700,
                          }}>
                            {u.iniciales}
                          </div>
                          <div>
                            <div style={{ fontSize: 12, fontWeight: 500, whiteSpace: "nowrap" }}>{u.nombre}</div>
                            <div style={{ fontSize: 10, color: "var(--text-3)", textTransform: "capitalize" }}>{u.rol}</div>
                          </div>
                        </div>
                      ) : <span className="muted">—</span>}
                    </td>
                    <td><TipoBadge tipo={s.tipo} /></td>
                    <td style={{ maxWidth: 220, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontSize: 12 }}>
                      {s.concepto}
                    </td>
                    <td className="muted" style={{ fontSize: 12, whiteSpace: "nowrap" }}>{fmtFecha(s.fecha)}</td>
                    <td className="num" style={{ fontWeight: 600, whiteSpace: "nowrap" }}>
                      {fmtMXN(parseFloat(s.monto))}
                    </td>
                    <td className="num" style={{ whiteSpace: "nowrap" }}>
                      {s.tipo === "anticipo" && saldo > 0
                        ? <span style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(saldo)}</span>
                        : <span className="muted">—</span>}
                    </td>
                    <td><StatusBadge status={s.status} /></td>
                    <td className="mono" style={{ fontSize: 11, color: "var(--text-3)" }}>
                      {u?.division || "—"}
                    </td>
                  </tr>
                )
              })}
            </tbody>
            <tfoot>
              <tr style={{ fontWeight: 700, borderTop: "2px solid var(--border)" }}>
                <td colSpan={5} style={{ padding: "10px 12px", fontSize: 12, color: "var(--text-3)" }}>
                  {filtradas.length} solicitudes
                </td>
                <td className="num" style={{ color: "var(--accent)" }}>{fmtMXN(totalFiltrado)}</td>
                <td className="num" style={{ color: saldoPendiente > 0 ? "var(--warn)" : undefined }}>
                  {saldoPendiente > 0 ? fmtMXN(saldoPendiente) : "—"}
                </td>
                <td colSpan={2} />
              </tr>
            </tfoot>
          </table>
        )}
      </div>
    </>
  )
}

