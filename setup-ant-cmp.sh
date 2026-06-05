#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/solicitudes/page.tsx')
cat > 'src/app/(app)/solicitudes/page.tsx' << 'FILEEOF'
"use client"
import React from "react"

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

  // CMPs/REEs with anticipo_ref are shown inline under their ANT — not as standalone rows
  const vinculados = new Set(solicitudes.filter(s => s.anticipoRef).map(s => s.id))
  // For each ANT, build a map to its linked comprobaciones
  const compsByAnticipo: Record<string, typeof solicitudes> = {}
  solicitudes.filter(s => s.anticipoRef).forEach(s => {
    if (!compsByAnticipo[s.anticipoRef!]) compsByAnticipo[s.anticipoRef!] = []
    compsByAnticipo[s.anticipoRef!].push(s)
  })

  const filtradas = solicitudes
    .filter(s => {
      // Hide CMPs/REEs that belong to an ANT (shown inline)
      if (s.anticipoRef && vinculados.has(s.id)) return false
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
                <React.Fragment key={s.id}>
                <tr style={{ cursor: "pointer" }}
                  onClick={() => router.push(`/solicitudes/${s.id}`)}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td><TipoBadge tipo={s.tipo} /></td>
                  <td style={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {s.concepto}
                  </td>
                  <td className="muted mono" style={{ fontSize: 12 }}>{fmtFecha(s.fecha)}</td>
                  <td className="num">
                    <div style={{ fontWeight:600 }}>{fmtMXN(s.monto)}</div>
                    {/* Show comprobacion breakdown for anticipos */}
                    {s.tipo === "anticipo" && compsByAnticipo[s.id]?.length > 0 && (() => {
                      const comps = compsByAnticipo[s.id]
                      const totalComp = comps.reduce((a,c) => a + c.monto, 0)
                      const diff = totalComp - s.monto
                      const color = diff > 0.01 ? "var(--accent)" : diff < -0.01 ? "var(--warn)" : "var(--success)"
                      const label = diff > 0.01 ? `+${fmtMXN(diff)}` : diff < -0.01 ? `−${fmtMXN(Math.abs(diff))}` : "Exacto"
                      return (
                        <div style={{ fontSize:10, marginTop:3 }}>
                          <span style={{ color:"var(--text-3)" }}>Comp: </span>
                          <span style={{ fontWeight:600 }}>{fmtMXN(totalComp)}</span>
                          <span style={{ marginLeft:4, color, fontWeight:600 }}>{label}</span>
                        </div>
                      )
                    })()}
                  </td>
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
                {s.tipo === "anticipo" && compsByAnticipo[s.id]?.map(cmp => (
                  <tr key={cmp.id}
                    style={{ cursor:"pointer", background:"var(--surface-2)", fontSize:12 }}
                    onClick={() => router.push(`/solicitudes/${cmp.id}`)}>
                    <td className="mono" style={{ fontSize:10, paddingLeft:28, color:"var(--text-3)" }}>↳ {cmp.id}</td>
                    <td><TipoBadge tipo={cmp.tipo}/></td>
                    <td style={{ fontSize:12, color:"var(--text-3)", maxWidth:200, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{cmp.concepto}</td>
                    <td className="muted mono" style={{ fontSize:11 }}>{fmtFecha(cmp.fecha)}</td>
                    <td className="num" style={{ fontWeight:600 }}>{fmtMXN(cmp.monto)}</td>
                    <td className="muted num">—</td>
                    <td><StatusBadge status={cmp.status}/></td>
                    <td/>
                  </tr>
                ))}
                </React.Fragment>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}


FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/todas/page.tsx')
cat > 'src/app/(app)/solicitudes/todas/page.tsx' << 'FILEEOF'
"use client"
import React from "react"

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

  // Build anticipo → comprobaciones map (CMPs are shown inline under their ANT)
  const compsByAnticipo = useMemo(() => {
    const map: Record<string,any[]> = {}
    solicitudes.filter(s => s.anticipo_ref).forEach(s => {
      if (!map[s.anticipo_ref]) map[s.anticipo_ref] = []
      map[s.anticipo_ref].push(s)
    })
    return map
  }, [solicitudes])

  const filtradas = useMemo(() => {
    let list = [...solicitudes]
    // Hide linked CMPs/REEs from top-level (shown as sub-rows under their ANT)
    list = list.filter(s => !s.anticipo_ref)

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

  const PAGADOS = ["liberado","comprobado"]
  const filtradas_pagadas = filtradas.filter(s => PAGADOS.includes(s.status))
  const totalFiltrado = filtradas_pagadas.reduce((a, s) => a + parseFloat(s.monto || 0), 0)
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
              {filtradas.map((s:any) => {
                const u = usuarios[s.usuario_id]
                const saldo = parseFloat(s.saldo_pendiente || 0)
                const comps = compsByAnticipo[s.id] || []
                const totalComp = comps.reduce((a:number,c:any)=>a+parseFloat(c.monto||0),0)
                const diff = s.tipo==="anticipo" && comps.length ? totalComp - parseFloat(s.monto) : 0
                const compColor = diff > 0.01 ? "var(--accent)" : diff < -0.01 ? "var(--warn)" : "var(--success)"
                return (
                  <React.Fragment key={s.id}>
                    <tr style={{ cursor:"pointer" }} onClick={() => router.push(`/solicitudes/${s.id}`)}>
                      <td className="mono" style={{ fontSize:11, whiteSpace:"nowrap" }}>{s.id}</td>
                      <td>
                        {u ? (
                          <div style={{ display:"flex", alignItems:"center", gap:8 }}>
                            <div style={{ width:26, height:26, borderRadius:"50%", flexShrink:0,
                              background:"var(--surface-2)", border:"1px solid var(--border)",
                              display:"grid", placeItems:"center", fontSize:9, fontWeight:700 }}>
                              {u.iniciales}
                            </div>
                            <div>
                              <div style={{ fontSize:12, fontWeight:500, whiteSpace:"nowrap" }}>{u.nombre}</div>
                              <div style={{ fontSize:10, color:"var(--text-3)", textTransform:"capitalize" }}>{u.rol}</div>
                            </div>
                          </div>
                        ) : <span className="muted">—</span>}
                      </td>
                      <td><TipoBadge tipo={s.tipo} /></td>
                      <td style={{ maxWidth:220, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", fontSize:12 }}>
                        {s.concepto}
                      </td>
                      <td className="muted" style={{ fontSize:12, whiteSpace:"nowrap" }}>{fmtFecha(s.fecha)}</td>
                      <td className="num" style={{ whiteSpace:"nowrap" }}>
                        <div style={{ fontWeight:600 }}>{fmtMXN(parseFloat(s.monto))}</div>
                      </td>
                      <td className="num" style={{ whiteSpace:"nowrap" }}>
                        {s.tipo==="anticipo" && comps.length > 0
                          ? <span style={{ fontWeight:600, color:compColor }}>{fmtMXN(totalComp)}</span>
                          : <span className="muted">—</span>}
                      </td>
                      <td className="num" style={{ whiteSpace:"nowrap" }}>
                        {s.tipo==="anticipo" && saldo > 0
                          ? <span style={{ color:"var(--warn)", fontWeight:600 }}>{fmtMXN(saldo)}</span>
                          : <span className="muted">—</span>}
                      </td>
                      <td><StatusBadge status={s.status} /></td>
                      <td className="mono" style={{ fontSize:11, color:"var(--text-3)" }}>
                        {u?.division || "—"}
                      </td>
                    </tr>
                    {comps.map((cmp:any) => {
                      const cu = usuarios[cmp.usuario_id]
                      return (
                        <tr key={cmp.id} style={{ cursor:"pointer", background:"var(--surface-2)" }}
                          onClick={() => router.push(`/solicitudes/${cmp.id}`)}>
                          <td className="mono" style={{ fontSize:10, paddingLeft:28, color:"var(--text-3)" }}>↳ {cmp.id}</td>
                          <td>{cu ? (
                            <div style={{ display:"flex", alignItems:"center", gap:6 }}>
                              <div style={{ width:20, height:20, borderRadius:"50%",
                                background:"var(--surface)", border:"1px solid var(--border)",
                                display:"grid", placeItems:"center", fontSize:8, fontWeight:700 }}>
                                {cu.iniciales}
                              </div>
                              <span style={{ fontSize:11 }}>{cu.nombre}</span>
                            </div>
                          ) : <span className="muted">—</span>}</td>
                          <td><TipoBadge tipo={cmp.tipo}/></td>
                          <td style={{ fontSize:11, color:"var(--text-3)", maxWidth:180, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{cmp.concepto}</td>
                          <td className="muted" style={{ fontSize:11 }}>{fmtFecha(cmp.fecha)}</td>
                          <td className="num" style={{ fontWeight:600 }}>{fmtMXN(parseFloat(cmp.monto))}</td>
                          <td className="muted num">—</td>
                          <td className="muted num">—</td>
                          <td><StatusBadge status={cmp.status}/></td>
                          <td className="mono" style={{ fontSize:10, color:"var(--text-3)" }}>{cu?.division||"—"}</td>
                        </tr>
                      )
                    })}
                  </React.Fragment>
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


FILEEOF

git add .
git commit -m "feat: anticipos show linked comprobaciones inline with monto comparison"
git push
echo "✓ Done"