#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/solicitudes/[id]/page.tsx')
cat > 'src/app/(app)/solicitudes/[id]/page.tsx' << 'FILEEOF'
import { createClient } from "@/lib/supabase/server"
import { redirect, notFound } from "next/navigation"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import { Stepper } from "@/components/ui/Stepper"
import Link from "next/link"

export default async function DetallePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  const { data: s } = await sb.from("solicitudes")
    .select("*, cfdi:comprobantes_cfdi(*), items:solicitud_items(*)")
    .eq("id", id)
    .single()

  if (!s) notFound()

  const { data: perfil } = await sb.from("usuarios")
    .select("nombre, iniciales, rol").eq("id", s.usuario_id).single()

  const { data: bitacora } = await sb.from("bitacora")
    .select("*, actor:usuarios!usuario_id(nombre)")
    .eq("solicitud_id", id).order("ts", { ascending: true })

  const archivos = (s.cfdi || []).filter((c: any) => c.archivo_url)

  const dates: Record<string, Date | null> = {}
  ;(bitacora || []).forEach((b: any) => { dates[b.accion] = new Date(b.ts) })

  return (
    <div style={{ maxWidth: 780 }}>
      {/* Header */}
      <div className="page-head">
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
            <TipoBadge tipo={s.tipo} />
            <StatusBadge status={s.status} />
            {s.notas?.includes("CIERRE_DEPOSITO") && (
              <span style={{ fontSize: 11, padding: "2px 8px", borderRadius: 12,
                background: "var(--accent-soft)", color: "var(--accent)", fontWeight: 600 }}>
                🏦 CIERRE
              </span>
            )}
          </div>
          <h1 className="page-title" style={{ fontSize: 20 }}>{id}</h1>
          <p className="page-sub">{s.concepto}</p>
        </div>
        <Link href="/solicitudes" className="btn ghost">← Mis solicitudes</Link>
      </div>

      {/* Stepper */}
      <div className="card" style={{ marginBottom: 16 }}>
        <Stepper status={s.status} dates={dates} />
      </div>

      {/* Info grid */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16 }}>
          {[
            { label: "Solicitante", value: perfil?.nombre || "—" },
            { label: "Fecha", value: fmtFecha(s.fecha) },
            { label: "Monto", value: fmtMXN(parseFloat(s.monto)) },
            ...(s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0 ? [
              { label: "Saldo pendiente", value: fmtMXN(parseFloat(s.saldo_pendiente)) }
            ] : []),
            ...(s.anticipo_ref ? [{ label: "Anticipo ref.", value: s.anticipo_ref }] : []),
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, color: "var(--text-3)", textTransform: "uppercase",
                letterSpacing: ".05em", marginBottom: 4 }}>{label}</div>
              <div style={{ fontWeight: 600, fontSize: 14 }}>{value}</div>
            </div>
          ))}
        </div>
        {s.motivo_rechazo && (
          <div style={{ marginTop: 14, padding: "10px 12px", borderRadius: 8,
            background: "var(--danger-soft)", color: "var(--danger)", fontSize: 13 }}>
            ✕ Motivo de rechazo: {s.motivo_rechazo}
          </div>
        )}
      </div>

      {/* CFDIs */}
      {s.cfdi && s.cfdi.length > 0 && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div className="card-title" style={{ marginBottom: 12 }}>
            Comprobantes · {s.cfdi.length}
          </div>
          <table className="t">
            <thead>
              <tr>
                <th>UUID</th><th>Emisor</th><th>Cuenta</th>
                <th className="num">Total</th><th>SAT</th><th></th>
              </tr>
            </thead>
            <tbody>
              {s.cfdi.map((cf: any) => (
                <tr key={cf.id}>
                  <td className="mono" style={{ fontSize: 10 }}>
                    {cf.uuid ? cf.uuid.slice(0, 20) + "…" : "—"}
                  </td>
                  <td style={{ fontSize: 12 }}>{cf.emisor || "—"}</td>
                  <td style={{ fontSize: 11, color: "var(--text-3)" }}>{cf.cuenta}</td>
                  <td className="num">{fmtMXN(parseFloat(cf.total))}</td>
                  <td>
                    {cf.sat_estado && (
                      <span style={{ fontSize: 10, padding: "2px 7px", borderRadius: 10, fontWeight: 600,
                        background: cf.sat_estado === "Vigente" ? "var(--success-soft)" : "var(--warn-soft)",
                        color: cf.sat_estado === "Vigente" ? "var(--success)" : "var(--warn)" }}>
                        {cf.sat_estado}
                      </span>
                    )}
                  </td>
                  <td>
                    {cf.archivo_url && (
                      <a href={cf.archivo_url} target="_blank" rel="noopener"
                        className="btn sm ghost" style={{ fontSize: 11 }}>
                        ↓
                      </a>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Bitácora */}
      {bitacora && bitacora.length > 0 && (
        <div className="card" style={{ marginBottom: 16 }}>
          <div className="card-title" style={{ marginBottom: 14 }}>Línea de tiempo</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 0 }}>
            {bitacora.map((b: any, i: number) => (
              <div key={b.id} style={{ display: "flex", gap: 14, paddingBottom: i < bitacora.length - 1 ? 16 : 0,
                position: "relative" }}>
                {i < bitacora.length - 1 && (
                  <div style={{ position: "absolute", left: 11, top: 24, width: 2,
                    height: "calc(100% - 8px)", background: "var(--border)" }} />
                )}
                <div style={{ width: 24, height: 24, borderRadius: "50%", flexShrink: 0,
                  background: b.accion === "rechazado" ? "var(--danger)" :
                               b.accion === "comprobado" ? "var(--success)" : "var(--accent)",
                  display: "grid", placeItems: "center", fontSize: 10, color: "#111",
                  fontWeight: 700, position: "relative", zIndex: 1 }}>
                  {i + 1}
                </div>
                <div style={{ flex: 1, paddingTop: 3 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, textTransform: "capitalize" }}>
                    {b.accion}
                  </div>
                  <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 1 }}>
                    {b.actor?.nombre || "Sistema"} · {fmtFecha(b.ts)}
                  </div>
                  {b.detalle && (
                    <div style={{ fontSize: 11, color: "var(--text-2)", marginTop: 2 }}>{b.detalle}</div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/gerente/page.tsx')
cat > 'src/app/(app)/gerente/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import type { Solicitud } from "@/types"

export default function GerenteBandejaPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)
  const [procesando, setProcesando] = useState<string | null>(null)
  const [motivoRechazo, setMotivoRechazo] = useState("")
  const [rechazandoId, setRechazandoId] = useState<string | null>(null)
  const [userId, setUserId] = useState<string | null>(null)
  const [rol, setRol] = useState<string>("")

  const loadPendientes = useCallback(async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    setUserId(user.id)
    const { data: perfil } = await sb.from("usuarios")
      .select("rol, id").eq("id", user.id).single()
    const userRol = perfil?.rol || ""
    setRol(userRol)

    let query = sb.from("solicitudes")
      .select("id, tipo, concepto, monto, fecha, status, usuario_id, saldo_pendiente")
      .eq("status", "solicitado")
      .order("fecha", { ascending: true })

    // Gerente: only their team — Admin: all
    if (userRol !== "admin") {
      const { data: equipo } = await sb.from("usuarios")
        .select("id").eq("gerente_id", user.id)
      const teamIds = (equipo || []).map((u: any) => u.id)
      if (teamIds.length === 0) { setLoading(false); return }
      query = query.in("usuario_id", teamIds)
    }

    const { data } = await query
    const mapped: Solicitud[] = (data || []).map((s: any) => ({
      id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
      monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
      status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0, cfdi: [],
    }))
    setSolicitudes(mapped)
    setLoading(false)
  }, [])

  useEffect(() => { loadPendientes() }, [loadPendientes])

  const aprobar = async (id: string) => {
    setProcesando(id)
    const sb = createClient()
    const s = solicitudes.find(x => x.id === id)
    if (!s) return
    const { error } = await sb.from("solicitudes")
      .update({ status: "autorizado", ...(s.tipo === "anticipo" ? { saldo_pendiente: s.monto } : {}) })
      .eq("id", id)
    if (error) { alert("Error: " + error.message); setProcesando(null); return }
    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "autorizado", usuario_id: userId,
      detalle: "Aprobado por gerente", ts: new Date().toISOString(),
    })
    setSolicitudes(prev => prev.filter(x => x.id !== id))
    setProcesando(null)
  }

  const rechazar = async (id: string) => {
    if (!motivoRechazo.trim()) { alert("Escribe el motivo de rechazo"); return }
    setProcesando(id)
    const sb = createClient()
    const { error } = await sb.from("solicitudes")
      .update({ status: "rechazado", motivo_rechazo: motivoRechazo.trim() })
      .eq("id", id)
    if (error) { alert("Error: " + error.message); setProcesando(null); return }
    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "rechazado", usuario_id: userId,
      detalle: motivoRechazo.trim(), ts: new Date().toISOString(),
    })
    setSolicitudes(prev => prev.filter(x => x.id !== id))
    setRechazandoId(null)
    setMotivoRechazo("")
    setProcesando(null)
  }

  const totalPendiente = solicitudes.reduce((a, s) => a + s.monto, 0)
  const diasPromedio = solicitudes.length > 0
    ? Math.round(solicitudes.reduce((a, s) => a + (Date.now() - s.fecha.getTime()) / 86400000, 0) / solicitudes.length)
    : 0

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Por aprobar</h1>
          <div className="page-sub">{solicitudes.length} solicitudes pendientes</div>
        </div>
        <button className="btn ghost" onClick={loadPendientes}>↻ Actualizar</button>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 20 }}>
        {[
          { label: "Pendientes", value: solicitudes.length, color: solicitudes.length > 0 ? "var(--warn)" : "var(--success)" },
          { label: "Monto total", value: fmtMXN(totalPendiente), color: undefined },
          { label: "Días promedio", value: diasPromedio + "d", color: diasPromedio > 3 ? "var(--danger)" : undefined },
        ].map(k => (
          <div key={k.label} className="card" style={{ textAlign: "center", padding: "14px 12px" }}>
            <div style={{ fontSize: 22, fontWeight: 700, color: k.color }}>{k.value}</div>
            <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
          </div>
        ))}
      </div>

      {/* Modal rechazo */}
      {rechazandoId && (
        <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.6)", zIndex: 100,
          display: "grid", placeItems: "center" }}>
          <div className="card" style={{ width: 400, maxWidth: "90vw" }}>
            <div style={{ fontWeight: 700, fontSize: 16, marginBottom: 14 }}>Motivo de rechazo</div>
            <textarea className="input" rows={3} value={motivoRechazo}
              onChange={e => setMotivoRechazo(e.target.value)}
              placeholder="Explica brevemente el motivo…"
              style={{ resize: "vertical", marginBottom: 12 }} />
            <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
              <button className="btn ghost" onClick={() => { setRechazandoId(null); setMotivoRechazo("") }}>
                Cancelar
              </button>
              <button className="btn" style={{ background: "var(--danger)", border: "none", color: "#fff" }}
                onClick={() => rechazar(rechazandoId)} disabled={!!procesando}>
                {procesando ? "Procesando…" : "Rechazar"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Lista */}
      {loading ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>
          Cargando solicitudes…
        </div>
      ) : solicitudes.length === 0 ? (
        <div className="card" style={{ padding: 48, textAlign: "center" }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>✅</div>
          <div style={{ fontWeight: 600, fontSize: 16, marginBottom: 6 }}>Bandeja al día</div>
          <div style={{ color: "var(--text-3)", fontSize: 13 }}>No hay solicitudes pendientes de autorizar</div>
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {solicitudes.map(s => {
            const dias = Math.floor((Date.now() - s.fecha.getTime()) / 86400000)
            return (
              <div key={s.id} className="card" style={{ cursor: "pointer" }}
                onClick={() => router.push(`/solicitudes/${s.id}`)}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12 }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
                      <TipoBadge tipo={s.tipo} />
                      <span className="mono" style={{ fontSize: 11, color: "var(--text-3)" }}>{s.id}</span>
                      {dias > 2 && (
                        <span style={{ fontSize: 10, padding: "1px 7px", borderRadius: 10,
                          background: "var(--danger-soft)", color: "var(--danger)", fontWeight: 600 }}>
                          {dias}d
                        </span>
                      )}
                    </div>
                    <div style={{ fontWeight: 600, marginBottom: 2, overflow: "hidden",
                      textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {s.concepto}
                    </div>
                    <div style={{ fontSize: 12, color: "var(--text-3)" }}>{fmtFecha(s.fecha)}</div>
                  </div>
                  <div style={{ textAlign: "right", flexShrink: 0 }}>
                    <div style={{ fontSize: 18, fontWeight: 700, marginBottom: 8 }}>
                      {fmtMXN(s.monto)}
                    </div>
                    <div style={{ display: "flex", gap: 6 }} onClick={e => e.stopPropagation()}>
                      <button className="btn sm ghost"
                        style={{ color: "var(--danger)", borderColor: "var(--danger)" }}
                        disabled={procesando === s.id}
                        onClick={() => setRechazandoId(s.id)}>
                        Rechazar
                      </button>
                      <button className="btn sm primary"
                        disabled={procesando === s.id}
                        onClick={() => aprobar(s.id)}>
                        {procesando === s.id ? "…" : "Aprobar ✓"}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/page.tsx')
cat > 'src/app/(app)/tesoreria/page.tsx' << 'FILEEOF'
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

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/pagados/page.tsx')
cat > 'src/app/(app)/tesoreria/pagados/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"

export default function TesoreriaPagadosPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [busqueda, setBusqueda] = useState("")

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("id, tipo, concepto, monto, fecha, status, usuario_id")
      .in("status", ["liberado","comprobado","parcial"])
      .order("fecha", { ascending: false })
      .limit(200)
      .then(({ data }) => { setSolicitudes(data || []); setLoading(false) })
  }, [])

  const filtradas = solicitudes.filter(s =>
    !busqueda.trim() ||
    s.id.toLowerCase().includes(busqueda.toLowerCase()) ||
    s.concepto.toLowerCase().includes(busqueda.toLowerCase())
  )

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Pagados</h1>
          <div className="page-sub">Historial de solicitudes liberadas</div>
        </div>
      </div>
      <input className="input" placeholder="Buscar por folio o concepto…"
        value={busqueda} onChange={e => setBusqueda(e.target.value)}
        style={{ marginBottom: 14, maxWidth: 400 }} />
      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando…</div>
        ) : (
          <table className="t">
            <thead>
              <tr><th>Folio</th><th>Tipo</th><th>Concepto</th><th>Fecha</th><th className="num">Monto</th><th>Status</th></tr>
            </thead>
            <tbody>
              {filtradas.map((s: any) => (
                <tr key={s.id} style={{ cursor: "pointer" }}
                  onClick={() => router.push(`/solicitudes/${s.id}`)}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td><TipoBadge tipo={s.tipo} /></td>
                  <td style={{ maxWidth: 240, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {s.concepto}
                  </td>
                  <td className="muted" style={{ fontSize: 12 }}>{fmtFecha(s.fecha)}</td>
                  <td className="num">{fmtMXN(parseFloat(s.monto))}</td>
                  <td><StatusBadge status={s.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/deudores/page.tsx')
cat > 'src/app/(app)/tesoreria/deudores/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

export default function TesoreriaDeudoresPage() {
  const [deudores, setDeudores] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const sb = createClient()
    // Get all anticipos with pending balance
    sb.from("solicitudes")
      .select("usuario_id, saldo_pendiente, id, concepto, usuarios!usuario_id(nombre, iniciales)")
      .in("status", ["liberado","parcial"])
      .gt("saldo_pendiente", 0)
      .eq("tipo", "anticipo")
      .order("saldo_pendiente", { ascending: false })
      .then(({ data }) => {
        // Group by usuario
        const byUser: Record<string, any> = {}
        ;(data || []).forEach((s: any) => {
          const uid = s.usuario_id
          if (!byUser[uid]) byUser[uid] = {
            userId: uid, nombre: s.usuarios?.nombre || "—",
            iniciales: s.usuarios?.iniciales || "??",
            total: 0, solicitudes: [],
          }
          byUser[uid].total += parseFloat(s.saldo_pendiente) || 0
          byUser[uid].solicitudes.push({ id: s.id, concepto: s.concepto, saldo: parseFloat(s.saldo_pendiente) })
        })
        setDeudores(Object.values(byUser).sort((a, b) => b.total - a.total))
        setLoading(false)
      })
  }, [])

  const totalGeneral = deudores.reduce((a, d) => a + d.total, 0)

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Deudores</h1>
          <div className="page-sub">Empleados con saldo de anticipo pendiente</div>
        </div>
        {!loading && (
          <div style={{ textAlign: "right" }}>
            <div style={{ fontSize: 22, fontWeight: 700, color: "var(--warn)" }}>{fmtMXN(totalGeneral)}</div>
            <div style={{ fontSize: 11, color: "var(--text-3)" }}>Total pendiente</div>
          </div>
        )}
      </div>

      {loading ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando…</div>
      ) : deudores.length === 0 ? (
        <div className="card" style={{ padding: 48, textAlign: "center" }}>
          <div style={{ fontSize: 36, marginBottom: 12 }}>🎉</div>
          <div style={{ fontWeight: 600 }}>Sin deudores</div>
          <div style={{ color: "var(--text-3)", fontSize: 13, marginTop: 6 }}>Todos los anticipos están comprobados</div>
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {deudores.map(d => (
            <div key={d.userId} className="card">
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10 }}>
                <div style={{ width: 38, height: 38, borderRadius: "50%", background: "var(--danger-soft)",
                  color: "var(--danger)", display: "grid", placeItems: "center",
                  fontSize: 13, fontWeight: 700, flexShrink: 0 }}>
                  {d.iniciales}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 600, fontSize: 14 }}>{d.nombre}</div>
                  <div style={{ fontSize: 11, color: "var(--text-3)" }}>
                    {d.solicitudes.length} anticipo{d.solicitudes.length > 1 ? "s" : ""} abierto{d.solicitudes.length > 1 ? "s" : ""}
                  </div>
                </div>
                <div style={{ fontWeight: 700, fontSize: 18, color: "var(--danger)" }}>
                  {fmtMXN(d.total)}
                </div>
              </div>
              <div style={{ borderTop: "1px solid var(--border)", paddingTop: 8, display: "flex", flexDirection: "column", gap: 4 }}>
                {d.solicitudes.map((s: any) => (
                  <div key={s.id} style={{ display: "flex", justifyContent: "space-between", fontSize: 12 }}>
                    <span className="mono" style={{ color: "var(--text-3)" }}>{s.id}</span>
                    <span style={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", flex: 1, margin: "0 12px" }}>
                      {s.concepto}
                    </span>
                    <span style={{ fontWeight: 600, color: "var(--warn)" }}>{fmtMXN(s.saldo)}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/StatusBadge.tsx')
cat > 'src/components/ui/StatusBadge.tsx' << 'FILEEOF'
import type { SolicitudStatus } from "@/types"

const LABELS: Record<string, string> = {
  solicitado: "Solicitado", autorizado: "Autorizado", liberado: "Liberado",
  comprobado: "Comprobado", rechazado: "Rechazado", parcial: "Parcial",
}

export function StatusBadge({ status }: { status: SolicitudStatus }) {
  return <span className={`badge ${status}`}>{LABELS[status] ?? status}</span>
}

export function TipoBadge({ tipo }: { tipo: string }) {
  const map: Record<string, string> = { anticipo: "ANT", comprobacion: "CMP", reembolso: "REE" }
  return <span className="badge tipo">{map[tipo] ?? tipo}</span>
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/Stepper.tsx')
cat > 'src/components/ui/Stepper.tsx' << 'FILEEOF'
"use client"
import { fmtFecha } from "@/lib/format"
import type { SolicitudStatus } from "@/types"

const STEPS = [
  { key: "solicitado", label: "Solicitado" },
  { key: "autorizado", label: "Autorizado" },
  { key: "liberado",   label: "Liberado"   },
  { key: "comprobado", label: "Comprobado" },
]

const ORDER: Record<string, number> = {
  solicitado: 0, autorizado: 1, liberado: 2, comprobado: 3, parcial: 2,
}

export function Stepper({ status, dates }: { status: SolicitudStatus; dates?: Record<string, Date | null> }) {
  if (status === "rechazado") {
    return (
      <div className="stepper">
        <div className="step done"><div className="dot">1</div><div className="label">Solicitado</div></div>
        <div className="step rejected"><div className="dot">✕</div><div className="label">Rechazado</div></div>
      </div>
    )
  }
  const cur = ORDER[status] ?? 0
  return (
    <div className="stepper">
      {STEPS.map((s, i) => {
        const cls = i < cur ? "done" : i === cur ? "active" : ""
        return (
          <div key={s.key} className={`step ${cls}`}>
            <div className="dot">{i < cur ? "✓" : i + 1}</div>
            <div className="label">{s.label}</div>
            {dates?.[s.key] && <div className="meta">{fmtFecha(dates[s.key])}</div>}
          </div>
        )
      })}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/globals.css')
cat > 'src/app/globals.css' << 'FILEEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ── Design tokens (same as current app) ──────────────────────────────────── */
:root {
  --bg:          #0d0d0d;
  --surface:     #161616;
  --surface-2:   #1c1c1c;
  --border:      #2a2a2a;
  --text:        #f0f0f0;
  --text-2:      #b0b0b0;
  --text-3:      #606060;
  --accent:      #c5f24d;
  --accent-soft: rgba(197,242,77,.12);
  --success:     #4ade80;
  --success-soft:rgba(74,222,128,.12);
  --danger:      #e24b4a;
  --danger-soft: rgba(226,75,74,.12);
  --warn:        #f59e0b;
  --warn-soft:   rgba(245,158,11,.12);
  --r-sm:        6px;
  --r-md:        8px;
  --r-lg:        12px;
  --r-xl:        16px;
  --f-display:   "Geist", system-ui, sans-serif;
}

.light {
  --bg:       #f5f5f0;
  --surface:  #ffffff;
  --surface-2:#f0f0ec;
  --border:   #ddddd8;
  --text:     #1a1a1a;
  --text-2:   #444444;
  --text-3:   #999999;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--f-display);
  font-size: 14px;
  min-height: 100vh;
}

/* ── Shared component styles ─────────────────────────────────────────────── */
.btn {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 8px 14px; border-radius: var(--r-md);
  border: 1px solid var(--border); background: var(--surface);
  color: var(--text); font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all .15s;
}
.btn:hover { border-color: var(--text-3); }
.btn.primary { background: var(--accent); border-color: var(--accent); color: #111; }
.btn.primary:hover { opacity: .9; }
.btn.ghost { background: transparent; }
.btn.sm { padding: 5px 10px; font-size: 12px; }
.btn:disabled { opacity: .5; cursor: not-allowed; }

.card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-lg); padding: 16px;
}
.card-title { font-weight: 600; font-size: 13px; color: var(--text-2); letter-spacing: .05em; text-transform: uppercase; }

.input, .select {
  width: 100%; padding: 8px 10px;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-md); color: var(--text); font-size: 13px;
  outline: none; transition: border-color .15s;
}
.input:focus, .select:focus { border-color: var(--accent); }

.badge {
  display: inline-flex; align-items: center;
  padding: 2px 10px; border-radius: 20px;
  font-size: 11px; font-weight: 600;
}
.badge.solicitado { background: rgba(245,158,11,.15); color: var(--warn); }
.badge.autorizado { background: var(--accent-soft); color: var(--accent); }
.badge.liberado   { background: rgba(96,165,250,.15); color: #60a5fa; }
.badge.comprobado { background: var(--success-soft); color: var(--success); }
.badge.rechazado  { background: var(--danger-soft); color: var(--danger); }
.badge.parcial    { background: rgba(245,158,11,.15); color: var(--warn); }

.t { width: 100%; border-collapse: collapse; font-size: 13px; }
.t th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600;
        color: var(--text-3); border-bottom: 1px solid var(--border); white-space: nowrap; }
.t td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
.t tbody tr:hover { background: var(--surface-2); }
.t .num { text-align: right; font-variant-numeric: tabular-nums; font-family: monospace; }
.mono { font-family: monospace; }
.muted { color: var(--text-3); }
.spread { display: flex; align-items: center; justify-content: space-between; }
.row { display: flex; align-items: center; gap: 8px; }
.divider { height: 1px; background: var(--border); }

/* ── Sidebar layout ──────────────────────────────────────────────────────── */
.app-layout {
  display: grid;
  grid-template-columns: 220px 1fr;
  min-height: 100vh;
}
.sidebar {
  background: var(--surface); border-right: 1px solid var(--border);
  padding: 20px 12px; display: flex; flex-direction: column; gap: 2px;
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.nav-item {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 12px; border-radius: var(--r-md);
  color: var(--text-2); font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all .15s; text-decoration: none;
}
.nav-item:hover { background: var(--surface-2); color: var(--text); }
.nav-item.active { background: var(--accent-soft); color: var(--accent); }
.main-content { padding: 24px 32px; overflow-y: auto; }

/* ── Page header ─────────────────────────────────────────────────────────── */
.page-head { display: flex; align-items: flex-start; justify-content: space-between;
             margin-bottom: 20px; gap: 12px; flex-wrap: wrap; }
.page-title { font-size: 24px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }
.page-sub { font-size: 13px; color: var(--text-3); margin-top: 4px; }

/* ── Stepper ─────────────────────────────────────────────────────────────── */
.stepper { display: flex; gap: 0; width: 100%; }
.step { flex: 1; display: flex; flex-direction: column; align-items: center; position: relative; }
.step::before { content: ""; position: absolute; top: 12px; right: -50%;
               width: 100%; height: 2px; background: var(--border); z-index: 0; }
.step:last-child::before { display: none; }
.step.done::before { background: var(--success); }
.step.active::before { background: var(--border); }
.step .dot { width: 24px; height: 24px; border-radius: 50%; border: 2px solid var(--border);
             display: grid; placeItems: center; font-size: 11px; font-weight: 700;
             background: var(--bg); position: relative; z-index: 1; }
.step.done .dot { background: var(--success); border-color: var(--success); color: #000; }
.step.active .dot { background: var(--accent); border-color: var(--accent); color: #000; }
.step.rejected .dot { background: var(--danger); border-color: var(--danger); color: #fff; }
.step .label { font-size: 10px; color: var(--text-3); margin-top: 4px; }
.step.active .label, .step.done .label { color: var(--text); }
.step .meta { font-size: 9px; color: var(--text-3); margin-top: 2px; }
.table { width: 100%; border-collapse: collapse; font-size: 13px; }
.table th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600; color: var(--text-3); border-bottom: 1px solid var(--border); white-space: nowrap; }
.table td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
.table tbody tr:hover { background: var(--surface-2); }
.table .num, .table .right { text-align: right; }
.kpi-grid { display: grid; gap: 12; }
.kpi { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-lg); padding: 14px 16px; }
.kpi-label { font-size: 11px; color: var(--text-3); text-transform: uppercase; letter-spacing: .05em; }
.kpi-value { font-size: 22px; font-weight: 700; margin-top: 4px; font-variant-numeric: tabular-nums; }

FILEEOF

echo "✓ Phase 3 files updated"
git add . && git commit -m "feat: phase 3 - approval flows" && git push