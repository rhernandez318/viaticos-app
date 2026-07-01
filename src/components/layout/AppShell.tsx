"use client"
import { useState, useEffect } from "react"
import Link from "next/link"
import Image from "next/image"
import { usePathname, useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import type { LucideIcon } from "lucide-react"
import {
  Home,
  LayoutDashboard,
  CheckCircle2,
  ShieldCheck,
  Banknote,
  HandCoins,
  Receipt,
  Paperclip,
  ClipboardList,
  FolderOpen,
  Users,
  Building2,
  BookOpen,
  Gauge,
  Settings,
  FileSpreadsheet,
  BarChart3,
  UserCircle,
  CircleCheckBig,
  Flag,
  UsersRound,
  Search,
  GitCompare,
  Bell,
  LogOut,
  Menu as MenuIcon,
  Moon,
  Sun,
} from "lucide-react"

interface NavItem  { id: string; label: string; icon: LucideIcon; href: string }
interface NavGroup { label?: string; items: NavItem[] }

const NAV_BY_ROL: Record<string, NavGroup[]> = {
  usuario: [
    { items: [
      { id:"dashboard",   label:"Inicio",             icon: Home,           href:"/dashboard" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",    label:"Solicitar anticipo", icon: HandCoins,      href:"/solicitudes/anticipo" },
      { id:"reembolso",   label:"Reembolso",          icon: Receipt,        href:"/solicitudes/reembolso" },
      { id:"solicitudes", label:"Mis solicitudes",    icon: ClipboardList,  href:"/solicitudes" },
    ]},
    { items: [
      { id:"perfil",      label:"Mi perfil",          icon: UserCircle,     href:"/perfil" },
    ]},
  ],
  gerente: [
    { label:"Flujo de autorizaciones", items: [
      { id:"bandeja",      label:"Por aprobar",       icon: CheckCircle2,   href:"/gerente" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",     label:"Solicitar anticipo",icon: HandCoins,      href:"/solicitudes/anticipo" },
      { id:"reembolso",    label:"Reembolso",         icon: Receipt,        href:"/solicitudes/reembolso" },
      { id:"comprobacion", label:"Comprobaciones",    icon: Paperclip,      href:"/solicitudes/comprobacion" },
      { id:"solicitudes",  label:"Mis solicitudes",   icon: ClipboardList,  href:"/solicitudes" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",     label:"Reportes",          icon: BarChart3,      href:"/gerente/reportes" },
      { id:"equipo",       label:"Mi equipo",         icon: UsersRound,     href:"/gerente/equipo" },
    ]},
    { items: [
      { id:"perfil",       label:"Mi perfil",         icon: UserCircle,     href:"/perfil" },
    ]},
  ],
  tesoreria: [
    { items: [
      { id:"workflow",  label:"Workflow",             icon: LayoutDashboard,href:"/dashboard" },
    ]},
    { label:"Gestión", items: [
      { id:"todas",     label:"Todas las sol.",       icon: FolderOpen,     href:"/solicitudes/todas" },
      { id:"liberar",   label:"Liberar pagos",        icon: Banknote,       href:"/tesoreria" },
      { id:"pagados",   label:"Pagados",              icon: CircleCheckBig, href:"/tesoreria/pagados" },
      { id:"deudores",  label:"Deudores",             icon: Flag,           href:"/tesoreria/deudores" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",  label:"Reportes",             icon: BarChart3,      href:"/tesoreria/reportes" },
    ]},
    { items: [
      { id:"perfil",    label:"Mi perfil",            icon: UserCircle,     href:"/perfil" },
    ]},
  ],
  contador: [
    { items: [
      { id:"workflow",         label:"Workflow",             icon: LayoutDashboard,  href:"/dashboard" },
    ]},
    { label:"Gestión", items: [
      { id:"todas",            label:"Todas las sol.",       icon: FolderOpen,       href:"/solicitudes/todas" },
      { id:"polizas",          label:"Pólizas contables",    icon: FileSpreadsheet,  href:"/contador/polizas" },
      { id:"trazabilidad",     label:"Trazabilidad",         icon: Search,           href:"/contador/trazabilidad" },
      { id:"validacion-sat",   label:"Validación SAT",       icon: ShieldCheck,      href:"/contador/validacion-sat" },
      { id:"conciliacion-sat", label:"Conciliación SAT",     icon: GitCompare,       href:"/contador/conciliacion-sat" },
      { id:"catalogo",         label:"Catálogo",             icon: BookOpen,         href:"/contador/catalogo" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",         label:"Reportes",             icon: BarChart3,        href:"/contador/reportes" },
    ]},
    { items: [
      { id:"perfil",           label:"Mi perfil",            icon: UserCircle,       href:"/perfil" },
    ]},
  ],
  admin: [
    { items: [
      { id:"dashboard",    label:"Inicio",                   icon: Home,             href:"/dashboard" },
    ]},
    { label:"Flujo de autorizaciones", items: [
      { id:"bandeja",      label:"Por aprobar",              icon: CheckCircle2,     href:"/gerente" },
      { id:"validar",      label:"Validar (Admin)",          icon: ShieldCheck,      href:"/admin/validar" },
      { id:"liberar",      label:"Liberar pagos",            icon: Banknote,         href:"/tesoreria" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",     label:"Solicitar anticipo",       icon: HandCoins,        href:"/solicitudes/anticipo" },
      { id:"reembolso",    label:"Reembolso",                icon: Receipt,          href:"/solicitudes/reembolso" },
      { id:"comprobacion", label:"Comprobaciones",           icon: Paperclip,        href:"/solicitudes/comprobacion" },
      { id:"solicitudes",  label:"Mis solicitudes",          icon: ClipboardList,    href:"/solicitudes" },
      { id:"todas",        label:"Todas las sol.",           icon: FolderOpen,       href:"/solicitudes/todas" },
    ]},
    { label:"Gestión", items: [
      { id:"usuarios",     label:"Usuarios",                 icon: Users,            href:"/admin/usuarios" },
      { id:"centros",      label:"Centros",                  icon: Building2,        href:"/admin/centros" },
      { id:"catalogo",     label:"Catálogo",                 icon: BookOpen,         href:"/admin/catalogo" },
      { id:"limites",      label:"Límites de gasto",         icon: Gauge,            href:"/admin/limites" },
      { id:"ajustes",      label:"Ajustes sistema",          icon: Settings,         href:"/admin/ajustes" },
      { id:"polizas",      label:"Pólizas",                  icon: FileSpreadsheet,  href:"/contador/polizas" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes",     label:"Reportes",                 icon: BarChart3,        href:"/admin/reportes" },
    ]},
    { items: [
      { id:"perfil",       label:"Mi perfil",                icon: UserCircle,       href:"/perfil" },
    ]},
  ],
}

interface Props {
  user: { nombre: string; rol: string; iniciales: string }
  children: React.ReactNode
}

export function AppShell({ user, children }: Props) {
  const pathname = usePathname()
  const router = useRouter()
  const navGroups = NAV_BY_ROL[user.rol] || []
  const navItems  = navGroups.flatMap(g => g.items)
  const [showUserMenu, setShowUserMenu] = useState(false)
  const [dark, setDark] = useState(true)

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href)

  const cerrarSesion = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  useEffect(() => {
    const t = localStorage.getItem("theme")
    if (t === "light") { setDark(false); document.documentElement.classList.add("light") }
  }, [])

  const toggleTheme = () => {
    const next = !dark
    setDark(next)
    if (next) { document.documentElement.classList.remove("light"); localStorage.setItem("theme","dark") }
    else      { document.documentElement.classList.add("light");    localStorage.setItem("theme","light") }
  }

  return (
    <div className="app-shell">
      {/* ── SIDEBAR DESKTOP ─────────────────────────── */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <Image src="/logo.png" alt="Logo" width={36} height={36} className="brand-logo"/>
          <div>
            <div className="brand-name">Grupo Zapata</div>
            <div className="brand-sub">Viáticos</div>
          </div>
        </div>

        <div className="sidebar-header">
          <button className="icon-btn" onClick={() => router.push("/notificaciones")}
            title="Notificaciones" aria-label="Notificaciones">
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme}
            title="Cambiar tema" aria-label="Cambiar tema">
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>
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
              {group.items.map(item => {
                const Icon = item.icon
                return (
                  <Link key={item.id} href={item.href}
                    className={`nav-item ${isActive(item.href) ? "active" : ""}`}>
                    <Icon size={18} strokeWidth={1.75} style={{ flexShrink:0 }}/>
                    <span>{item.label}</span>
                  </Link>
                )
              })}
              {gi < navGroups.length - 1 && group.label && (
                <div style={{ height:1, background:"var(--border)", margin:"6px 12px 2px" }}/>
              )}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="user-card">
            <div className="user-avatar">{user.iniciales}</div>
            <div style={{ minWidth:0, flex:1 }}>
              <div style={{ fontSize:12, fontWeight:600, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{user.nombre}</div>
              <div style={{ fontSize:10, color:"var(--text-3)", textTransform:"capitalize" }}>{user.rol}</div>
            </div>
          </div>
          <button className="logout-btn" onClick={cerrarSesion}>
            <LogOut size={14} strokeWidth={1.75}/> Cerrar sesión
          </button>
        </div>
      </aside>

      {/* ── BOTTOM NAV MOBILE (4 tabs) + MENU ────────────── */}
      <nav className="mobile-nav">
        {navItems.slice(0, 4).map(item => {
          const Icon = item.icon
          return (
            <Link key={item.id} href={item.href}
              className={`mobile-nav-item ${isActive(item.href) ? "active" : ""}`}>
              <Icon size={20} strokeWidth={1.75}/>
              <span style={{ fontSize:9, marginTop:2 }}>{item.label.split(" ")[0]}</span>
            </Link>
          )
        })}
        <button className={`mobile-nav-item ${showUserMenu ? "active" : ""}`}
          onClick={() => setShowUserMenu(!showUserMenu)}>
          <MenuIcon size={20} strokeWidth={1.75}/>
          <span style={{ fontSize:9, marginTop:2 }}>Más</span>
        </button>
      </nav>

      {/* ── DRAWER MOBILE (grupos con cabeceras) ────────── */}
      {showUserMenu && (
        <div className="mobile-drawer-backdrop" onClick={() => setShowUserMenu(false)}>
          <div className="mobile-drawer" onClick={e => e.stopPropagation()}>
            <div className="drawer-user">
              <div className="user-avatar" style={{ width:40, height:40, fontSize:14 }}>{user.iniciales}</div>
              <div>
                <div style={{ fontSize:14, fontWeight:600 }}>{user.nombre}</div>
                <div style={{ fontSize:11, color:"var(--text-3)", textTransform:"capitalize" }}>{user.rol}</div>
              </div>
            </div>

            <div style={{ display:"flex", flexDirection:"column", gap:0, marginBottom:12 }}>
              <Link href="/perfil" onClick={() => setShowUserMenu(false)}
                style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                  borderRadius:10, color:"var(--text)", textDecoration:"none", marginBottom:8,
                  background: isActive("/perfil") ? "var(--accent-soft)" : "transparent" }}>
                <UserCircle size={20} strokeWidth={1.75}/>
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
                      {visibleItems.map(item => {
                        const Icon = item.icon
                        return (
                          <Link key={item.id} href={item.href}
                            onClick={() => setShowUserMenu(false)}
                            style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                              borderRadius:10, color:"var(--text)", textDecoration:"none",
                              background: isActive(item.href) ? "var(--accent-soft)" : "transparent" }}>
                            <Icon size={20} strokeWidth={1.75}/>
                            <span style={{ fontSize:14 }}>{item.label}</span>
                          </Link>
                        )
                      })}
                    </div>
                  )
                })
              })()}
            </div>

            <button className="logout-btn" onClick={cerrarSesion} style={{ width:"100%" }}>
              <LogOut size={14} strokeWidth={1.75}/> Cerrar sesión
            </button>
          </div>
        </div>
      )}

      {/* ── TOP BAR MOBILE ───────────────────────────────── */}
      <div className="mobile-topbar">
        <div style={{ display:"flex", alignItems:"center", gap:8 }}>
          <Image src="/logo.png" alt="Logo" width={28} height={28}/>
          <span style={{ fontSize:14, fontWeight:600 }}>Viáticos</span>
        </div>
        <div style={{ display:"flex", gap:6 }}>
          <button className="icon-btn" onClick={() => router.push("/notificaciones")}>
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme}>
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>
        </div>
      </div>

      {/* ── CONTENIDO PRINCIPAL ─────────────────────────── */}
      <main className="main-content">{children}</main>
    </div>
  )
}

