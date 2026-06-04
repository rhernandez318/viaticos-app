#!/bin/bash
set -e

mkdir -p $(dirname 'src/components/ui/PushNotifications.tsx')
cat > 'src/components/ui/PushNotifications.tsx' << 'FILEEOF'
"use client"
import { useEffect, useState, useRef, useCallback } from "react"

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY || ""
const FIREBASE_CONFIG = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

interface Props { userId: string }
type Status = "idle" | "asking" | "granted" | "denied"

// Global reference so triggerNotifSetup() can be called from anywhere (e.g. perfil)
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
    const s1 = document.createElement("script")
    s1.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"
    const s2 = document.createElement("script")
    s2.src = "https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js"
    s2.onload = () => {
      try {
        const fb = (window as any).firebase
        if (!fb.apps?.length) fb.initializeApp(FIREBASE_CONFIG)
        messagingRef.current = fb.messaging()
        fbReadyRef.current = true
        messagingRef.current.onMessage((payload: any) => {
          const { t: title, b: body } = payload.data || {}
          if (title) { setToast({ title, body: body||"" }); setTimeout(()=>setToast(null),5000) }
        })
        resolve()
      } catch(e) { reject(e) }
    }
    s2.onerror = reject
    s1.onload = () => document.head.appendChild(s2)
    s1.onerror = reject
    document.head.appendChild(s1)
  }), [])

  const registerToken = useCallback(async () => {
    try {
      await loadFirebase()
      const token = await messagingRef.current?.getToken({ vapidKey: VAPID_KEY })
      if (!token) return
      await fetch("/api/push/register", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, token }),
      })
      console.log("[FCM] ✓ Registered")
      localStorage.setItem("notif-status", "granted")
    } catch(e) { console.warn("[FCM]", e) }
  }, [userId, loadFirebase])

  const handleActivar = useCallback(async () => {
    if (!("Notification" in window)) {
      alert("Tu navegador no soporta notificaciones"); return
    }
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
    } catch(e) { setStatus("idle") }
  }, [registerToken])

  // Expose globally for perfil page
  useEffect(() => { globalSetup = handleActivar; return () => { globalSetup = null } }, [handleActivar])

  useEffect(() => {
    if (!userId || typeof window === "undefined") return
    if (!("Notification" in window)) return

    const perm = Notification.permission
    const saved = localStorage.getItem("notif-status")

    if (perm === "granted") {
      setStatus("granted")
      registerToken()
      return
    }
    if (perm === "denied") { setStatus("denied"); return }

    // "default" and not previously dismissed → show banner
    if (saved === "denied") { setStatus("denied"); return }

    // Show banner after 3s (clear if previously dismissed with "later")
    const t = setTimeout(() => setBanner(true), 3000)
    return () => clearTimeout(t)
  }, [userId, registerToken])

  const handleDismiss = () => {
    setBanner(false)
    localStorage.setItem("notif-status", "later")
  }

  return (
    <>
      {/* Banner */}
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

      {/* Asking state */}
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

      {/* Foreground toast */}
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

mkdir -p $(dirname 'src/components/ui/NotifButton.tsx')
cat > 'src/components/ui/NotifButton.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { triggerNotifSetup } from "@/components/ui/PushNotifications"

export function NotifButton() {
  const [perm, setPerm] = useState<string>("default")

  useEffect(() => {
    if ("Notification" in window) setPerm(Notification.permission)
  }, [])

  const handleClick = () => {
    const saved = localStorage.getItem("notif-status")
    // Reset so the setup can run again
    if (saved) localStorage.removeItem("notif-status")
    triggerNotifSetup()
  }

  return (
    <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between" }}>
      <div>
        <div style={{ fontSize:13, fontWeight:600, marginBottom:2 }}>Notificaciones push</div>
        <div style={{ fontSize:11.5, color:"var(--text-3)" }}>
          {perm==="granted" ? "✅ Activadas" :
           perm==="denied"  ? "🚫 Bloqueadas — habilítalas en los ajustes del navegador" :
           "Sin configurar"}
        </div>
      </div>
      {perm !== "denied" && (
        <button onClick={handleClick}
          className="btn sm"
          style={{
            background: perm==="granted" ? "var(--success-soft)" : "var(--accent)",
            border: "none",
            color: perm==="granted" ? "var(--success)" : "#111",
            fontWeight: 600,
          }}>
          {perm==="granted" ? "Reactivar" : "Activar 🔔"}
        </button>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/perfil/page.tsx')
cat > 'src/app/(app)/perfil/page.tsx' << 'FILEEOF'
import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { fmtMXN } from "@/lib/format"
import { NotifButton } from "@/components/ui/NotifButton"

export default async function PerfilPage() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  const [{ data: u }, { data: sols }] = await Promise.all([
    sb.from("usuarios").select("*, centro:centros(*), gerente:usuarios!gerente_id(nombre)").eq("id", user.id).single(),
    sb.from("solicitudes").select("id, tipo, status, monto, saldo_pendiente").eq("usuario_id", user.id),
  ])

  if (!u) redirect("/login")

  const totalAbierto = (sols || [])
    .filter(s => ["liberado","parcial"].includes(s.status) && parseFloat(s.saldo_pendiente) > 0)
    .reduce((a, s) => a + parseFloat(s.saldo_pendiente), 0)

  const ROL_COLOR: Record<string, string> = {
    admin: "var(--accent)", gerente: "var(--success)", tesoreria: "#60a5fa",
    contador: "#c084fc", usuario: "var(--text-3)",
  }

  return (
    <div style={{ maxWidth: 620 }}>
      <div className="page-head">
        <h1 className="page-title">Mi perfil</h1>
      </div>

      {/* Avatar + name */}
      <div className="card" style={{ textAlign: "center", marginBottom: 16, padding: "28px 20px" }}>
        <div style={{ width: 68, height: 68, borderRadius: "50%", margin: "0 auto 14px",
          background: "var(--accent-soft)", color: "var(--accent)",
          display: "grid", placeItems: "center", fontSize: 24, fontWeight: 700 }}>
          {u.iniciales}
        </div>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 4 }}>{u.nombre}</div>
        <div style={{ fontSize: 13, color: "var(--text-3)", marginBottom: 10 }}>{u.correo}</div>
        <span style={{ fontSize: 12, padding: "3px 14px", borderRadius: 20, fontWeight: 600,
          background: ROL_COLOR[u.rol] + "22", color: ROL_COLOR[u.rol] }}>
          {u.rol}
        </span>
      </div>

      {/* Info */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Cuenta</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
          {[
            { label: "Centro de beneficio", value: u.centro ? `${u.centro.id} · ${u.centro.nombre}` : "—" },
            { label: "Departamento", value: u.centro?.depto || "—" },
            { label: "Gerente", value: (u.gerente as any)?.nombre || "—" },
            { label: "División SAP", value: u.division || "4105" },
            { label: "Banco", value: u.banco || "—" },
            { label: "CLABE", value: u.clabe ? "•••• " + u.clabe.slice(-4) : "—" },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, color: "var(--text-3)", textTransform: "uppercase",
                letterSpacing: ".05em", marginBottom: 3 }}>{label}</div>
              <div style={{ fontSize: 13, fontWeight: 500 }}>{value}</div>
            </div>
          ))}
        </div>
        <div style={{ marginTop: 10, fontSize: 11.5, color: "var(--text-3)", fontStyle: "italic" }}>
          Para cambiar CLABE o banco, contacta a Tesorería.
        </div>
        <div style={{ marginTop: 16, paddingTop: 14, borderTop: "1px solid var(--border)" }}>
          <NotifButton/>
        </div>
        <div style={{ marginTop: 14, paddingTop: 12, borderTop: "1px solid var(--border)", fontSize: 12, color: "var(--text-3)" }}>
          Las notificaciones push se activan automáticamente al usar la app.
          Si no las recibiste, cierra y vuelve a abrir la app para ver el banner.
        </div>
      </div>

      {/* Activity summary */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Resumen de actividad</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12 }}>
          {[
            { label: "Total solicitudes", value: (sols || []).length },
            { label: "Anticipos abiertos", value: (sols || []).filter(s => s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0).length },
            { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : undefined },
          ].map(k => (
            <div key={k.label} className="card" style={{ margin: 0, textAlign: "center", padding: "12px 8px" }}>
              <div style={{ fontSize: 18, fontWeight: 700, color: k.color }}>{k.value}</div>
              <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

FILEEOF

git add .
git commit -m "feat: notification banner mobile fix + manual toggle in perfil"
git push
echo "✓ Done"