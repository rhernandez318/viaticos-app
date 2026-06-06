#!/bin/bash
set -e

mkdir -p $(dirname 'src/lib/cfdi.ts')
cat > 'src/lib/cfdi.ts' << 'FILEEOF'
// CFDI XML parsing utilities

import type { CfdItem } from "@/types"

function attr(el: Element | null, ...names: string[]): string {
  if (!el) return ""
  for (const n of names) {
    const v = el.getAttribute(n) || el.getAttribute(n.toLowerCase())
    if (v) return v
  }
  return ""
}

function qn(parent: Document | Element, localName: string): Element | null {
  const el = parent.querySelector(localName)
  if (el) return el
  const all = parent.getElementsByTagName("*")
  for (let i = 0; i < all.length; i++) {
    if (all[i].localName === localName) return all[i]
  }
  return null
}

// SAT ClaveProdServ prefix → semantic type
const SAT_CLAVESERV_TIPOS: [string, string][] = [
  ["9010", "alimentos"],   // 90101501 consumo alimentos, restaurante
  ["9011", "alimentos"],   // 90111500 servicios de comida
  ["5015", "hospedaje"],   // 50151500 hotel/alojamiento
  ["7810", "aereo"],       // 78101500 transporte aéreo
  ["7812", "taxi"],        // 78121500 transporte terrestre
  ["7813", "taxi"],        // 78131500 taxi local
  ["1517", "gasolina"],    // 15171500 combustibles
  ["7211", "peaje"],       // 72111500 peajes/autopistas
  ["7216", "estacionamiento"], // estacionamiento
]

// Text patterns → semantic type (for description/emisor matching)
const TEXTO_TIPOS: [RegExp, string][] = [
  [/(peaje|caseta|autopista|telepeaje|iave|pase)/i,         "peaje"],
  [/(estacionamiento|parking|parquímetro)/i,                "estacionamiento"],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i,    "gasolina"],
  [/(taxi|uber|didi|cabify|transporte local)/i,             "taxi"],
  [/(hotel|hospedaje|alojamiento)/i,                        "hospedaje"],
  [/(restaurante|alimentos|comida|consumo|viático)/i,       "alimentos"],
  [/(aéreo|vuelo|boleto.*avión|pasaje.*aéreo)/i,            "aereo"],
]

// Determine semantic type from SAT code and/or text
export function getTipoGasto(claveProdServ: string, texto: string): string | null {
  // SAT code takes priority (most reliable)
  for (const [prefix, tipo] of SAT_CLAVESERV_TIPOS) {
    if (claveProdServ.startsWith(prefix)) return tipo
  }
  // Fall back to text matching
  for (const [regex, tipo] of TEXTO_TIPOS) {
    if (regex.test(texto)) return tipo
  }
  return null
}

export function parseCFDIXml(xmlText: string): CfdItem | null {
  try {
    const doc = new DOMParser().parseFromString(xmlText, "application/xml")
    if (doc.querySelector("parsererror")) return null

    const comp = qn(doc, "Comprobante") || doc.documentElement
    const total    = parseFloat(attr(comp, "Total", "total") || "0")
    const subtotal = parseFloat(attr(comp, "SubTotal", "Subtotal", "subtotal") || "0")

    const emisorEl  = qn(doc, "Emisor")
    const emisor    = attr(emisorEl, "Nombre", "nombre") || ""
    const rfcEmisor = attr(emisorEl, "Rfc", "rfc") || ""

    const receptorEl  = qn(doc, "Receptor")
    const rfcReceptor = attr(receptorEl, "Rfc", "rfc") || ""

    let iva = 0
    const traslados = doc.querySelectorAll("Traslado,traslado")
    traslados.forEach((t) => {
      const imp = attr(t, "Impuesto", "impuesto")
      if (imp === "002" || imp.toUpperCase() === "IVA") {
        iva += parseFloat(attr(t, "Importe", "importe") || "0") || 0
      }
    })
    if (!iva && total && subtotal) iva = Math.round((total - subtotal) * 100) / 100

    const tfd  = qn(doc, "TimbreFiscalDigital")
    const uuid = (attr(tfd, "UUID", "uuid") || "").toUpperCase().trim()

    const conceptoEl   = qn(doc, "Concepto")
    const conceptoStr  = attr(conceptoEl, "Descripcion", "descripcion") || ""
    const claveProdServ = attr(conceptoEl, "ClaveProdServ", "claveProdServ") || ""

    // Determine semantic tipo — stored as __tipo__ for normalizaCuenta to resolve
    const matchText = (emisor + " " + conceptoStr).toLowerCase()
    const tipo = getTipoGasto(claveProdServ, matchText)

    // Use __tipo__ marker so normalizaCuenta can resolve it against the real catalog
    // This avoids returning a hardcoded code that may not exist in the client's catalog
    const cuentaHint = tipo ? `__${tipo}__` : "__nd__"

    return {
      uuid,
      uuidFull: uuid,
      emisor,
      concepto: conceptoStr || emisor,
      subtotal,
      iva,
      total,
      cuenta: cuentaHint,  // resolved by normalizaCuenta in the component
      confianza: tipo ? 0.9 : 0.4,
      archivoUrl: null,
      rfcEmisor,
      rfcReceptor,
    } as CfdItem & { uuidFull: string }
  } catch {
    return null
  }
}

