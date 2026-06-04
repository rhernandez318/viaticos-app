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

