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
            position: "fixed", top: 56, left: 8, right: 8, zIndex: 200,
            width: "auto", maxWidth: 360, maxHeight: 480, overflowY: "auto",
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