FILEEOF

mkdir -p $(dirname 'src/lib/normalizaCuenta.ts')
cat > 'src/lib/normalizaCuenta.ts' << 'FILEEOF'
// Resolves a semantic tipo marker (like __alimentos__) to the actual account
// code that exists in the client's catalog.

// Catalog name patterns per semantic type
const TIPO_CATALOG_PATTERNS: Record<string, RegExp> = {
  alimentos:       /(alimento|comida|comidas|restaurante|consumo|viático|representaci)/i,
  hospedaje:       /(hotel|hospedaje|alojamiento)/i,
  peaje:           /(peaje|caseta|autopista|telepeaje)/i,
  estacionamiento: /(estacionamiento|parking)/i,
  gasolina:        /(gasolina|combustible|diésel|diesel|gas)/i,
  taxi:            /(taxi|transporte.*local|uber|didi|terrestre)/i,
  aereo:           /(aéreo|vuelo|boleto|avión|pasaje)/i,
  nd:              /(no deducible|nd\b)/i,
}

function findInCatalog(tipo: string, catalog: Array<{ cuenta: string; nombre: string }>): string | null {
  const pattern = TIPO_CATALOG_PATTERNS[tipo]
  if (!pattern) return null
  return catalog.find(c => pattern.test(c.nombre))?.cuenta ?? null
}

function getNdAccount(catalog: Array<{ cuenta: string; nombre: string }>): string {
  return catalog.find(c => TIPO_CATALOG_PATTERNS.nd.test(c.nombre))?.cuenta
      ?? catalog[catalog.length - 1]?.cuenta
      ?? "6121200001"
}

export function normalizaCuenta(
  cuentaOrTipo: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): string {
  if (!catalog?.length) return cuentaOrTipo

  // Already a real code that exists in catalog
  if (catalog.some(c => c.cuenta === cuentaOrTipo)) return cuentaOrTipo

  // Resolve __tipo__ marker
  const tipoMatch = cuentaOrTipo.match(/^__(\w+)__$/)
  if (tipoMatch) {
    const tipo = tipoMatch[1]
    const found = findInCatalog(tipo, catalog)
    if (found) {
      console.log(`[normalizaCuenta] ${cuentaOrTipo} → ${found}`)
      return found
    }
    return getNdAccount(catalog)
  }

  // Unknown code not in catalog → No Deducibles
  return getNdAccount(catalog)
}

