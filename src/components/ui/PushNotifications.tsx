"use client"
import { useEffect, useState } from "react"
import { registerPushToken, listenMessages } from "@/lib/firebase"

interface Props { userId: string }

export function PushNotifications({ userId }: Props) {
  const [toast, setToast] = useState<{ title: string; body: string } | null>(null)

  useEffect(() => {
    if (!userId) return

    // Register FCM token (asks for permission if not granted)
    registerPushToken(userId)

    // Listen for foreground messages
    listenMessages(payload => {
      const { t: title, b: body } = payload.data || {}
      if (title) {
        setToast({ title, body: body || "" })
        setTimeout(() => setToast(null), 5000)
      }
    })
  }, [userId])

  if (!toast) return null

  return (
    <div style={{
      position: "fixed", top: 20, right: 20, zIndex: 300,
      background: "var(--surface)", border: "1px solid var(--border)",
      borderLeft: "4px solid var(--accent)",
      borderRadius: 12, padding: "14px 18px",
      boxShadow: "0 8px 32px rgba(0,0,0,.4)",
      maxWidth: 320, animation: "slideUp .3s ease-out",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 10 }}>
        <div>
          <div style={{ fontWeight: 700, fontSize: 14, marginBottom: 3 }}>🔔 {toast.title}</div>
          {toast.body && <div style={{ fontSize: 12, color: "var(--text-2)" }}>{toast.body}</div>}
        </div>
        <button onClick={() => setToast(null)}
          style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 18, lineHeight: 1 }}>
          ×
        </button>
      </div>
    </div>
  )
}

