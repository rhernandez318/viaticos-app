bash setup-reset-pw.sh#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(auth)/reset-password/page.tsx')
cat > 'src/app/(auth)/reset-password/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"

export default function ResetPasswordPage() {
  const router = useRouter()
  const [password,  setPassword]  = useState("")
  const [confirm,   setConfirm]   = useState("")
  const [loading,   setLoading]   = useState(false)
  const [error,     setError]     = useState<string|null>(null)
  const [success,   setSuccess]   = useState(false)
  const [ready,     setReady]     = useState(false)

  useEffect(() => {
    // Supabase puts the recovery token in the URL hash
    // It automatically picks it up via onAuthStateChange
    const sb = createClient()
    const { data: { subscription } } = sb.auth.onAuthStateChange(async (event) => {
      if (event === "PASSWORD_RECOVERY") {
        setReady(true)
      }
    })

    // Check if already has session from recovery link
    sb.auth.getSession().then(({ data: { session } }) => {
      if (session) setReady(true)
    })

    return () => subscription.unsubscribe()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (password.length < 6) { setError("La contraseña debe tener al menos 6 caracteres"); return }
    if (password !== confirm) { setError("Las contraseñas no coinciden"); return }

    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.updateUser({ password })
    if (error) { setError("Error al actualizar: " + error.message); setLoading(false); return }

    setSuccess(true)
    setTimeout(() => router.push("/dashboard"), 2000)
  }

  return (
    <div style={{ minHeight:"100vh", display:"grid", placeItems:"center", background:"var(--bg)" }}>
      <div style={{ width:"100%", maxWidth:380, padding:"0 20px" }}>
        <div style={{ textAlign:"center", marginBottom:28 }}>
          <div style={{ width:64, height:64, margin:"0 auto 14px", borderRadius:16,
            overflow:"hidden", background:"white", padding:3, boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={58} height={58}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontSize:20, fontWeight:700, letterSpacing:"-0.02em" }}>
            Nueva contraseña
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)", marginTop:4 }}>Grupo Zapata · Viáticos</div>
        </div>

        {success ? (
          <div style={{ textAlign:"center", padding:"24px 0" }}>
            <div style={{ fontSize:48, marginBottom:16 }}>✅</div>
            <div style={{ fontWeight:700, fontSize:16, marginBottom:8 }}>¡Contraseña actualizada!</div>
            <div style={{ fontSize:13, color:"var(--text-3)" }}>Redirigiendo al sistema…</div>
          </div>
        ) : !ready ? (
          <div style={{ textAlign:"center", padding:"24px 0", color:"var(--text-3)" }}>
            <div style={{ fontSize:32, marginBottom:12 }}>⏳</div>
            <div>Validando enlace de recuperación…</div>
            <div style={{ fontSize:12, marginTop:8 }}>
              Si esto tarda mucho,{" "}
              <button onClick={() => router.push("/login")}
                style={{ color:"var(--accent)", background:"none", border:"none", cursor:"pointer" }}>
                vuelve al inicio de sesión
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} style={{ display:"flex", flexDirection:"column", gap:14 }}>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Nueva contraseña
              </label>
              <input className="input" type="password" value={password}
                onChange={e => setPassword(e.target.value)} required
                minLength={6} placeholder="Mínimo 6 caracteres"
                autoComplete="new-password"/>
            </div>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Confirmar contraseña
              </label>
              <input className="input" type="password" value={confirm}
                onChange={e => setConfirm(e.target.value)} required
                placeholder="Repite la contraseña"
                autoComplete="new-password"/>
            </div>
            {error && (
              <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>
                {error}
              </div>
            )}
            <button className="btn primary" type="submit" disabled={loading}
              style={{ justifyContent:"center", padding:"12px" }}>
              {loading ? "Guardando…" : "Guardar nueva contraseña →"}
            </button>
            <button type="button" className="btn ghost"
              onClick={() => router.push("/login")}
              style={{ justifyContent:"center" }}>
              ← Cancelar
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(auth)/login/page.tsx')
cat > 'src/app/(auth)/login/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"
import { triggerNotifSetup } from "@/components/ui/PushNotifications"

function InstallButton() {
  const [canInstall, setCanInstall] = useState(false)
  const promptRef = useRef<any>(null)
  useEffect(() => {
    const handler = (e: Event) => { e.preventDefault(); promptRef.current = e; setCanInstall(true) }
    window.addEventListener("beforeinstallprompt", handler)
    return () => window.removeEventListener("beforeinstallprompt", handler)
  }, [])
  if (!canInstall) return null
  return (
    <button onClick={async () => {
      if (!promptRef.current) return
      await promptRef.current.prompt()
      const { outcome } = await promptRef.current.userChoice
      if (outcome === "accepted") { promptRef.current = null; setCanInstall(false) }
    }} style={{
      marginTop:12, width:"100%", padding:"11px", borderRadius:10,
      border:"1px solid var(--border)", background:"var(--surface-2)",
      color:"var(--text-2)", fontSize:13, fontWeight:500, cursor:"pointer",
      display:"flex", alignItems:"center", justifyContent:"center", gap:8,
    }}>⬇️ Instalar aplicación</button>
  )
}

export default function LoginPage() {
  const [email,    setEmail]    = useState("")
  const [password, setPassword] = useState("")
  const [error,    setError]    = useState<string|null>(null)
  const [loading,  setLoading]  = useState(false)
  const [mode,     setMode]     = useState<"login"|"recover">("login")
  const [sent,     setSent]     = useState(false)
  const router = useRouter()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) { setError("Credenciales incorrectas"); setLoading(false); return }
    router.push("/dashboard")
  }

  const handleRecover = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.trim()) { setError("Ingresa tu correo"); return }
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (error) { setError("Error al enviar: " + error.message); setLoading(false); return }
    setSent(true); setLoading(false)
  }

  return (
    <div style={{ minHeight:"100vh", display:"grid", placeItems:"center", background:"var(--bg)" }}>
      <div style={{ width:"100%", maxWidth:380, padding:"0 20px" }}>
        {/* Logo */}
        <div style={{ textAlign:"center", marginBottom:28 }}>
          <div style={{ width:80, height:80, margin:"0 auto 14px", borderRadius:20,
            overflow:"hidden", background:"white", padding:4, boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={72} height={72}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontSize:24, fontWeight:800, letterSpacing:"-0.03em", marginBottom:4 }}>
            Grupo Zapata
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)" }}>Sistema de Viáticos</div>
        </div>

        {mode === "login" ? (
          <>
            <form onSubmit={handleLogin} style={{ display:"flex", flexDirection:"column", gap:12 }}>
              <div>
                <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                  Correo electrónico
                </label>
                <input className="input" type="email" value={email}
                  onChange={e=>setEmail(e.target.value)} required
                  placeholder="usuario@grupozapata.com.mx" autoComplete="email"/>
              </div>
              <div>
                <div style={{ display:"flex", justifyContent:"space-between", marginBottom:4 }}>
                  <label style={{ fontSize:12, color:"var(--text-3)" }}>Contraseña</label>
                  <button type="button" onClick={()=>{ setMode("recover"); setError(null); setSent(false) }}
                    style={{ fontSize:12, color:"var(--accent)", background:"none", border:"none",
                      cursor:"pointer", padding:0 }}>
                    ¿Olvidaste tu contraseña?
                  </button>
                </div>
                <input className="input" type="password" value={password}
                  onChange={e=>setPassword(e.target.value)} required
                  placeholder="••••••••" autoComplete="current-password"/>
              </div>
              {error && (
                <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                  borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>{error}</div>
              )}
              <button className="btn primary" type="submit" disabled={loading}
                style={{ justifyContent:"center", marginTop:4, padding:"12px" }}>
                {loading ? "Iniciando sesión…" : "Entrar →"}
              </button>
            </form>
            <InstallButton/>
          </>
        ) : sent ? (
          <div style={{ textAlign:"center", padding:"24px 0" }}>
            <div style={{ fontSize:40, marginBottom:16 }}>📧</div>
            <div style={{ fontWeight:700, fontSize:16, marginBottom:8 }}>Revisa tu correo</div>
            <div style={{ fontSize:13, color:"var(--text-3)", lineHeight:1.6, marginBottom:20 }}>
              Enviamos un enlace a <strong>{email}</strong> para restablecer tu contraseña.
              Puede tardar unos minutos.
            </div>
            <button className="btn ghost" onClick={()=>{ setMode("login"); setSent(false) }}
              style={{ width:"100%" }}>
              ← Volver al inicio de sesión
            </button>
          </div>
        ) : (
          <form onSubmit={handleRecover} style={{ display:"flex", flexDirection:"column", gap:12 }}>
            <div style={{ marginBottom:4 }}>
              <div style={{ fontWeight:700, fontSize:16, marginBottom:6 }}>Recuperar contraseña</div>
              <div style={{ fontSize:13, color:"var(--text-3)" }}>
                Ingresa tu correo y te enviaremos un enlace para restablecerla.
              </div>
            </div>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Correo electrónico
              </label>
              <input className="input" type="email" value={email}
                onChange={e=>setEmail(e.target.value)} required
                placeholder="usuario@grupozapata.com.mx" autoComplete="email"/>
            </div>
            {error && (
              <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>{error}</div>
            )}
            <button className="btn primary" type="submit" disabled={loading}
              style={{ justifyContent:"center", padding:"12px" }}>
              {loading ? "Enviando…" : "Enviar enlace de recuperación"}
            </button>
            <button type="button" className="btn ghost" onClick={()=>{ setMode("login"); setError(null) }}
              style={{ justifyContent:"center" }}>
              ← Volver
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/middleware.ts')
cat > 'src/middleware.ts' << 'FILEEOF'
import { type NextRequest } from "next/server"
import { updateSession } from "@/lib/supabase/middleware"

export async function middleware(request: NextRequest) {
  return await updateSession(request)
}

export const config = {
  matcher: [
    /*
     * Match all paths EXCEPT:
     * - _next/static, _next/image (Next.js internals)
     * - favicon.ico, images
     * - PWA files: sw.js, manifest.json, icons
     * - .well-known (assetlinks.json)
     */
    "/((?!_next/static|_next/image|favicon\\.ico|sw\\.js|firebase-messaging-sw\\.js|manifest\\.json|icon.*\\.png|logo\\.png|\\.well-known|reset-password|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
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
    height: 48px;
    min-height: 48px;
    max-height: 48px;
    overflow: visible;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 0 16px;
    flex-shrink: 0;
  }
  .main-content {
    padding: 12px 14px calc(70px + env(safe-area-inset-bottom, 0px)) !important;
  }
}

FILEEOF

git add .
git commit -m "feat: reset password page, fix mobile spacing"
git push
echo "✓ Done"