"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"

export default function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const sb = createClient()
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) { setError("Credenciales incorrectas"); setLoading(false); return }
    router.push("/dashboard")
  }

  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "var(--bg)" }}>
      <div style={{ width: "100%", maxWidth: 380, padding: "0 16px" }}>
        {/* Logo */}
        <div style={{ textAlign: "center", marginBottom: 32 }}>
          <div style={{ width: 48, height: 48, borderRadius: 12, background: "var(--accent)", margin: "0 auto 12px",
                        display: "grid", placeItems: "center", fontSize: 22, fontWeight: 700, color: "#111" }}>
            Z
          </div>
          <div style={{ fontFamily: "var(--f-display)", fontSize: 22, fontWeight: 700, letterSpacing: "-0.02em" }}>
            Casa Zapata
          </div>
          <div style={{ fontSize: 13, color: "var(--text-3)", marginTop: 4 }}>Sistema de viáticos</div>
        </div>

        <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div>
            <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
              Correo electrónico
            </label>
            <input className="input" type="email" value={email}
              onChange={(e) => setEmail(e.target.value)} required placeholder="usuario@zapata.com.mx" />
          </div>
          <div>
            <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
              Contraseña
            </label>
            <input className="input" type="password" value={password}
              onChange={(e) => setPassword(e.target.value)} required placeholder="••••••••" />
          </div>

          {error && (
            <div style={{ padding: "8px 12px", background: "var(--danger-soft)", borderRadius: "var(--r-md)",
                          fontSize: 12, color: "var(--danger)" }}>
              {error}
            </div>
          )}

          <button className="btn primary" type="submit" disabled={loading}
            style={{ justifyContent: "center", marginTop: 4, padding: "10px" }}>
            {loading ? "Iniciando sesión…" : "Entrar"}
          </button>
        </form>
      </div>
    </div>
  )
}

