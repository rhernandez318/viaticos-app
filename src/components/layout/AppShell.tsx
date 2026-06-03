"use client"

import { usePathname } from "next/navigation"
import Link from "next/link"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"

const ICONS: Record<string, string> = {
  home: "⊞", book: "📋", chart: "📊", users: "👥", settings: "⚙️",
  check: "✓", shield: "🛡", search: "🔍", cash: "💵", flag: "⚑",
}

interface NavItem { id: string; label: string; icon: string; href: string }

const NAV_BY_ROL: Record<string, NavItem[]> = {
  usuario: [
    { id: "dashboard", label: "Inicio", icon: "home", href: "/dashboard" },
    { id: "anticipo", label: "Solicitar anticipo", icon: "cash", href: "/solicitudes/anticipo" },
    { id: "reembolso", label: "Reembolso", icon: "check", href: "/solicitudes/reembolso" },
    { id: "historial", label: "Mis solicitudes", icon: "book", href: "/solicitudes" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  gerente: [
    { id: "bandeja", label: "Por aprobar", icon: "check", href: "/gerente" },
    { id: "equipo", label: "Mi equipo", icon: "users", href: "/gerente/equipo" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/gerente/reportes" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  tesoreria: [
    { id: "liberar", label: "Liberar pagos", icon: "cash", href: "/tesoreria" },
    { id: "pagados", label: "Pagados", icon: "check", href: "/tesoreria/pagados" },
    { id: "deudores", label: "Deudores", icon: "flag", href: "/tesoreria/deudores" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/tesoreria/reportes" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  contador: [
    { id: "polizas", label: "Pólizas contables", icon: "book", href: "/contador/polizas" },
    { id: "trazabilidad", label: "Trazabilidad", icon: "search", href: "/contador/trazabilidad" },
    { id: "validacion-sat", label: "Validación SAT", icon: "shield", href: "/contador/validacion-sat" },
    { id: "conciliacion-sat", label: "Conciliación SAT", icon: "check", href: "/contador/conciliacion-sat" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/contador/reportes" },
    { id: "catalogo", label: "Catálogo de gastos", icon: "book", href: "/contador/catalogo" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  admin: [
    { id: "dashboard", label: "Inicio", icon: "home", href: "/dashboard" },
    { id: "bandeja", label: "Por aprobar", icon: "check", href: "/admin/bandeja" },
    { id: "liberar", label: "Liberar pagos", icon: "cash", href: "/admin/liberar" },
    { id: "usuarios", label: "Usuarios", icon: "users", href: "/admin/usuarios" },
    { id: "centros", label: "Centros", icon: "book", href: "/admin/centros" },
    { id: "catalogo", label: "Catálogo", icon: "book", href: "/admin/catalogo" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/admin/reportes" },
    { id: "polizas", label: "Pólizas", icon: "book", href: "/contador/polizas" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
}

export default function AppShell({ user, children }: { user: any; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const navItems = NAV_BY_ROL[user.rol] || []

  const handleLogout = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  return (
    <div className="app-layout">
      {/* Sidebar */}
      <aside className="sidebar">
        <div style={{ padding: "8px 12px 20px" }}>
          <div style={{ fontSize: 15, fontWeight: 700, letterSpacing: "-0.02em" }}>
            Casa Zapata
          </div>
          <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>Viáticos</div>
        </div>

        <nav style={{ flex: 1 }}>
          {navItems.map((item) => (
            <Link
              key={item.id}
              href={item.href}
              className={`nav-item ${pathname.startsWith(item.href) && item.href !== "/" ? "active" : ""}`}
            >
              <span style={{ fontSize: 15 }}>{ICONS[item.icon] || "•"}</span>
              {item.label}
            </Link>
          ))}
        </nav>

        {/* User info */}
        <div style={{ borderTop: "1px solid var(--border)", paddingTop: 12, marginTop: 8 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "6px 12px" }}>
            <div style={{
              width: 30, height: 30, borderRadius: "50%",
              background: "var(--accent-soft)", color: "var(--accent)",
              display: "grid", placeItems: "center",
              fontSize: 12, fontWeight: 700
            }}>
              {user.iniciales}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 12, fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {user.nombre}
              </div>
              <div style={{ fontSize: 10, color: "var(--text-3)", textTransform: "capitalize" }}>{user.rol}</div>
            </div>
          </div>
          <button className="btn ghost" onClick={handleLogout}
            style={{ width: "100%", justifyContent: "center", fontSize: 12, marginTop: 4 }}>
            Cerrar sesión
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="main-content">
        {children}
      </main>
    </div>
  )
}

