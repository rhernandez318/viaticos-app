#!/bin/bash
set -e

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
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ fontSize:13, fontWeight:700, letterSpacing:"-0.02em" }}>Grupo Zapata</div>
            <div style={{ fontSize:10, color:"var(--text-3)" }}>Viáticos</div>
          </div>
          <div style={{ display:"flex", gap:4, alignItems:"center" }}>
            <NotificationBell userId={user.id}/>
            <ThemePanel/>
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
    position: sticky;
    top: 0;
    z-index: 50;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 10px 16px;
    margin: -16px -16px 16px -16px;
  }
  .main-content {
    padding-top: 0 !important;
  }
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/PushNotifications.tsx')
cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState, useRef, useCallback } from "react"

// Firebase public config - safe to hardcode (client-side values, not secrets)
const VAPID_KEY = "BC4H1SRGR-megh4PQ-N4BpczTZkkZF3F8cfmS7bW1WL0Zp5rnfsN59Q7L9cKkUBaoo7NZ-2x0H_ja23MtUWinmQ"
const FIREBASE_CONFIG = {
  apiKey:            "AIzaSyD5WCpMWnQkwLJplAtbOXrjU2_5gwSRI2w",
  authDomain:        "viaticos-zapata.firebaseapp.com",
  projectId:         "viaticos-zapata",
  storageBucket:     "viaticos-zapata.appspot.com",
  messagingSenderId: "318139943193",
  appId:             "1:318139943193:web:3fade17ff5c1e89a805d88",
}

