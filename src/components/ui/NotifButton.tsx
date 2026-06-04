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

