"use client"
import { useState, useEffect } from "react"
import Image from "next/image"

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>
}

// Store prompt globally so it survives re-renders
let deferredPrompt: BeforeInstallPromptEvent | null = null

export function InstallBanner() {
  const [canInstall, setCanInstall] = useState(false)
  const [visible, setVisible] = useState(false)
  const [installed, setInstalled] = useState(false)

  useEffect(() => {
    // Already running as standalone (installed)?
    if (window.matchMedia("(display-mode: standalone)").matches) {
      setInstalled(true)
      return
    }

    // Previously dismissed within 7 days?
    const dismissed = localStorage.getItem("pwa-dismissed")
    const tooRecent = dismissed && Date.now() - parseInt(dismissed) < 7 * 86400000

    const handlePrompt = (e: Event) => {
      e.preventDefault()
      deferredPrompt = e as BeforeInstallPromptEvent
      setCanInstall(true)
      if (!tooRecent) {
        setTimeout(() => setVisible(true), 2000)
      }
    }

    window.addEventListener("beforeinstallprompt", handlePrompt)

    // Listen for successful install
    window.addEventListener("appinstalled", () => {
      setInstalled(true)
      setVisible(false)
      deferredPrompt = null
    })

    return () => window.removeEventListener("beforeinstallprompt", handlePrompt)
  }, [])

  const install = async () => {
    if (!deferredPrompt) return
    await deferredPrompt.prompt()
    const { outcome } = await deferredPrompt.userChoice
    if (outcome === "accepted") {
      setVisible(false)
      setInstalled(true)
    } else {
      dismiss()
    }
    deferredPrompt = null
    setCanInstall(false)
  }

  const dismiss = () => {
    setVisible(false)
    localStorage.setItem("pwa-dismissed", String(Date.now()))
  }

  if (installed || !visible) return null

  return (
    <>
      {/* Backdrop */}
      <div style={{ position:"fixed", inset:0, zIndex:199, background:"rgba(0,0,0,.4)" }}
        onClick={dismiss}/>
      {/* Sheet */}
      <div style={{
        position:"fixed", bottom:0, left:0, right:0, zIndex:200,
        background:"var(--surface)", borderTop:"1px solid var(--border)",
        borderRadius:"20px 20px 0 0",
        padding:"16px 24px 32px",
        boxShadow:"0 -8px 40px rgba(0,0,0,.5)",
        animation:"slideUp .3s cubic-bezier(.32,.72,0,1)",
      }}>
        <div style={{ width:40, height:4, borderRadius:2, background:"var(--border)", margin:"0 auto 20px" }}/>

        <div style={{ display:"flex", alignItems:"center", gap:16, marginBottom:20 }}>
          <div style={{ width:60, height:60, borderRadius:16, overflow:"hidden",
            background:"white", padding:4, flexShrink:0,
            boxShadow:"0 4px 16px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Viáticos GZ" width={52} height={52}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div>
            <div style={{ fontWeight:700, fontSize:17, marginBottom:2 }}>Viáticos Grupo Zapata</div>
            <div style={{ fontSize:13, color:"var(--text-3)" }}>
              Instala la app para acceso rápido
            </div>
          </div>
          <button onClick={dismiss}
            style={{ marginLeft:"auto", background:"none", border:"none",
              color:"var(--text-3)", cursor:"pointer", fontSize:22, padding:4, lineHeight:1 }}>
            ×
          </button>
        </div>

        <button onClick={install}
          style={{
            width:"100%", padding:"15px", borderRadius:14,
            background:"var(--accent)", border:"none", color:"#111",
            fontSize:16, fontWeight:700, cursor:"pointer",
            display:"flex", alignItems:"center", justifyContent:"center", gap:10,
          }}>
          ⬇️ Instalar aplicación
        </button>
        <div style={{ textAlign:"center", fontSize:12, color:"var(--text-3)", marginTop:10 }}>
          Sin ocupar espacio adicional · Funciona sin conexión
        </div>
      </div>
    </>
  )
}

// Exportar función para trigger manual (desde un botón en el UI)
export function triggerInstall() {
  if (deferredPrompt) deferredPrompt.prompt()
}

