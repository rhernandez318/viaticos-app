#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/layout.tsx')
cat > 'src/app/layout.tsx' << 'FILEEOF'
import type { Metadata, Viewport } from "next"
import { ThemeProvider } from "@/contexts/ThemeContext"
import { PWARegister } from "@/components/ui/PWARegister"
import "./globals.css"

export const metadata: Metadata = {
  title: "Sistema de Viáticos — Grupo Zapata",
  description: "Sistema de gestión de viáticos y gastos",
  manifest: "/manifest.json",
  appleWebApp: { capable: true, statusBarStyle: "black-translucent", title: "Viáticos GZ" },
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
        <link rel="apple-touch-icon" href="/logo.png"/>
      </head>
      <body>
        <ThemeProvider><PWARegister/>{children}</ThemeProvider>
      </body>
    </html>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(auth)/login/page.tsx')
cat > 'src/app/(auth)/login/page.tsx' << 'FILEEOF'
"use client"
import { useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"

export default function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string|null>(null)
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) { setError("Credenciales incorrectas"); setLoading(false); return }
    router.push("/dashboard")
  }

  return (
    <div style={{ minHeight:"100vh", display:"grid", placeItems:"center", background:"var(--bg)" }}>
      <div style={{ width:"100%", maxWidth:380, padding:"0 20px" }}>
        {/* Logo + Brand */}
        <div style={{ textAlign:"center", marginBottom:32 }}>
          <div style={{ width:80, height:80, margin:"0 auto 16px", borderRadius:20,
            overflow:"hidden", background:"white", padding:4,
            boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={72} height={72}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontFamily:"var(--f-display)", fontSize:24, fontWeight:800,
            letterSpacing:"-0.03em", marginBottom:4 }}>
            Grupo Zapata
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)" }}>Sistema de Viáticos</div>
        </div>

        <form onSubmit={handleLogin} style={{ display:"flex", flexDirection:"column", gap:12 }}>
          <div>
            <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>Correo electrónico</label>
            <input className="input" type="email" value={email} onChange={e=>setEmail(e.target.value)}
              required placeholder="usuario@grupoznapata.com.mx" autoComplete="email"/>
          </div>
          <div>
            <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>Contraseña</label>
            <input className="input" type="password" value={password} onChange={e=>setPassword(e.target.value)}
              required placeholder="••••••••" autoComplete="current-password"/>
          </div>
          {error && (
            <div style={{ padding:"8px 12px", background:"var(--danger-soft)", borderRadius:"var(--r-md)",
              fontSize:12, color:"var(--danger)" }}>{error}</div>
          )}
          <button className="btn primary" type="submit" disabled={loading}
            style={{ justifyContent:"center", marginTop:4, padding:"12px" }}>
            {loading ? "Iniciando sesión…" : "Entrar →"}
          </button>
        </form>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/catalogo/page.tsx')
cat > 'src/app/(app)/contador/catalogo/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

