#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/dashboard/page.tsx')
cat > 'src/app/(app)/dashboard/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useMemo } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"

type Status = "solicitado"|"autorizado"|"validado"|"liberado"|"parcial"|"comprobado"|"rechazado"

const STATUS_CONFIG: Record<Status,{label:string,icon:string,color:string,bg:string}> = {
  solicitado:  { label:"Por aprobar",    icon:"📨", color:"var(--warn)",    bg:"var(--warn-soft)"    },
  autorizado:  { label:"Pend. Admin",    icon:"🔐", color:"#c084fc",        bg:"rgba(192,132,252,.12)"},
  validado:    { label:"Aut. Admin",     icon:"✅", color:"var(--accent)",  bg:"var(--accent-soft)"  },
  liberado:    { label:"Liberados",      icon:"💵", color:"#60a5fa",        bg:"rgba(96,165,250,.12)"},
  parcial:     { label:"Parcial",        icon:"📎", color:"#f97316",        bg:"rgba(249,115,22,.12)"},
  comprobado:  { label:"Comprobados",    icon:"🏆", color:"var(--success)", bg:"var(--success-soft)" },
  rechazado:   { label:"Rechazados",     icon:"❌", color:"var(--danger)",  bg:"var(--danger-soft)"  },
}

export default function DashboardPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [usuarios, setUsuarios] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [activeStatus, setActiveStatus] = useState<Status|null>(null)
  const [expandedId, setExpandedId] = useState<string|null>(null)
  const [userRol, setUserRol] = useState("")
  const [userId, setUserId] = useState("")

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(async ({data:{user}}) => {
      if (!user) return
      setUserId(user.id)
      const {data:perfil} = await sb.from("usuarios").select("rol").eq("id",user.id).single()
      const rol = perfil?.rol || ""
      setUserRol(rol)

      const [solRes, usrRes] = await Promise.all([
        sb.from("solicitudes")
          .select("id,tipo,concepto,monto,fecha,status,usuario_id,saldo_pendiente,anticipo_ref,comprobantes,cfdi:comprobantes_cfdi(id,uuid,emisor,total,cuenta,archivo_url)")
          .order("fecha",{ascending:false})
          .limit(500),
        sb.from("usuarios").select("id,nombre,iniciales,rol"),
      ])
      // usuario: own only | gerente/admin/tesoreria/contador: all
      const ownOnly = rol === "usuario"
      setSolicitudes(
        ownOnly
          ? (solRes.data||[]).filter((s:any) => s.usuario_id === user.id)
          : (solRes.data||[])
      )
      setUsuarios(usrRes.data||[])
      setLoading(false)
    })
  },[])

  const byStatus = useMemo(() => {
    const map: Record<string, any[]> = {}
    Object.keys(STATUS_CONFIG).forEach(s => map[s]=[])
    solicitudes.forEach(s => { if (map[s.status]) map[s.status].push(s) })
    return map
  }, [solicitudes])

  const findUser = (id:string) => usuarios.find(u=>u.id===id)

  const drillItems = activeStatus ? byStatus[activeStatus] : []

  const VALIDOS = ["liberado","comprobado"]  // KPIs: only settled amounts
  const solicitudesValidas = solicitudes.filter(s => VALIDOS.includes(s.status))
  const totalMonto = solicitudesValidas.reduce((a,s)=>a+parseFloat(s.monto||0),0)
  const saldoPendiente = solicitudes
    .filter(s=>["liberado","parcial"].includes(s.status)&&s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0)
    .reduce((a,s)=>a+parseFloat(s.saldo_pendiente||0),0)

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Workflow</h1>
          <div className="page-sub">Vista interactiva por estatus · {solicitudes.filter(s=>s.status!=="rechazado").length} activas</div>
        </div>
        {saldoPendiente > 0 && (
          <div style={{textAlign:"right"}}>
            <div style={{fontSize:20,fontWeight:700,color:"var(--warn)"}}>{fmtMXN(saldoPendiente)}</div>
            <div style={{fontSize:11,color:"var(--text-3)"}}>saldo por comprobar</div>
          </div>
        )}
      </div>

      {loading ? (
        <div style={{padding:60,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
      ) : (
        <>
          {/* ── KPI Status Cards ── */}
          <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:10,marginBottom:20}}>
            {(Object.entries(STATUS_CONFIG) as [Status,any][]).map(([status,cfg])=>{
              const items = byStatus[status]
              const monto = items.reduce((a:number,s:any)=>a+parseFloat(s.monto||0),0)
              const isActive = activeStatus===status
              return (
                <button key={status}
                  onClick={()=>setActiveStatus(isActive?null:status)}
                  style={{
                    padding:"14px 16px", borderRadius:12, border:"2px solid",
                    borderColor:isActive?cfg.color:"var(--border)",
                    background:isActive?cfg.bg:"var(--surface)",
                    cursor:"pointer", textAlign:"left", transition:"all .15s",
                    boxShadow:isActive?`0 0 0 3px ${cfg.color}22`:"none",
                  }}>
                  <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",marginBottom:6}}>
                    <span style={{fontSize:20}}>{cfg.icon}</span>
                    <span style={{fontSize:24,fontWeight:800,color:cfg.color}}>
                      {items.length}
                    </span>
                  </div>
                  <div style={{fontSize:12,fontWeight:600,color:isActive?cfg.color:"var(--text-2)"}}>{cfg.label}</div>
                  {monto > 0 && <div style={{fontSize:11,color:"var(--text-3)",marginTop:2}}>{fmtMXN(monto)}</div>}
                </button>
              )
            })}
          </div>

          {/* ── Total bar ── */}
          <div className="card" style={{marginBottom:16,padding:"10px 16px"}}>
            <div style={{display:"flex",gap:0,height:12,borderRadius:6,overflow:"hidden"}}>
              {(Object.entries(STATUS_CONFIG) as [Status,any][]).map(([status,cfg])=>{
                // Exclude rechazado from progress bar (it distorts active flow)
                if (status === "rechazado") return null
                const validTotal = solicitudes.filter(s => s.status !== "rechazado").length
                const pct = validTotal ? byStatus[status].length/validTotal*100 : 0
                if (!pct) return null
                return <div key={status} title={`${cfg.label}: ${byStatus[status].length}`}
                  style={{width:`${pct}%`,background:cfg.color,transition:"width .5s"}}/>
              })}
            </div>
            <div style={{display:"flex",gap:16,marginTop:8,flexWrap:"wrap"}}>
              {(Object.entries(STATUS_CONFIG) as [Status,any][]).map(([status,cfg])=>(
                byStatus[status].length > 0 &&
                <span key={status} style={{fontSize:11,color:"var(--text-3)",display:"flex",alignItems:"center",gap:4}}>
                  <span style={{width:8,height:8,borderRadius:"50%",background:cfg.color,display:"inline-block"}}/>
                  {cfg.label}: {byStatus[status].length}
                </span>
              ))}
            </div>
          </div>

          {/* ── Drilldown ── */}
          {activeStatus && (
            <div>
              <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:12}}>
                <div style={{fontWeight:700,fontSize:15,color:STATUS_CONFIG[activeStatus].color}}>
                  {STATUS_CONFIG[activeStatus].icon} {STATUS_CONFIG[activeStatus].label}
                  <span style={{fontWeight:400,color:"var(--text-3)",marginLeft:8,fontSize:13}}>
                    · {drillItems.length} solicitudes · {fmtMXN(drillItems.reduce((a,s)=>a+parseFloat(s.monto||0),0))}
                  </span>
                </div>
                <button onClick={()=>setActiveStatus(null)}
                  style={{background:"none",border:"none",color:"var(--text-3)",cursor:"pointer",fontSize:18}}>×</button>
              </div>

              <div style={{display:"flex",flexDirection:"column",gap:8}}>
                {drillItems.map(s => {
                  const u = findUser(s.usuario_id)
                  const isExpanded = expandedId===s.id
                  const cfdis = s.cfdi||[]
                  return (
                    <div key={s.id} className="card" style={{padding:0,overflow:"hidden"}}>
                      {/* Header row */}
                      <div style={{padding:"12px 16px",display:"flex",gap:12,alignItems:"center",cursor:"pointer"}}
                        onClick={()=>setExpandedId(isExpanded?null:s.id)}>
                        <TipoBadge tipo={s.tipo}/>
                        <div style={{flex:1,minWidth:0}}>
                          <div style={{display:"flex",alignItems:"center",gap:8}}>
                            <span className="mono" style={{fontSize:11,color:"var(--text-3)"}}>{s.id}</span>
                            {u && <span style={{fontSize:12,fontWeight:500}}>{u.nombre}</span>}
                          </div>
                          <div style={{fontSize:13,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",marginTop:2}}>
                            {s.concepto}
                          </div>
                        </div>
                        <div style={{textAlign:"right",flexShrink:0}}>
                          <div style={{fontWeight:700,fontSize:15}}>{fmtMXN(parseFloat(s.monto))}</div>
                          <div style={{fontSize:11,color:"var(--text-3)"}}>{fmtFecha(s.fecha)}</div>
                        </div>
                        <span style={{color:"var(--text-3)",fontSize:13}}>{isExpanded?"▲":"▼"}</span>
                      </div>

                      {/* Expanded detail */}
                      {isExpanded && (
                        <div style={{borderTop:"1px solid var(--border)",padding:"12px 16px",
                          background:"var(--surface-2)",display:"flex",flexDirection:"column",gap:12}}>
                          {/* Meta */}
                          <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(140px,1fr))",gap:10}}>
                            {[
                              {label:"Status",value:<StatusBadge status={s.status}/>},
                              {label:"Monto",value:fmtMXN(parseFloat(s.monto))},
                              ...(parseFloat(s.saldo_pendiente)>0?[{label:"Saldo pendiente",value:<span style={{color:"var(--warn)",fontWeight:600}}>{fmtMXN(parseFloat(s.saldo_pendiente))}</span>}]:[]),
                              {label:"Comprobantes",value:`${cfdis.length} CFDIs`},
                              {label:"Fecha",value:fmtFecha(s.fecha)},
                              ...(s.anticipo_ref?[{label:"Anticipo ref.",value:<span className="mono" style={{fontSize:11}}>{s.anticipo_ref}</span>}]:[]),
                            ].map(({label,value})=>(
                              <div key={label}>
                                <div style={{fontSize:10,color:"var(--text-3)",textTransform:"uppercase",letterSpacing:".05em",marginBottom:3}}>{label}</div>
                                <div style={{fontSize:13,fontWeight:500}}>{value}</div>
                              </div>
                            ))}
                          </div>

                          {/* CFDIs + Adjuntos */}
                          {cfdis.length>0&&(
                            <div>
                              <div style={{fontSize:11,fontWeight:600,textTransform:"uppercase",letterSpacing:".06em",color:"var(--text-3)",marginBottom:8}}>Comprobantes</div>
                              <div style={{display:"flex",flexDirection:"column",gap:4}}>
                                {cfdis.map((cf:any)=>(
                                  <div key={cf.id} style={{display:"flex",alignItems:"center",gap:10,padding:"7px 10px",
                                    background:"var(--surface)",borderRadius:8,fontSize:12}}>
                                    <span style={{fontSize:15}}>🧾</span>
                                    <span style={{flex:1,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{cf.emisor||"—"}</span>
                                    <span className="mono" style={{fontSize:10,color:"var(--text-3)"}}>{cf.cuenta}</span>
                                    <span style={{fontWeight:600}}>{fmtMXN(parseFloat(cf.total))}</span>
                                    {cf.archivo_url&&(
                                      <a href={cf.archivo_url} target="_blank" rel="noopener"
                                        className="btn sm ghost" style={{fontSize:10,padding:"2px 8px"}}>↓</a>
                                    )}
                                  </div>
                                ))}
                              </div>
                            </div>
                          )}

                          {/* Actions */}
                          <div style={{display:"flex",gap:8}}>
                            <button className="btn sm ghost" onClick={()=>router.push(`/solicitudes/${s.id}`)}>
                              Ver detalle completo →
                            </button>
                            {s.status==="solicitado"&&(userRol==="gerente"||userRol==="admin")&&(
                              <button className="btn sm primary" onClick={()=>router.push("/gerente")}>
                                Ir a bandeja
                              </button>
                            )}
                            {s.status==="autorizado"&&(userRol==="admin")&&(
                              <button className="btn sm" style={{background:"#c084fc",border:"none",color:"#111",fontWeight:600}}
                                onClick={()=>router.push("/admin/validar")}>
                                🔐 Validar →
                              </button>
                            )}
                            {s.status==="validado"&&(userRol==="tesoreria"||userRol==="admin")&&(
                              <button className="btn sm primary" onClick={()=>router.push("/tesoreria")}>
                                Liberar pago
                              </button>
                            )}
                          </div>
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>
            </div>
          )}

          {/* Empty state when no status selected */}
          {!activeStatus && (
            <div className="card" style={{padding:32,textAlign:"center",color:"var(--text-3)"}}>
              <div style={{fontSize:36,marginBottom:12}}>☝️</div>
              <div style={{fontWeight:600,fontSize:15,marginBottom:6}}>Selecciona un estatus</div>
              <div style={{fontSize:13}}>Toca cualquier tarjeta para ver el detalle de las solicitudes</div>
            </div>
          )}
        </>
      )}
    </>
  )
}


FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/page.tsx')
cat > 'src/app/(app)/solicitudes/page.tsx' << 'FILEEOF'
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/todas/page.tsx')
cat > 'src/app/(app)/solicitudes/todas/page.tsx' << 'FILEEOF'
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


FILEEOF

git add .
git commit -m "fix: KPIs only count liberado/comprobado, exclude rechazado from all totals"
git push
echo "✓ Done"