interface Props { userId: string }
type Status = "idle" | "asking" | "granted" | "denied"

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
    const load = (src: string): Promise<void> => new Promise((res, rej) => {
      const s = document.createElement("script")
      s.src = src; s.async = true
      s.onload = () => res(); s.onerror = () => rej(new Error(`Failed to load ${src}`))
      document.head.appendChild(s)
    })
    load("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js")
      .then(() => load("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"))
      .then(() => {
        const fb = (window as any).firebase
        if (!fb) { reject(new Error("Firebase not available")); return }
        if (!fb.apps?.length) fb.initializeApp(FIREBASE_CONFIG)
        messagingRef.current = fb.messaging()
        fbReadyRef.current = true
        messagingRef.current.onMessage((payload: any) => {
          const { t: title, b: body } = payload.data || {}
          if (title) { setToast({ title, body: body||"" }); setTimeout(() => setToast(null), 5000) }
        })
        resolve()
      })
      .catch(reject)
  }), [])

  const registerToken = useCallback(async () => {
    try {
      await loadFirebase()

      // Explicitly register Firebase SW and pass it to getToken
      let swReg: ServiceWorkerRegistration | undefined
      try {
        swReg = await navigator.serviceWorker.register("/firebase-messaging-sw.js", { scope: "/" })
        await navigator.serviceWorker.ready
        console.log("[FCM] Firebase SW registered:", swReg.scope)
      } catch(e) {
        console.warn("[FCM] Could not register firebase SW, using default:", e)
      }

      const token = await messagingRef.current?.getToken({
        vapidKey: VAPID_KEY,
        ...(swReg ? { serviceWorkerRegistration: swReg } : {}),
      })

      if (!token) { console.warn("[FCM] No token returned - check VAPID key and permissions"); return }

      console.log("[FCM] ✓ Token:", token.slice(0, 30) + "...")

      const res = await fetch("/api/push/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, token }),
      })
      const data = await res.json()
      if (data.ok) {
        console.log("[FCM] ✓ Token saved to DB")
        localStorage.setItem("notif-status", "granted")
      } else {
        console.error("[FCM] DB save failed:", data)
      }
    } catch(e: any) {
      console.error("[FCM] registerToken error:", e?.message || e)
    }
  }, [userId, loadFirebase])

  const handleActivar = useCallback(async () => {
    if (!("Notification" in window)) { alert("Tu navegador no soporta notificaciones"); return }
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
    } catch(e: any) {
      console.error("[FCM] handleActivar error:", e?.message || e)
      setStatus("idle")
    }
  }, [registerToken])

  useEffect(() => { globalSetup = handleActivar; return () => { globalSetup = null } }, [handleActivar])

  useEffect(() => {
    if (!userId || typeof window === "undefined") return
    if (!("Notification" in window)) return

    const perm = Notification.permission
    if (perm === "granted") {
      setStatus("granted")
      registerToken() // Always refresh token
      return
    }
    if (perm === "denied") { setStatus("denied"); return }

    const saved = localStorage.getItem("notif-status")
    if (saved === "denied") { setStatus("denied"); return }

    const t = setTimeout(() => setBanner(true), 3000)
    return () => clearTimeout(t)
  }, [userId, registerToken])

  const handleDismiss = () => { setBanner(false); localStorage.setItem("notif-status", "later") }

  return (
    <>
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

mkdir -p $(dirname 'src/components/ui/NotificationBell.tsx')
cat > 'src/components/ui/NotificationBell.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtFecha } from "@/lib/format"

interface Notif {
  id: string
  titulo: string
  cuerpo: string
  tipo: string
  leida: boolean
  created_at: string
  solicitud_id?: string
}

const TIPO_ICON: Record<string, string> = {
  aprobacion: "✅", rechazo: "❌", liberacion: "💵",
  comprobacion: "📎", cierre: "🏦", sistema: "ℹ️", default: "🔔",
}

export function NotificationBell({ userId }: { userId: string }) {
  const [notifs, setNotifs] = useState<Notif[]>([])
  const [open, setOpen] = useState(false)
  const unread = notifs.filter(n => !n.leida).length

  const load = useCallback(async () => {
    const sb = createClient()
    // Try notificaciones table, fallback to bitacora
    const { data, error } = await sb
      .from("notificaciones")
      .select("*")
      .eq("usuario_id", userId)
      .order("created_at", { ascending: false })
      .limit(30)

    if (!error && data) {
      setNotifs(data)
    } else {
      // Fallback: use bitacora entries as notifications
      const { data: bData } = await sb
        .from("bitacora")
        .select("id, accion, detalle, ts, solicitud_id")
        .order("ts", { ascending: false })
        .limit(20)
      if (bData && bData.length > 0) {
        setNotifs(bData.map((b: any) => ({
          id: b.id, titulo: b.accion, cuerpo: b.detalle || "",
          tipo: b.accion, leida: true,
          created_at: b.ts, solicitud_id: b.solicitud_id,
        })))
      } else {
        setNotifs([])
      }
    }
  }, [userId])

  useEffect(() => { load() }, [load])

  // Real-time subscription (only if notificaciones table exists)
  useEffect(() => {
    const sb = createClient()
    try {
      const channel = sb.channel("notifs-" + userId)
        .on("postgres_changes", {
          event: "INSERT", schema: "public", table: "notificaciones",
          filter: `usuario_id=eq.${userId}`,
        }, payload => {
          setNotifs(prev => [payload.new as Notif, ...prev])
        })
        .subscribe()
      return () => { sb.removeChannel(channel) }
    } catch {}
  }, [userId])

  const markAllRead = async () => {
    const sb = createClient()
    const unreadIds = notifs.filter(n => !n.leida).map(n => n.id)
    if (!unreadIds.length) return
    await sb.from("notificaciones").update({ leida: true }).in("id", unreadIds)
    setNotifs(prev => prev.map(n => ({ ...n, leida: true })))
  }

  const markRead = async (id: string) => {
    const sb = createClient()
    await sb.from("notificaciones").update({ leida: true }).eq("id", id)
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, leida: true } : n))
  }

  return (
    <div style={{ position: "relative" }}>
      <button onClick={() => { setOpen(!open); if (!open && unread > 0) markAllRead() }}
        style={{
          width: 36, height: 36, borderRadius: 8, border: "1px solid var(--border)",
          background: "var(--surface-2)", display: "grid", placeItems: "center",
          cursor: "pointer", position: "relative", fontSize: 18,
        }}>
        🔔
        {unread > 0 && (
          <span style={{
            position: "absolute", top: -4, right: -4,
            width: 18, height: 18, borderRadius: "50%",
            background: "var(--danger)", color: "#fff",
            fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center",
            border: "2px solid var(--bg)",
          }}>
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>

      {open && (
        <>
          <div style={{ position: "fixed", inset: 0, zIndex: 49 }} onClick={() => setOpen(false)} />
          <div style={{
            position: "absolute", top: 44, right: 0, zIndex: 50,
            width: 340, maxHeight: 480, overflowY: "auto",
            background: "var(--surface)", border: "1px solid var(--border)",
            borderRadius: 12, boxShadow: "0 8px 32px rgba(0,0,0,.4)",
          }}>
            <div style={{
              padding: "12px 16px", display: "flex", justifyContent: "space-between",
              alignItems: "center", borderBottom: "1px solid var(--border)", position: "sticky", top: 0,
              background: "var(--surface)",
            }}>
              <div style={{ fontWeight: 700, fontSize: 14 }}>Notificaciones</div>
              {unread > 0 && (
                <button onClick={markAllRead}
                  style={{ fontSize: 11, color: "var(--accent)", background: "none", border: "none", cursor: "pointer" }}>
                  Marcar todo leído
                </button>
              )}
            </div>

            {notifs.length === 0 ? (
              <div style={{ padding: 32, textAlign: "center", color: "var(--text-3)", fontSize: 13 }}>
                <div style={{ fontSize: 32, marginBottom: 8 }}>🔔</div>
                Sin notificaciones
              </div>
            ) : (
              notifs.map(n => (
                <div key={n.id}
                  onClick={() => markRead(n.id)}
                  style={{
                    padding: "12px 16px", borderBottom: "1px solid var(--border)",
                    cursor: "pointer", display: "flex", gap: 12, alignItems: "flex-start",
                    background: n.leida ? "transparent" : "var(--accent-soft)",
                    transition: "background .15s",
                  }}>
                  <span style={{ fontSize: 20, flexShrink: 0, marginTop: 1 }}>
                    {TIPO_ICON[n.tipo] || TIPO_ICON.default}
                  </span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: n.leida ? 400 : 600,
                      overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {n.titulo}
                    </div>
                    {n.cuerpo && (
                      <div style={{ fontSize: 11.5, color: "var(--text-3)", marginTop: 2,
                        overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {n.cuerpo}
                      </div>
                    )}
                    <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>
                      {fmtFecha(n.created_at)}
                    </div>
                  </div>
                  {!n.leida && (
                    <div style={{ width: 8, height: 8, borderRadius: "50%",
                      background: "var(--accent)", flexShrink: 0, marginTop: 5 }} />
                  )}
                </div>
              ))
            )}
          </div>
        </>
      )}
    </div>
  )
}

FILEEOF

cat > 'public/sw.js' << 'FILEEOF'
const CACHE = "viaticos-gz-v4"
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
git commit -m "fix: move bell+theme to sidebar/topbar, sw clone error, firebase config"
git push
echo "✓ Done"