#!/bin/bash
set -e

cat > 'src/components/layout/AppShell.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import Link from "next/link"
import Image from "next/image"
import { usePathname, useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import type { LucideIcon } from "lucide-react"
import {
  Home, LayoutDashboard, CheckCircle2, ShieldCheck, Banknote, HandCoins,
  Receipt, Paperclip, ClipboardList, FolderOpen, Users, Building2,
  BookOpen, Gauge, Settings, FileSpreadsheet, BarChart3, UserCircle,
  CircleCheckBig, Flag, UsersRound, Search, GitCompare, Bell, LogOut,
  Menu as MenuIcon, Moon, Sun,
} from "lucide-react"

interface NavItem  { id: string; label: string; icon: LucideIcon; href: string }
interface NavGroup { label?: string; items: NavItem[] }

const NAV_BY_ROL: Record<string, NavGroup[]> = {
  usuario: [
    { items: [{ id:"dashboard", label:"Inicio", icon: Home, href:"/dashboard" }]},
    { label:"Solicitudes", items: [
      { id:"anticipo",    label:"Solicitar anticipo", icon: HandCoins,     href:"/solicitudes/anticipo" },
      { id:"reembolso",   label:"Reembolso",          icon: Receipt,       href:"/solicitudes/reembolso" },
      { id:"solicitudes", label:"Mis solicitudes",    icon: ClipboardList, href:"/solicitudes" },
    ]},
    { items: [{ id:"perfil", label:"Mi perfil", icon: UserCircle, href:"/perfil" }]},
  ],
  gerente: [
    { label:"Flujo de autorizaciones", items: [
      { id:"bandeja", label:"Por aprobar", icon: CheckCircle2, href:"/gerente" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",     label:"Solicitar anticipo", icon: HandCoins,     href:"/solicitudes/anticipo" },
      { id:"reembolso",    label:"Reembolso",          icon: Receipt,       href:"/solicitudes/reembolso" },
      { id:"comprobacion", label:"Comprobaciones",     icon: Paperclip,     href:"/solicitudes/comprobacion" },
      { id:"solicitudes",  label:"Mis solicitudes",    icon: ClipboardList, href:"/solicitudes" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes", label:"Reportes",   icon: BarChart3,  href:"/gerente/reportes" },
      { id:"equipo",   label:"Mi equipo",  icon: UsersRound, href:"/gerente/equipo" },
    ]},
    { items: [{ id:"perfil", label:"Mi perfil", icon: UserCircle, href:"/perfil" }]},
  ],
  tesoreria: [
    { items: [{ id:"workflow", label:"Workflow", icon: LayoutDashboard, href:"/dashboard" }]},
    { label:"Gestión", items: [
      { id:"todas",    label:"Todas las sol.", icon: FolderOpen,     href:"/solicitudes/todas" },
      { id:"liberar",  label:"Liberar pagos",  icon: Banknote,       href:"/tesoreria" },
      { id:"pagados",  label:"Pagados",        icon: CircleCheckBig, href:"/tesoreria/pagados" },
      { id:"deudores", label:"Deudores",       icon: Flag,           href:"/tesoreria/deudores" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes", label:"Reportes", icon: BarChart3, href:"/tesoreria/reportes" },
    ]},
    { items: [{ id:"perfil", label:"Mi perfil", icon: UserCircle, href:"/perfil" }]},
  ],
  contador: [
    { items: [{ id:"workflow", label:"Workflow", icon: LayoutDashboard, href:"/dashboard" }]},
    { label:"Gestión", items: [
      { id:"todas",            label:"Todas las sol.",     icon: FolderOpen,      href:"/solicitudes/todas" },
      { id:"polizas",          label:"Pólizas contables",  icon: FileSpreadsheet, href:"/contador/polizas" },
      { id:"trazabilidad",     label:"Trazabilidad",       icon: Search,          href:"/contador/trazabilidad" },
      { id:"validacion-sat",   label:"Validación SAT",     icon: ShieldCheck,     href:"/contador/validacion-sat" },
      { id:"conciliacion-sat", label:"Conciliación SAT",   icon: GitCompare,      href:"/contador/conciliacion-sat" },
      { id:"catalogo",         label:"Catálogo",           icon: BookOpen,        href:"/contador/catalogo" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes", label:"Reportes", icon: BarChart3, href:"/contador/reportes" },
    ]},
    { items: [{ id:"perfil", label:"Mi perfil", icon: UserCircle, href:"/perfil" }]},
  ],
  admin: [
    { items: [{ id:"dashboard", label:"Inicio", icon: Home, href:"/dashboard" }]},
    { label:"Flujo de autorizaciones", items: [
      { id:"bandeja", label:"Por aprobar",     icon: CheckCircle2, href:"/gerente" },
      { id:"validar", label:"Validar (Admin)", icon: ShieldCheck,  href:"/admin/validar" },
      { id:"liberar", label:"Liberar pagos",   icon: Banknote,     href:"/tesoreria" },
    ]},
    { label:"Solicitudes", items: [
      { id:"anticipo",     label:"Solicitar anticipo", icon: HandCoins,     href:"/solicitudes/anticipo" },
      { id:"reembolso",    label:"Reembolso",          icon: Receipt,       href:"/solicitudes/reembolso" },
      { id:"comprobacion", label:"Comprobaciones",     icon: Paperclip,     href:"/solicitudes/comprobacion" },
      { id:"solicitudes",  label:"Mis solicitudes",    icon: ClipboardList, href:"/solicitudes" },
      { id:"todas",        label:"Todas las sol.",     icon: FolderOpen,    href:"/solicitudes/todas" },
    ]},
    { label:"Gestión", items: [
      { id:"usuarios", label:"Usuarios",         icon: Users,           href:"/admin/usuarios" },
      { id:"centros",  label:"Centros",          icon: Building2,       href:"/admin/centros" },
      { id:"catalogo", label:"Catálogo",         icon: BookOpen,        href:"/admin/catalogo" },
      { id:"limites",  label:"Límites de gasto", icon: Gauge,           href:"/admin/limites" },
      { id:"ajustes",  label:"Ajustes sistema",  icon: Settings,        href:"/admin/ajustes" },
      { id:"polizas",  label:"Pólizas",          icon: FileSpreadsheet, href:"/contador/polizas" },
    ]},
    { label:"Reportes", items: [
      { id:"reportes", label:"Reportes", icon: BarChart3, href:"/admin/reportes" },
    ]},
    { items: [{ id:"perfil", label:"Mi perfil", icon: UserCircle, href:"/perfil" }]},
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
  const [isMobile, setIsMobile] = useState(false)

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href)

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768)
    checkMobile()
    window.addEventListener("resize", checkMobile)
    const t = localStorage.getItem("theme")
    if (t === "light") { setDark(false); document.documentElement.classList.add("light") }
    return () => window.removeEventListener("resize", checkMobile)
  }, [])

  const cerrarSesion = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  const toggleTheme = () => {
    const next = !dark
    setDark(next)
    if (next) { document.documentElement.classList.remove("light"); localStorage.setItem("theme","dark") }
    else      { document.documentElement.classList.add("light");    localStorage.setItem("theme","light") }
  }

  // Estilos inline garantizan el layout — no dependen de globals.css
  const containerStyle: React.CSSProperties = {
    display: "grid",
    gridTemplateColumns: isMobile ? "1fr" : "240px 1fr",
    minHeight: "100vh",
    background: "var(--bg, #0f1114)",
  }
  const sidebarStyle: React.CSSProperties = {
    display: isMobile ? "none" : "flex",
    flexDirection: "column",
    width: 240,
    borderRight: "1px solid var(--border, #23262c)",
    background: "var(--surface, #14171b)",
    padding: 14,
    gap: 8,
    height: "100vh",
    position: "sticky",
    top: 0,
    overflowY: "auto",
  }
  const mainStyle: React.CSSProperties = {
    padding: isMobile ? "60px 14px 80px" : 20,
    overflowX: "hidden",
    minWidth: 0,
  }
  const mobileNavStyle: React.CSSProperties = {
    display: isMobile ? "flex" : "none",
    position: "fixed",
    bottom: 0, left: 0, right: 0,
    height: 60,
    background: "var(--surface, #14171b)",
    borderTop: "1px solid var(--border, #23262c)",
    zIndex: 100,
    justifyContent: "space-around",
    alignItems: "center",
  }
  const mobileTopbarStyle: React.CSSProperties = {
    display: isMobile ? "flex" : "none",
    position: "fixed",
    top: 0, left: 0, right: 0,
    height: 48,
    background: "var(--surface, #14171b)",
    borderBottom: "1px solid var(--border, #23262c)",
    zIndex: 99,
    justifyContent: "space-between",
    alignItems: "center",
    padding: "0 14px",
  }

  return (
    <div style={containerStyle}>
      {/* SIDEBAR DESKTOP */}
      <aside style={sidebarStyle} className="sidebar">
        <div style={{ display:"flex", alignItems:"center", gap:10, padding:"4px 8px 12px" }}>
          <Image src="/logo.png" alt="Logo" width={36} height={36} style={{ borderRadius:8 }}/>
          <div>
            <div style={{ fontSize:12, fontWeight:700 }}>Grupo Zapata</div>
            <div style={{ fontSize:10, color:"var(--text-3, #888)" }}>Viáticos</div>
          </div>
        </div>

        <div style={{ display:"flex", gap:6, padding:"0 4px" }}>
          <button className="icon-btn" onClick={() => router.push("/notificaciones")} title="Notificaciones">
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme} title="Cambiar tema">
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>
        </div>

        <nav style={{ flex:1, display:"flex", flexDirection:"column", overflowY:"auto", marginTop:8 }}>
          {navGroups.map((group, gi) => (
            <div key={gi} style={{ marginBottom: group.label ? 4 : 0 }}>
              {group.label && (
                <div style={{
                  fontSize:9, fontWeight:700, textTransform:"uppercase",
                  letterSpacing:"0.1em", color:"var(--text-3, #888)",
                  padding:"10px 14px 4px", userSelect:"none",
                }}>
                  {group.label}
                </div>
              )}
              {group.items.map(item => {
                const Icon = item.icon
                return (
                  <Link key={item.id} href={item.href}
                    className={`nav-item ${isActive(item.href) ? "active" : ""}`}
                    style={{
                      display:"flex", alignItems:"center", gap:10,
                      padding:"8px 12px", borderRadius:8, textDecoration:"none",
                      color: isActive(item.href) ? "var(--accent, #c5f24d)" : "var(--text, #e5e7eb)",
                      background: isActive(item.href) ? "var(--accent-soft, rgba(197,242,77,0.1))" : "transparent",
                      fontSize:13, fontWeight: isActive(item.href) ? 600 : 400,
                    }}>
                    <Icon size={18} strokeWidth={1.75} style={{ flexShrink:0 }}/>
                    <span style={{ overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                      {item.label}
                    </span>
                  </Link>
                )
              })}
              {gi < navGroups.length - 1 && group.label && (
                <div style={{ height:1, background:"var(--border, #23262c)", margin:"6px 12px 2px" }}/>
              )}
            </div>
          ))}
        </nav>

        <div style={{ borderTop:"1px solid var(--border, #23262c)", paddingTop:10, marginTop:8 }}>
          <div style={{ display:"flex", alignItems:"center", gap:8, padding:"4px 8px", marginBottom:8 }}>
            <div style={{
              width:32, height:32, borderRadius:"50%",
              background:"var(--surface-2, #1a1e24)",
              border:"1px solid var(--border, #23262c)",
              display:"grid", placeItems:"center", fontSize:11, fontWeight:700,
              flexShrink:0,
            }}>{user.iniciales}</div>
            <div style={{ minWidth:0, flex:1 }}>
              <div style={{ fontSize:12, fontWeight:600, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{user.nombre}</div>
              <div style={{ fontSize:10, color:"var(--text-3, #888)", textTransform:"capitalize" }}>{user.rol}</div>
            </div>
          </div>
          <button onClick={cerrarSesion}
            style={{
              width:"100%", display:"flex", alignItems:"center", gap:8,
              padding:"8px 12px", borderRadius:8, border:"none", cursor:"pointer",
              background:"transparent", color:"var(--text-2, #aaa)", fontSize:12,
            }}>
            <LogOut size={14} strokeWidth={1.75}/> Cerrar sesión
          </button>
        </div>
      </aside>

      {/* TOP BAR MOBILE */}
      <div style={mobileTopbarStyle}>
        <div style={{ display:"flex", alignItems:"center", gap:8 }}>
          <Image src="/logo.png" alt="Logo" width={28} height={28} style={{ borderRadius:6 }}/>
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

      {/* MAIN */}
      <main style={mainStyle}>{children}</main>

      {/* BOTTOM NAV MOBILE */}
      <nav style={mobileNavStyle}>
        {navItems.slice(0, 4).map(item => {
          const Icon = item.icon
          return (
            <Link key={item.id} href={item.href}
              style={{
                display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center",
                gap:2, flex:1, padding:"6px 2px", textDecoration:"none",
                color: isActive(item.href) ? "var(--accent, #c5f24d)" : "var(--text-3, #888)",
              }}>
              <Icon size={20} strokeWidth={1.75}/>
              <span style={{ fontSize:9 }}>{item.label.split(" ")[0]}</span>
            </Link>
          )
        })}
        <button onClick={() => setShowUserMenu(!showUserMenu)}
          style={{
            display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center",
            gap:2, flex:1, padding:"6px 2px", background:"transparent", border:"none",
            color: showUserMenu ? "var(--accent, #c5f24d)" : "var(--text-3, #888)",
            cursor:"pointer",
          }}>
          <MenuIcon size={20} strokeWidth={1.75}/>
          <span style={{ fontSize:9 }}>Más</span>
        </button>
      </nav>

      {/* DRAWER MOBILE */}
      {showUserMenu && (
        <div onClick={() => setShowUserMenu(false)}
          style={{
            position:"fixed", inset:0, background:"rgba(0,0,0,0.5)",
            zIndex:200, display:"flex", alignItems:"flex-end",
          }}>
          <div onClick={e => e.stopPropagation()}
            style={{
              width:"100%", background:"var(--surface, #14171b)",
              borderTopLeftRadius:16, borderTopRightRadius:16,
              padding:16, maxHeight:"80vh", overflowY:"auto",
            }}>
            <div style={{ display:"flex", alignItems:"center", gap:10, marginBottom:14 }}>
              <div style={{
                width:40, height:40, borderRadius:"50%",
                background:"var(--surface-2, #1a1e24)", border:"1px solid var(--border, #23262c)",
                display:"grid", placeItems:"center", fontSize:14, fontWeight:700,
              }}>{user.iniciales}</div>
              <div>
                <div style={{ fontSize:14, fontWeight:600 }}>{user.nombre}</div>
                <div style={{ fontSize:11, color:"var(--text-3, #888)", textTransform:"capitalize" }}>{user.rol}</div>
              </div>
            </div>

            <Link href="/perfil" onClick={() => setShowUserMenu(false)}
              style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                borderRadius:10, color:"var(--text, #e5e7eb)", textDecoration:"none", marginBottom:8,
                background: isActive("/perfil") ? "var(--accent-soft, rgba(197,242,77,0.1))" : "transparent" }}>
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
                        letterSpacing:"0.08em", color:"var(--text-3, #888)",
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
                            borderRadius:10, color:"var(--text, #e5e7eb)", textDecoration:"none",
                            background: isActive(item.href) ? "var(--accent-soft, rgba(197,242,77,0.1))" : "transparent" }}>
                          <Icon size={20} strokeWidth={1.75}/>
                          <span style={{ fontSize:14 }}>{item.label}</span>
                        </Link>
                      )
                    })}
                  </div>
                )
              })
            })()}

            <button onClick={cerrarSesion}
              style={{
                width:"100%", display:"flex", alignItems:"center", justifyContent:"center",
                gap:8, padding:"10px 12px", borderRadius:10, border:"1px solid var(--border, #23262c)",
                background:"transparent", color:"var(--text-2, #aaa)", fontSize:13,
                cursor:"pointer", marginTop:12,
              }}>
              <LogOut size={14} strokeWidth={1.75}/> Cerrar sesión
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

export default AppShell

FILEEOF

npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

git add .
git commit -m "fix: AppShell inline layout styles guarantee grid works, added default export"
git push
echo "✓ Done"