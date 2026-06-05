#!/bin/bash
set -e

mkdir -p $(dirname 'src/types/index.ts')
cat > 'src/types/index.ts' << 'FILEEOF'
// ─── Core domain types ────────────────────────────────────────────────────────

export type Rol = "usuario" | "gerente" | "tesoreria" | "contador" | "admin"

export type SolicitudStatus = "solicitado" | "autorizado" | "validado" | "liberado" | "comprobado" | "rechazado" | "parcial" | "devuelto" | "devuelto"

export type SolicitudTipo = "anticipo" | "reembolso" | "comprobacion"

export interface Usuario {
  id: string
  nombre: string
  correo: string
  rol: Rol
  iniciales: string
  centro: string | null
  gerente: string | null
  division: "4105" | "4106" | string
  clabe: string | null
  banco: string | null
  suplanteId: string | null
  suplantaDesde: string | null
  suplantaHasta: string | null
}

export interface Centro {
  id: string
  nombre: string
  depto: string
  division: string
}

export interface CuentaContable {
  cuenta: string
  nombre: string
  grupo: string
  activo: boolean
}

export interface CfdItem {
  id?: string
  uuid: string
  emisor: string
  concepto: string
  subtotal: number
  iva: number
  total: number
  cuenta: string
  confianza: number
  archivoUrl: string | null
  archivoPdfUrl?: string | null
  archivoXmlUrl?: string | null
  rfcEmisor?: string | null
  rfcReceptor?: string | null
  satEstado?: string | null
  duplicado?: boolean
  motivoDup?: string
  ocrLeido?: boolean
  ocrPendiente?: boolean
}

export interface Solicitud {
  id: string
  tipo: SolicitudTipo
  concepto: string
  usuario: string
  monto: number
  fecha: Date
  status: SolicitudStatus
  saldoPendiente: number
  division?: string
  anticipoRef?: string | null
  motivoRechazo?: string | null
  notas?: string | null
  esCierre?: boolean
  comprobantes?: number
  centroId?: string | null
  cfdi?: CfdItem[]
  items?: Array<{ cuenta: string; desc: string; monto: number }>
}

export interface BitacoraEntry {
  id: string
  solicitudId: string
  accion: string
  usuarioId: string
  detalle?: string
  ts: string
}