// Async version: fetches catalog from Supabase if local catalog is empty
// Debug: log when catalog is used for normalization
export async function normalizaCuentaAsync(
  cuentaOrTipo: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): Promise<string> {
  // Always fetch fresh from Supabase to avoid stale catalog state
  try {
    const { createClient } = await import("@/lib/supabase/client")
    const sb = createClient()
    const { data } = await sb
      .from("cuentas_contables")
      .select("cuenta,nombre")
      .eq("activo", true)
      .order("cuenta")
    if (data?.length) {
      console.log("[normalizaCuenta] catalog loaded:", data.length, "accounts")
      return normalizaCuenta(cuentaOrTipo, data)
    }
  } catch (e) {
    console.warn("[normalizaCuenta] catalog fetch failed:", e)
  }
  // Fallback to passed catalog
  if (catalog?.length) return normalizaCuenta(cuentaOrTipo, catalog)
  return cuentaOrTipo
}

// For isComidas: check if a catalog account code corresponds to a food account
export function isCuentaComidas(cuenta: string, catalog: Array<{ cuenta: string; nombre: string }>): boolean {
  const entry = catalog.find(c => c.cuenta === cuenta)
  if (entry) return TIPO_CATALOG_PATTERNS.alimentos.test(entry.nombre)
  // Fallback for __alimentos__ markers
  return cuenta === "__alimentos__"
}

FILEEOF

mkdir -p $(dirname 'src/lib/cuentaComidas.ts')
cat > 'src/lib/cuentaComidas.ts' << 'FILEEOF'
// Re-exports from normalizaCuenta for backward compatibility
export { isCuentaComidas as isComidas } from "@/lib/normalizaCuenta"

FILEEOF

mkdir -p $(dirname 'src/app/sw.js/route.ts')
cat > 'src/app/sw.js/route.ts' << 'FILEEOF'
import { NextResponse } from "next/server"

const SW_CONTENT = `
const CACHE = "viaticos-gz-v5"
const PRECACHE = ["/", "/login", "/icon-192.png", "/manifest.json"]

self.addEventListener("install", e => {
  console.log("[SW] Installing v3")
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", e => {
  console.log("[SW] Activated v3")
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  const url = new URL(e.request.url)
  if (url.pathname.startsWith("/api/") || url.hostname.includes("supabase")) return
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()))
        return res
      })
      .catch(() => caches.match(e.request))
  )
})
`

