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
    // Notify solicitante
    try {
      await sb.from("notificaciones").insert({
        usuario_id: s.usuario, titulo: "Solicitud autorizada",
        cuerpo: `Tu solicitud ${id} fue autorizada`, tipo: "aprobacion",
        leida: false, created_at: new Date().toISOString(),
      })
    } catch {}

    // Notify all admins — push + in-app
    try {
      const { data: admins } = await sb.from("usuarios")
        .select("id").eq("rol","admin").eq("activo",true)
      if (admins?.length) {
        const solicitante = usuarios[s.usuario]
        // Push notification
        await notifyUsers(
          admins.map((a:any) => a.id),
          "🔐 Solicitud pendiente de validación",
          `${solicitante?.nombre || "Usuario"} · ${fmtMXN(s.monto)} — requiere tu validación admin`,
          "/admin/validar"
        )
        // In-app bell notification for each admin
        await sb.from("notificaciones").insert(
          admins.map((a:any) => ({
            usuario_id: a.id,
            titulo: "🔐 Pendiente: validación admin",
            cuerpo: `${solicitante?.nombre || "Usuario"} · ${fmtMXN(s.monto)} · ${s.concepto}`,
            tipo: "aprobacion",
            leida: false,
            solicitud_id: id,
            created_at: new Date().toISOString(),
          }))
        )
      }
    } catch(e) { console.warn("[Notify admins]", e) }

    setSolicitudes(prev => prev.filter(x => x.id !== id))
    setProcesando(null)
  }

  const rechazar = async (id: string, devolver = false) => {
    if (!motivoRechazo.trim()) { alert("Escribe el motivo de rechazo"); return }
    setProcesando(id)
    const sb = createClient()
    const s = solicitudes.find(x => x.id === id)
    const newStatus = devolver ? "devuelto" : "rechazado"
    await sb.from("solicitudes")
      .update({
        status: newStatus,
        motivo_rechazo: motivoRechazo.trim(),
        // Reset saldo_pendiente to 0 on rejected anticipos
        ...(newStatus === "rechazado" && s?.tipo === "anticipo" ? { saldo_pendiente: 0 } : {}),
      })
      .eq("id", id)
    await sb.from("bitacora").insert({
      solicitud_id: id, accion: newStatus, usuario_id: userId,
      detalle: (s?.tipo==="comprobacion"?"Devuelto para corrección: ":"Rechazado: ") + motivoRechazo.trim(), ts: new Date().toISOString(),
    })
    try {
      await sb.from("notificaciones").insert({
        usuario_id: s?.usuario,
        titulo: devolver ? "⚠ Solicitud devuelta para corrección" : "❌ Solicitud rechazada",
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
              {solicitudes.find(s=>s.id===rechazandoId)?.tipo !== "anticipo" && (
                <button className="btn" style={{background:"var(--warn)",border:"none",color:"#fff",fontWeight:600}}
                  onClick={()=>rechazar(rechazandoId, true)} disabled={!!procesando}>
                  ↩ Devolver para corrección
                </button>
              )}
              <button className="btn" style={{background:"var(--danger)",border:"none",color:"#fff"}}
                onClick={()=>rechazar(rechazandoId, false)} disabled={!!procesando}>
                {procesando?"Procesando…":"Rechazar definitivo"}
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

mkdir -p $(dirname 'src/app/(app)/admin/validar/page.tsx')
cat > 'src/app/(app)/admin/validar/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { TipoBadge } from "@/components/ui/StatusBadge"
import { notifyUsers } from "@/lib/notify"
import type { Solicitud } from "@/types"

export default function AdminValidarPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [usuarios,    setUsuarios]    = useState<Record<string,any>>({})
  const [loading,     setLoading]     = useState(true)
  const [procesando,  setProcesando]  = useState<string|null>(null)
  const [rechazandoId,setRechazandoId]= useState<string|null>(null)
  const [motivo,      setMotivo]      = useState("")
  const [userId,      setUserId]      = useState<string|null>(null)

  const load = useCallback(async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return
    setUserId(user.id)
    const [solRes, usrRes] = await Promise.all([
      sb.from("solicitudes")
        .select("id,tipo,concepto,monto,fecha,status,usuario_id,saldo_pendiente")
        .eq("status","autorizado")
        .order("fecha",{ascending:true}),
      sb.from("usuarios").select("id,nombre,iniciales,rol,gerente_id"),
    ])
    const map: Record<string,any> = {}
    ;(usrRes.data||[]).forEach((u:any)=>{ map[u.id]=u })
    setUsuarios(map)
    setSolicitudes((solRes.data||[]).map((s:any)=>({
      id:s.id,tipo:s.tipo,concepto:s.concepto,usuario:s.usuario_id,
      monto:parseFloat(s.monto)||0,fecha:new Date(s.fecha),
      status:s.status,saldoPendiente:parseFloat(s.saldo_pendiente)||0,cfdi:[],
    })))
    setLoading(false)
  },[])

  useEffect(()=>{ load() },[load])

  const validar = async (id: string) => {
    setProcesando(id)
    const sb = createClient()
    const s = solicitudes.find(x=>x.id===id)
    if (!s) return
    await sb.from("solicitudes")
      .update({ status:"validado", ...(s.tipo==="anticipo"?{saldo_pendiente:s.monto}:{}) })
      .eq("id",id)
    await sb.from("bitacora").insert({
      solicitud_id:id, accion:"validado", usuario_id:userId,
      detalle:"Validado por administrador — listo para tesorería",
      ts:new Date().toISOString(),
    })
    // Notify tesorería users
    const tesoUsers = Object.values(usuarios).filter((u:any)=>u.rol==="tesoreria").map((u:any)=>u.id)
    if (tesoUsers.length) {
      await notifyUsers(tesoUsers, "💵 Nueva solicitud para liberar",
        `${usuarios[s.usuario]?.nombre||"Usuario"} · ${fmtMXN(s.monto)}`, `/tesoreria`)
    }
    // Notify the solicitante
    try {
      await sb.from("notificaciones").insert({
        usuario_id:s.usuario, titulo:"✅ Solicitud validada por admin",
        cuerpo:`Tu solicitud ${id} fue validada. Tesorería procederá con el pago.`,
        tipo:"aprobacion", leida:false, created_at:new Date().toISOString(),
      })
    } catch {}
    setSolicitudes(prev=>prev.filter(x=>x.id!==id))
    setProcesando(null)
  }

  const rechazar = async (id: string, devolver = false) => {
    if (!motivo.trim()) { alert("Escribe el motivo"); return }
    setProcesando(id)
    const sb = createClient()
    const s = solicitudes.find(x=>x.id===id)
    const newStatus = devolver ? "devuelto" : "rechazado"
    await sb.from("solicitudes")
      .update({
        status: newStatus,
        motivo_rechazo: `[Admin] ${motivo.trim()}`,
        ...(newStatus === "rechazado" && s?.tipo === "anticipo" ? { saldo_pendiente: 0 } : {}),
      })
      .eq("id",id)
    await sb.from("bitacora").insert({
      solicitud_id:id,
      accion: s?.tipo === "comprobacion" ? "devuelto" : "rechazado",
      usuario_id:userId,
      detalle:`${s?.tipo==="comprobacion"?"Devuelto para corrección":"Rechazado"} por admin: ${motivo.trim()}`,
      ts:new Date().toISOString(),
    })
    try {
      const sb2 = createClient()
      await sb2.from("notificaciones").insert({
        usuario_id:s?.usuario, titulo: s?.tipo==="comprobacion" ? "↩️ Comprobación devuelta para corrección" : "❌ Solicitud rechazada por Admin",
        cuerpo:`${motivo.trim()}`, tipo:"rechazo", leida:false,
        created_at:new Date().toISOString(),
      })
    } catch {}
    setSolicitudes(prev=>prev.filter(x=>x.id!==id))
    setRechazandoId(null); setMotivo(""); setProcesando(null)
  }

  const totalPendiente = solicitudes.reduce((a,s)=>a+s.monto,0)
  const diasPromedio = solicitudes.length>0
    ? Math.round(solicitudes.reduce((a,s)=>a+(Date.now()-s.fecha.getTime())/86400000,0)/solicitudes.length) : 0

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Validación Admin</h1>
          <div className="page-sub">Aprobación final antes de tesorería · {solicitudes.length} pendientes</div>
        </div>
        <button className="btn ghost" onClick={load}>↻ Actualizar</button>
      </div>

      {/* KPIs */}
      <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:12,marginBottom:20}}>
        {[
          {label:"Pendientes",    value:solicitudes.length,    color:solicitudes.length>0?"var(--warn)":"var(--success)"},
          {label:"Monto total",   value:fmtMXN(totalPendiente)},
          {label:"Días promedio", value:diasPromedio+"d",      color:diasPromedio>2?"var(--danger)":undefined},
        ].map(k=>(
          <div key={k.label} className="card" style={{textAlign:"center",padding:"14px 12px"}}>
            <div style={{fontSize:22,fontWeight:700,color:k.color}}>{k.value}</div>
            <div style={{fontSize:11,color:"var(--text-3)",marginTop:3}}>{k.label}</div>
          </div>
        ))}
      </div>

      {/* Modal rechazo */}
      {rechazandoId&&(
        <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center"}}>
          <div className="card" style={{width:400,maxWidth:"90vw"}}>
            <div style={{fontWeight:700,fontSize:16,marginBottom:8}}>Rechazar solicitud</div>
            <div style={{fontSize:12,color:"var(--text-3)",marginBottom:12}}>
              {solicitudes.find(s=>s.id===rechazandoId)?.concepto}
            </div>
            <textarea className="input" rows={3} value={motivo} onChange={e=>setMotivo(e.target.value)}
              placeholder="Motivo del rechazo…" style={{resize:"vertical",marginBottom:12}}/>
            <div style={{display:"flex",gap:8,justifyContent:"flex-end"}}>
              <button className="btn ghost" onClick={()=>{setRechazandoId(null);setMotivo("")}}>Cancelar</button>
              <button className="btn" style={{background:"var(--danger)",border:"none",color:"#fff"}}
                onClick={()=>rechazar(rechazandoId)} disabled={!!procesando}>
                {procesando?"Procesando…":"Rechazar"}
              </button>
            </div>
          </div>
        </div>
      )}

      {loading?(
        <div className="card" style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
      ):solicitudes.length===0?(
        <div className="card" style={{padding:48,textAlign:"center"}}>
          <div style={{fontSize:40,marginBottom:12}}>✅</div>
          <div style={{fontWeight:600,fontSize:16}}>Todo validado</div>
          <div style={{color:"var(--text-3)",fontSize:13,marginTop:6}}>No hay solicitudes pendientes de validación admin</div>
        </div>
      ):(
        <div style={{display:"flex",flexDirection:"column",gap:10}}>
          {solicitudes.map(s=>{
            const u = usuarios[s.usuario]
            const gerente = u?.gerente_id ? usuarios[u.gerente_id] : null
            const dias = Math.floor((Date.now()-s.fecha.getTime())/86400000)
            return (
              <div key={s.id} className="card" style={{cursor:"pointer"}}
                onClick={()=>router.push(`/solicitudes/${s.id}`)}>
                <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:12}}>
                  <div style={{flex:1,minWidth:0}}>
                    <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:6,flexWrap:"wrap"}}>
                      <TipoBadge tipo={s.tipo}/>
                      <span className="mono" style={{fontSize:11,color:"var(--text-3)"}}>{s.id}</span>
                      {dias>1&&<span style={{fontSize:10,padding:"1px 7px",borderRadius:10,
                        background:"var(--warn-soft)",color:"var(--warn)",fontWeight:600}}>
                        {dias}d
                      </span>}
                      {/* Already approved by gerente badge */}
                      <span style={{fontSize:10,padding:"1px 7px",borderRadius:10,
                        background:"var(--success-soft)",color:"var(--success)",fontWeight:600}}>
                        ✓ Aut. Gerente
                      </span>
                    </div>
                    {/* Solicitante */}
                    {u&&(
                      <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:4}}>
                        <div style={{width:22,height:22,borderRadius:"50%",background:"var(--accent-soft)",
                          color:"var(--accent)",display:"grid",placeItems:"center",fontSize:9,fontWeight:700}}>
                          {u.iniciales}
                        </div>
                        <span style={{fontSize:12,fontWeight:600,color:"var(--text-2)"}}>{u.nombre}</span>
                        {gerente&&<span style={{fontSize:10,color:"var(--text-3)"}}>· Ger: {gerente.nombre}</span>}
                      </div>
                    )}
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
                        onClick={()=>setRechazandoId(s.id)}>Rechazar</button>
                      <button className="btn sm primary"
                        disabled={procesando===s.id}
                        onClick={()=>validar(s.id)}>
                        {procesando===s.id?"…":"Validar ✓"}
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

git add .
git commit -m "fix: saldo_pendiente=0 on rejected anticipos"
git push
echo "✓ Done"