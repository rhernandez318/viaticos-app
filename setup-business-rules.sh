#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/admin/limites/page.tsx')
cat > 'src/app/(app)/admin/limites/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

const ROLES = ["(todos)","usuario","gerente","tesoreria","contador","admin"]

export default function LimitesPage() {
  const [limites, setLimites] = useState<any[]>([])
  const [cuentas, setCuentas] = useState<any[]>([])
  const [editing, setEditing] = useState<any|null>(null)
  const [guardando, setGuardando] = useState(false)
  const [toast, setToast] = useState<string|null>(null)

  const showToast = (m:string)=>{ setToast(m); setTimeout(()=>setToast(null),3000) }
  const load = async () => {
    const sb = createClient()
    const [l,c] = await Promise.all([
      sb.from("limites_gasto").select("*").order("nombre"),
      sb.from("cuentas_contables").select("cuenta,nombre").eq("activo",true).order("cuenta"),
    ])
    setLimites(l.data||[]); setCuentas(c.data||[])
  }
  useEffect(()=>{ load() },[])

  const openNuevo = () => setEditing({ nombre:"", cuenta:null, limite_monto:null, limite_diario:null, aplica_rol:null, activo:true })

  const guardar = async () => {
    if (!editing.nombre.trim()) { showToast("⚠ Nombre requerido"); return }
    setGuardando(true)
    const sb = createClient()
    const row = {
      nombre: editing.nombre,
      cuenta: editing.cuenta||null,
      limite_monto: editing.limite_monto ? parseFloat(editing.limite_monto) : null,
      limite_diario: editing.limite_diario ? parseFloat(editing.limite_diario) : null,
      aplica_rol: editing.aplica_rol||null,
      activo: editing.activo ?? true,
    }
    const { error } = editing.id
      ? await sb.from("limites_gasto").update(row).eq("id",editing.id)
      : await sb.from("limites_gasto").insert(row)
    if (error) showToast("⚠ "+error.message)
    else { showToast("✓ Guardado"); await load() }
    setEditing(null); setGuardando(false)
  }

  const toggleActivo = async (l:any) => {
    const sb = createClient()
    await sb.from("limites_gasto").update({ activo:!l.activo }).eq("id",l.id)
    await load()
  }

  const Field = ({ label, children }: any) => (
    <div>
      <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>{label}</label>
      {children}
    </div>
  )

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Límites de gasto</h1>
          <div className="page-sub">Reglas de negocio por cuenta contable y por día</div>
        </div>
        <button className="btn primary" onClick={openNuevo}>+ Nuevo límite</button>
      </div>

      {toast&&<div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background:toast.startsWith("✓")?"var(--success-soft)":"var(--danger-soft)",
        color:toast.startsWith("✓")?"var(--success)":"var(--danger)"}}>{toast}</div>}

      {editing&&(
        <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center",padding:20}}>
          <div className="card" style={{width:"100%",maxWidth:500}}>
            <div style={{fontWeight:700,fontSize:16,marginBottom:16}}>{editing.id?"Editar":"Nuevo"} límite</div>
            <div style={{display:"grid",gap:12}}>
              <Field label="Nombre del límite *">
                <input className="input" value={editing.nombre||""} onChange={e=>setEditing({...editing,nombre:e.target.value})} placeholder="Ej: Alimentos por viaje"/>
              </Field>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:12}}>
                <Field label="Cuenta contable (opcional)">
                  <select className="select" value={editing.cuenta||""} onChange={e=>setEditing({...editing,cuenta:e.target.value||null})}>
                    <option value="">— Todas las cuentas —</option>
                    {cuentas.map((c:any)=><option key={c.cuenta} value={c.cuenta}>{c.cuenta} · {c.nombre}</option>)}
                  </select>
                </Field>
                <Field label="Aplica a rol">
                  <select className="select" value={editing.aplica_rol||""} onChange={e=>setEditing({...editing,aplica_rol:e.target.value||null})}>
                    {ROLES.map(r=><option key={r} value={r==="(todos)"?"":r}>{r}</option>)}
                  </select>
                </Field>
                <Field label="Límite por solicitud ($)">
                  <input className="input mono" type="number" min="0" value={editing.limite_monto||""} onChange={e=>setEditing({...editing,limite_monto:e.target.value})} placeholder="Sin límite"/>
                </Field>
                <Field label="Límite diario ($)">
                  <input className="input mono" type="number" min="0" value={editing.limite_diario||""} onChange={e=>setEditing({...editing,limite_diario:e.target.value})} placeholder="Sin límite"/>
                </Field>
              </div>
            </div>
            <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:16}}>
              <button className="btn ghost" onClick={()=>setEditing(null)}>Cancelar</button>
              <button className="btn primary" onClick={guardar} disabled={guardando}>{guardando?"Guardando…":"Guardar"}</button>
            </div>
          </div>
        </div>
      )}

      <div className="card" style={{padding:0,overflow:"hidden"}}>
        <table className="t">
          <thead><tr><th>Nombre</th><th>Cuenta</th><th>Rol</th><th className="num">Por solicitud</th><th className="num">Diario</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {limites.map((l:any)=>{
              const c = cuentas.find((x:any)=>x.cuenta===l.cuenta)
              return (
                <tr key={l.id} style={{opacity:l.activo?1:.5}}>
                  <td style={{fontWeight:500}}>{l.nombre}</td>
                  <td style={{fontSize:11,color:"var(--text-3)"}}>{c?`${c.cuenta} · ${c.nombre}`:"Todas"}</td>
                  <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,background:"var(--surface-2)"}}>{l.aplica_rol||"Todos"}</span></td>
                  <td className="num">{l.limite_monto?fmtMXN(l.limite_monto):"—"}</td>
                  <td className="num">{l.limite_diario?fmtMXN(l.limite_diario):"—"}</td>
                  <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,fontWeight:600,
                    background:l.activo?"var(--success-soft)":"var(--surface-2)",
                    color:l.activo?"var(--success)":"var(--text-3)"}}>{l.activo?"Activo":"Inactivo"}</span></td>
                  <td><div style={{display:"flex",gap:6}}>
                    <button className="btn sm ghost" onClick={()=>setEditing({...l})}>Editar</button>
                    <button className="btn sm ghost" style={{color:l.activo?"var(--danger)":"var(--success)"}} onClick={()=>toggleActivo(l)}>
                      {l.activo?"Desactivar":"Activar"}
                    </button>
                  </div></td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/lib/limites.ts')
