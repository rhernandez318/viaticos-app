#!/bin/bash
set -e

mkdir -p $(dirname 'src/components/ui/PushNotifications.tsx')
cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState, useRef, useCallback } from "react"

// Firebase public config - safe to hardcode (client-side values, not secrets)
const VAPID_KEY = "BC4H1SRGR-megh4PQ-N4BpczTZkkZF3F8cfmS7bW1WL0Zp5rnfsN59Q7L9cKkUBaoo7NZ-2x0H_ja23MtUWinmQ"
const FIREBASE_CONFIG = {
  apiKey:            "AIzaSyD5WCpMWnQkwLJplAtbOXrjU2_5gwSRI2w",
  authDomain:        "viaticos-zapata.firebaseapp.com",
  projectId:         "viaticos-zapata",
  storageBucket:     "viaticos-zapata.appspot.com",
  messagingSenderId: "318139943193",
  appId:             "1:318139943193:web:3fade17ff5c1e89a805d88",
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

mkdir -p $(dirname 'src/components/ui/NotificationBell.tsx')
cat > 'src/components/ui/NotificationBell.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtFecha } from "@/lib/format"

interface Notif {
  id: string
  titulo: string
  cuerpo: string
  tipo: string
  leida: boolean
  created_at: string
  solicitud_id?: string
}

const TIPO_ICON: Record<string, string> = {
  aprobacion: "✅", rechazo: "❌", liberacion: "💵",
  comprobacion: "📎", cierre: "🏦", sistema: "ℹ️", default: "🔔",
}

export function NotificationBell({ userId }: { userId: string }) {
  const [notifs, setNotifs] = useState<Notif[]>([])
  const [open, setOpen] = useState(false)
  const unread = notifs.filter(n => !n.leida).length

  const load = useCallback(async () => {
    const sb = createClient()
    // Try notificaciones table, fallback to bitacora
    const { data, error } = await sb
      .from("notificaciones")
      .select("*")
      .eq("usuario_id", userId)
      .order("created_at", { ascending: false })
      .limit(30)

    if (!error && data) {
      setNotifs(data)
    } else {
      // Fallback: use bitacora entries as notifications
      const { data: bData } = await sb
        .from("bitacora")
        .select("id, accion, detalle, ts, solicitud_id")
        .order("ts", { ascending: false })
        .limit(20)
      if (bData && bData.length > 0) {
        setNotifs(bData.map((b: any) => ({
          id: b.id, titulo: b.accion, cuerpo: b.detalle || "",
          tipo: b.accion, leida: true,
          created_at: b.ts, solicitud_id: b.solicitud_id,
        })))
      } else {
        setNotifs([])
      }
    }
  }, [userId])

  useEffect(() => { load() }, [load])

  // Real-time subscription (only if notificaciones table exists)
  useEffect(() => {
    const sb = createClient()
    try {
      const channel = sb.channel("notifs-" + userId)
        .on("postgres_changes", {
          event: "INSERT", schema: "public", table: "notificaciones",
          filter: `usuario_id=eq.${userId}`,
        }, payload => {
          setNotifs(prev => [payload.new as Notif, ...prev])
        })
        .subscribe()
      return () => { sb.removeChannel(channel) }
    } catch {}
  }, [userId])

  const markAllRead = async () => {
    const sb = createClient()
    const unreadIds = notifs.filter(n => !n.leida).map(n => n.id)
    if (!unreadIds.length) return
    await sb.from("notificaciones").update({ leida: true }).in("id", unreadIds)
    setNotifs(prev => prev.map(n => ({ ...n, leida: true })))
  }

  const markRead = async (id: string) => {
    const sb = createClient()
    await sb.from("notificaciones").update({ leida: true }).eq("id", id)
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, leida: true } : n))
  }

  return (
    <div style={{ position: "relative" }}>
      <button onClick={() => { setOpen(!open); if (!open && unread > 0) markAllRead() }}
        style={{
          width: 36, height: 36, borderRadius: 8, border: "1px solid var(--border)",
          background: "var(--surface-2)", display: "grid", placeItems: "center",
          cursor: "pointer", position: "relative", fontSize: 18,
        }}>
        🔔
        {unread > 0 && (
          <span style={{
            position: "absolute", top: -4, right: -4,
            width: 18, height: 18, borderRadius: "50%",
            background: "var(--danger)", color: "#fff",
            fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center",
            border: "2px solid var(--bg)",
          }}>
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>

      {open && (
        <>
          <div style={{ position: "fixed", inset: 0, zIndex: 49 }} onClick={() => setOpen(false)} />
          <div style={{
            position: "absolute", top: 44, right: 0, zIndex: 50,
            width: 340, maxHeight: 480, overflowY: "auto",
            background: "var(--surface)", border: "1px solid var(--border)",
            borderRadius: 12, boxShadow: "0 8px 32px rgba(0,0,0,.4)",
          }}>
            <div style={{
              padding: "12px 16px", display: "flex", justifyContent: "space-between",
              alignItems: "center", borderBottom: "1px solid var(--border)", position: "sticky", top: 0,
              background: "var(--surface)",
            }}>
              <div style={{ fontWeight: 700, fontSize: 14 }}>Notificaciones</div>
              {unread > 0 && (
                <button onClick={markAllRead}
                  style={{ fontSize: 11, color: "var(--accent)", background: "none", border: "none", cursor: "pointer" }}>
                  Marcar todo leído
                </button>
              )}
            </div>

            {notifs.length === 0 ? (
              <div style={{ padding: 32, textAlign: "center", color: "var(--text-3)", fontSize: 13 }}>
                <div style={{ fontSize: 32, marginBottom: 8 }}>🔔</div>
                Sin notificaciones
              </div>
            ) : (
              notifs.map(n => (
                <div key={n.id}
                  onClick={() => markRead(n.id)}
                  style={{
                    padding: "12px 16px", borderBottom: "1px solid var(--border)",
                    cursor: "pointer", display: "flex", gap: 12, alignItems: "flex-start",
                    background: n.leida ? "transparent" : "var(--accent-soft)",
                    transition: "background .15s",
                  }}>
                  <span style={{ fontSize: 20, flexShrink: 0, marginTop: 1 }}>
                    {TIPO_ICON[n.tipo] || TIPO_ICON.default}
                  </span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: n.leida ? 400 : 600,
                      overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {n.titulo}
                    </div>
                    {n.cuerpo && (
                      <div style={{ fontSize: 11.5, color: "var(--text-3)", marginTop: 2,
                        overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {n.cuerpo}
                      </div>
                    )}
                    <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>
                      {fmtFecha(n.created_at)}
                    </div>
                  </div>
                  {!n.leida && (
                    <div style={{ width: 8, height: 8, borderRadius: "50%",
                      background: "var(--accent)", flexShrink: 0, marginTop: 5 }} />
                  )}
                </div>
              ))
            )}
          </div>
        </>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'public/sw.js')
cat > 'public/sw.js' << 'FILEEOF'
const CACHE = "viaticos-gz-v4"
const PRECACHE = ["/", "/login", "/icon-192.png", "/manifest.json"]

self.addEventListener("install", e => {
  console.log("[SW] Installing v4")
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", e => {
  console.log("[SW] Activated v4")
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  const url = new URL(e.request.url)
  // Skip API calls, Supabase, Firebase, external CDN
  if (
    url.pathname.startsWith("/api/") ||
    url.pathname.includes("sw.js") ||
    url.pathname.includes("firebase") ||
    url.hostname.includes("supabase") ||
    url.hostname.includes("googleapis") ||
    url.hostname.includes("gstatic") ||
    url.hostname !== self.location.hostname
  ) return

  e.respondWith(
    fetch(e.request)
      .then(res => {
        // Only cache successful same-origin responses
        if (res.ok && res.status < 400 && res.type === "basic") {
          const clone = res.clone() // clone BEFORE returning
          caches.open(CACHE).then(c => c.put(e.request, clone)).catch(() => {})
        }
        return res
      })
      .catch(() => caches.match(e.request).then(r => r || Response.error()))
  )
})

FILEEOF

git add .
git commit -m "fix: hardcode firebase config, sw.js clone error, notificaciones fallback"
git push
echo "✓ Done!"