export async function GET() {
  return new NextResponse(SW_CONTENT, {
    headers: {
      "Content-Type": "application/javascript; charset=utf-8",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Service-Worker-Allowed": "/",
    },
  })
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
                            {s.status==="liberado"&&s.tipo==="anticipo"&&(
                              <button className="btn sm primary"
                                onClick={()=>router.push(`/solicitudes/comprobacion?anticipo=${s.id}`)}>
                                📎 Comprobar →
                              </button>
                            )}
                            {s.status==="parcial"&&s.tipo==="anticipo"&&(
                              <button className="btn sm"
                                style={{background:"var(--warn)",border:"none",color:"#111",fontWeight:600}}
                                onClick={()=>router.push(`/solicitudes/comprobacion?anticipo=${s.id}`)}>
                                📎 Comprobar saldo →
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

mkdir -p $(dirname 'src/app/(app)/solicitudes/comprobacion/page.tsx')
cat > 'src/app/(app)/solicitudes/comprobacion/page.tsx' << 'FILEEOF'
"use client"

import { notifyUsers } from "@/lib/notify"
import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { CompUploader } from "@/components/ui/CompUploader"
import { useCatalogos } from "@/hooks/useCatalogos"
import { isComidas } from "@/lib/cuentaComidas"
import { normalizaCuentaAsync } from "@/lib/normalizaCuenta"
import type { CfdItem, Solicitud } from "@/types"
import { Suspense } from "react"

function NuevaComprobacionInner() {
  const router = useRouter()
  const params = useSearchParams()
  const anticipoId = params.get("anticipo")
  const { catalogoGastos } = useCatalogos()

  const [anticipo, setAnticipo] = useState<Solicitud | null>(null)
  const [anticipos, setAnticipos] = useState<Solicitud[]>([])
  const [anticipoSel, setAnticipoSel] = useState<Solicitud | null>(null)
  const [items, setItems] = useState<CfdItem[]>([])
  const [enviando, setEnviando] = useState(false)
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 3500) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      sb.from("solicitudes")
        .select("id, concepto, monto, status, saldo_pendiente, fecha, tipo")
        .eq("usuario_id", user.id)
        .eq("tipo", "anticipo")
        .in("status", ["liberado", "parcial"])
        .gt("saldo_pendiente", 0)
        .order("fecha", { ascending: false })
        .then(({ data }) => {
          const mapped = (data || []).map(s => ({
            id: s.id, tipo: s.tipo as any, concepto: s.concepto, usuario: user.id,
            monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha), status: s.status as any,
            saldoPendiente: parseFloat(s.saldo_pendiente) || 0, cfdi: [],
          }))
          setAnticipos(mapped)
          if (anticipoId) {
            const found = mapped.find(a => a.id === anticipoId)
            if (found) setAnticipoSel(found)
          }
        })
    })
  }, [anticipoId])

  const handleAdd = (newItems: CfdItem[]) => {
    setItems(prev => [...prev, ...newItems])
  }

  const handleEnviar = async () => {
    if (!anticipoSel)              { showToast("⚠ Selecciona el anticipo a comprobar", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Agrega al menos un comprobante XML válido", false); return }
    if (total <= 0)                { showToast("⚠ El total es cero", false); return }
    const sinCom = itemsValidos.filter(it => isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones?.trim())
    if (sinCom.length > 0) { showToast("⚠ Indica número y nombre de comensales en gastos de alimentos", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const nuevoSaldo = Math.max(0, anticipoSel.saldoPendiente - total)
    const nuevoStatus = nuevoSaldo <= 0 ? "comprobado" : "parcial"
    const id = "CMP-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "comprobacion", concepto: `Comprobación de ${anticipoSel.id}`,
      usuario_id: user.id, monto: total, status: "solicitado",
      anticipo_ref: anticipoSel.id, saldo_pendiente: 0,
      comprobantes: itemsValidos.length, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    // Save CFDIs
    await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
      solicitud_id: id, uuid: it.uuid || `SIN-UUID-${Date.now()}`,
      emisor: it.emisor, concepto: it.concepto,
      subtotal: it.subtotal, iva: it.iva, total: it.total,
      cuenta: it.cuenta, confianza: it.confianza, archivo_url: it.archivoUrl,
      rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
    })))

    // Update anticipo saldo
    await sb.from("solicitudes")
      .update({ saldo_pendiente: nuevoSaldo, status: nuevoStatus, comprobantes: (anticipoSel as any).comprobantes + 1 })
      .eq("id", anticipoSel.id)

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Comprobación ${fmtMXN(total)} del anticipo ${anticipoSel.id}`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    const { data: pf } = await sb.from("usuarios").select("gerente_id, nombre").eq("id", user.id).single()
    if (pf?.gerente_id) {
      await notifyUsers([pf.gerente_id], "📎 Nueva comprobación por autorizar",
        `${pf.nombre} comprobó ${fmtMXN(total)} del anticipo ${anticipoSel.id}`, `/solicitudes/${id}`)
    }

    showToast("✓ Comprobación enviada a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  return (
    <div style={{ maxWidth: 900 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nueva comprobación</h1>
          <div className="page-sub">Sube los CFDIs para comprobar tu anticipo</div>
        </div>
      </div>

      {/* Anticipo selector */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 12 }}>Anticipo a comprobar</div>
        {anticipos.length === 0 ? (
          <div style={{ color: "var(--text-3)", fontSize: 13 }}>
            No tienes anticipos liberados pendientes de comprobar.
          </div>
        ) : anticipoSel ? (
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ fontWeight: 600 }}>{anticipoSel.id}</div>
              <div style={{ fontSize: 13, color: "var(--text-2)" }}>{anticipoSel.concepto}</div>
              <div style={{ fontSize: 12, color: "var(--warn)", marginTop: 2 }}>
                Saldo pendiente: {fmtMXN(anticipoSel.saldoPendiente)}
              </div>
            </div>
            <button className="btn ghost" onClick={() => setAnticipoSel(null)}>Cambiar</button>
          </div>
        ) : (
          <div style={{ display: "grid", gap: 8 }}>
            {anticipos.map(a => (
              <div key={a.id} className="card" style={{ cursor: "pointer", margin: 0 }}
                onClick={() => setAnticipoSel(a)}>
                <div className="spread">
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 13 }}>{a.id}</div>
                    <div style={{ fontSize: 12, color: "var(--text-2)" }}>{a.concepto}</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(a.saldoPendiente)}</div>
                    <div style={{ fontSize: 11, color: "var(--text-3)" }}>{fmtFecha(a.fecha)}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Uploader */}
      <div style={{ marginBottom: 16 }}>
        <CompUploader solicitudId={anticipoSel?.id} catalogoGastos={catalogoGastos} onAdd={handleAdd} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom: 16, padding: 0, overflow: "auto" }}>
          <table className="t" style={{ minWidth: 960 }}>
            <thead>
              <tr>
                <th style={{ minWidth: 100 }}>UUID</th>
                <th style={{ minWidth: 120 }}>Emisor</th>
                <th style={{ minWidth: 140 }}>Concepto</th>
                <th style={{ minWidth: 220 }}>Cuenta</th>
                <th style={{ minWidth: 220 }}>Comentarios</th>
                <th className="num" style={{ minWidth: 90 }}>Total</th>
                <th style={{ width: 32 }}></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => (
                <tr key={i} style={{ ...(it.duplicado ? { textDecoration: "line-through", opacity: 0.5 } : {}) }}>
                  <td className="mono" style={{ fontSize: 10, maxWidth: 120 }}>
                    <span title={it.uuid} onClick={() => navigator.clipboard.writeText(it.uuid)}
                      style={{ cursor: "pointer" }}>
                      {it.uuid ? it.uuid.slice(0, 18) + "…" : "—"}
                    </span>
                  </td>
                  <td style={{ fontSize: 12 }}>{it.emisor}</td>
                  <td style={{ fontSize: 11, maxWidth: 160, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {it.concepto}
                    {it.duplicado && <span style={{ color: "var(--danger)", fontSize: 10, marginLeft: 6 }}>⚠ {it.motivoDup}</span>}
                  </td>
                  <td>
                    {it.duplicado ? (
                      <span style={{ fontSize: 11 }}>{catalogoGastos.find(g => g.cuenta === it.cuenta)?.nombre}</span>
                    ) : (
                      <select className="select" value={it.cuenta}
                        onChange={e => setItems(prev => prev.map((x, j) => j === i ? { ...x, cuenta: e.target.value } : x))}
                        style={{ fontSize: 11, padding: "5px 6px",
                          borderColor: it.cuenta === "6121200001" ? "var(--warn)" : "var(--border)",
                          background: it.cuenta === "6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                        {catalogoGastos.map(g => <option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                      </select>
                    )}
                  </td>
                  <td>
                    <div>
                      <input
                        className="input"
                        value={(it as any).observaciones || ""}
                        onChange={e => setItems(prev => prev.map((x,j) => j===i ? {...x, observaciones: e.target.value} : x))}
                        placeholder={isComidas(it.cuenta, catalogoGastos) ? "Requerido: nombres y número de comensales" : "Opcional"}
                        style={{
                          fontSize:11, padding:"5px 6px",
                          borderColor: isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones ? "var(--danger)" : "var(--border)",
                          background: isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones ? "var(--danger-soft)" : "var(--surface)",
                        }}
                      />
                      {isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones && (
                        <div style={{fontSize:10,color:"var(--danger)",marginTop:2}}>
                          ⚠ Favor de indicar número y nombre de los comensales
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="num">{fmtMXN(it.total)}</td>
                  <td>
                    <button onClick={() => setItems(prev => prev.filter((_, j) => j !== i))}
                      style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 16 }}>×</button>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ textAlign: "right", fontWeight: 600, padding: "10px 12px" }}>Total a comprobar</td>
                <td className="num" style={{ fontWeight: 700, fontSize: 16 }}>{fmtMXN(total)}</td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div style={{ padding: "10px 14px", borderRadius: 8, marginBottom: 12, fontSize: 13,
          background: toast.ok ? "var(--success-soft)" : "var(--danger-soft)",
          color: toast.ok ? "var(--success)" : "var(--danger)" }}>
          {toast.msg}
        </div>
      )}

      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <button className="btn ghost" onClick={() => router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || !anticipoSel || total <= 0}
          style={{ opacity: enviando || !anticipoSel || total <= 0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : "Enviar comprobación →"}
        </button>
      </div>
    </div>
  )
}

export default function NuevaComprobacionPage() {
  return (
    <Suspense fallback={<div style={{ padding: 40, color: "var(--text-3)" }}>Cargando…</div>}>
      <NuevaComprobacionInner />
    </Suspense>
  )
}


FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/reembolso/page.tsx')
cat > 'src/app/(app)/solicitudes/reembolso/page.tsx' << 'FILEEOF'
"use client"
import { useState, useRef, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import { isComidas } from "@/lib/cuentaComidas"
import { normalizaCuentaAsync } from "@/lib/normalizaCuenta"
import { notifyUsers } from "@/lib/notify"
import type { CfdItem } from "@/types"

interface ItemConObs extends CfdItem { observaciones?: string }

export default function NuevoReembolsoPage() {
  const router = useRouter()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [concepto,  setConcepto]  = useState("")
  const [items,     setItems]     = useState<ItemConObs[]>([])
  const [enviando,  setEnviando]  = useState(false)
  const [toast,     setToast]     = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 4000) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)
  const totalDups = items.filter(i => i.duplicado).reduce((a, i) => a + (i.total || 0), 0)

  const checkDuplicado = useCallback(async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    if (items.some(i => i.uuid === uuid)) return "Ya en la lista"
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id, solicitudes!inner(status)")
      .eq("uuid", uuid)
      .not("solicitudes.status", "eq", "rechazado")
      .limit(1)
    return data && data.length > 0 ? "Ya comprobado en otra solicitud" : null
  }, [items])

  const handleFiles = useCallback(async (files: FileList | null) => {
    if (!files) return
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    for (const file of Array.from(files)) {
      const isXml = file.name.toLowerCase().endsWith(".xml")
      const isPdf = file.name.toLowerCase().endsWith(".pdf")
      const isImg = file.type.startsWith("image/")
      if (!isXml && !isPdf && !isImg) continue

      let archivoUrl: string | null = null
      const ext = file.name.split(".").pop()
      const path = `${user.id}/${Date.now()}.${ext}`
      const { data: uploadData } = await sb.storage.from("comprobantes").upload(path, file, { upsert: true })
      if (uploadData) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }

      if (isXml) {
        const text = await file.text()
        const parsed = parseCFDIXml(text)
        if (!parsed) { showToast(`XML inválido: ${file.name}`, false); continue }
        parsed.archivoUrl = archivoUrl
        // Normalize parsed account code to one that exists in the catalog
        parsed.cuenta = await normalizaCuentaAsync(parsed.cuenta, catalogoGastos)
        const motivoDup = await checkDuplicado(parsed.uuid)
        setItems(prev => [...prev, { ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined }])
      } else {
        setItems(prev => [...prev, {
          uuid: "", emisor: file.name, concepto: file.name,
          subtotal: 0, iva: 0, total: 0, cuenta: "6121200001",
          confianza: 0.5, archivoUrl, duplicado: false,
        } as ItemConObs])
      }
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [checkDuplicado])

  const handleEnviar = async () => {
    if (!concepto.trim())          { showToast("⚠ Agrega un concepto", false); return }
    if (items.length === 0)        { showToast("⚠ Agrega al menos un comprobante", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Todos son duplicados", false); return }
    if (total <= 0)                { showToast("⚠ Total cero — no se puede enviar", false); return }

    // Validate comidas observaciones
    const sinObs = itemsValidos.filter(it => isComidas(it.cuenta, catalogoGastos) && !it.observaciones?.trim())
    if (sinObs.length > 0) {
      showToast("⚠ Indica número y nombre de comensales en los gastos de alimentos", false); return
    }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const { data: perfil } = await sb.from("usuarios").select("centro_id, gerente_id, nombre").eq("id", user.id).single()
    const id = "REM-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "reembolso", concepto, usuario_id: user.id, monto: total,
      status: "solicitado", saldo_pendiente: 0, comprobantes: itemsValidos.length,
      centro_id: perfil?.centro_id ?? null, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    if (itemsValidos.length > 0) {
      await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
        solicitud_id: id,
        uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        emisor: it.emisor, concepto: it.concepto,
        subtotal: it.subtotal, iva: it.iva, total: it.total,
        cuenta: it.cuenta, confianza: it.confianza,
        archivo_url: it.archivoUrl,
        rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
        observaciones: it.observaciones || null,
            nombre_cuenta: catalogoGastos.find(g => g.cuenta === it.cuenta)?.nombre || null,
      })))
    }

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Reembolso ${fmtMXN(total)} · ${itemsValidos.length} comprobante(s)`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    if (perfil?.gerente_id) {
      await notifyUsers([perfil.gerente_id], "🧾 Nuevo reembolso por autorizar",
        `${perfil.nombre} solicitó ${fmtMXN(total)}`, `/solicitudes/${id}`)
    }

    showToast("✓ Reembolso enviado a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  return (
    <div style={{ maxWidth: 1000 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nuevo reembolso</h1>
          <div className="page-sub">Gastos pagados de tu bolsa sin anticipo previo</div>
        </div>
      </div>

      {/* Concepto */}
      <div className="card" style={{ marginBottom: 16 }}>
        <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:6, display:"block" }}>
          Concepto / descripción general *
        </label>
        <input className="input" value={concepto} onChange={e=>setConcepto(e.target.value)}
          placeholder="Ej: Gastos de viaje a Guadalajara — 28 mayo 2026" />
      </div>

      {/* Drop zone */}
      <div className="card" style={{ marginBottom:16, border:"2px dashed var(--border)",
           textAlign:"center", padding:"28px 20px", cursor:"pointer" }}
        onClick={() => fileRef.current?.click()}
        onDragOver={e=>{ e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e=>{ (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e=>{ e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; handleFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize:28, marginBottom:8 }}>📂</div>
        <div style={{ fontWeight:600, marginBottom:4 }}>Arrastra o haz clic para subir</div>
        <div style={{ fontSize:12, color:"var(--text-3)" }}>XML (CFDI), PDF o imágenes de ticket</div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e=>handleFiles(e.target.files)} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom:16, padding:0, overflow:"auto" }}>
          <table className="t" style={{ minWidth:900 }}>
            <thead>
              <tr>
                <th style={{ minWidth:120 }}>Emisor</th>
                <th style={{ minWidth:150 }}>Concepto</th>
                <th style={{ minWidth:220 }}>Cuenta contable</th>
                <th style={{ minWidth:220 }}>Comentarios</th>
                <th className="num" style={{ minWidth:100 }}>Total</th>
                <th style={{ width:32 }}></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => {
                const meta = catalogoGastos.find(g => g.cuenta === it.cuenta)
                return (
                  <tr key={i} style={{ ...(it.duplicado ? { textDecoration:"line-through", opacity:0.5 } : {}) }}>
                    <td style={{ fontSize:12 }}>
                      {it.emisor}
                      {it.duplicado && <span style={{ fontSize:10, color:"var(--danger)", marginLeft:6 }}>⚠ {it.motivoDup}</span>}
                    </td>
                    <td style={{ fontSize:12 }}>{it.concepto}</td>
                    <td>
                      {it.duplicado
                        ? <span style={{ fontSize:11 }}>{meta?.nombre}</span>
                        : <select className="select" value={it.cuenta}
                            onChange={e => setItems(prev => prev.map((x,j) => j===i ? {...x, cuenta:e.target.value} : x))}
                            style={{ fontSize:11, padding:"5px 6px",
                              borderColor: it.cuenta==="6121200001" ? "var(--warn)" : "var(--border)",
                              background: it.cuenta==="6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                            {catalogoGastos.map(g=><option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                          </select>}
                    </td>
                    <td>
                      {!it.duplicado && (
                        <div>
                          <input className="input"
                            value={it.observaciones || ""}
                            onChange={e => setItems(prev => prev.map((x,j) => j===i ? {...x, observaciones:e.target.value} : x))}
                            placeholder={isComidas(it.cuenta, catalogoGastos) ? "Requerido: nombres y № comensales" : "Opcional"}
                            style={{
                              fontSize:11, padding:"5px 6px",
                              borderColor: isComidas(it.cuenta, catalogoGastos) && !it.observaciones ? "var(--danger)" : "var(--border)",
                              background: isComidas(it.cuenta, catalogoGastos) && !it.observaciones ? "var(--danger-soft)" : "var(--surface)",
                            }}/>
                          {isComidas(it.cuenta, catalogoGastos) && !it.observaciones && (
                            <div style={{ fontSize:10, color:"var(--danger)", marginTop:2 }}>
                              ⚠ Favor de indicar número y nombre de los comensales
                            </div>
                          )}
                        </div>
                      )}
                    </td>
                    <td className="num">{fmtMXN(it.total)}</td>
                    <td>
                      <button onClick={() => setItems(prev => prev.filter((_,j)=>j!==i))}
                        style={{ background:"none", border:"none", color:"var(--text-3)", cursor:"pointer", fontSize:16 }}>×</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ textAlign:"right", fontWeight:600, padding:"10px 12px" }}>
                  Total a reembolsar
                  {totalDups>0 && <span style={{ fontSize:10, color:"var(--text-3)", fontWeight:400, marginLeft:6 }}>(excl. dup: {fmtMXN(totalDups)})</span>}
                </td>
                <td className="num" style={{ fontWeight:700, fontSize:16 }}>{fmtMXN(total)}</td>
                <td/>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {toast && (
        <div style={{ padding:"10px 14px", borderRadius:8, marginBottom:12, fontSize:13,
          background:toast.ok ? "var(--success-soft)" : "var(--danger-soft)",
          color:toast.ok ? "var(--success)" : "var(--danger)" }}>
          {toast.msg}
        </div>
      )}

      <div style={{ display:"flex", justifyContent:"flex-end", gap:10 }}>
        <button className="btn ghost" onClick={()=>router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || total<=0 || itemsValidos.length===0}
          style={{ opacity:enviando||total<=0||itemsValidos.length===0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : `Enviar reembolso · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}


FILEEOF

cat > 'public/sw.js' << 'FILEEOF'
const CACHE = "viaticos-gz-v5"
const PRECACHE = ["/", "/login", "/icon-192.png", "/manifest.json"]

self.addEventListener("install", e => {
  console.log("[SW] Installing v4")
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", e => {
  console.log("[SW] Activated v4")
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  const url = new URL(e.request.url)
  // Skip API calls, Supabase, Firebase, external CDN
  if (
    url.pathname.startsWith("/api/") ||
    url.pathname.includes("sw.js") ||
    url.pathname.includes("firebase") ||
    url.hostname.includes("supabase") ||
    url.hostname.includes("googleapis") ||
    url.hostname.includes("gstatic") ||
    url.hostname !== self.location.hostname
  ) return

  e.respondWith(
    fetch(e.request)
      .then(res => {
        // Only cache successful same-origin responses
        if (res.ok && res.status < 400 && res.type === "basic") {
          const clone = res.clone() // clone BEFORE returning
          caches.open(CACHE).then(c => c.put(e.request, clone)).catch(() => {})
        }
        return res
      })
      .catch(() => caches.match(e.request).then(r => r || Response.error()))
  )
})


FILEEOF

git add .
git commit -m "fix: SW cache v5 forces reload, normalizaCuenta fetches fresh catalog, Comprobar button in workflow"
git push
echo "✓ Done"
echo ""
echo "Para limpiar el caché en el celular:"
echo "  Chrome → ... → Configuración → Privacidad → Borrar datos de navegación"
echo "  Marca: Caché e Imágenes → Borrar"
echo "  Luego recarga la app — el SW v5 se instalará automáticamente"