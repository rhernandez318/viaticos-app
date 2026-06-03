"use client"

import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { TipoBadge } from "@/components/ui/StatusBadge"
import Link from "next/link"
import type { Solicitud } from "@/types"

export default function TesoreriaLiberarPage() {
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [procesando, setProcesando] = useState(false)
  const [userId, setUserId] = useState<string | null>(null)

  const load = useCallback(async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return
    setUserId(user.id)

    const { data } = await sb.from("solicitudes")
      .select("id, tipo, concepto, monto, fecha, status, usuario_id, saldo_pendiente, anticipo_ref")
      .eq("status", "autorizado")
      .order("fecha", { ascending: true })

    const mapped: Solicitud[] = (data || []).map((s: any) => ({
      id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
      monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
      status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
      anticipoRef: s.anticipo_ref, cfdi: [],
    }))
    setSolicitudes(mapped)
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const toggle = (id: string) => setSelected(prev => {
    const n = new Set(prev)
    n.has(id) ? n.delete(id) : n.add(id)
    return n
  })

  const toggleAll = () => setSelected(
    selected.size === solicitudes.length ? new Set() : new Set(solicitudes.map(s => s.id))
  )

  const liberar = async () => {
    if (selected.size === 0) return
    setProcesando(true)
    const sb = createClient()
    const ids = Array.from(selected)

    for (const id of ids) {
      const s = solicitudes.find(x => x.id === id)
      if (!s) continue

      let newStatus = "liberado"
      // Comprobaciones → comprobado
      if (s.tipo === "comprobacion") newStatus = "comprobado"

      await sb.from("solicitudes").update({ status: newStatus }).eq("id", id)

      // If comprobacion with anticipo ref, recalculate saldo
      if (s.tipo === "comprobacion" && s.anticipoRef) {
        const { data: comps } = await sb.from("solicitudes")
          .select("monto, status, anticipo_ref, tipo")
          .eq("anticipo_ref", s.anticipoRef)
          .in("status", ["liberado", "comprobado"])
        const totalComp = (comps || []).reduce((a: number, c: any) => a + (parseFloat(c.monto) || 0), 0)
        const { data: ant } = await sb.from("solicitudes")
          .select("monto").eq("id", s.anticipoRef).single()
        if (ant) {
          const saldo = Math.max(0, (parseFloat(ant.monto) || 0) - totalComp)
          await sb.from("solicitudes").update({
            saldo_pendiente: saldo,
            status: saldo <= 0 ? "comprobado" : "parcial",
          }).eq("id", s.anticipoRef)
        }
      }

      await sb.from("bitacora").insert({
        solicitud_id: id, accion: newStatus, usuario_id: userId,
        detalle: "Liberado por tesorería", ts: new Date().toISOString(),
      })
    }

    await load()
    setSelected(new Set())
    setProcesando(false)
  }

  const selectedTotal = solicitudes
    .filter(s => selected.has(s.id))
    .reduce((a, s) => a + s.monto, 0)

  // Group by tipo
  const anticipos = solicitudes.filter(s => s.tipo === "anticipo")
  const comprobaciones = solicitudes.filter(s => ["comprobacion","reembolso"].includes(s.tipo))

  const renderGroup = (title: string, items: Solicitud[]) => {
    if (items.length === 0) return null
    return (
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 11, fontWeight: 600, textTransform: "uppercase",
          letterSpacing: ".06em", color: "var(--text-3)", marginBottom: 10 }}>
          {title} · {items.length}
        </div>
        {items.map(s => (
          <div key={s.id} className="card"
            style={{ marginBottom: 8, cursor: "pointer",
              borderColor: selected.has(s.id) ? "var(--accent)" : "var(--border)",
              background: selected.has(s.id) ? "var(--accent-soft)" : "var(--surface)" }}
            onClick={() => toggle(s.id)}>
            <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
              <input type="checkbox" checked={selected.has(s.id)}
                onChange={() => toggle(s.id)}
                onClick={e => e.stopPropagation()} />
              <TipoBadge tipo={s.tipo} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: 13, overflow: "hidden",
                  textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{s.concepto}</div>
                <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>
                  {s.id} · {fmtFecha(s.fecha)}
                </div>
              </div>
              <div style={{ fontWeight: 700, fontSize: 16, textAlign: "right" }}>
                {fmtMXN(s.monto)}
              </div>
            </div>
          </div>
        ))}
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
        <div style={{ display: "flex", gap: 8 }}>
          <Link href="/tesoreria/pagados" className="btn ghost">Pagados</Link>
          <Link href="/tesoreria/deudores" className="btn ghost">Deudores</Link>
        </div>
      </div>

      {/* Bulk action bar */}
      {selected.size > 0 && (
        <div style={{ padding: "12px 16px", background: "var(--accent-soft)",
          border: "1px solid var(--accent)", borderRadius: 10, marginBottom: 16,
          display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ fontSize: 13, fontWeight: 600 }}>
            {selected.size} seleccionada{selected.size > 1 ? "s" : ""} · {fmtMXN(selectedTotal)}
          </div>
          <button className="btn primary" onClick={liberar} disabled={procesando}>
            {procesando ? "Liberando…" : `Liberar ${selected.size} ✓`}
          </button>
        </div>
      )}

      {loading ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>
          Cargando…
        </div>
      ) : solicitudes.length === 0 ? (
        <div className="card" style={{ padding: 48, textAlign: "center" }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>✅</div>
          <div style={{ fontWeight: 600, fontSize: 16, marginBottom: 6 }}>Todo liberado</div>
          <div style={{ color: "var(--text-3)", fontSize: 13 }}>Sin solicitudes pendientes de dispersión</div>
        </div>
      ) : (
        <>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
            <button className="btn ghost" style={{ fontSize: 12 }} onClick={toggleAll}>
              {selected.size === solicitudes.length ? "Deseleccionar todo" : "Seleccionar todo"}
            </button>
          </div>
          {renderGroup("Anticipos para dispersión SPEI", anticipos)}
          {renderGroup("Comprobaciones y reembolsos", comprobaciones)}
        </>
      )}
    </>
  )
}

