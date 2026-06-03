"use client"
import { useState, useEffect } from "react"
import Image from "next/image"

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>
}

export function InstallBanner() {
  const [prompt, setPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [visible, setVisible] = useState(false)
  const [installed, setInstalled] = useState(false)

  useEffect(() => {
    // Already installed as standalone? Hide banner
    if (window.matchMedia("(display-mode: standalone)").matches) {
      setInstalled(true)
      return
    }

    // Dismissed before? Respect it for 3 days
    const dismissed = localStorage.getItem("pwa-install-dismissed")
    if (dismissed && Date.now() - parseInt(dismissed) < 3 * 24 * 60 * 60 * 1000) return

    const handler = (e: Event) => {
      e.preventDefault()
      setPrompt(e as BeforeInstallPromptEvent)
      // Small delay so it doesn't pop immediately on first visit
      setTimeout(() => setVisible(true), 3000)
    }

    window.addEventListener("beforeinstallprompt", handler)
    return () => window.removeEventListener("beforeinstallprompt", handler)
  }, [])

  const install = async () => {
    if (!prompt) return
    await prompt.prompt()
    const { outcome } = await prompt.userChoice
    if (outcome === "accepted") {
      setVisible(false)
      setInstalled(true)
    } else {
      dismiss()
    }
  }

  const dismiss = () => {
    setVisible(false)
    localStorage.setItem("pwa-install-dismissed", String(Date.now()))
  }

  if (!visible || installed) return null

  return (
    <div style={{
      position: "fixed", bottom: 0, left: 0, right: 0, zIndex: 200,
      background: "var(--surface)",
      borderTop: "1px solid var(--border)",
      padding: "16px 20px 24px",
      borderRadius: "20px 20px 0 0",
      boxShadow: "0 -8px 32px rgba(0,0,0,.4)",
      animation: "slideUp .3s ease-out",
    }}>
      {/* Drag handle */}
      <div style={{ width: 36, height: 4, borderRadius: 2, background: "var(--border)",
        margin: "0 auto 16px" }}/>

      <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 16 }}>
        <div style={{ width: 52, height: 52, borderRadius: 14, overflow: "hidden",
          background: "white", padding: 4, flexShrink: 0,
          boxShadow: "0 2px 8px rgba(0,0,0,.2)" }}>
          <Image src="/logo.png" alt="Viáticos GZ" width={44} height={44}
            style={{ width: "100%", height: "100%", objectFit: "contain" }}/>
        </div>
        <div>
          <div style={{ fontWeight: 700, fontSize: 15 }}>Viáticos Grupo Zapata</div>
          <div style={{ fontSize: 12, color: "var(--text-3)", marginTop: 2 }}>
            viaticos-app-bice.vercel.app
          </div>
        </div>
        <button onClick={dismiss}
          style={{ marginLeft: "auto", background: "none", border: "none",
            color: "var(--text-3)", cursor: "pointer", fontSize: 20, padding: 4 }}>
          ×
        </button>
      </div>

      <button onClick={install} style={{
        width: "100%", padding: "14px", borderRadius: 12,
        background: "var(--accent)", border: "none", color: "#111",
        fontSize: 15, fontWeight: 700, cursor: "pointer",
        display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
      }}>
        ⬇️ Instalar aplicación
      </button>
      <div style={{ textAlign: "center", fontSize: 11, color: "var(--text-3)", marginTop: 8 }}>
        Se instala sin ocupar espacio adicional
      </div>
    </div>
  )
}

