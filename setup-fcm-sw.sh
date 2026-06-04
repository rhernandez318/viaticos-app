#!/bin/bash
set -e

cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState, useRef, useCallback } from "react"

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY || ""
const FIREBASE_CONFIG = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain:        `${process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID}.firebaseapp.com`,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket:     `${process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID}.appspot.com`,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

interface Props { userId: string }
type Status = "idle" | "asking" | "granted" | "denied"

let globalSetup: (() => void) | null = null
export function triggerNotifSetup() { globalSetup?.() }

export function PushNotifications({ userId }: Props) {
  const [status, setStatus]   = useState<Status>("idle")
  const [banner, setBanner]   = useState(false)
  const [toast, setToast]     = useState<{ title: string; body: string } | null>(null)
  const fbReadyRef            = useRef(false)
  const messagingRef          = useRef<any>(null)

  const loadFirebase = useCallback((): Promise<void> => new Promise((resolve, reject) => {
    if (fbReadyRef.current) { resolve(); return }
    const load = (src: string): Promise<void> => new Promise((res, rej) => {
      const s = document.createElement("script")
      s.src = src; s.async = true
      s.onload = () => res(); s.onerror = () => rej(new Error(`Failed to load ${src}`))
      document.head.appendChild(s)
    })
    load("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js")
      .then(() => load("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"))
      .then(() => {
        const fb = (window as any).firebase
        if (!fb) { reject(new Error("Firebase not available")); return }
        if (!fb.apps?.length) fb.initializeApp(FIREBASE_CONFIG)
        messagingRef.current = fb.messaging()
        fbReadyRef.current = true
        messagingRef.current.onMessage((payload: any) => {
          const { t: title, b: body } = payload.data || {}
          if (title) { setToast({ title, body: body||"" }); setTimeout(() => setToast(null), 5000) }
        })
        resolve()
      })
      .catch(reject)
  }), [])

  const registerToken = useCallback(async () => {
    try {
      await loadFirebase()

      // Explicitly register Firebase SW and pass it to getToken
      let swReg: ServiceWorkerRegistration | undefined
      try {
        swReg = await navigator.serviceWorker.register("/firebase-messaging-sw.js", { scope: "/" })
        await navigator.serviceWorker.ready
        console.log("[FCM] Firebase SW registered:", swReg.scope)
      } catch(e) {
        console.warn("[FCM] Could not register firebase SW, using default:", e)
      }

      const token = await messagingRef.current?.getToken({
        vapidKey: VAPID_KEY,
        ...(swReg ? { serviceWorkerRegistration: swReg } : {}),
      })

      if (!token) { console.warn("[FCM] No token returned - check VAPID key and permissions"); return }

      console.log("[FCM] ✓ Token:", token.slice(0, 30) + "...")

      const res = await fetch("/api/push/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, token }),
      })
      const data = await res.json()
      if (data.ok) {
        console.log("[FCM] ✓ Token saved to DB")
        localStorage.setItem("notif-status", "granted")
      } else {
        console.error("[FCM] DB save failed:", data)
      }
    } catch(e: any) {
      console.error("[FCM] registerToken error:", e?.message || e)
    }
  }, [userId, loadFirebase])

  const handleActivar = useCallback(async () => {
    if (!("Notification" in window)) { alert("Tu navegador no soporta notificaciones"); return }
    setStatus("asking"); setBanner(false)
    try {
      const perm = await Notification.requestPermission()
      if (perm === "granted") {
        setStatus("granted")
        await registerToken()
      } else {
        setStatus("denied")
        localStorage.setItem("notif-status", "denied")
      }
    } catch(e: any) {
      console.error("[FCM] handleActivar error:", e?.message || e)
      setStatus("idle")
    }
  }, [registerToken])

  useEffect(() => { globalSetup = handleActivar; return () => { globalSetup = null } }, [handleActivar])

  useEffect(() => {
    if (!userId || typeof window === "undefined") return
    if (!("Notification" in window)) return

    const perm = Notification.permission
    if (perm === "granted") {
      setStatus("granted")
      registerToken() // Always refresh token
      return
    }
    if (perm === "denied") { setStatus("denied"); return }

    const saved = localStorage.getItem("notif-status")
    if (saved === "denied") { setStatus("denied"); return }

    const t = setTimeout(() => setBanner(true), 3000)
    return () => clearTimeout(t)
  }, [userId, registerToken])

  const handleDismiss = () => { setBanner(false); localStorage.setItem("notif-status", "later") }

  return (
    <>
      {banner && status === "idle" && (
        <div style={{
          position:"fixed", bottom:"calc(72px + env(safe-area-inset-bottom, 0px))",
          left:16, right:16, zIndex:200,
          background:"var(--surface)", border:"1px solid var(--border)",
          borderRadius:16, padding:"14px 16px",
          boxShadow:"0 8px 32px rgba(0,0,0,.5)",
          display:"flex", alignItems:"center", gap:12,
          animation:"slideUp .3s ease-out",
        }}>
          <span style={{fontSize:26,flexShrink:0}}>🔔</span>
          <div style={{flex:1,minWidth:0}}>
            <div style={{fontWeight:700,fontSize:13,marginBottom:2}}>Activar notificaciones</div>
            <div style={{fontSize:11.5,color:"var(--text-3)",lineHeight:1.4}}>
              Recibe alertas al autorizar o liberar solicitudes
            </div>
          </div>
          <div style={{display:"flex",flexDirection:"column",gap:5,flexShrink:0}}>
            <button onClick={handleActivar} style={{
              padding:"7px 13px",borderRadius:8,border:"none",
              background:"var(--accent)",color:"#111",
              fontSize:12,fontWeight:700,cursor:"pointer",whiteSpace:"nowrap",
            }}>Activar</button>
            <button onClick={handleDismiss} style={{
              padding:"5px 13px",borderRadius:8,border:"1px solid var(--border)",
              background:"none",color:"var(--text-3)",fontSize:11,cursor:"pointer",
            }}>Ahora no</button>
          </div>
        </div>
      )}

      {status==="asking" && (
        <div style={{
          position:"fixed", bottom:"calc(72px + env(safe-area-inset-bottom, 0px))",
          left:16, right:16, zIndex:200,
          background:"var(--surface)", border:"1px solid var(--accent)",
          borderRadius:16, padding:"12px 16px",
          display:"flex", alignItems:"center", gap:12,
        }}>
          <span style={{fontSize:18}}>⏳</span>
          <span style={{fontSize:13,color:"var(--text-2)"}}>
            Acepta el permiso en el mensaje del sistema…
          </span>
        </div>
      )}

      {toast && (
        <div style={{
          position:"fixed",top:20,right:20,zIndex:300,
          background:"var(--surface)",border:"1px solid var(--border)",
          borderLeft:"4px solid var(--accent)",borderRadius:12,
          padding:"14px 18px",boxShadow:"0 8px 32px rgba(0,0,0,.4)",
          maxWidth:320,animation:"slideUp .3s ease-out",
          display:"flex",gap:10,alignItems:"flex-start",
        }}>
          <div style={{flex:1}}>
            <div style={{fontWeight:700,fontSize:14,marginBottom:3}}>🔔 {toast.title}</div>
            {toast.body&&<div style={{fontSize:12,color:"var(--text-2)"}}>{toast.body}</div>}
          </div>
          <button onClick={()=>setToast(null)} style={{
            background:"none",border:"none",color:"var(--text-3)",cursor:"pointer",fontSize:18,lineHeight:1
          }}>×</button>
        </div>
      )}
    </>
  )
}

FILEEOF

git add .
git commit -m "fix: explicit Firebase SW registration in getToken"
git push
echo "✓ Done"