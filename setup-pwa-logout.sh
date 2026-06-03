#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/layout.tsx')
cat > 'src/app/layout.tsx' << 'FILEEOF'
import type { Metadata, Viewport } from "next"
import { ThemeProvider } from "@/contexts/ThemeContext"
import { InstallBanner } from "@/components/ui/InstallBanner"
import "./globals.css"

export const metadata: Metadata = {
  title: "Viáticos Grupo Zapata",
  description: "Sistema de gestión de viáticos y gastos corporativos",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Viáticos GZ",
  },
  icons: { icon: "/icon-192.png", apple: "/icon-512.png" },
}

export const viewport: Viewport = {
  themeColor: "#0d0d0d",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" suppressHydrationWarning>
      <head>
        <meta name="mobile-web-app-capable" content="yes"/>
        <meta name="apple-mobile-web-app-capable" content="yes"/>
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent"/>
        <meta name="apple-mobile-web-app-title" content="Viáticos GZ"/>
        <link rel="apple-touch-icon" href="/icon-512.png"/>
        {/* Register SW before React hydration for faster PWA detection */}
        <script dangerouslySetInnerHTML={{ __html: `
          if ('serviceWorker' in navigator) {
            window.addEventListener('load', function() {
              navigator.serviceWorker.register('/sw.js', { scope: '/' })
                .then(function(reg) { console.log('SW registered', reg.scope); })
                .catch(function(err) { console.log('SW error', err); });
            });
          }
        `}}/>
      </head>
      <body>
        <ThemeProvider>
          <InstallBanner/>
          {children}
        </ThemeProvider>
      </body>
    </html>
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
    { id:"liberar",  label:"Liberar pagos", icon:"💵", href:"/tesoreria" },
    { id:"pagados",  label:"Pagados",        icon:"✅", href:"/tesoreria/pagados" },
    { id:"deudores", label:"Deudores",       icon:"⚑",  href:"/tesoreria/deudores" },
    { id:"reportes", label:"Reportes",       icon:"📊", href:"/tesoreria/reportes" },
    { id:"perfil",   label:"Mi perfil",      icon:"⚙️", href:"/perfil" },
  ],
  contador: [
    { id:"polizas",          label:"Pólizas contables", icon:"📒", href:"/contador/polizas" },
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
                { label:"Mi perfil", icon:"⚙️", href:"/perfil" },
                ...navItems.slice(4).filter(i => i.id !== "perfil"),
              ].map(item => (
                <Link key={item.id || item.label} href={(item as any).href}
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

mkdir -p $(dirname 'public/manifest.json')
cat > 'public/manifest.json' << 'FILEEOF'
{
  "name": "Viáticos Grupo Zapata",
  "short_name": "Viáticos GZ",
  "description": "Sistema de gestión de viáticos y gastos corporativos",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "portrait-primary",
  "background_color": "#0d0d0d",
  "theme_color": "#0d0d0d",
  "lang": "es-MX",
  "dir": "ltr",
  "categories": ["business", "finance", "productivity"],
  "prefer_related_applications": false,
  "icons": [
    { "src": "/icon-192.png",          "sizes": "192x192", "type": "image/png", "purpose": "any"      },
    { "src": "/icon-512.png",          "sizes": "512x512", "type": "image/png", "purpose": "any"      },
    { "src": "/icon-192-maskable.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
    { "src": "/icon-512-maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}

FILEEOF

mkdir -p $(dirname 'next.config.ts')
cat > 'next.config.ts' << 'FILEEOF'
import type { NextConfig } from "next"

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/.well-known/assetlinks.json",
        headers: [{ key: "Content-Type", value: "application/json" }],
      },
      {
        source: "/sw.js",
        headers: [
          { key: "Content-Type",  value: "application/javascript" },
          { key: "Cache-Control", value: "no-cache, no-store, must-revalidate" },
          { key: "Service-Worker-Allowed", value: "/" },
        ],
      },
      {
        source: "/manifest.json",
        headers: [{ key: "Content-Type", value: "application/manifest+json" }],
      },
    ]
  },
}

export default nextConfig

FILEEOF

git add .
git commit -m "fix: PWA start_url, SW headers, logout button web+mobile"
git push
echo ""
echo "✓ Deployed! After Vercel finishes (~2min):"
echo "  1. Open Chrome on Android → visit the site"
echo "  2. Chrome menu (3 dots) → Add to Home Screen"
echo "  3. Should show Install (not just Create shortcut)"
echo "  4. Also test: logout button in sidebar (web) and Cuenta tab (mobile)"