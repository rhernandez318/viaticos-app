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

