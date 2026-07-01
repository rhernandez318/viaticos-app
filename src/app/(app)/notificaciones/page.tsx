"use client"
import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Bell, CheckCheck, Inbox } from "lucide-react"

interface Notif {
  id: string
  tipo: string
  titulo: string
  mensaje: string | null
  ref_id: string | null
  leida: boolean
  created_at: string
}

const fmtFechaRel = (iso: string) => {
  const d = new Date(iso)
  const diff = Date.now() - d.getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return "hace segundos"
  if (min < 60) return `hace ${min} min`
  const hrs = Math.floor(min / 60)
  if (hrs < 24) return `hace ${hrs} h`
  const dias = Math.floor(hrs / 24)
  if (dias < 30) return `hace ${dias} d`
  return d.toLocaleDateString("es-MX", { day: "numeric", month: "short" })
}

export default function NotificacionesPage() {
  const router = useRouter()
  const [notifs, setNotifs] = useState<Notif[]>([])
  const [loading, setLoading] = useState(true)

  const cargar = async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { setLoading(false); return }
    const { data } = await sb
      .from("notificaciones")
      .select("*")
      .eq("usuario_id", user.id)
      .order("created_at", { ascending: false })
      .limit(50)
    setNotifs(data || [])
    setLoading(false)
  }

  useEffect(() => { cargar() }, [])

  const marcarLeida = async (id: string) => {
    const sb = createClient()
    await sb.from("notificaciones").update({ leida: true }).eq("id", id)
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, leida: true } : n))
  }

  const marcarTodasLeidas = async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return
    await sb.from("notificaciones").update({ leida: true }).eq("usuario_id", user.id).eq("leida", false)
    setNotifs(prev => prev.map(n => ({ ...n, leida: true })))
  }

  const abrirRef = async (n: Notif) => {
    if (!n.leida) await marcarLeida(n.id)
    if (n.ref_id) router.push(`/solicitudes/${n.ref_id}`)
  }

  const noLeidas = notifs.filter(n => !n.leida).length

  if (loading) return <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>

  return (
    <>
      <div className="page-head" style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",flexWrap:"wrap",gap:10}}>
        <div>
          <h1 className="page-title" style={{display:"flex",alignItems:"center",gap:10}}>
            <Bell size={22} strokeWidth={1.75}/> Notificaciones
          </h1>
          <div className="page-sub">
            {noLeidas > 0 ? `${noLeidas} sin leer` : "Todas leídas"}
          </div>
        </div>
        {noLeidas > 0 && (
          <button className="btn sm" onClick={marcarTodasLeidas}
            style={{display:"flex",alignItems:"center",gap:6}}>
            <CheckCheck size={14}/> Marcar todas
          </button>
        )}
      </div>

      {notifs.length === 0 ? (
        <div className="card" style={{padding:60,textAlign:"center"}}>
          <Inbox size={48} strokeWidth={1.5} style={{color:"var(--text-3)",marginBottom:14}}/>
          <div style={{fontSize:14,color:"var(--text-3)"}}>
            No tienes notificaciones aún
          </div>
          <div style={{fontSize:11,color:"var(--text-3)",marginTop:6}}>
            Cuando alguien te envíe una solicitud o cambie el estatus de una tuya, aparecerá aquí.
          </div>
        </div>
      ) : (
        <div className="card" style={{padding:0,overflow:"hidden"}}>
          {notifs.map((n, i) => (
            <div key={n.id}
              onClick={() => abrirRef(n)}
              style={{
                padding: "14px 16px",
                borderBottom: i < notifs.length-1 ? "1px solid var(--border)" : "none",
                cursor: n.ref_id ? "pointer" : "default",
                background: !n.leida ? "var(--accent-soft, rgba(197,242,77,0.05))" : "transparent",
                position: "relative",
                display: "flex",
                gap: 12,
                alignItems: "flex-start",
              }}>
              {!n.leida && (
                <div style={{
                  width: 8, height: 8, borderRadius: "50%",
                  background: "var(--accent, #c5f24d)",
                  marginTop: 8, flexShrink: 0,
                }}/>
              )}
              {n.leida && <div style={{width:8,flexShrink:0}}/>}
              <div style={{flex:1,minWidth:0}}>
                <div style={{display:"flex",justifyContent:"space-between",gap:10,marginBottom:4}}>
                  <div style={{fontWeight: n.leida ? 500 : 600, fontSize:14}}>{n.titulo}</div>
                  <div style={{fontSize:11,color:"var(--text-3)",whiteSpace:"nowrap",flexShrink:0}}>
                    {fmtFechaRel(n.created_at)}
                  </div>
                </div>
                {n.mensaje && (
                  <div style={{fontSize:12,color:"var(--text-2)",lineHeight:1.5}}>{n.mensaje}</div>
                )}
                {n.ref_id && (
                  <div className="mono" style={{fontSize:10,color:"var(--text-3)",marginTop:6}}>
                    {n.ref_id}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
