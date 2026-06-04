#!/bin/bash
set -e

mkdir -p $(dirname 'src/components/ui/PushNotifications.tsx')
cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState } from "react"

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY || ""
const FIREBASE_CONFIG = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

interface Props { userId: string }

export function PushNotifications({ userId }: Props) {
  const [toast, setToast] = useState<{ title: string; body: string } | null>(null)

  useEffect(() => {
    if (!userId || typeof window === "undefined") return

    // Load Firebase from CDN at runtime (not bundled by Turbopack)
    const script1 = document.createElement("script")
    script1.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"
    script1.async = true

    const script2 = document.createElement("script")
    script2.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"
    script2.async = true

    script2.onload = async () => {
      try {
        const fb = (window as any).firebase
        if (!fb) return
        if (!fb.apps.length) fb.initializeApp(FIREBASE_CONFIG)
        const messaging = fb.messaging()

        // Request permission & get token
        const permission = await Notification.requestPermission()
        if (permission !== "granted") return

        const token = await messaging.getToken({ vapidKey: VAPID_KEY })
        if (!token) return

        console.log("[FCM] ✓ Token registered")

        // Save token to Supabase via API route
        await fetch("/api/push/register", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ userId, token }),
        })

        // Listen for foreground messages
        messaging.onMessage((payload: any) => {
          const { t: title, b: body } = payload.data || {}
          if (title) {
            setToast({ title, body: body || "" })
            setTimeout(() => setToast(null), 5000)
          }
        })
      } catch (err) {
        console.warn("[FCM] Error:", err)
      }
    }

    script1.onload = () => document.head.appendChild(script2)
    document.head.appendChild(script1)

    return () => {
      script1.remove()
      script2.remove()
    }
  }, [userId])

  if (!toast) return null

  return (
    <div style={{
      position: "fixed", top: 20, right: 20, zIndex: 300,
      background: "var(--surface)", border: "1px solid var(--border)",
      borderLeft: "4px solid var(--accent)", borderRadius: 12,
      padding: "14px 18px", boxShadow: "0 8px 32px rgba(0,0,0,.4)",
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

FILEEOF

mkdir -p $(dirname 'src/app/api/push/register/route.ts')
cat > 'src/app/api/push/register/route.ts' << 'FILEEOF'
import { NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

export async function POST(request: NextRequest) {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const { userId, token } = await request.json()
  if (!token) return NextResponse.json({ error: "No token" }, { status: 400 })

  const { error } = await sb.from("push_subscriptions").upsert(
    { usuario_id: userId || user.id, subscription: token, updated_at: new Date().toISOString() },
    { onConflict: "usuario_id" }
  )

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}

FILEEOF

rm -f src/lib/firebase.ts
git add .
git commit -m "fix: load Firebase from CDN instead of bundle - fixes Turbopack"
git push
echo "✓ Done - Vercel should deploy now"