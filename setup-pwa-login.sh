#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(auth)/login/page.tsx')
cat > 'src/app/(auth)/login/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"

function InstallButton() {
  const [canInstall, setCanInstall] = useState(false)
  const promptRef = useRef<any>(null)

  useEffect(() => {
    const handler = (e: Event) => {
      e.preventDefault()
      promptRef.current = e
      setCanInstall(true)
    }
    window.addEventListener("beforeinstallprompt", handler)
    return () => window.removeEventListener("beforeinstallprompt", handler)
  }, [])

  if (!canInstall) return null

  return (
    <button
      onClick={async () => {
        if (!promptRef.current) return
        await promptRef.current.prompt()
        const { outcome } = await promptRef.current.userChoice
        if (outcome === "accepted") { promptRef.current = null; setCanInstall(false) }
      }}
      style={{
        marginTop:12, width:"100%", padding:"11px", borderRadius:10,
        border:"1px solid var(--border)", background:"var(--surface-2)",
        color:"var(--text-2)", fontSize:13, fontWeight:500, cursor:"pointer",
        display:"flex", alignItems:"center", justifyContent:"center", gap:8,
      }}>
      ⬇️ Instalar aplicación
    </button>
  )
}

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
        <div style={{ textAlign:"center", marginBottom:32 }}>
          <div style={{ width:80, height:80, margin:"0 auto 16px", borderRadius:20,
            overflow:"hidden", background:"white", padding:4,
            boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={72} height={72}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontSize:24, fontWeight:800, letterSpacing:"-0.03em", marginBottom:4 }}>
            Grupo Zapata
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)" }}>Sistema de Viáticos</div>
        </div>

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
            <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
              Contraseña
            </label>
            <input className="input" type="password" value={password}
              onChange={e=>setPassword(e.target.value)} required
              placeholder="••••••••" autoComplete="current-password"/>
          </div>
          {error && (
            <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
              borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>
              {error}
            </div>
          )}
          <button className="btn primary" type="submit" disabled={loading}
            style={{ justifyContent:"center", marginTop:4, padding:"12px" }}>
            {loading ? "Iniciando sesión…" : "Entrar →"}
          </button>
        </form>

        {/* Shows only when Chrome fires beforeinstallprompt */}
        <InstallButton/>

        <div style={{ marginTop:20, textAlign:"center", fontSize:11, color:"var(--text-3)" }}>
          También puedes instalar desde Chrome → ⋮ → Añadir a pantalla de inicio
        </div>
      </div>
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
    if (typeof window === "undefined") return
    if (!("serviceWorker" in navigator)) {
      console.log("[PWA] Service workers not supported")
      return
    }

    // Register SW on page load
    const register = async () => {
      try {
        const reg = await navigator.serviceWorker.register("/sw.js", {
          scope: "/",
          updateViaCache: "none",
        })
        console.log("[PWA] SW registered ✓ scope:", reg.scope)

        // Check for updates
        reg.addEventListener("updatefound", () => {
          const newSW = reg.installing
          newSW?.addEventListener("statechange", () => {
            if (newSW.state === "installed" && navigator.serviceWorker.controller) {
              console.log("[PWA] New SW installed, ready")
            }
          })
        })
      } catch (err) {
        console.error("[PWA] SW registration failed:", err)
      }
    }

    if (document.readyState === "complete") {
      register()
    } else {
      window.addEventListener("load", register)
    }
  }, [])

  return null
}

FILEEOF

mkdir -p $(dirname 'src/app/layout.tsx')
cat > 'src/app/layout.tsx' << 'FILEEOF'
import type { Metadata, Viewport } from "next"
import { ThemeProvider } from "@/contexts/ThemeContext"
import { InstallBanner } from "@/components/ui/InstallBanner"
import { PWARegister } from "@/components/ui/PWARegister"
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
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Viáticos GZ" />
        <link rel="apple-touch-icon" href="/icon-512.png" />
      </head>
      <body>
        <ThemeProvider>
          <PWARegister />
          <InstallBanner />
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}

FILEEOF

git add .
git commit -m "fix: install button on login page, clean PWA setup"
git push
echo "✓ Done"