cat > 'src/lib/limites.ts' << 'FILEEOF'
import { createClient } from "@/lib/supabase/client"

export interface LimiteViolacion {
  tipo: "solicitud" | "diario"
  cuenta: string
  nombreCuenta: string
  montoPropuesto: number
  limitePermitido: number
  limitNombre: string
}

export async function validarLimites(
  userId: string,
  items: Array<{ cuenta: string; monto: number; nombreCuenta?: string }>,
  fechaStr?: string
): Promise<LimiteViolacion[]> {
  if (!items.length) return []

  const sb = createClient()
  const [{ data: perfil }, { data: limites }, { data: gastosHoy }] = await Promise.all([
    sb.from("usuarios").select("rol").eq("id", userId).single(),
    sb.from("limites_gasto").select("*").eq("activo", true),
    sb.from("solicitudes")
      .select("monto, status, cfdi:comprobantes_cfdi(cuenta, total)")
      .eq("usuario_id", userId)
      .gte("fecha", new Date().toISOString().slice(0, 10) + "T00:00:00")
      .not("status", "eq", "rechazado"),
  ])

  if (!limites?.length) return []
  const rol = perfil?.rol || "usuario"
  const violaciones: LimiteViolacion[] = []

  // Group items by cuenta
  const byAccount: Record<string, number> = {}
  items.forEach(it => {
    byAccount[it.cuenta] = (byAccount[it.cuenta] || 0) + it.monto
  })
  const totalSolicitud = items.reduce((a, it) => a + it.monto, 0)

  // Calculate today's spending by account
  const gastadoHoyByCuenta: Record<string, number> = {}
  let gastadoHoyTotal = 0
  ;(gastosHoy || []).forEach((s: any) => {
    ;(s.cfdi || []).forEach((cf: any) => {
      gastadoHoyByCuenta[cf.cuenta] = (gastadoHoyByCuenta[cf.cuenta] || 0) + (parseFloat(cf.total) || 0)
      gastadoHoyTotal += parseFloat(cf.total) || 0
    })
    if (!s.cfdi?.length) {
      gastadoHoyTotal += parseFloat(s.monto) || 0
    }
  })

  for (const limite of limites) {
    // Skip if limit applies to a different role
    if (limite.aplica_rol && limite.aplica_rol !== rol) continue

    if (limite.cuenta) {
      // Per-account limits
      const montoCuenta = byAccount[limite.cuenta] || 0
      if (!montoCuenta) continue

      const nombreCuenta = items.find(i => i.cuenta === limite.cuenta)?.nombreCuenta || limite.cuenta

      // Per-request limit
      if (limite.limite_monto && montoCuenta > limite.limite_monto) {
        violaciones.push({
          tipo: "solicitud", cuenta: limite.cuenta, nombreCuenta,
          montoPropuesto: montoCuenta, limitePermitido: limite.limite_monto,
          limitNombre: limite.nombre,
        })
      }

      // Daily limit per account
      if (limite.limite_diario) {
        const totalConHoy = (gastadoHoyByCuenta[limite.cuenta] || 0) + montoCuenta
        if (totalConHoy > limite.limite_diario) {
          violaciones.push({
            tipo: "diario", cuenta: limite.cuenta, nombreCuenta,
            montoPropuesto: totalConHoy, limitePermitido: limite.limite_diario,
            limitNombre: limite.nombre,
          })
        }
      }
    } else {
      // Global limits (no specific account)
      if (limite.limite_monto && totalSolicitud > limite.limite_monto) {
        violaciones.push({
          tipo: "solicitud", cuenta: "todas", nombreCuenta: "Total solicitud",
          montoPropuesto: totalSolicitud, limitePermitido: limite.limite_monto,
          limitNombre: limite.nombre,
        })
      }
      if (limite.limite_diario) {
        const totalConHoy = gastadoHoyTotal + totalSolicitud
        if (totalConHoy > limite.limite_diario) {
          violaciones.push({
            tipo: "diario", cuenta: "todas", nombreCuenta: "Total del día",
            montoPropuesto: totalConHoy, limitePermitido: limite.limite_diario,
            limitNombre: limite.nombre,
          })
        }
      }
    }
  }

  return violaciones
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/page.tsx')
cat > 'src/app/(app)/tesoreria/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { TipoBadge } from "@/components/ui/StatusBadge"
import Link from "next/link"
import type { Solicitud } from "@/types"

export default function TesoreriaLiberarPage() {
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [usuarios, setUsuarios] = useState<Record<string,any>>({})
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [procesando, setProcesando] = useState(false)
  const [userId, setUserId] = useState<string | null>(null)

  const load = useCallback(async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return
    setUserId(user.id)

    const [solRes, usrRes] = await Promise.all([
      sb.from("solicitudes")
        .select("id, tipo, concepto, monto, fecha, status, usuario_id, saldo_pendiente, anticipo_ref")
        .eq("status", "autorizado")
        .order("fecha", { ascending: true }),
      sb.from("usuarios").select("id, nombre, iniciales"),
    ])

    const usrMap: Record<string,any> = {}
    ;(usrRes.data||[]).forEach((u:any) => { usrMap[u.id] = u })
    setUsuarios(usrMap)

    setSolicitudes((solRes.data || []).map((s: any) => ({
      id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
      monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
      status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
      anticipoRef: s.anticipo_ref, cfdi: [],
    })))
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const toggle = (id: string) => setSelected(prev => {
    const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n
  })
  const toggleAll = () => setSelected(
    selected.size === solicitudes.length ? new Set() : new Set(solicitudes.map(s => s.id))
  )

  const liberar = async () => {
    if (!selected.size) return
    setProcesando(true)
    const sb = createClient()
    for (const id of Array.from(selected)) {
      const s = solicitudes.find(x => x.id === id)
      if (!s) continue
      const newStatus = s.tipo === "comprobacion" ? "comprobado" : "liberado"
      await sb.from("solicitudes").update({ status: newStatus }).eq("id", id)
      if (s.tipo === "comprobacion" && s.anticipoRef) {
        const { data: comps } = await sb.from("solicitudes")
          .select("monto").eq("anticipo_ref", s.anticipoRef).in("status",["liberado","comprobado"])
        const { data: ant } = await sb.from("solicitudes").select("monto").eq("id", s.anticipoRef).single()
        if (ant) {
          const totalComp = (comps||[]).reduce((a:number,c:any)=>a+parseFloat(c.monto),0) + s.monto
          const saldo = Math.max(0, parseFloat(ant.monto) - totalComp)
          await sb.from("solicitudes").update({ saldo_pendiente: saldo, status: saldo<=0?"comprobado":"parcial" }).eq("id", s.anticipoRef)
        }
      }
      await sb.from("bitacora").insert({
        solicitud_id: id, accion: newStatus, usuario_id: userId,
        detalle: "Liberado por tesorería", ts: new Date().toISOString(),
      })
      // Notificar al solicitante
      try {
        await sb.from("notificaciones").insert({
          usuario_id: s.usuario, titulo: "Pago liberado",
          cuerpo: `Tu solicitud ${id} fue liberada para pago`, tipo: "liberacion",
          leida: false, created_at: new Date().toISOString(),
        })
      } catch {}
    }
    await load(); setSelected(new Set()); setProcesando(false)
  }

  const selectedTotal = solicitudes.filter(s => selected.has(s.id)).reduce((a, s) => a + s.monto, 0)
  const anticipos = solicitudes.filter(s => s.tipo === "anticipo")
  const comprobaciones = solicitudes.filter(s => ["comprobacion","reembolso"].includes(s.tipo))

  const renderCard = (s: Solicitud) => {
    const u = usuarios[s.usuario]
    return (
      <div key={s.id} className="card"
        style={{ marginBottom:8, cursor:"pointer",
          borderColor: selected.has(s.id) ? "var(--accent)" : "var(--border)",
          background: selected.has(s.id) ? "var(--accent-soft)" : "var(--surface)" }}
        onClick={() => toggle(s.id)}>
        <div style={{ display:"flex", gap:12, alignItems:"center" }}>
          <input type="checkbox" checked={selected.has(s.id)} onChange={() => toggle(s.id)}
            onClick={e => e.stopPropagation()} style={{ flexShrink:0 }}/>
          <TipoBadge tipo={s.tipo}/>
          <div style={{ flex:1, minWidth:0 }}>
            {/* Usuario */}
            {u && (
              <div style={{ display:"flex", alignItems:"center", gap:6, marginBottom:3 }}>
                <div style={{ width:20, height:20, borderRadius:"50%", flexShrink:0,
                  background:"var(--accent-soft)", color:"var(--accent)",
                  display:"grid", placeItems:"center", fontSize:8, fontWeight:700 }}>
                  {u.iniciales}
                </div>
                <span style={{ fontSize:12, fontWeight:600, color:"var(--text-2)" }}>{u.nombre}</span>
              </div>
            )}
            <div style={{ fontWeight:600, fontSize:13, overflow:"hidden",
              textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{s.concepto}</div>
            <div style={{ display:"flex", gap:6, alignItems:"center", marginTop:2 }}>
              <span style={{ fontSize:11, color:"var(--text-3)" }}>{s.id} · {fmtFecha(s.fecha)}</span>
              {s.concepto?.includes("Saldo a favor") && (
                <span style={{ fontSize:10, padding:"1px 7px", borderRadius:10, fontWeight:600,
                  background:"var(--accent-soft)", color:"var(--accent)" }}>
                  💰 Saldo a favor
                </span>
              )}
            </div>
          </div>
          <div style={{ fontWeight:700, fontSize:16, flexShrink:0 }}>
            {fmtMXN(s.monto)}
          </div>
        </div>
      </div>
    )
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Liberar pagos</h1>
          <div className="page-sub">{solicitudes.length} autorizadas pendientes de dispersión</div>
        </div>
        <div style={{ display:"flex", gap:8 }}>
          <Link href="/tesoreria/pagados" className="btn ghost">Pagados</Link>
          <Link href="/tesoreria/deudores" className="btn ghost">Deudores</Link>
        </div>
      </div>

      {selected.size > 0 && (
        <div style={{ padding:"12px 16px", background:"var(--accent-soft)",
          border:"1px solid var(--accent)", borderRadius:10, marginBottom:16,
          display:"flex", alignItems:"center", justifyContent:"space-between" }}>
          <div style={{ fontSize:13, fontWeight:600 }}>
            {selected.size} seleccionada{selected.size>1?"s":""} · {fmtMXN(selectedTotal)}
          </div>
          <button className="btn primary" onClick={liberar} disabled={procesando}>
            {procesando ? "Liberando…" : `Liberar ${selected.size} ✓`}
          </button>
        </div>
      )}

      {loading ? (
        <div className="card" style={{ padding:40, textAlign:"center", color:"var(--text-3)" }}>Cargando…</div>
      ) : solicitudes.length === 0 ? (
        <div className="card" style={{ padding:48, textAlign:"center" }}>
          <div style={{ fontSize:40, marginBottom:12 }}>✅</div>
          <div style={{ fontWeight:600, fontSize:16 }}>Todo liberado</div>
          <div style={{ color:"var(--text-3)", fontSize:13, marginTop:6 }}>Sin pagos pendientes</div>
        </div>
      ) : (
        <>
          <button className="btn ghost" style={{ fontSize:12, marginBottom:12 }} onClick={toggleAll}>
            {selected.size === solicitudes.length ? "Deseleccionar todo" : "Seleccionar todo"}
          </button>
          {anticipos.length > 0 && (
            <div style={{ marginBottom:16 }}>
              <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
                letterSpacing:".06em", color:"var(--text-3)", marginBottom:8 }}>
                Anticipos para dispersión SPEI · {anticipos.length}
              </div>
              {anticipos.map(renderCard)}
            </div>
          )}
          {comprobaciones.length > 0 && (
            <div>
              <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
                letterSpacing:".06em", color:"var(--text-3)", marginBottom:8 }}>
                Comprobaciones y reembolsos · {comprobaciones.length}
              </div>
              {comprobaciones.map(renderCard)}
            </div>
          )}
        </>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/layout/AppShell.tsx')
cat > 'src/components/layout/AppShell.tsx' << 'FILEEOF'
"use client"

import { usePathname } from "next/navigation"
import Link from "next/link"
import Image from "next/image"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"
import { ThemePanel } from "@/components/ui/ThemePanel"
import { NotificationBell } from "@/components/ui/NotificationBell"
import { PushNotifications } from "@/components/ui/PushNotifications"
import { useState } from "react"

interface NavItem { id: string; label: string; icon: string; href: string }

const NAV_BY_ROL: Record<string, NavItem[]> = {
  usuario: [
    { id:"dashboard",   label:"Inicio",             icon:"🏠", href:"/dashboard" },
    { id:"anticipo",    label:"Solicitar anticipo",  icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",   label:"Reembolso",           icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"solicitudes", label:"Mis solicitudes",     icon:"📋", href:"/solicitudes" },
    { id:"perfil",      label:"Mi perfil",           icon:"⚙️", href:"/perfil" },
  ],
  gerente: [
    { id:"bandeja",      label:"Por aprobar",        icon:"✅", href:"/gerente" },
    { id:"equipo",       label:"Mi equipo",           icon:"👥", href:"/gerente/equipo" },
    { id:"anticipo",     label:"Anticipo",            icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",    label:"Reembolso",           icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"comprobacion", label:"Comprobaciones",      icon:"📎", href:"/solicitudes/comprobacion" },
    { id:"solicitudes",  label:"Mis solicitudes",     icon:"📋", href:"/solicitudes" },
    { id:"reportes",     label:"Reportes",            icon:"📊", href:"/gerente/reportes" },
    { id:"perfil",       label:"Mi perfil",           icon:"⚙️", href:"/perfil" },
  ],
  tesoreria: [
    { id:"workflow",  label:"Workflow",         icon:"🗂", href:"/dashboard" },
    { id:"todas",     label:"Todas las sol.",   icon:"📂", href:"/solicitudes/todas" },
    { id:"liberar",   label:"Liberar pagos",    icon:"💵", href:"/tesoreria" },
    { id:"pagados",  label:"Pagados",        icon:"✅", href:"/tesoreria/pagados" },
    { id:"deudores", label:"Deudores",       icon:"⚑",  href:"/tesoreria/deudores" },
    { id:"reportes", label:"Reportes",       icon:"📊", href:"/tesoreria/reportes" },
    { id:"perfil",   label:"Mi perfil",      icon:"⚙️", href:"/perfil" },
  ],
  contador: [
    { id:"workflow",         label:"Workflow",             icon:"🗂", href:"/dashboard" },
    { id:"todas",            label:"Todas las sol.",      icon:"📂", href:"/solicitudes/todas" },
    { id:"polizas",          label:"Pólizas contables",   icon:"📒", href:"/contador/polizas" },
    { id:"trazabilidad",     label:"Trazabilidad",       icon:"🔍", href:"/contador/trazabilidad" },
    { id:"validacion-sat",   label:"Validación SAT",     icon:"🛡", href:"/contador/validacion-sat" },
    { id:"conciliacion-sat", label:"Conciliación SAT",   icon:"📊", href:"/contador/conciliacion-sat" },
    { id:"reportes",         label:"Reportes",           icon:"📊", href:"/contador/reportes" },
    { id:"catalogo",         label:"Catálogo",           icon:"📋", href:"/contador/catalogo" },
    { id:"perfil",           label:"Mi perfil",          icon:"⚙️", href:"/perfil" },
  ],
  admin: [
    { id:"dashboard",    label:"Inicio",           icon:"🏠", href:"/dashboard" },
    { id:"bandeja",      label:"Por aprobar",       icon:"✅", href:"/gerente" },
    { id:"liberar",      label:"Liberar pagos",     icon:"💵", href:"/tesoreria" },
    { id:"anticipo",     label:"Anticipo",          icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",    label:"Reembolso",         icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"comprobacion", label:"Comprobaciones",    icon:"📎", href:"/solicitudes/comprobacion" },
    { id:"solicitudes",  label:"Mis solicitudes",   icon:"📋", href:"/solicitudes" },
    { id:"todas",         label:"Todas las sol.",    icon:"📂", href:"/solicitudes/todas" },
    { id:"usuarios",     label:"Usuarios",          icon:"👥", href:"/admin/usuarios" },
    { id:"centros",      label:"Centros",           icon:"🏢", href:"/admin/centros" },
    { id:"catalogo",     label:"Catálogo",          icon:"📋", href:"/admin/catalogo" },
    { id:"reportes",     label:"Reportes",          icon:"📊", href:"/admin/reportes" },
    { id:"polizas",      label:"Pólizas",           icon:"📒", href:"/contador/polizas" },
    { id:"perfil",       label:"Mi perfil",         icon:"⚙️", href:"/perfil" },
  ],
}

export default function AppShell({ user, children }: { user: any; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const navItems = NAV_BY_ROL[user.rol] || []
  const [showUserMenu, setShowUserMenu] = useState(false)

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href)

  const handleLogout = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  return (
    <div className="app-layout">
      {/* ── Sidebar (desktop) ──────────────────────────────── */}
      <aside className="sidebar">
        <div style={{ padding:"8px 12px 16px", display:"flex", alignItems:"center", gap:10 }}>
          <Image src="/logo.png" alt="Grupo Zapata" width={36} height={36}
            style={{ borderRadius:8, objectFit:"cover" }} />
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ fontSize:13, fontWeight:700, letterSpacing:"-0.02em" }}>Grupo Zapata</div>
            <div style={{ fontSize:10, color:"var(--text-3)" }}>Viáticos</div>
          </div>
          <div style={{ display:"flex", gap:4, alignItems:"center" }}>
            <NotificationBell userId={user.id}/>
            <ThemePanel/>
          </div>
        </div>

        <nav style={{ flex:1, display:"flex", flexDirection:"column", gap:1 }}>
          {navItems.map(item => (
            <Link key={item.id} href={item.href}
              className={`nav-item ${isActive(item.href) ? "active" : ""}`}>
              <span style={{ fontSize:15, width:20, textAlign:"center" }}>{item.icon}</span>
              {item.label}
            </Link>
          ))}
        </nav>

        <div style={{ borderTop:"1px solid var(--border)", paddingTop:12, marginTop:8 }}>
          <div style={{ display:"flex", alignItems:"center", gap:10, padding:"6px 12px" }}>
            <div style={{ width:30, height:30, borderRadius:"50%", background:"var(--accent-soft)",
              color:"var(--accent)", display:"grid", placeItems:"center", fontSize:12, fontWeight:700 }}>
              {user.iniciales}
            </div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontSize:12, fontWeight:500, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                {user.nombre}
              </div>
              <div style={{ fontSize:10, color:"var(--text-3)", textTransform:"capitalize" }}>{user.rol}</div>
            </div>
          </div>
          <button className="btn ghost" onClick={handleLogout}
            style={{ width:"100%", justifyContent:"center", fontSize:12, marginTop:4, gap:6 }}>
            🚪 Cerrar sesión
          </button>
        </div>
      </aside>

      {/* ── Push notifications (registers FCM + shows toasts) */}
      <PushNotifications userId={user.id}/>

      {/* ── Mobile bottom nav ──────────────────────────────── */}
      <nav className="mobile-nav">
        {navItems.slice(0, 4).map(item => (
          <Link key={item.id} href={item.href}
            className={`mobile-nav-item ${isActive(item.href) ? "active" : ""}`}>
            <span className="icon">{item.icon}</span>
            <span className="label">{item.label.split(" ")[0]}</span>
          </Link>
        ))}
        {/* User menu button (mobile) */}
        <button className={`mobile-nav-item ${showUserMenu ? "active" : ""}`}
          onClick={() => setShowUserMenu(!showUserMenu)}>
          <span className="icon">👤</span>
          <span className="label">Cuenta</span>
        </button>
      </nav>

      {/* ── Mobile user menu ───────────────────────────────── */}
      {showUserMenu && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:80, background:"rgba(0,0,0,.5)" }}
            onClick={() => setShowUserMenu(false)}/>
          <div style={{ position:"fixed", bottom:65, left:0, right:0, zIndex:90,
            background:"var(--surface)", borderTop:"1px solid var(--border)",
            borderRadius:"20px 20px 0 0", padding:"16px 20px 24px",
            boxShadow:"0 -8px 32px rgba(0,0,0,.4)" }}>
            <div style={{ width:36, height:4, borderRadius:2, background:"var(--border)",
              margin:"0 auto 16px" }}/>
            {/* User info */}
            <div style={{ display:"flex", alignItems:"center", gap:12, marginBottom:16 }}>
              <div style={{ width:42, height:42, borderRadius:"50%", background:"var(--accent-soft)",
                color:"var(--accent)", display:"grid", placeItems:"center",
                fontSize:15, fontWeight:700 }}>
                {user.iniciales}
              </div>
              <div>
                <div style={{ fontWeight:600 }}>{user.nombre}</div>
                <div style={{ fontSize:12, color:"var(--text-3)", textTransform:"capitalize" }}>{user.rol}</div>
              </div>
            </div>
            {/* Nav items */}
            <div style={{ display:"flex", flexDirection:"column", gap:4, marginBottom:12 }}>
              {[
                { id:"perfil", label:"Mi perfil", icon:"⚙️", href:"/perfil" } as NavItem,
                ...navItems.slice(4).filter(i => i.id !== "perfil"),
              ].map(item => (
                <Link key={item.id} href={item.href}
                  onClick={() => setShowUserMenu(false)}
                  style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                    borderRadius:10, color:"var(--text)", textDecoration:"none",
                    background: isActive((item as any).href) ? "var(--accent-soft)" : "transparent" }}>
                  <span style={{ fontSize:18 }}>{item.icon}</span>
                  <span style={{ fontSize:14 }}>{item.label}</span>
                </Link>
              ))}
            </div>
            <div style={{ height:1, background:"var(--border)", margin:"8px 0 12px" }}/>
            <button onClick={handleLogout}
              style={{ width:"100%", padding:"12px", borderRadius:10, border:"none",
                background:"var(--danger-soft)", color:"var(--danger)",
                fontSize:14, fontWeight:600, cursor:"pointer", display:"flex",
                alignItems:"center", justifyContent:"center", gap:8 }}>
              🚪 Cerrar sesión
            </button>
          </div>
        </>
      )}

      {/* ── Top bar mobile (bell + theme) ─────────────────── */}
      <div className="mobile-topbar">
        <div style={{ display:"flex", alignItems:"center", gap:8 }}>
          <Image src="/logo.png" alt="GZ" width={24} height={24} style={{ borderRadius:4, objectFit:"cover" }}/>
          <span style={{ fontSize:13, fontWeight:700 }}>Grupo Zapata</span>
        </div>
        <div style={{ display:"flex", gap:6 }}>
          <NotificationBell userId={user.id}/>
          <ThemePanel/>
        </div>
      </div>

      {/* ── Main content ───────────────────────────────────── */}
      <main className="main-content">
        {children}
      </main>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/globals.css')
cat > 'src/app/globals.css' << 'FILEEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ── Design tokens (same as current app) ──────────────────────────────────── */
:root {
  --bg:          #0d0d0d;
  --surface:     #161616;
  --surface-2:   #1c1c1c;
  --border:      #2a2a2a;
  --text:        #f0f0f0;
  --text-2:      #b0b0b0;
  --text-3:      #606060;
  --accent:      #c5f24d;
  --accent-soft: rgba(197,242,77,.12);
  --success:     #4ade80;
  --success-soft:rgba(74,222,128,.12);
  --danger:      #e24b4a;
  --danger-soft: rgba(226,75,74,.12);
  --warn:        #f59e0b;
  --warn-soft:   rgba(245,158,11,.12);
  --r-sm:        6px;
  --r-md:        8px;
  --r-lg:        12px;
  --r-xl:        16px;
  --f-display:   "Geist", system-ui, sans-serif;
}

.light {
  --bg:       #f5f5f0;
  --surface:  #ffffff;
  --surface-2:#f0f0ec;
  --border:   #ddddd8;
  --text:     #1a1a1a;
  --text-2:   #444444;
  --text-3:   #999999;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--f-display);
  font-size: 14px;
  min-height: 100vh;
}

/* ── Shared component styles ─────────────────────────────────────────────── */
.btn {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 8px 14px; border-radius: var(--r-md);
  border: 1px solid var(--border); background: var(--surface);
  color: var(--text); font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all .15s;
}
.btn:hover { border-color: var(--text-3); }
.btn.primary { background: var(--accent); border-color: var(--accent); color: #111; }
.btn.primary:hover { opacity: .9; }
.btn.ghost { background: transparent; }
.btn.sm { padding: 5px 10px; font-size: 12px; }
.btn:disabled { opacity: .5; cursor: not-allowed; }

.card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-lg); padding: 16px;
}
.card-title { font-weight: 600; font-size: 13px; color: var(--text-2); letter-spacing: .05em; text-transform: uppercase; }

.input, .select {
  width: 100%; padding: 8px 10px;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-md); color: var(--text); font-size: 13px;
  outline: none; transition: border-color .15s;
}
.input:focus, .select:focus { border-color: var(--accent); }