export default function ContadorCatalogoPage() {
  const [cuentas, setCuentas] = useState<any[]>([])
  const [busqueda, setBusqueda] = useState("")
  const [filtroGrupo, setFiltroGrupo] = useState("todos")
  const [loading, setLoading] = useState(true)

  useEffect(()=>{
    const sb = createClient()
    sb.from("cuentas_contables").select("*").eq("activo",true).order("cuenta")
      .then(({data})=>{ setCuentas(data||[]); setLoading(false) })
  },[])

  const grupos = ["todos", ...Array.from(new Set(cuentas.map((c:any)=>c.grupo))).sort() as string[]]
  const filtradas = cuentas.filter((c:any)=>
    (filtroGrupo==="todos"||c.grupo===filtroGrupo)&&
    (!busqueda||c.cuenta?.includes(busqueda)||c.nombre?.toLowerCase().includes(busqueda.toLowerCase())))

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Catálogo de gastos</h1>
          <div className="page-sub">{cuentas.length} cuentas activas</div></div>
      </div>
      <div style={{display:"flex",gap:8,marginBottom:14,flexWrap:"wrap"}}>
        <input className="input" placeholder="Buscar…" value={busqueda} onChange={e=>setBusqueda(e.target.value)} style={{flex:"1 1 200px",maxWidth:320}}/>
        <select className="select" style={{width:160}} value={filtroGrupo} onChange={e=>setFiltroGrupo(e.target.value)}>
          {grupos.map(g=><option key={g} value={g}>{g==="todos"?"Todos los grupos":g}</option>)}
        </select>
      </div>
      <div className="card" style={{padding:0,overflow:"hidden"}}>
        {loading ? <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div> : (
          <table className="t">
            <thead><tr><th>Cuenta</th><th>Nombre</th><th>Grupo</th></tr></thead>
            <tbody>{filtradas.map((c:any)=>(
              <tr key={c.cuenta}>
                <td className="mono" style={{fontWeight:700,color:"var(--accent)"}}>{c.cuenta}</td>
                <td>{c.nombre}</td>
                <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,background:"var(--surface-2)",color:"var(--text-2)"}}>{c.grupo}</span></td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
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

FILEEOF

mkdir -p $(dirname 'src/components/ui/ThemePanel.tsx')
cat > 'src/components/ui/ThemePanel.tsx' << 'FILEEOF'
"use client"
import { useState } from "react"
import { useTheme } from "@/contexts/ThemeContext"

export function ThemePanel() {
  const { mode, accent, setMode, setAccent, accents } = useTheme()
  const [open, setOpen] = useState(false)

  return (
    <div style={{ position:"relative" }}>
      <button onClick={() => setOpen(!open)}
        style={{ width:32, height:32, borderRadius:8, border:"1px solid var(--border)",
          background:"var(--surface-2)", display:"grid", placeItems:"center",
          cursor:"pointer", fontSize:16 }}>
        {mode === "dark" ? "🌙" : "☀️"}
      </button>

      {open && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:49 }} onClick={() => setOpen(false)}/>
          <div style={{ position:"absolute", top:40, right:0, zIndex:50, width:220,
            background:"var(--surface)", border:"1px solid var(--border)", borderRadius:12,
            padding:14, boxShadow:"0 8px 32px rgba(0,0,0,.3)" }}>
            <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
              letterSpacing:".06em", color:"var(--text-3)", marginBottom:10 }}>
              Tema
            </div>
            {/* Mode toggle */}
            <div style={{ display:"flex", gap:6, marginBottom:14 }}>
              {(["dark","light"] as const).map(m => (
                <button key={m} onClick={() => setMode(m)}
                  style={{ flex:1, padding:"7px 0", borderRadius:8, fontSize:12, fontWeight:600,
                    border:"1px solid",
                    borderColor: mode===m ? "var(--accent)" : "var(--border)",
                    background: mode===m ? "var(--accent-soft)" : "var(--surface-2)",
                    color: mode===m ? "var(--accent)" : "var(--text-3)",
                    cursor:"pointer" }}>
                  {m === "dark" ? "🌙 Oscuro" : "☀️ Claro"}
                </button>
              ))}
            </div>
            <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
              letterSpacing:".06em", color:"var(--text-3)", marginBottom:10 }}>
              Color de acento
            </div>
            <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:6 }}>
              {(Object.entries(accents) as [any, any][]).map(([key, val]) => (
                <button key={key} onClick={() => setAccent(key)}
                  style={{ padding:"8px 6px", borderRadius:8, fontSize:11, fontWeight:600,
                    border:`2px solid ${accent===key ? val.color : "var(--border)"}`,
                    background: accent===key ? val.soft : "var(--surface-2)",
                    color: accent===key ? val.color : "var(--text-2)",
                    cursor:"pointer", display:"flex", alignItems:"center", gap:6 }}>
                  <span style={{ width:12, height:12, borderRadius:"50%",
                    background:val.color, flexShrink:0 }}/>
                  {val.name}
                </button>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/PWARegister.tsx')
cat > 'src/components/ui/PWARegister.tsx' << 'FILEEOF'
"use client"
import { useEffect } from "react"

export function PWARegister() {
  useEffect(() => {
    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(console.error)
    }
  }, [])
  return null
}

FILEEOF

mkdir -p $(dirname 'src/contexts/ThemeContext.tsx')
cat > 'src/contexts/ThemeContext.tsx' << 'FILEEOF'
"use client"
import { createContext, useContext, useState, useEffect } from "react"

type Mode = "dark" | "light"
type Accent = "lime" | "blue" | "orange" | "purple"

const ACCENTS: Record<Accent, { name:string; color:string; soft:string }> = {
  lime:   { name:"Verde lima", color:"#c5f24d", soft:"rgba(197,242,77,.12)" },
  blue:   { name:"Azul",       color:"#60a5fa", soft:"rgba(96,165,250,.12)" },
  orange: { name:"Naranja",    color:"#f97316", soft:"rgba(249,115,22,.12)" },
  purple: { name:"Morado",     color:"#c084fc", soft:"rgba(192,132,252,.12)" },
}

interface ThemeCtx {
  mode: Mode; accent: Accent
  setMode: (m: Mode) => void
  setAccent: (a: Accent) => void
  accents: typeof ACCENTS
}

const ThemeContext = createContext<ThemeCtx|null>(null)

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setModeState] = useState<Mode>("dark")
  const [accent, setAccentState] = useState<Accent>("lime")

  // Load from localStorage
  useEffect(() => {
    const m = localStorage.getItem("vz-mode") as Mode
    const a = localStorage.getItem("vz-accent") as Accent
    if (m === "light" || m === "dark") setModeState(m)
    if (a && ACCENTS[a]) setAccentState(a)
  }, [])

  // Apply CSS variables
  useEffect(() => {
    const root = document.documentElement
    const ac = ACCENTS[accent]
    root.style.setProperty("--accent", ac.color)
    root.style.setProperty("--accent-soft", ac.soft)
    if (mode === "light") {
      root.classList.add("light")
    } else {
      root.classList.remove("light")
    }
  }, [mode, accent])

  const setMode = (m: Mode) => { setModeState(m); localStorage.setItem("vz-mode", m) }
  const setAccent = (a: Accent) => { setAccentState(a); localStorage.setItem("vz-accent", a) }

  return (
    <ThemeContext.Provider value={{ mode, accent, setMode, setAccent, accents:ACCENTS }}>
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => useContext(ThemeContext)!

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
    grid-template-columns: 1fr;
    grid-template-rows: 1fr auto;
  }
  .sidebar {
    display: none;
  }
  .main-content {
    padding: 16px 16px 80px;
  }
  .page-title { font-size: 20px; }
  .page-head { margin-bottom: 14px; }

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

FILEEOF

cat > 'public/manifest.json' << 'FILEEOF'
{
  "name": "Viáticos Grupo Zapata",
  "short_name": "Viáticos GZ",
  "description": "Sistema de gestión de viáticos y gastos",
  "start_url": "/dashboard",
  "display": "standalone",
  "background_color": "#0d0d0d",
  "theme_color": "#0d0d0d",
  "orientation": "portrait-primary",
  "icons": [
    { "src": "/logo.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "/logo.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ],
  "categories": ["finance", "business"],
  "lang": "es"
}

FILEEOF

cat > 'public/sw.js' << 'FILEEOF'
const CACHE = "viaticos-gz-v1"
const STATIC = ["/", "/login", "/dashboard", "/logo.png", "/manifest.json"]

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(STATIC).catch(()=>{})))
  self.skipWaiting()
})

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ))
  self.clients.claim()
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  if (e.request.url.includes("/api/") || e.request.url.includes("supabase")) return
  e.respondWith(
    fetch(e.request).then(res => {
      const clone = res.clone()
      caches.open(CACHE).then(c => c.put(e.request, clone))
      return res
    }).catch(() => caches.match(e.request))
  )
})

FILEEOF

echo "⚠ Dont forget to copy logo.png manually to public/logo.png"
git add .
git commit -m "feat: logo, Grupo Zapata, theme tweaks, mobile nav, PWA"
git push
echo "✓ All done!"