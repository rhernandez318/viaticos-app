"use client"

import { usePathname } from "next/navigation"
import Link from "next/link"
import Image from "next/image"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"
import { ThemePanel } from "@/components/ui/ThemePanel"

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
    { id:"bandeja",        label:"Por aprobar",         icon:"✅", href:"/gerente" },
    { id:"equipo",         label:"Mi equipo",            icon:"👥", href:"/gerente/equipo" },
    { id:"anticipo",       label:"Solicitar anticipo",   icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",      label:"Reembolso",            icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"comprobacion",   label:"Comprobaciones",       icon:"📎", href:"/solicitudes/comprobacion" },
    { id:"solicitudes",    label:"Mis solicitudes",      icon:"📋", href:"/solicitudes" },
    { id:"reportes",       label:"Reportes",             icon:"📊", href:"/gerente/reportes" },
    { id:"perfil",         label:"Mi perfil",            icon:"⚙️", href:"/perfil" },
  ],
  tesoreria: [
    { id:"liberar",   label:"Liberar pagos",  icon:"💵", href:"/tesoreria" },
    { id:"pagados",   label:"Pagados",         icon:"✅", href:"/tesoreria/pagados" },
    { id:"deudores",  label:"Deudores",        icon:"⚑",  href:"/tesoreria/deudores" },
    { id:"reportes",  label:"Reportes",        icon:"📊", href:"/tesoreria/reportes" },
    { id:"perfil",    label:"Mi perfil",       icon:"⚙️", href:"/perfil" },
  ],
  contador: [
    { id:"polizas",          label:"Pólizas contables",  icon:"📒", href:"/contador/polizas" },
    { id:"trazabilidad",     label:"Trazabilidad",        icon:"🔍", href:"/contador/trazabilidad" },
    { id:"validacion-sat",   label:"Validación SAT",      icon:"🛡", href:"/contador/validacion-sat" },
    { id:"conciliacion-sat", label:"Conciliación SAT",    icon:"📊", href:"/contador/conciliacion-sat" },
    { id:"reportes",         label:"Reportes",            icon:"📊", href:"/contador/reportes" },
    { id:"catalogo",         label:"Catálogo de gastos",  icon:"📋", href:"/contador/catalogo" },
    { id:"perfil",           label:"Mi perfil",           icon:"⚙️", href:"/perfil" },
  ],
  admin: [
    { id:"dashboard",      label:"Inicio",              icon:"🏠", href:"/dashboard" },
    { id:"bandeja",        label:"Por aprobar",          icon:"✅", href:"/gerente" },
    { id:"liberar",        label:"Liberar pagos",        icon:"💵", href:"/tesoreria" },
    { id:"anticipo",       label:"Solicitar anticipo",   icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",      label:"Reembolso",            icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"comprobacion",   label:"Comprobaciones",       icon:"📎", href:"/solicitudes/comprobacion" },
    { id:"solicitudes",    label:"Mis solicitudes",      icon:"📋", href:"/solicitudes" },
    { id:"usuarios",       label:"Usuarios",             icon:"👥", href:"/admin/usuarios" },
    { id:"centros",        label:"Centros",              icon:"🏢", href:"/admin/centros" },
    { id:"catalogo",       label:"Catálogo",             icon:"📋", href:"/admin/catalogo" },
    { id:"reportes",       label:"Reportes",             icon:"📊", href:"/admin/reportes" },
    { id:"polizas",        label:"Pólizas",              icon:"📒", href:"/contador/polizas" },
    { id:"perfil",         label:"Mi perfil",            icon:"⚙️", href:"/perfil" },
  ],
}

export default function AppShell({ user, children }: { user: any; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const navItems = NAV_BY_ROL[user.rol] || []

  const isActive = (href: string) => {
    if (href === "/dashboard") return pathname === "/dashboard"
    return pathname.startsWith(href)
  }

  const handleLogout = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  return (
    <div className="app-layout">
      {/* Sidebar */}
      <aside className="sidebar">
        {/* Logo + Brand */}
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

        {/* User + logout */}
        <div style={{ borderTop:"1px solid var(--border)", paddingTop:12, marginTop:8 }}>
          <div style={{ display:"flex", alignItems:"center", gap:10, padding:"6px 12px" }}>
            <div style={{
              width:30, height:30, borderRadius:"50%",
              background:"var(--accent-soft)", color:"var(--accent)",
              display:"grid", placeItems:"center", fontSize:12, fontWeight:700
            }}>
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
            style={{ width:"100%", justifyContent:"center", fontSize:12, marginTop:4 }}>
            Cerrar sesión
          </button>
        </div>
      </aside>

      {/* Mobile bottom nav */}
      <nav className="mobile-nav">
        {navItems.slice(0,5).map(item => (
          <Link key={item.id} href={item.href}
            className={`mobile-nav-item ${isActive(item.href) ? "active" : ""}`}>
            <span className="icon">{item.icon}</span>
            <span className="label">{item.label.split(" ")[0]}</span>
          </Link>
        ))}
      </nav>

      {/* Main */}
      <main className="main-content">
        <div style={{ position:"fixed", top:16, right:20, zIndex:40 }}>
          <ThemePanel/>
        </div>
        {children}
      </main>
    </div>
  )
}

