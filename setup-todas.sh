#!/bin/bash
set -e

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
            {["solicitado","autorizado","liberado","parcial","comprobado","rechazado"].map(s => (
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

mkdir -p $(dirname 'src/app/api/push/debug/route.ts')
cat > 'src/app/api/push/debug/route.ts' << 'FILEEOF'
import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

export async function GET() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const { data: sub } = await sb
    .from("push_subscriptions")
    .select("usuario_id, subscription, updated_at")
    .eq("usuario_id", user.id)
    .single()

  const { data: perfil } = await sb
    .from("usuarios")
    .select("nombre, rol, gerente_id")
    .eq("id", user.id)
    .single()

  // Test calling the Worker
  const WORKER = process.env.NEXT_PUBLIC_WORKER_URL || "https://viaticos-admin.rhernandez-e52.workers.dev"
  let workerStatus = "not tested"
  if (sub?.subscription) {
    try {
      const r = await fetch(`${WORKER}/notify`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer viaticos-zapata-push-2026" },
        body: JSON.stringify({
          userIds: [user.id],
          title: "🔔 Test de notificación",
          body: "Si recibes esto, las notificaciones funcionan correctamente",
          url: "https://viaticos-app-bice.vercel.app/dashboard",
        }),
      })
      const data = await r.json()
      workerStatus = r.ok ? `OK: ${JSON.stringify(data)}` : `Error ${r.status}: ${JSON.stringify(data)}`
    } catch(e: any) {
      workerStatus = `Fetch error: ${e.message}`
    }
  }

  return NextResponse.json({
    userId: user.id,
    nombre: perfil?.nombre,
    rol: perfil?.rol,
    gerenteId: perfil?.gerente_id,
    hasToken: !!sub?.subscription,
    tokenPreview: sub?.subscription ? sub.subscription.slice(0, 30) + "..." : null,
    tokenUpdated: sub?.updated_at,
    workerTest: workerStatus,
  })
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
          <div>
            <div style={{ fontSize:13, fontWeight:700, letterSpacing:"-0.02em" }}>Grupo Zapata</div>
            <div style={{ fontSize:10, color:"var(--text-3)" }}>Viáticos</div>
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

      {/* ── Top bar (web + mobile) ─────────────────────────── */}
      <div style={{ position:"fixed", top:16, right:20, zIndex:40,
        display:"flex", gap:8, alignItems:"center" }}>
        <NotificationBell userId={user.id}/>
        <ThemePanel/>
      </div>

      {/* ── Main content ───────────────────────────────────── */}
      <main className="main-content">
        {children}
      </main>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/PushNotifications.tsx')
cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState, useRef, useCallback } from "react"

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY || ""
const FIREBASE_CONFIG = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

interface Props { userId: string }
type Status = "idle" | "asking" | "granted" | "denied"

// Global reference so triggerNotifSetup() can be called from anywhere (e.g. perfil)
let globalSetup: (() => void) | null = null
export function triggerNotifSetup() { globalSetup?.() }

export function PushNotifications({ userId }: Props) {
  const [status, setStatus]   = useState<Status>("idle")
  const [banner, setBanner]   = useState(false)
  const [toast, setToast]     = useState<{ title: string; body: string } | null>(null)
  const fbReadyRef            = useRef(false)
  const messagingRef          = useRef<any>(null)

  const loadFirebase = useCallback((): Promise<void> => new Promise((resolve, reject) => {
    if (fbReadyRef.current) { resolve(); return }
    const s1 = document.createElement("script")
    s1.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"
    const s2 = document.createElement("script")
    s2.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"
    s2.onload = () => {
      try {
        const fb = (window as any).firebase
        if (!fb.apps?.length) fb.initializeApp(FIREBASE_CONFIG)
        messagingRef.current = fb.messaging()
        fbReadyRef.current = true
        messagingRef.current.onMessage((payload: any) => {
          const { t: title, b: body } = payload.data || {}
          if (title) { setToast({ title, body: body||"" }); setTimeout(()=>setToast(null),5000) }
        })
        resolve()
      } catch(e) { reject(e) }
    }
    s2.onerror = reject
    s1.onload = () => document.head.appendChild(s2)
    s1.onerror = reject
    document.head.appendChild(s1)
  }), [])

  const registerToken = useCallback(async () => {
    try {
      await loadFirebase()
      const token = await messagingRef.current?.getToken({ vapidKey: VAPID_KEY })
      if (!token) return
      await fetch("/api/push/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, token }),
      })
      console.log("[FCM] ✓ Registered")
      localStorage.setItem("notif-status", "granted")
    } catch(e) { console.warn("[FCM]", e) }
  }, [userId, loadFirebase])

  const handleActivar = useCallback(async () => {
    if (!("Notification" in window)) {
      alert("Tu navegador no soporta notificaciones"); return
    }
    setStatus("asking"); setBanner(false)
    try {
      const perm = await Notification.requestPermission()
      if (perm === "granted") {
        setStatus("granted")
        await registerToken()
      } else {
        setStatus("denied")
        localStorage.setItem("notif-status", "denied")
      }
    } catch(e) { setStatus("idle") }
  }, [registerToken])

  // Expose globally for perfil page
  useEffect(() => { globalSetup = handleActivar; return () => { globalSetup = null } }, [handleActivar])

  useEffect(() => {
    if (!userId || typeof window === "undefined") return
    if (!("Notification" in window)) return

    const perm = Notification.permission
    const saved = localStorage.getItem("notif-status")

    if (perm === "granted") {
      setStatus("granted")
      registerToken()
      return
    }
    if (perm === "denied") { setStatus("denied"); return }

    // "default" and not previously dismissed → show banner
    if (saved === "denied") { setStatus("denied"); return }

    // Show banner after 3s (clear if previously dismissed with "later")
    const t = setTimeout(() => setBanner(true), 3000)
    return () => clearTimeout(t)
  }, [userId, registerToken])

  const handleDismiss = () => {
    setBanner(false)
    localStorage.setItem("notif-status", "later")
  }

  return (
    <>
      {/* Banner */}
      {banner && status === "idle" && (
        <div style={{
          position:"fixed", bottom:"calc(72px + env(safe-area-inset-bottom, 0px))",
          left:16, right:16, zIndex:200,
          background:"var(--surface)", border:"1px solid var(--border)",
          borderRadius:16, padding:"14px 16px",
          boxShadow:"0 8px 32px rgba(0,0,0,.5)",
          display:"flex", alignItems:"center", gap:12,
          animation:"slideUp .3s ease-out",
        }}>
          <span style={{fontSize:26,flexShrink:0}}>🔔</span>
          <div style={{flex:1,minWidth:0}}>
            <div style={{fontWeight:700,fontSize:13,marginBottom:2}}>Activar notificaciones</div>
            <div style={{fontSize:11.5,color:"var(--text-3)",lineHeight:1.4}}>
              Recibe alertas al autorizar o liberar solicitudes
            </div>
          </div>
          <div style={{display:"flex",flexDirection:"column",gap:5,flexShrink:0}}>
            <button onClick={handleActivar} style={{
              padding:"7px 13px",borderRadius:8,border:"none",
              background:"var(--accent)",color:"#111",
              fontSize:12,fontWeight:700,cursor:"pointer",whiteSpace:"nowrap",
            }}>Activar</button>
            <button onClick={handleDismiss} style={{
              padding:"5px 13px",borderRadius:8,border:"1px solid var(--border)",
              background:"none",color:"var(--text-3)",fontSize:11,cursor:"pointer",
            }}>Ahora no</button>
          </div>
        </div>
      )}

      {/* Asking state */}
      {status==="asking" && (
        <div style={{
          position:"fixed", bottom:"calc(72px + env(safe-area-inset-bottom, 0px))",
          left:16, right:16, zIndex:200,
          background:"var(--surface)", border:"1px solid var(--accent)",
          borderRadius:16, padding:"12px 16px",
          display:"flex", alignItems:"center", gap:12,
        }}>
          <span style={{fontSize:18}}>⏳</span>
          <span style={{fontSize:13,color:"var(--text-2)"}}>
            Acepta el permiso en el mensaje del sistema…
          </span>
        </div>
      )}

      {/* Foreground toast */}
      {toast && (
        <div style={{
          position:"fixed",top:20,right:20,zIndex:300,
          background:"var(--surface)",border:"1px solid var(--border)",
          borderLeft:"4px solid var(--accent)",borderRadius:12,
          padding:"14px 18px",boxShadow:"0 8px 32px rgba(0,0,0,.4)",
          maxWidth:320,animation:"slideUp .3s ease-out",
          display:"flex",gap:10,alignItems:"flex-start",
        }}>
          <div style={{flex:1}}>
            <div style={{fontWeight:700,fontSize:14,marginBottom:3}}>🔔 {toast.title}</div>
            {toast.body&&<div style={{fontSize:12,color:"var(--text-2)"}}>{toast.body}</div>}
          </div>
          <button onClick={()=>setToast(null)} style={{
            background:"none",border:"none",color:"var(--text-3)",cursor:"pointer",fontSize:18,lineHeight:1
          }}>×</button>
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/NotifButton.tsx')
cat > 'src/components/ui/NotifButton.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { triggerNotifSetup } from "@/components/ui/PushNotifications"

export function NotifButton() {
  const [perm, setPerm] = useState<string>("default")

  useEffect(() => {
    if ("Notification" in window) setPerm(Notification.permission)
  }, [])

  const handleClick = () => {
    const saved = localStorage.getItem("notif-status")
    // Reset so the setup can run again
    if (saved) localStorage.removeItem("notif-status")
    triggerNotifSetup()
  }

  return (
    <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between" }}>
      <div>
        <div style={{ fontSize:13, fontWeight:600, marginBottom:2 }}>Notificaciones push</div>
        <div style={{ fontSize:11.5, color:"var(--text-3)" }}>
          {perm==="granted" ? "✅ Activadas" :
           perm==="denied"  ? "🚫 Bloqueadas — habilítalas en los ajustes del navegador" :
           "Sin configurar"}
        </div>
      </div>
      {perm !== "denied" && (
        <button onClick={handleClick}
          className="btn sm"
          style={{
            background: perm==="granted" ? "var(--success-soft)" : "var(--accent)",
            border: "none",
            color: perm==="granted" ? "var(--success)" : "#111",
            fontWeight: 600,
          }}>
          {perm==="granted" ? "Reactivar" : "Activar 🔔"}
        </button>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/perfil/page.tsx')
cat > 'src/app/(app)/perfil/page.tsx' << 'FILEEOF'
import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { fmtMXN } from "@/lib/format"
import { NotifButton } from "@/components/ui/NotifButton"

export default async function PerfilPage() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  const [{ data: u }, { data: sols }] = await Promise.all([
    sb.from("usuarios").select("*, centro:centros(*), gerente:usuarios!gerente_id(nombre)").eq("id", user.id).single(),
    sb.from("solicitudes").select("id, tipo, status, monto, saldo_pendiente").eq("usuario_id", user.id),
  ])

  if (!u) redirect("/login")

  const totalAbierto = (sols || [])
    .filter(s => ["liberado","parcial"].includes(s.status) && parseFloat(s.saldo_pendiente) > 0)
    .reduce((a, s) => a + parseFloat(s.saldo_pendiente), 0)

  const ROL_COLOR: Record<string, string> = {
    admin: "var(--accent)", gerente: "var(--success)", tesoreria: "#60a5fa",
    contador: "#c084fc", usuario: "var(--text-3)",
  }

  return (
    <div style={{ maxWidth: 620 }}>
      <div className="page-head">
        <h1 className="page-title">Mi perfil</h1>
      </div>

      {/* Avatar + name */}
      <div className="card" style={{ textAlign: "center", marginBottom: 16, padding: "28px 20px" }}>
        <div style={{ width: 68, height: 68, borderRadius: "50%", margin: "0 auto 14px",
          background: "var(--accent-soft)", color: "var(--accent)",
          display: "grid", placeItems: "center", fontSize: 24, fontWeight: 700 }}>
          {u.iniciales}
        </div>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 4 }}>{u.nombre}</div>
        <div style={{ fontSize: 13, color: "var(--text-3)", marginBottom: 10 }}>{u.correo}</div>
        <span style={{ fontSize: 12, padding: "3px 14px", borderRadius: 20, fontWeight: 600,
          background: ROL_COLOR[u.rol] + "22", color: ROL_COLOR[u.rol] }}>
          {u.rol}
        </span>
      </div>

      {/* Info */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Cuenta</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
          {[
            { label: "Centro de beneficio", value: u.centro ? `${u.centro.id} · ${u.centro.nombre}` : "—" },
            { label: "Departamento", value: u.centro?.depto || "—" },
            { label: "Gerente", value: (u.gerente as any)?.nombre || "—" },
            { label: "División SAP", value: u.division || "4105" },
            { label: "Banco", value: u.banco || "—" },
            { label: "CLABE", value: u.clabe ? "•••• " + u.clabe.slice(-4) : "—" },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, color: "var(--text-3)", textTransform: "uppercase",
                letterSpacing: ".05em", marginBottom: 3 }}>{label}</div>
              <div style={{ fontSize: 13, fontWeight: 500 }}>{value}</div>
            </div>
          ))}
        </div>
        <div style={{ marginTop: 10, fontSize: 11.5, color: "var(--text-3)", fontStyle: "italic" }}>
          Para cambiar CLABE o banco, contacta a Tesorería.
        </div>
        <div style={{ marginTop: 16, paddingTop: 14, borderTop: "1px solid var(--border)" }}>
          <NotifButton/>
        </div>
        <div style={{ marginTop: 14, paddingTop: 12, borderTop: "1px solid var(--border)", fontSize: 12, color: "var(--text-3)" }}>
          Las notificaciones push se activan automáticamente al usar la app.
          Si no las recibiste, cierra y vuelve a abrir la app para ver el banner.
        </div>
      </div>

      {/* Activity summary */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Resumen de actividad</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12 }}>
          {[
            { label: "Total solicitudes", value: (sols || []).length },
            { label: "Anticipos abiertos", value: (sols || []).filter(s => s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0).length },
            { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : undefined },
          ].map(k => (
            <div key={k.label} className="card" style={{ margin: 0, textAlign: "center", padding: "12px 8px" }}>
              <div style={{ fontSize: 18, fontWeight: 700, color: k.color }}>{k.value}</div>
              <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

FILEEOF

git add .
git commit -m "feat: todas solicitudes, notif banner v2, push debug endpoint"
git push
echo "✓ Done"