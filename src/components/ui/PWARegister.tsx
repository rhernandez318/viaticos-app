"use client"
import { useEffect } from "react"

export function PWARegister() {
  useEffect(() => {
    console.log("[PWA] PWARegister mounted, checking SW support...")

    if (!("serviceWorker" in navigator)) {
      console.log("[PWA] Service workers NOT supported in this browser")
      return
    }

    console.log("[PWA] Registering service worker at /sw.js")

    navigator.serviceWorker
      .register("/sw.js", { scope: "/", updateViaCache: "none" })
      .then(reg => {
        console.log("[PWA] ✓ Service Worker registered! Scope:", reg.scope)
        console.log("[PWA] SW state:", reg.active?.state ?? reg.installing?.state ?? "pending")
      })
      .catch(err => {
        console.error("[PWA] ✗ SW registration FAILED:", err.message, err)
      })
  }, [])

  return null
}

