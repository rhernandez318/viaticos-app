"use client"
import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { TipoBadge } from "@/components/ui/StatusBadge"
import Link from "next/link"
import type { Solicitud } from "@/types"

export default function TesoreriaLiberarPage() {
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [usuarios, setUsuarios] = useState<Record<string,any>>({})
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [procesando, setProcesando] = useState(false)
  const [userId, setUserId] = useState<string | null>(null)

  const load = useCallback(async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return
    setUserId(user.id)

    const [solRes, usrRes] = await Promise.all([
      sb.from("solicitudes")
        .select("id, tipo, concepto, monto, fecha, status, usuario_id, saldo_pendiente, anticipo_ref")
        .eq("status", "validado")
        .order("fecha", { ascending: true }),
      sb.from("usuarios").select("id, nombre, iniciales"),
    ])

    const usrMap: Record<string,any> = {}
    ;(usrRes.data||[]).forEach((u:any) => { usrMap[u.id] = u })
    setUsuarios(usrMap)

    setSolicitudes((solRes.data || []).map((s: any) => ({
      id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
      monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
      status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
      anticipoRef: s.anticipo_ref, cfdi: [],
    })))
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const toggle = (id: string) => setSelected(prev => {
    const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n
  })
  const toggleAll = () => setSelected(
    selected.size === solicitudes.length ? new Set() : new Set(solicitudes.map(s => s.id))
  )

  const liberar = async () => {
    if (!selected.size) return
    setProcesando(true)
    const sb = createClient()
    for (const id of Array.from(selected)) {
      const s = solicitudes.find(x => x.id === id)
      if (!s) continue
      // Comprobaciones sin anticipo ref → comprobado (ya tienen factura).
      // Reembolsos liberados → comprobado (representan gasto ya hecho, no requieren comprobación posterior).
      // Anticipos → liberado (deben comprobarse después).
      const newStatus =
        (s.tipo === "comprobacion" && !s.anticipoRef) || s.tipo === "reembolso"
          ? "comprobado"
          : "liberado"
      await sb.from("solicitudes").update({ status: newStatus }).eq("id", id)
      if (s.tipo === "comprobacion" && s.anticipoRef) {
        const { data: comps } = await sb.from("solicitudes")
          .select("monto").eq("anticipo_ref", s.anticipoRef).in("status",["liberado","comprobado"])
        const { data: ant } = await sb.from("solicitudes").select("monto").eq("id", s.anticipoRef).single()
        if (ant) {
          const totalComp = (comps||[]).reduce((a:number,c:any)=>a+parseFloat(c.monto),0) + s.monto
          const saldo = Math.max(0, parseFloat(ant.monto) - totalComp)
          await sb.from("solicitudes").update({ saldo_pendiente: saldo, status: saldo<=0?"comprobado":"parcial" }).eq("id", s.anticipoRef)
        }
      }
      await sb.from("bitacora").insert({
        solicitud_id: id, accion: newStatus, usuario_id: userId,
        detalle: "Liberado por tesorería", ts: new Date().toISOString(),
      })
      // Notificar al solicitante
      try {
        await sb.from("notificaciones").insert({
          usuario_id: s.usuario, titulo: "Pago liberado",
          cuerpo: `Tu solicitud ${id} fue liberada para pago`, tipo: "liberacion",
          leida: false, created_at: new Date().toISOString(),
        })
      } catch {}
    }
    await load(); setSelected(new Set()); setProcesando(false)
  }

  const selectedTotal = solicitudes.filter(s => selected.has(s.id)).reduce((a, s) => a + s.monto, 0)
  const anticipos = solicitudes.filter(s => s.tipo === "anticipo")
  const comprobaciones = solicitudes.filter(s => ["comprobacion","reembolso"].includes(s.tipo))

  const renderCard = (s: Solicitud) => {
    const u = usuarios[s.usuario]
    return (
      <div key={s.id} className="card"
        style={{ marginBottom:8, cursor:"pointer",
          borderColor: selected.has(s.id) ? "var(--accent)" : "var(--border)",
          background: selected.has(s.id) ? "var(--accent-soft)" : "var(--surface)" }}
        onClick={() => toggle(s.id)}>
        <div style={{ display:"flex", gap:12, alignItems:"center" }}>
          <input type="checkbox" checked={selected.has(s.id)} onChange={() => toggle(s.id)}
            onClick={e => e.stopPropagation()} style={{ flexShrink:0 }}/>
          <TipoBadge tipo={s.tipo}/>
          <div style={{ flex:1, minWidth:0 }}>
            {/* Usuario */}
            {u && (
              <div style={{ display:"flex", alignItems:"center", gap:6, marginBottom:3 }}>
                <div style={{ width:20, height:20, borderRadius:"50%", flexShrink:0,
                  background:"var(--accent-soft)", color:"var(--accent)",
                  display:"grid", placeItems:"center", fontSize:8, fontWeight:700 }}>
                  {u.iniciales}
                </div>
                <span style={{ fontSize:12, fontWeight:600, color:"var(--text-2)" }}>{u.nombre}</span>
              </div>
            )}
            <div style={{ fontWeight:600, fontSize:13, overflow:"hidden",
              textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{s.concepto}</div>
            <div style={{ display:"flex", gap:6, alignItems:"center", marginTop:2 }}>
              <span style={{ fontSize:11, color:"var(--text-3)" }}>{s.id} · {fmtFecha(s.fecha)}</span>
              {s.concepto?.includes("Saldo a favor") && (
                <span style={{ fontSize:10, padding:"1px 7px", borderRadius:10, fontWeight:600,
                  background:"var(--accent-soft)", color:"var(--accent)" }}>
                  💰 Saldo a favor
                </span>
              )}
            </div>
          </div>
          <div style={{ fontWeight:700, fontSize:16, flexShrink:0 }}>
            {fmtMXN(s.monto)}
          </div>
        </div>
      </div>
    )
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Liberar pagos</h1>
          <div className="page-sub">{solicitudes.length} autorizadas pendientes de dispersión</div>
        </div>
        <div style={{ display:"flex", gap:8 }}>
          <Link href="/tesoreria/pagados" className="btn ghost">Pagados</Link>
          <Link href="/tesoreria/deudores" className="btn ghost">Deudores</Link>
        </div>
      </div>

      {selected.size > 0 && (
        <div style={{ padding:"12px 16px", background:"var(--accent-soft)",
          border:"1px solid var(--accent)", borderRadius:10, marginBottom:16,
          display:"flex", alignItems:"center", justifyContent:"space-between" }}>
          <div style={{ fontSize:13, fontWeight:600 }}>
            {selected.size} seleccionada{selected.size>1?"s":""} · {fmtMXN(selectedTotal)}
          </div>
          <button className="btn primary" onClick={liberar} disabled={procesando}>
            {procesando ? "Liberando…" : `Liberar ${selected.size} ✓`}
          </button>
        </div>
      )}

      {loading ? (
        <div className="card" style={{ padding:40, textAlign:"center", color:"var(--text-3)" }}>Cargando…</div>
      ) : solicitudes.length === 0 ? (
        <div className="card" style={{ padding:48, textAlign:"center" }}>
          <div style={{ fontSize:40, marginBottom:12 }}>✅</div>
          <div style={{ fontWeight:600, fontSize:16 }}>Todo liberado</div>
          <div style={{ color:"var(--text-3)", fontSize:13, marginTop:6 }}>Sin pagos pendientes</div>
        </div>
      ) : (
        <>
          <button className="btn ghost" style={{ fontSize:12, marginBottom:12 }} onClick={toggleAll}>
            {selected.size === solicitudes.length ? "Deseleccionar todo" : "Seleccionar todo"}
          </button>
          {anticipos.length > 0 && (
            <div style={{ marginBottom:16 }}>
              <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
                letterSpacing:".06em", color:"var(--text-3)", marginBottom:8 }}>
                Anticipos para dispersión SPEI · {anticipos.length}
              </div>
              {anticipos.map(renderCard)}
            </div>
          )}
          {comprobaciones.length > 0 && (
            <div>
              <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
                letterSpacing:".06em", color:"var(--text-3)", marginBottom:8 }}>
                Comprobaciones y reembolsos · {comprobaciones.length}
              </div>
              {comprobaciones.map(renderCard)}
            </div>
          )}
        </>
      )}
    </>
  )
}


