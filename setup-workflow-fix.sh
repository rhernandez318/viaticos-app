#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/gerente/page.tsx')
cat > 'src/app/(app)/gerente/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { notifyUsers } from "@/lib/notify"
import { TipoBadge } from "@/components/ui/StatusBadge"
import type { Solicitud } from "@/types"

export default function GerenteBandejaPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [usuarios, setUsuarios] = useState<Record<string,any>>({})
  const [loading, setLoading] = useState(true)
  const [procesando, setProcesando] = useState<string | null>(null)
  const [motivoRechazo, setMotivoRechazo] = useState("")
  const [rechazandoId, setRechazandoId] = useState<string | null>(null)
  const [userId, setUserId] = useState<string | null>(null)
  const [rol, setRol] = useState<string>("")

  const loadPendientes = useCallback(async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    setUserId(user.id)
    const { data: perfil } = await sb.from("usuarios")
      .select("rol").eq("id", user.id).single()
    const userRol = perfil?.rol || ""
    setRol(userRol)

    // Load all users map for name lookup
    const { data: usrData } = await sb.from("usuarios").select("id, nombre, iniciales, rol")
    const usrMap: Record<string,any> = {}
    ;(usrData||[]).forEach((u:any) => { usrMap[u.id] = u })
    setUsuarios(usrMap)

    let query = sb.from("solicitudes")
      .select("id, tipo, concepto, monto, fecha, status, usuario_id, saldo_pendiente")
      .eq("status", "solicitado")
      .order("fecha", { ascending: true })

    if (userRol !== "admin") {
      const { data: equipo } = await sb.from("usuarios")
        .select("id").eq("gerente_id", user.id)
      const teamIds = (equipo || []).map((u: any) => u.id)
      if (teamIds.length === 0) { setLoading(false); return }
      query = query.in("usuario_id", teamIds)
    }

    const { data } = await query
    const mapped: Solicitud[] = (data || []).map((s: any) => ({
      id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
      monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
      status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0, cfdi: [],
    }))
    setSolicitudes(mapped)
    setLoading(false)
  }, [])

  useEffect(() => { loadPendientes() }, [loadPendientes])

  const aprobar = async (id: string) => {
    setProcesando(id)
    const sb = createClient()
    const s = solicitudes.find(x => x.id === id)
    if (!s) return
    await sb.from("solicitudes")
      .update({ status: "autorizado", ...(s.tipo === "anticipo" ? { saldo_pendiente: s.monto } : {}) })
      .eq("id", id)
    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "autorizado", usuario_id: userId,
      detalle: "Aprobado por gerente", ts: new Date().toISOString(),
    })
    // Insertar notificación al solicitante
    try {
      await sb.from("notificaciones").insert({
        usuario_id: s.usuario, titulo: "Solicitud autorizada",
        cuerpo: `Tu solicitud ${id} fue autorizada`, tipo: "aprobacion",
        leida: false, created_at: new Date().toISOString(),
      })
    } catch {}
    setSolicitudes(prev => prev.filter(x => x.id !== id))
    setProcesando(null)
  }

  const rechazar = async (id: string) => {
    if (!motivoRechazo.trim()) { alert("Escribe el motivo de rechazo"); return }
    setProcesando(id)
    const sb = createClient()
    const s = solicitudes.find(x => x.id === id)
    await sb.from("solicitudes")
      .update({ status: "rechazado", motivo_rechazo: motivoRechazo.trim() })
      .eq("id", id)
    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "rechazado", usuario_id: userId,
      detalle: motivoRechazo.trim(), ts: new Date().toISOString(),
    })
    try {
      await sb.from("notificaciones").insert({
        usuario_id: s?.usuario, titulo: "Solicitud rechazada",
        cuerpo: `${id}: ${motivoRechazo.trim()}`, tipo: "rechazo",
        leida: false, created_at: new Date().toISOString(),
      })
    } catch {}
    setSolicitudes(prev => prev.filter(x => x.id !== id))
    setRechazandoId(null); setMotivoRechazo(""); setProcesando(null)
  }

  const totalPendiente = solicitudes.reduce((a, s) => a + s.monto, 0)
  const diasPromedio = solicitudes.length > 0
    ? Math.round(solicitudes.reduce((a, s) => a + (Date.now() - s.fecha.getTime()) / 86400000, 0) / solicitudes.length)
    : 0

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Por aprobar</h1>
          <div className="page-sub">{solicitudes.length} solicitudes pendientes</div>
        </div>
        <button className="btn ghost" onClick={loadPendientes}>↻ Actualizar</button>
      </div>

      {/* KPIs */}
      <div style={{ display:"grid", gridTemplateColumns:"repeat(3,1fr)", gap:12, marginBottom:20 }}>
        {[
          { label:"Pendientes",     value:solicitudes.length,    color:solicitudes.length>0?"var(--warn)":"var(--success)" },
          { label:"Monto total",    value:fmtMXN(totalPendiente) },
          { label:"Días promedio",  value:diasPromedio+"d",       color:diasPromedio>3?"var(--danger)":undefined },
        ].map(k=>(
          <div key={k.label} className="card" style={{textAlign:"center",padding:"14px 12px"}}>
            <div style={{fontSize:22,fontWeight:700,color:k.color}}>{k.value}</div>
            <div style={{fontSize:11,color:"var(--text-3)",marginTop:3}}>{k.label}</div>
          </div>
        ))}
      </div>

      {/* Modal rechazo */}
      {rechazandoId && (
        <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center"}}>
          <div className="card" style={{width:400,maxWidth:"90vw"}}>
            <div style={{fontWeight:700,fontSize:16,marginBottom:14}}>Motivo de rechazo</div>
            <div style={{marginBottom:10,fontSize:13,color:"var(--text-3)"}}>
              {solicitudes.find(s=>s.id===rechazandoId)?.concepto}
            </div>
            <textarea className="input" rows={3} value={motivoRechazo}
              onChange={e=>setMotivoRechazo(e.target.value)}
              placeholder="Explica brevemente el motivo…"
              style={{resize:"vertical",marginBottom:12}}/>
            <div style={{display:"flex",gap:8,justifyContent:"flex-end"}}>
              <button className="btn ghost" onClick={()=>{setRechazandoId(null);setMotivoRechazo("")}}>Cancelar</button>
              <button className="btn" style={{background:"var(--danger)",border:"none",color:"#fff"}}
                onClick={()=>rechazar(rechazandoId)} disabled={!!procesando}>
                {procesando?"Procesando…":"Rechazar"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Lista */}
      {loading ? (
        <div className="card" style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
      ) : solicitudes.length===0 ? (
        <div className="card" style={{padding:48,textAlign:"center"}}>
          <div style={{fontSize:40,marginBottom:12}}>✅</div>
          <div style={{fontWeight:600,fontSize:16,marginBottom:6}}>Bandeja al día</div>
          <div style={{color:"var(--text-3)",fontSize:13}}>No hay solicitudes pendientes de autorizar</div>
        </div>
      ) : (
        <div style={{display:"flex",flexDirection:"column",gap:10}}>
          {solicitudes.map(s => {
            const u = usuarios[s.usuario]
            const dias = Math.floor((Date.now()-s.fecha.getTime())/86400000)
            return (
              <div key={s.id} className="card" style={{cursor:"pointer"}}
                onClick={()=>router.push(`/solicitudes/${s.id}`)}>
                <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:12}}>
                  <div style={{flex:1,minWidth:0}}>
                    {/* Tipo + folio + días */}
                    <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:6,flexWrap:"wrap"}}>
                      <TipoBadge tipo={s.tipo}/>
                      <span className="mono" style={{fontSize:11,color:"var(--text-3)"}}>{s.id}</span>
                      {dias>2&&(
                        <span style={{fontSize:10,padding:"1px 7px",borderRadius:10,
                          background:"var(--danger-soft)",color:"var(--danger)",fontWeight:600}}>
                          {dias}d esperando
                        </span>
                      )}
                    </div>
                    {/* Usuario */}
                    {u && (
                      <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:4}}>
                        <div style={{width:22,height:22,borderRadius:"50%",background:"var(--accent-soft)",
                          color:"var(--accent)",display:"grid",placeItems:"center",fontSize:9,fontWeight:700,flexShrink:0}}>
                          {u.iniciales}
                        </div>
                        <span style={{fontSize:12,fontWeight:600,color:"var(--text-2)"}}>{u.nombre}</span>
                        <span style={{fontSize:10,color:"var(--text-3)",textTransform:"capitalize"}}>{u.rol}</span>
                      </div>
                    )}
                    {/* Concepto */}
                    <div style={{fontSize:13,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>
                      {s.concepto}
                    </div>
                    <div style={{fontSize:11,color:"var(--text-3)",marginTop:2}}>{fmtFecha(s.fecha)}</div>
                  </div>
                  <div style={{textAlign:"right",flexShrink:0}}>
                    <div style={{fontSize:18,fontWeight:700,marginBottom:8}}>{fmtMXN(s.monto)}</div>
                    <div style={{display:"flex",gap:6}} onClick={e=>e.stopPropagation()}>
                      <button className="btn sm ghost"
                        style={{color:"var(--danger)",borderColor:"var(--danger)"}}
                        disabled={procesando===s.id}
                        onClick={()=>setRechazandoId(s.id)}>
                        Rechazar
                      </button>
                      <button className="btn sm primary"
                        disabled={procesando===s.id}
                        onClick={()=>aprobar(s.id)}>
                        {procesando===s.id?"…":"Aprobar ✓"}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}

FILEEOF

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

  const totalMonto = solicitudes.reduce((a,s)=>a+parseFloat(s.monto||0),0)
  const saldoPendiente = solicitudes.filter(s=>s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0)
    .reduce((a,s)=>a+parseFloat(s.saldo_pendiente||0),0)

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Workflow</h1>
          <div className="page-sub">Vista interactiva por estatus · {solicitudes.length} solicitudes</div>
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
                const pct = solicitudes.length ? byStatus[status].length/solicitudes.length*100 : 0
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

mkdir -p $(dirname 'src/components/ui/StatusBadge.tsx')
cat > 'src/components/ui/StatusBadge.tsx' << 'FILEEOF'
import type { SolicitudStatus } from "@/types"

const LABELS: Record<string, string> = {
  solicitado: "Solicitado", autorizado: "Pend. Admin", validado: "Aut. Admin",
  liberado: "Liberado", comprobado: "Comprobado", rechazado: "Rechazado", parcial: "Parcial",
}

export function StatusBadge({ status }: { status: SolicitudStatus }) {
  return <span className={`badge ${status}`}>{LABELS[status] ?? status}</span>
}

export function TipoBadge({ tipo }: { tipo: string }) {
  const map: Record<string, string> = { anticipo: "ANT", comprobacion: "CMP", reembolso: "REE" }
  return <span className="badge tipo">{map[tipo] ?? tipo}</span>
}

FILEEOF

git add .
git commit -m "fix: notify admins on gerente approval, workflow autorizado shows as Pend. Admin"
git push
echo "✓ Done"