export interface PolizaLinea {
  poliza: string
  folio: string
  fecha: string
  centro: string
  area: string
  division: string
  cuenta: string
  nombreCuenta: string
  tipo: "C" | "A"  // Cargo / Abono
  debe: number
  haber: number
  concepto: string
  proveedor: string
  usuario: string
  ref: string
  _archivos?: Array<{ nombre: string; url: string | null; uuid: string | null; emisor?: string | null; total?: number }>
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
.badge.validado   { background: rgba(192,132,252,.15); color: #c084fc; }
.badge.devuelto   { background: rgba(249,115,22,.15);  color: #f97316; }
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

mkdir -p $(dirname 'src/components/ui/StatusBadge.tsx')
cat > 'src/components/ui/StatusBadge.tsx' << 'FILEEOF'
import type { SolicitudStatus } from "@/types"

const LABELS: Record<string, string> = {
  solicitado: "Solicitado", autorizado: "Pend. Admin", validado: "Aut. Admin",
  liberado: "Liberado", comprobado: "Comprobado", rechazado: "Rechazado", devuelto: "Devuelto", parcial: "Parcial", devuelto: "A corregir",
}

export function StatusBadge({ status }: { status: SolicitudStatus }) {
  return <span className={`badge ${status}`}>{LABELS[status] ?? status}</span>
}

export function TipoBadge({ tipo }: { tipo: string }) {
  const map: Record<string, string> = { anticipo: "ANT", comprobacion: "CMP", reembolso: "REE" }
  return <span className="badge tipo">{map[tipo] ?? tipo}</span>
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

  const VALIDOS = ["solicitado","autorizado","validado","liberado","parcial","comprobado"]
  const solicitudesValidas = solicitudes.filter(s => VALIDOS.includes(s.status))
  const totalMonto = solicitudesValidas.reduce((a,s)=>a+parseFloat(s.monto||0),0)
  const saldoPendiente = solicitudesValidas.filter(s=>s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0)
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
      .update({ status: newStatus, motivo_rechazo:`[Admin] ${motivo.trim()}` })
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
      .update({ status: newStatus, motivo_rechazo: motivoRechazo.trim() })
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

mkdir -p $(dirname 'src/app/(app)/solicitudes/[id]/corregir/page.tsx')
cat > 'src/app/(app)/solicitudes/[id]/corregir/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef, useCallback } from "react"
import { useRouter, useParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import { notifyUsers } from "@/lib/notify"
import type { CfdItem } from "@/types"

const CUENTA_COMIDAS = "6122200001"
interface ItemConObs extends CfdItem { observaciones?: string }

export default function CorregirComprobacionPage() {
  const router  = useRouter()
  const { id }  = useParams<{ id: string }>()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [solicitud, setSolicitud]   = useState<any>(null)
  const [items,     setItems]       = useState<ItemConObs[]>([])
  const [enviando,  setEnviando]    = useState(false)
  const [toast,     setToast]       = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({msg,ok}); setTimeout(()=>setToast(null),4000) }

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("*,comprobantes_cfdi(*)")
      .eq("id", id).single()
      .then(({ data }) => {
        if (!data || data.status !== "devuelto") { router.push(`/solicitudes/${id}`); return }
        setSolicitud(data)
        setItems((data.comprobantes_cfdi || []).map((c: any) => ({
          uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
          subtotal: c.subtotal, iva: c.iva, total: c.total,
          cuenta: c.cuenta, confianza: c.confianza,
          archivoUrl: c.archivo_url, rfcEmisor: c.rfc_emisor,
          rfcReceptor: c.rfc_receptor, duplicado: false,
          observaciones: c.observaciones || "",
        } as ItemConObs)))
      })
  }, [id, router])

  const handleFiles = useCallback(async (files: FileList | null) => {
    if (!files) return
    for (const file of Array.from(files)) {
      if (!file.name.toLowerCase().endsWith(".xml")) continue
      const text = await file.text()
      const parsed = parseCFDIXml(text)
      if (!parsed) { showToast(`XML inválido: ${file.name}`, false); continue }
      setItems(prev => [...prev, { ...parsed, duplicado: false } as ItemConObs])
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [])

  const handleReenviar = async () => {
    const validos = items.filter(i => !i.duplicado)
    if (!validos.length) { showToast("⚠ Sin comprobantes válidos", false); return }

    const sinObs = validos.filter(it => it.cuenta === CUENTA_COMIDAS && !it.observaciones?.trim())
    if (sinObs.length) { showToast("⚠ Indica comensales en los gastos de alimentos", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    const total = validos.reduce((a, i) => a + i.total, 0)

    // Delete existing comprobantes and reinsert
    await sb.from("comprobantes_cfdi").delete().eq("solicitud_id", id)
    await sb.from("comprobantes_cfdi").insert(validos.map(it => ({
      solicitud_id: id,
      uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      emisor: it.emisor, concepto: it.concepto,
      subtotal: it.subtotal, iva: it.iva, total: it.total,
      cuenta: it.cuenta, confianza: it.confianza,
      archivo_url: it.archivoUrl, rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
      observaciones: it.observaciones || null,
    })))

    // Reset to solicitado
    await sb.from("solicitudes")
      .update({ status: "solicitado", monto: total, motivo_rechazo: null })
      .eq("id", id)

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Comprobación corregida y reenviada · ${fmtMXN(total)}`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    const { data: perfil } = await sb.from("usuarios")
      .select("gerente_id, nombre").eq("id", user.id).single()
    if (perfil?.gerente_id) {
      await notifyUsers([perfil.gerente_id],
        "📎 Comprobación corregida para revisar",
        `${perfil.nombre} corrigió y reenvió la comprobación ${id}`,
        `/solicitudes/${id}`)
    }

    showToast("✓ Comprobación reenviada a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  if (!solicitud) return (
    <div style={{padding:60,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
  )

  const total = items.filter(i=>!i.duplicado).reduce((a,i)=>a+i.total,0)

  return (
    <div style={{ maxWidth:1000 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">↩️ Corregir comprobación</h1>
          <div className="page-sub">{id} · {solicitud.concepto}</div>
        </div>
      </div>

      {solicitud.motivo_rechazo && (
        <div style={{padding:"12px 16px",background:"rgba(251,191,36,.1)",
          border:"1px solid #fbbf24",borderRadius:10,marginBottom:16,fontSize:13}}>
          <strong>Motivo de devolución:</strong> {solicitud.motivo_rechazo}
        </div>
      )}

      {/* Add more comprobantes */}
      <div className="card" style={{marginBottom:16,border:"2px dashed var(--border)",
        textAlign:"center",padding:"20px",cursor:"pointer"}}
        onClick={()=>fileRef.current?.click()}>
        <div style={{fontSize:24,marginBottom:6}}>➕</div>
        <div style={{fontWeight:600,fontSize:13}}>Agregar o reemplazar XMLs</div>
        <div style={{fontSize:12,color:"var(--text-3)"}}>Haz clic o arrastra archivos XML</div>
        <input ref={fileRef} type="file" accept=".xml" multiple hidden
          onChange={e=>handleFiles(e.target.files)}/>
      </div>

      {/* Items table */}
      <div className="card" style={{marginBottom:16,padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:860}}>
          <thead>
            <tr>
              <th>Emisor</th><th>Concepto</th>
              <th style={{minWidth:200}}>Cuenta</th>
              <th style={{minWidth:200}}>Comentarios</th>
              <th className="num">Total</th><th style={{width:32}}></th>
            </tr>
          </thead>
          <tbody>
            {items.map((it,i)=>(
              <tr key={i}>
                <td style={{fontSize:12}}>{it.emisor}</td>
                <td style={{fontSize:12}}>{it.concepto}</td>
                <td>
                  <select className="select" value={it.cuenta}
                    onChange={e=>setItems(prev=>prev.map((x,j)=>j===i?{...x,cuenta:e.target.value}:x))}
                    style={{fontSize:11,padding:"5px 6px"}}>
                    {catalogoGastos.map(g=><option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                  </select>
                </td>
                <td>
                  <input className="input"
                    value={it.observaciones||""}
                    onChange={e=>setItems(prev=>prev.map((x,j)=>j===i?{...x,observaciones:e.target.value}:x))}
                    placeholder={it.cuenta===CUENTA_COMIDAS?"Requerido: nombres y № comensales":"Opcional"}
                    style={{fontSize:11,padding:"5px 6px",
                      borderColor:it.cuenta===CUENTA_COMIDAS&&!it.observaciones?"var(--danger)":"var(--border)"}}/>
                  {it.cuenta===CUENTA_COMIDAS&&!it.observaciones&&(
                    <div style={{fontSize:10,color:"var(--danger)",marginTop:2}}>
                      ⚠ Favor de indicar número y nombre de los comensales
                    </div>
                  )}
                </td>
                <td className="num">{fmtMXN(it.total)}</td>
                <td>
                  <button onClick={()=>setItems(p=>p.filter((_,j)=>j!==i))}
                    style={{background:"none",border:"none",color:"var(--text-3)",cursor:"pointer",fontSize:16}}>×</button>
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={4} style={{textAlign:"right",fontWeight:600,padding:"10px 12px"}}>Total</td>
              <td className="num" style={{fontWeight:700,fontSize:16}}>{fmtMXN(total)}</td>
              <td/>
            </tr>
          </tfoot>
        </table>
      </div>

      {toast&&(
        <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
          background:toast.ok?"var(--success-soft)":"var(--danger-soft)",
          color:toast.ok?"var(--success)":"var(--danger)"}}>
          {toast.msg}
        </div>
      )}

      <div style={{display:"flex",justifyContent:"flex-end",gap:10}}>
        <button className="btn ghost" onClick={()=>router.push(`/solicitudes/${id}`)}>Cancelar</button>
        <button className="btn primary" onClick={handleReenviar}
          disabled={enviando||total<=0}
          style={{opacity:enviando||total<=0?0.5:1}}>
          {enviando?"Reenviando…":`Reenviar comprobación · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}

FILEEOF

git add .
git commit -m "fix: rechazados out of KPIs, comprobacion devuelto for correction"
git push
echo "✓ Done!"
echo ""
echo "Pendiente en Supabase: ejecutar add-validado-status.sql (ya incluye devuelto)"