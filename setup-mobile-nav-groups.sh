#!/bin/bash
set -e

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

interface NavItem  { id: string; label: string; icon: string; href: string }
interface NavGroup { label?: string; items: NavItem[] }

const NAV_BY_ROL: Record<string, NavGroup[]> = {
  usuario: [
    { items: [
      { id:"dashboard",   label:"Inicio",            icon:"🏠", href:"/dashboard" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",    label:"Solicitar anticipo", icon:"💵", href:"/solicitudes/anticipo" },
      { id:"reembolso",   label:"Reembolso",          icon:"🧾", href:"/solicitudes/reembolso" },
      { id:"solicitudes", label:"Mis solicitudes",    icon:"📋", href:"/solicitudes" },
    ]},
    { items: [
      { id:"perfil",      label:"Mi perfil",          icon:"⚙️", href:"/perfil" },
    ]},
  ],
  gerente: [
    { label:"Flujo de autorizaciones", items: [
      { id:"bandeja",      label:"Por aprobar",       icon:"✅", href:"/gerente" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",     label:"Solicitar anticipo", icon:"💵", href:"/solicitudes/anticipo" },
      { id:"reembolso",    label:"Reembolso",          icon:"🧾", href:"/solicitudes/reembolso" },
      { id:"comprobacion", label:"Comprobaciones",     icon:"📎", href:"/solicitudes/comprobacion" },
      { id:"solicitudes",  label:"Mis solicitudes",    icon:"📋", href:"/solicitudes" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",     label:"Reportes",           icon:"📊", href:"/gerente/reportes" },
      { id:"equipo",       label:"Mi equipo",          icon:"👥", href:"/gerente/equipo" },
    ]},
    { items: [
      { id:"perfil",       label:"Mi perfil",          icon:"⚙️", href:"/perfil" },
    ]},
  ],
  tesoreria: [
    { items: [
      { id:"workflow",  label:"Workflow",              icon:"🗂", href:"/dashboard" },
    ]},
    { label:"Gestión", items: [
      { id:"todas",     label:"Todas las sol.",        icon:"📂", href:"/solicitudes/todas" },
      { id:"liberar",   label:"Liberar pagos",         icon:"💵", href:"/tesoreria" },
      { id:"pagados",   label:"Pagados",               icon:"✅", href:"/tesoreria/pagados" },
      { id:"deudores",  label:"Deudores",              icon:"⚑",  href:"/tesoreria/deudores" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",  label:"Reportes",              icon:"📊", href:"/tesoreria/reportes" },
    ]},
    { items: [
      { id:"perfil",    label:"Mi perfil",             icon:"⚙️", href:"/perfil" },
    ]},
  ],
  contador: [
    { items: [
      { id:"workflow",         label:"Workflow",             icon:"🗂", href:"/dashboard" },
    ]},
    { label:"Gestión", items: [
      { id:"todas",            label:"Todas las sol.",       icon:"📂", href:"/solicitudes/todas" },
      { id:"polizas",          label:"Pólizas contables",    icon:"📒", href:"/contador/polizas" },
      { id:"trazabilidad",     label:"Trazabilidad",         icon:"🔍", href:"/contador/trazabilidad" },
      { id:"validacion-sat",   label:"Validación SAT",       icon:"🛡", href:"/contador/validacion-sat" },
      { id:"conciliacion-sat", label:"Conciliación SAT",     icon:"📊", href:"/contador/conciliacion-sat" },
      { id:"catalogo",         label:"Catálogo",             icon:"📋", href:"/contador/catalogo" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",         label:"Reportes",             icon:"📊", href:"/contador/reportes" },
    ]},
    { items: [
      { id:"perfil",           label:"Mi perfil",            icon:"⚙️", href:"/perfil" },
    ]},
  ],
  admin: [
    { items: [
      { id:"dashboard",    label:"Inicio",                   icon:"🏠", href:"/dashboard" },
    ]},
    { label:"Flujo de autorizaciones", items: [
      { id:"bandeja",      label:"Por aprobar",              icon:"✅", href:"/gerente" },
      { id:"validar",      label:"Validar (Admin)",          icon:"🔐", href:"/admin/validar" },
      { id:"liberar",      label:"Liberar pagos",            icon:"💵", href:"/tesoreria" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",     label:"Solicitar anticipo",       icon:"💵", href:"/solicitudes/anticipo" },
      { id:"reembolso",    label:"Reembolso",                icon:"🧾", href:"/solicitudes/reembolso" },
      { id:"comprobacion", label:"Comprobaciones",           icon:"📎", href:"/solicitudes/comprobacion" },
      { id:"solicitudes",  label:"Mis solicitudes",          icon:"📋", href:"/solicitudes" },
      { id:"todas",        label:"Todas las sol.",           icon:"📂", href:"/solicitudes/todas" },
    ]},
    { label:"Gestión", items: [
      { id:"usuarios",     label:"Usuarios",                 icon:"👥", href:"/admin/usuarios" },
      { id:"centros",      label:"Centros",                  icon:"🏢", href:"/admin/centros" },
      { id:"catalogo",     label:"Catálogo",                 icon:"📋", href:"/admin/catalogo" },
      { id:"limites",      label:"Límites de gasto",         icon:"🚦", href:"/admin/limites" },
      { id:"ajustes",      label:"Ajustes sistema",          icon:"⚙️", href:"/admin/ajustes" },
      { id:"polizas",      label:"Pólizas",                  icon:"📒", href:"/contador/polizas" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",     label:"Reportes",                 icon:"📊", href:"/admin/reportes" },
    ]},
    { items: [
      { id:"perfil",       label:"Mi perfil",                icon:"⚙️", href:"/perfil" },
    ]},
  ],
}

export default function AppShell({ user, children }: { user: any; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const navGroups = NAV_BY_ROL[user.rol] || []
  const navItems = navGroups.flatMap(g => g.items)
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

        <nav style={{ flex:1, display:"flex", flexDirection:"column", overflowY:"auto" }}>
          {navGroups.map((group, gi) => (
            <div key={gi} style={{ marginBottom: group.label ? 4 : 0 }}>
              {group.label && (
                <div style={{
                  fontSize:9, fontWeight:700, textTransform:"uppercase",
                  letterSpacing:"0.1em", color:"var(--text-3)",
                  padding:"10px 14px 4px", userSelect:"none",
                }}>
                  {group.label}
                </div>
              )}
              {group.items.map(item => (
                <Link key={item.id} href={item.href}
                  className={`nav-item ${isActive(item.href) ? "active" : ""}`}>
                  <span style={{ fontSize:15, width:20, textAlign:"center" }}>{item.icon}</span>
                  {item.label}
                </Link>
              ))}
              {gi < navGroups.length - 1 && group.label && (
                <div style={{ height:1, background:"var(--border)", margin:"6px 12px 2px" }}/>
              )}
            </div>
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
            {/* Nav items grouped — exclude items already in bottom tab bar */}
            <div style={{ display:"flex", flexDirection:"column", gap:0, marginBottom:12 }}>
              {/* Mi perfil siempre arriba */}
              <Link href="/perfil" onClick={() => setShowUserMenu(false)}
                style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                  borderRadius:10, color:"var(--text)", textDecoration:"none", marginBottom:8,
                  background: isActive("/perfil") ? "var(--accent-soft)" : "transparent" }}>
                <span style={{ fontSize:18 }}>⚙️</span>
                <span style={{ fontSize:14 }}>Mi perfil</span>
              </Link>
              {(() => {
                const bottomIds = new Set(navItems.slice(0, 4).map(i => i.id))
                return navGroups.map((group, gi) => {
                  const visibleItems = group.items.filter(i => !bottomIds.has(i.id) && i.id !== "perfil")
                  if (!visibleItems.length) return null
                  return (
                    <div key={gi} style={{ marginBottom:6 }}>
                      {group.label && (
                        <div style={{
                          fontSize:10, fontWeight:700, textTransform:"uppercase",
                          letterSpacing:"0.08em", color:"var(--text-3)",
                          padding:"10px 12px 4px", userSelect:"none",
                        }}>
                          {group.label}
                        </div>
                      )}
                      {visibleItems.map(item => (
                        <Link key={item.id} href={item.href}
                          onClick={() => setShowUserMenu(false)}
                          style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                            borderRadius:10, color:"var(--text)", textDecoration:"none",
                            background: isActive(item.href) ? "var(--accent-soft)" : "transparent" }}>
                          <span style={{ fontSize:18 }}>{item.icon}</span>
                          <span style={{ fontSize:14 }}>{item.label}</span>
                        </Link>
                      ))}
                    </div>
                  )
                })
              })()}
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

git add .
git commit -m "feat: grouped nav also in mobile drawer menu"
git push
echo "✓ Done"