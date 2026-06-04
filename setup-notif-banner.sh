#!/bin/bash
set -e

mkdir -p src/components/ui
cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState, useRef } from "react"

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY || ""
const FIREBASE_CONFIG = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

interface Props { userId: string }
type Status = "idle" | "asking" | "granted" | "denied" | "loading"

export function PushNotifications({ userId }: Props) {
  const [status, setStatus]     = useState<Status>("idle")
  const [banner, setBanner]     = useState(false)
  const [toast, setToast]       = useState<{ title: string; body: string } | null>(null)
  const messagingRef            = useRef<any>(null)
  const firebaseReadyRef        = useRef(false)

  // Check current permission state and whether to show banner
  useEffect(() => {
    if (!userId || typeof window === "undefined") return

    const perm = Notification.permission
    if (perm === "granted") {
      setStatus("granted")
      loadFirebaseAndRegister()
      return
    }
    if (perm === "denied") {
      setStatus("denied")
      return
    }

    // "default" = not asked yet → show banner after 3s
    const dismissed = localStorage.getItem("notif-dismissed")
    if (!dismissed) {
      setTimeout(() => setBanner(true), 3000)
    }
  }, [userId])

  const loadFirebase = (): Promise<void> => new Promise((resolve, reject) => {
    if (firebaseReadyRef.current) { resolve(); return }

    const s1 = document.createElement("script")
    s1.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"
    const s2 = document.createElement("script")
    s2.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"

    s2.onload = () => {
      try {
        const fb = (window as any).firebase
        if (!fb.apps.length) fb.initializeApp(FIREBASE_CONFIG)
        messagingRef.current = fb.messaging()
        firebaseReadyRef.current = true

        // Listen for foreground messages
        messagingRef.current.onMessage((payload: any) => {
          const { t: title, b: body } = payload.data || {}
          if (title) { setToast({ title, body: body || "" }); setTimeout(() => setToast(null), 5000) }
        })
        resolve()
      } catch(e) { reject(e) }
    }
    s2.onerror = reject
    s1.onload = () => document.head.appendChild(s2)
    s1.onerror = reject
    document.head.appendChild(s1)
  })

  const loadFirebaseAndRegister = async () => {
    try {
      await loadFirebase()
      const token = await messagingRef.current.getToken({ vapidKey: VAPID_KEY })
      if (!token) return
      await fetch("/api/push/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, token }),
      })
      console.log("[FCM] ✓ Token registered")
    } catch(e) {
      console.warn("[FCM]", e)
    }
  }

  // Called when user clicks "Activar"
  const handleActivar = async () => {
    setStatus("asking")
    setBanner(false)
    try {
      await loadFirebase()
      const perm = await Notification.requestPermission()
      if (perm === "granted") {
        setStatus("granted")
        await loadFirebaseAndRegister()
      } else {
        setStatus("denied")
        localStorage.setItem("notif-dismissed", "denied")
      }
    } catch(e) {
      setStatus("idle")
    }
  }

  const handleDismiss = () => {
    setBanner(false)
    localStorage.setItem("notif-dismissed", "later")
  }

  return (
    <>
      {/* Permission banner */}
      {banner && status === "idle" && (
        <div style={{
          position: "fixed", bottom: 80, left: 16, right: 16, zIndex: 150,
          background: "var(--surface)", border: "1px solid var(--border)",
          borderRadius: 16, padding: "16px 18px",
          boxShadow: "0 8px 32px rgba(0,0,0,.4)",
          display: "flex", alignItems: "center", gap: 14,
          animation: "slideUp .3s ease-out",
        }}>
          <span style={{ fontSize: 28, flexShrink: 0 }}>🔔</span>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 3 }}>
              Activar notificaciones
            </div>
            <div style={{ fontSize: 12, color: "var(--text-3)", lineHeight: 1.4 }}>
              Recibe alertas cuando autoricen o liberen tus solicitudes
            </div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 6, flexShrink: 0 }}>
            <button onClick={handleActivar}
              style={{
                padding: "8px 14px", borderRadius: 8, border: "none",
                background: "var(--accent)", color: "#111",
                fontSize: 13, fontWeight: 700, cursor: "pointer", whiteSpace: "nowrap",
              }}>
              Activar
            </button>
            <button onClick={handleDismiss}
              style={{
                padding: "6px 14px", borderRadius: 8, border: "1px solid var(--border)",
                background: "none", color: "var(--text-3)",
                fontSize: 12, cursor: "pointer",
              }}>
              Ahora no
            </button>
          </div>
        </div>
      )}

      {/* Status asking */}
      {status === "asking" && (
        <div style={{
          position: "fixed", bottom: 80, left: 16, right: 16, zIndex: 150,
          background: "var(--surface)", border: "1px solid var(--accent)",
          borderRadius: 16, padding: "14px 18px",
          display: "flex", alignItems: "center", gap: 12,
        }}>
          <span style={{ fontSize: 20 }}>⏳</span>
          <span style={{ fontSize: 13, color: "var(--text-2)" }}>
            Acepta el permiso de notificaciones en el mensaje del sistema…
          </span>
        </div>
      )}

      {/* Foreground message toast */}
      {toast && (
        <div style={{
          position: "fixed", top: 20, right: 20, zIndex: 300,
          background: "var(--surface)", border: "1px solid var(--border)",
          borderLeft: "4px solid var(--accent)", borderRadius: 12,
          padding: "14px 18px", boxShadow: "0 8px 32px rgba(0,0,0,.4)",
          maxWidth: 320, animation: "slideUp .3s ease-out",
          display: "flex", gap: 10, alignItems: "flex-start",
        }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 3 }}>🔔 {toast.title}</div>
            {toast.body && <div style={{ fontSize: 12, color: "var(--text-2)" }}>{toast.body}</div>}
          </div>
          <button onClick={() => setToast(null)}
            style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 18, lineHeight: 1 }}>×</button>
        </div>
      )}
    </>
  )
}

FILEEOF

git add .
git commit -m "feat: notification opt-in banner with user gesture"
git push
echo "✓ Done"