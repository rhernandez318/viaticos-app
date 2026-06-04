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