.badge {
  display: inline-flex; align-items: center;
  padding: 2px 10px; border-radius: 20px;
  font-size: 11px; font-weight: 600;
}
.badge.solicitado { background: rgba(245,158,11,.15); color: var(--warn); }
.badge.autorizado { background: var(--accent-soft); color: var(--accent); }
.badge.liberado   { background: rgba(96,165,250,.15); color: #60a5fa; }
.badge.comprobado { background: var(--success-soft); color: var(--success); }
.badge.rechazado  { background: var(--danger-soft); color: var(--danger); }
.badge.parcial    { background: rgba(245,158,11,.15); color: var(--warn); }

.t { width: 100%; border-collapse: collapse; font-size: 13px; }
.t th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600;
        color: var(--text-3); border-bottom: 1px solid var(--border); white-space: nowrap; }
.t td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
.t tbody tr:hover { background: var(--surface-2); }
.t .num { text-align: right; font-variant-numeric: tabular-nums; font-family: monospace; }
.mono { font-family: monospace; }
.muted { color: var(--text-3); }
.spread { display: flex; align-items: center; justify-content: space-between; }
.row { display: flex; align-items: center; gap: 8px; }
.divider { height: 1px; background: var(--border); }

/* ── Sidebar layout ──────────────────────────────────────────────────────── */
.app-layout {
  display: grid;
  grid-template-columns: 220px 1fr;
  min-height: 100vh;
}
.sidebar {
  background: var(--surface); border-right: 1px solid var(--border);
  padding: 20px 12px; display: flex; flex-direction: column; gap: 2px;
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.nav-item {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 12px; border-radius: var(--r-md);
  color: var(--text-2); font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all .15s; text-decoration: none;
}
.nav-item:hover { background: var(--surface-2); color: var(--text); }
.nav-item.active { background: var(--accent-soft); color: var(--accent); }
.main-content { padding: 24px 32px; overflow-y: auto; }

/* ── Page header ─────────────────────────────────────────────────────────── */
.page-head { display: flex; align-items: flex-start; justify-content: space-between;
             margin-bottom: 20px; gap: 12px; flex-wrap: wrap; }
.page-title { font-size: 24px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }
.page-sub { font-size: 13px; color: var(--text-3); margin-top: 4px; }

/* ── Stepper ─────────────────────────────────────────────────────────────── */
.stepper { display: flex; gap: 0; width: 100%; }
.step { flex: 1; display: flex; flex-direction: column; align-items: center; position: relative; }
.step::before { content: ""; position: absolute; top: 12px; right: -50%;
               width: 100%; height: 2px; background: var(--border); z-index: 0; }
.step:last-child::before { display: none; }
.step.done::before { background: var(--success); }
.step.active::before { background: var(--border); }
.step .dot { width: 24px; height: 24px; border-radius: 50%; border: 2px solid var(--border);
             display: grid; placeItems: center; font-size: 11px; font-weight: 700;
             background: var(--bg); position: relative; z-index: 1; }
.step.done .dot { background: var(--success); border-color: var(--success); color: #000; }
.step.active .dot { background: var(--accent); border-color: var(--accent); color: #000; }
.step.rejected .dot { background: var(--danger); border-color: var(--danger); color: #fff; }
.step .label { font-size: 10px; color: var(--text-3); margin-top: 4px; }
.step.active .label, .step.done .label { color: var(--text); }
.step .meta { font-size: 9px; color: var(--text-3); margin-top: 2px; }
.table { width: 100%; border-collapse: collapse; font-size: 13px; }
.table th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600; color: var(--text-3); border-bottom: 1px solid var(--border); white-space: nowrap; }
.table td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
.table tbody tr:hover { background: var(--surface-2); }
.table .num, .table .right { text-align: right; }
.kpi-grid { display: grid; gap: 12; }
.kpi { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-lg); padding: 14px 16px; }
.kpi-label { font-size: 11px; color: var(--text-3); text-transform: uppercase; letter-spacing: .05em; }
.kpi-value { font-size: 22px; font-weight: 700; margin-top: 4px; font-variant-numeric: tabular-nums; }

/* ── Mobile responsive layout ────────────────────────────────────────────── */
@media (max-width: 768px) {
  .app-layout {
    display: block;
    min-height: 100vh;
  }
  .sidebar {
    display: none;
  }
  .main-content {
    padding: 60px 14px calc(70px + env(safe-area-inset-bottom, 0px)) 14px;
  }
  .page-title { font-size: 20px; }
  .page-head { margin-bottom: 12px; }

  /* Bottom navigation for mobile */
  .mobile-nav {
    display: flex;
    position: fixed; bottom: 0; left: 0; right: 0; z-index: 50;
    background: var(--surface); border-top: 1px solid var(--border);
    padding: 8px 4px 12px;
    gap: 0;
  }
  .mobile-nav-item {
    flex: 1; display: flex; flex-direction: column; align-items: center;
    gap: 3px; padding: 4px 2px; cursor: pointer; text-decoration: none;
    color: var(--text-3); border: none; background: none; font-family: inherit;
    transition: color .15s;
  }
  .mobile-nav-item.active { color: var(--accent); }
  .mobile-nav-item span.icon { font-size: 20px; }
  .mobile-nav-item span.label { font-size: 9px; font-weight: 600; text-align: center; }

  /* Adjust cards and tables for mobile */
  .card { padding: 12px; }
  .t { font-size: 12px; }
  .t th, .t td { padding: 8px 8px; }
  .t th:nth-child(n+5), .t td:nth-child(n+5) { display: none; }
}

@media (min-width: 769px) {
  .mobile-nav { display: none !important; }
}

/* ── Safe area for notched phones ──────────────────────────────────────── */
@supports (padding-bottom: env(safe-area-inset-bottom)) {
  .mobile-nav { padding-bottom: calc(12px + env(safe-area-inset-bottom)); }
  @media (max-width: 768px) { .main-content { padding-bottom: calc(80px + env(safe-area-inset-bottom)); } }
}

@keyframes slideUp {
  from { transform: translateY(100%); opacity: 0; }
  to   { transform: translateY(0);    opacity: 1; }
}

/* ── Mobile top bar ──────────────────────────────────────────────────────── */
.mobile-topbar {
  display: none;
}
@media (max-width: 768px) {
  .mobile-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 50;
    height: 48px;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 0 16px;
  }
}

FILEEOF

mkdir -p $(dirname 'src/app/(auth)/reset-password/page.tsx')
cat > 'src/app/(auth)/reset-password/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"

export default function ResetPasswordPage() {
  const router = useRouter()
  const [password,  setPassword]  = useState("")
  const [confirm,   setConfirm]   = useState("")
  const [loading,   setLoading]   = useState(false)
  const [error,     setError]     = useState<string|null>(null)
  const [success,   setSuccess]   = useState(false)
  const [ready,     setReady]     = useState(false)

  useEffect(() => {
    // Supabase puts the recovery token in the URL hash
    // It automatically picks it up via onAuthStateChange
    const sb = createClient()
    const { data: { subscription } } = sb.auth.onAuthStateChange(async (event) => {
      if (event === "PASSWORD_RECOVERY") {
        setReady(true)
      }
    })

    // Check if already has session from recovery link
    sb.auth.getSession().then(({ data: { session } }) => {
      if (session) setReady(true)
    })

    return () => subscription.unsubscribe()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (password.length < 6) { setError("La contraseña debe tener al menos 6 caracteres"); return }
    if (password !== confirm) { setError("Las contraseñas no coinciden"); return }

    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.updateUser({ password })
    if (error) { setError("Error al actualizar: " + error.message); setLoading(false); return }

    setSuccess(true)
    setTimeout(() => router.push("/dashboard"), 2000)
  }

  return (
    <div style={{ minHeight:"100vh", display:"grid", placeItems:"center", background:"var(--bg)" }}>
      <div style={{ width:"100%", maxWidth:380, padding:"0 20px" }}>
        <div style={{ textAlign:"center", marginBottom:28 }}>
          <div style={{ width:64, height:64, margin:"0 auto 14px", borderRadius:16,
            overflow:"hidden", background:"white", padding:3, boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={58} height={58}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontSize:20, fontWeight:700, letterSpacing:"-0.02em" }}>
            Nueva contraseña
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)", marginTop:4 }}>Grupo Zapata · Viáticos</div>
        </div>

        {success ? (
          <div style={{ textAlign:"center", padding:"24px 0" }}>
            <div style={{ fontSize:48, marginBottom:16 }}>✅</div>
            <div style={{ fontWeight:700, fontSize:16, marginBottom:8 }}>¡Contraseña actualizada!</div>
            <div style={{ fontSize:13, color:"var(--text-3)" }}>Redirigiendo al sistema…</div>
          </div>
        ) : !ready ? (
          <div style={{ textAlign:"center", padding:"24px 0", color:"var(--text-3)" }}>
            <div style={{ fontSize:32, marginBottom:12 }}>⏳</div>
            <div>Validando enlace de recuperación…</div>
            <div style={{ fontSize:12, marginTop:8 }}>
              Si esto tarda mucho,{" "}
              <button onClick={() => router.push("/login")}
                style={{ color:"var(--accent)", background:"none", border:"none", cursor:"pointer" }}>
                vuelve al inicio de sesión
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} style={{ display:"flex", flexDirection:"column", gap:14 }}>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Nueva contraseña
              </label>
              <input className="input" type="password" value={password}
                onChange={e => setPassword(e.target.value)} required
                minLength={6} placeholder="Mínimo 6 caracteres"
                autoComplete="new-password"/>
            </div>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Confirmar contraseña
              </label>
              <input className="input" type="password" value={confirm}
                onChange={e => setConfirm(e.target.value)} required
                placeholder="Repite la contraseña"
                autoComplete="new-password"/>
            </div>
            {error && (
              <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>
                {error}
              </div>
            )}
            <button className="btn primary" type="submit" disabled={loading}
              style={{ justifyContent:"center", padding:"12px" }}>
              {loading ? "Guardando…" : "Guardar nueva contraseña →"}
            </button>
            <button type="button" className="btn ghost"
              onClick={() => router.push("/login")}
              style={{ justifyContent:"center" }}>
              ← Cancelar
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(auth)/login/page.tsx')
cat > 'src/app/(auth)/login/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"
import { triggerNotifSetup } from "@/components/ui/PushNotifications"

function InstallButton() {
  const [canInstall, setCanInstall] = useState(false)
  const promptRef = useRef<any>(null)
  useEffect(() => {
    const handler = (e: Event) => { e.preventDefault(); promptRef.current = e; setCanInstall(true) }
    window.addEventListener("beforeinstallprompt", handler)
    return () => window.removeEventListener("beforeinstallprompt", handler)
  }, [])
  if (!canInstall) return null
  return (
    <button onClick={async () => {
      if (!promptRef.current) return
      await promptRef.current.prompt()
      const { outcome } = await promptRef.current.userChoice
      if (outcome === "accepted") { promptRef.current = null; setCanInstall(false) }
    }} style={{
      marginTop:12, width:"100%", padding:"11px", borderRadius:10,
      border:"1px solid var(--border)", background:"var(--surface-2)",
      color:"var(--text-2)", fontSize:13, fontWeight:500, cursor:"pointer",
      display:"flex", alignItems:"center", justifyContent:"center", gap:8,
    }}>⬇️ Instalar aplicación</button>
  )
}

export default function LoginPage() {
  const [email,    setEmail]    = useState("")
  const [password, setPassword] = useState("")
  const [error,    setError]    = useState<string|null>(null)
  const [loading,  setLoading]  = useState(false)
  const [mode,     setMode]     = useState<"login"|"recover">("login")
  const [sent,     setSent]     = useState(false)
  const router = useRouter()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) { setError("Credenciales incorrectas"); setLoading(false); return }
    router.push("/dashboard")
  }

  const handleRecover = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.trim()) { setError("Ingresa tu correo"); return }
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (error) { setError("Error al enviar: " + error.message); setLoading(false); return }
    setSent(true); setLoading(false)
  }

  return (
    <div style={{ minHeight:"100vh", display:"grid", placeItems:"center", background:"var(--bg)" }}>
      <div style={{ width:"100%", maxWidth:380, padding:"0 20px" }}>
        {/* Logo */}
        <div style={{ textAlign:"center", marginBottom:28 }}>
          <div style={{ width:80, height:80, margin:"0 auto 14px", borderRadius:20,
            overflow:"hidden", background:"white", padding:4, boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={72} height={72}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontSize:24, fontWeight:800, letterSpacing:"-0.03em", marginBottom:4 }}>
            Grupo Zapata
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)" }}>Sistema de Viáticos</div>
        </div>

        {mode === "login" ? (
          <>
            <form onSubmit={handleLogin} style={{ display:"flex", flexDirection:"column", gap:12 }}>
              <div>
                <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                  Correo electrónico
                </label>
                <input className="input" type="email" value={email}
                  onChange={e=>setEmail(e.target.value)} required
                  placeholder="usuario@grupozapata.com.mx" autoComplete="email"/>
              </div>
              <div>
                <div style={{ display:"flex", justifyContent:"space-between", marginBottom:4 }}>
                  <label style={{ fontSize:12, color:"var(--text-3)" }}>Contraseña</label>
                  <button type="button" onClick={()=>{ setMode("recover"); setError(null); setSent(false) }}
                    style={{ fontSize:12, color:"var(--accent)", background:"none", border:"none",
                      cursor:"pointer", padding:0 }}>
                    ¿Olvidaste tu contraseña?
                  </button>
                </div>
                <input className="input" type="password" value={password}
                  onChange={e=>setPassword(e.target.value)} required
                  placeholder="••••••••" autoComplete="current-password"/>
              </div>
              {error && (
                <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                  borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>{error}</div>
              )}
              <button className="btn primary" type="submit" disabled={loading}
                style={{ justifyContent:"center", marginTop:4, padding:"12px" }}>
                {loading ? "Iniciando sesión…" : "Entrar →"}
              </button>
            </form>
            <InstallButton/>
          </>
        ) : sent ? (
          <div style={{ textAlign:"center", padding:"24px 0" }}>
            <div style={{ fontSize:40, marginBottom:16 }}>📧</div>
            <div style={{ fontWeight:700, fontSize:16, marginBottom:8 }}>Revisa tu correo</div>
            <div style={{ fontSize:13, color:"var(--text-3)", lineHeight:1.6, marginBottom:20 }}>
              Enviamos un enlace a <strong>{email}</strong> para restablecer tu contraseña.
              Puede tardar unos minutos.
            </div>
            <button className="btn ghost" onClick={()=>{ setMode("login"); setSent(false) }}
              style={{ width:"100%" }}>
              ← Volver al inicio de sesión
            </button>
          </div>
        ) : (
          <form onSubmit={handleRecover} style={{ display:"flex", flexDirection:"column", gap:12 }}>
            <div style={{ marginBottom:4 }}>
              <div style={{ fontWeight:700, fontSize:16, marginBottom:6 }}>Recuperar contraseña</div>
              <div style={{ fontSize:13, color:"var(--text-3)" }}>
                Ingresa tu correo y te enviaremos un enlace para restablecerla.
              </div>
            </div>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Correo electrónico
              </label>
              <input className="input" type="email" value={email}
                onChange={e=>setEmail(e.target.value)} required
                placeholder="usuario@grupozapata.com.mx" autoComplete="email"/>
            </div>
            {error && (
              <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>{error}</div>
            )}
            <button className="btn primary" type="submit" disabled={loading}
              style={{ justifyContent:"center", padding:"12px" }}>
              {loading ? "Enviando…" : "Enviar enlace de recuperación"}
            </button>
            <button type="button" className="btn ghost" onClick={()=>{ setMode("login"); setError(null) }}
              style={{ justifyContent:"center" }}>
              ← Volver
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/middleware.ts')
cat > 'src/middleware.ts' << 'FILEEOF'
import { type NextRequest } from "next/server"
import { updateSession } from "@/lib/supabase/middleware"

export async function middleware(request: NextRequest) {
  return await updateSession(request)
}

export const config = {
  matcher: [
    /*
     * Match all paths EXCEPT:
     * - _next/static, _next/image (Next.js internals)
     * - favicon.ico, images
     * - PWA files: sw.js, manifest.json, icons
     * - .well-known (assetlinks.json)
     */
    "/((?!_next/static|_next/image|favicon\\.ico|sw\\.js|firebase-messaging-sw\\.js|manifest\\.json|icon.*\\.png|logo\\.png|\\.well-known|reset-password|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
}

FILEEOF

git add .
git commit -m "feat: spending limits admin, saldo a favor on over-comprobation, mobile layout fix, reset password"
git push
echo "✓ Done!"
echo ""
echo "Pendiente ejecutar en Supabase:"
echo "  1. limites-gasto.sql (nueva tabla)"
echo "  2. create-notificaciones.sql (si no se ejecutó antes)"