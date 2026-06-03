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

