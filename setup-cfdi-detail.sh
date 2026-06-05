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
                <th>UUID</th><th>Emisor</th><th>Cuenta / Nombre</th><th>Comentarios</th>
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
                  <td style={{ fontSize: 11 }}>
                    <div className="mono" style={{ color:"var(--text-3)" }}>{cf.cuenta}</div>
                    {cf.nombre_cuenta && <div style={{ fontSize:10, color:"var(--text-3)", marginTop:1 }}>{cf.nombre_cuenta}</div>}
                  </td>
                  <td style={{ fontSize: 11, color: cf.observaciones ? "var(--text-2)" : "var(--text-3)", maxWidth:180 }}>
                    {cf.observaciones || <span className="muted">—</span>}
                  </td>
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

mkdir -p $(dirname 'src/app/(app)/solicitudes/[id]/corregir/page.tsx')
cat > 'src/app/(app)/solicitudes/[id]/corregir/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef, useCallback } from "react"
import { useRouter, useParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import { isComidas } from "@/lib/cuentaComidas"
import { notifyUsers } from "@/lib/notify"
import type { CfdItem } from "@/types"

interface ItemConObs extends CfdItem { observaciones?: string }

export default function CorregirComprobacionPage() {
  const router  = useRouter()
  const { id }  = useParams<{ id: string }>()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [solicitud, setSolicitud]   = useState<any>(null)
  const [items,     setItems]       = useState<ItemConObs[]>([])
  const [enviando,  setEnviando]    = useState(false)
  const [toast,     setToast]       = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({msg,ok}); setTimeout(()=>setToast(null),4000) }

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("*,comprobantes_cfdi(*)")
      .eq("id", id).single()
      .then(({ data }) => {
        if (!data || data.status !== "devuelto") { router.push(`/solicitudes/${id}`); return }
        setSolicitud(data)
        setItems((data.comprobantes_cfdi || []).map((c: any) => ({
          uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
          subtotal: c.subtotal, iva: c.iva, total: c.total,
          cuenta: c.cuenta, confianza: c.confianza,
          archivoUrl: c.archivo_url, rfcEmisor: c.rfc_emisor,
          rfcReceptor: c.rfc_receptor, duplicado: false,
          observaciones: c.observaciones || "",
        } as ItemConObs)))
      })
  }, [id, router])

  const handleFiles = useCallback(async (files: FileList | null) => {
    if (!files) return
    for (const file of Array.from(files)) {
      if (!file.name.toLowerCase().endsWith(".xml")) continue
      const text = await file.text()
      const parsed = parseCFDIXml(text)
      if (!parsed) { showToast(`XML inválido: ${file.name}`, false); continue }
      setItems(prev => [...prev, { ...parsed, duplicado: false } as ItemConObs])
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [])

  const handleReenviar = async () => {
    const validos = items.filter(i => !i.duplicado)
    if (!validos.length) { showToast("⚠ Sin comprobantes válidos", false); return }

    const sinObs = validos.filter(it => isComidas(it.cuenta, catalogoGastos) && !it.observaciones?.trim())
    if (sinObs.length) { showToast("⚠ Indica comensales en los gastos de alimentos", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    const total = validos.reduce((a, i) => a + i.total, 0)

    // Delete existing comprobantes and reinsert
    await sb.from("comprobantes_cfdi").delete().eq("solicitud_id", id)
    await sb.from("comprobantes_cfdi").insert(validos.map(it => ({
      solicitud_id: id,
      uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      emisor: it.emisor, concepto: it.concepto,
      subtotal: it.subtotal, iva: it.iva, total: it.total,
      cuenta: it.cuenta, confianza: it.confianza,
      archivo_url: it.archivoUrl, rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
      observaciones: it.observaciones || null,
    })))

    // Reset to solicitado
    await sb.from("solicitudes")
      .update({ status: "solicitado", monto: total, motivo_rechazo: null })
      .eq("id", id)

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Comprobación corregida y reenviada · ${fmtMXN(total)}`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    const { data: perfil } = await sb.from("usuarios")
      .select("gerente_id, nombre").eq("id", user.id).single()
    if (perfil?.gerente_id) {
      await notifyUsers([perfil.gerente_id],
        "📎 Comprobación corregida para revisar",
        `${perfil.nombre} corrigió y reenvió la comprobación ${id}`,
        `/solicitudes/${id}`)
    }

    showToast("✓ Comprobación reenviada a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  if (!solicitud) return (
    <div style={{padding:60,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
  )

  const total = items.filter(i=>!i.duplicado).reduce((a,i)=>a+i.total,0)

  return (
    <div style={{ maxWidth:1000 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">↩️ Corregir comprobación</h1>
          <div className="page-sub">{id} · {solicitud.concepto}</div>
        </div>
      </div>

      {solicitud.motivo_rechazo && (
        <div style={{padding:"12px 16px",background:"rgba(251,191,36,.1)",
          border:"1px solid #fbbf24",borderRadius:10,marginBottom:16,fontSize:13}}>
          <strong>Motivo de devolución:</strong> {solicitud.motivo_rechazo}
        </div>
      )}

      {/* Add more comprobantes */}
      <div className="card" style={{marginBottom:16,border:"2px dashed var(--border)",
        textAlign:"center",padding:"20px",cursor:"pointer"}}
        onClick={()=>fileRef.current?.click()}>
        <div style={{fontSize:24,marginBottom:6}}>➕</div>
        <div style={{fontWeight:600,fontSize:13}}>Agregar o reemplazar XMLs</div>
        <div style={{fontSize:12,color:"var(--text-3)"}}>Haz clic o arrastra archivos XML</div>
        <input ref={fileRef} type="file" accept=".xml" multiple hidden
          onChange={e=>handleFiles(e.target.files)}/>
      </div>

      {/* Items table */}
      <div className="card" style={{marginBottom:16,padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:860}}>
          <thead>
            <tr>
              <th>Emisor</th><th>Concepto</th>
              <th style={{minWidth:200}}>Cuenta</th>
              <th style={{minWidth:200}}>Comentarios</th>
              <th className="num">Total</th><th style={{width:32}}></th>
            </tr>
          </thead>
          <tbody>
            {items.map((it,i)=>(
              <tr key={i}>
                <td style={{fontSize:12}}>{it.emisor}</td>
                <td style={{fontSize:12}}>{it.concepto}</td>
                <td>
                  <select className="select" value={it.cuenta}
                    onChange={e=>setItems(prev=>prev.map((x,j)=>j===i?{...x,cuenta:e.target.value}:x))}
                    style={{fontSize:11,padding:"5px 6px"}}>
                    {catalogoGastos.map(g=><option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                  </select>
                </td>
                <td>
                  <input className="input"
                    value={it.observaciones||""}
                    onChange={e=>setItems(prev=>prev.map((x,j)=>j===i?{...x,observaciones:e.target.value}:x))}
                    placeholder={isComidas(it.cuenta, catalogoGastos)?"Requerido: nombres y № comensales":"Opcional"}
                    style={{fontSize:11,padding:"5px 6px",
                      borderColor:isComidas(it.cuenta, catalogoGastos)&&!it.observaciones?"var(--danger)":"var(--border)"}}/>
                  {isComidas(it.cuenta, catalogoGastos)&&!it.observaciones&&(
                    <div style={{fontSize:10,color:"var(--danger)",marginTop:2}}>
                      ⚠ Favor de indicar número y nombre de los comensales
                    </div>
                  )}
                </td>
                <td className="num">{fmtMXN(it.total)}</td>
                <td>
                  <button onClick={()=>setItems(p=>p.filter((_,j)=>j!==i))}
                    style={{background:"none",border:"none",color:"var(--text-3)",cursor:"pointer",fontSize:16}}>×</button>
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={4} style={{textAlign:"right",fontWeight:600,padding:"10px 12px"}}>Total</td>
              <td className="num" style={{fontWeight:700,fontSize:16}}>{fmtMXN(total)}</td>
              <td/>
            </tr>
          </tfoot>
        </table>
      </div>

      {toast&&(
        <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
          background:toast.ok?"var(--success-soft)":"var(--danger-soft)",
          color:toast.ok?"var(--success)":"var(--danger)"}}>
          {toast.msg}
        </div>
      )}

      <div style={{display:"flex",justifyContent:"flex-end",gap:10}}>
        <button className="btn ghost" onClick={()=>router.push(`/solicitudes/${id}`)}>Cancelar</button>
        <button className="btn primary" onClick={handleReenviar}
          disabled={enviando||total<=0}
          style={{opacity:enviando||total<=0?0.5:1}}>
          {enviando?"Reenviando…":`Reenviar comprobación · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/comprobacion/page.tsx')
cat > 'src/app/(app)/solicitudes/comprobacion/page.tsx' << 'FILEEOF'
"use client"

import { notifyUsers } from "@/lib/notify"
import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { CompUploader } from "@/components/ui/CompUploader"
import { useCatalogos } from "@/hooks/useCatalogos"
import { isComidas } from "@/lib/cuentaComidas"
import type { CfdItem, Solicitud } from "@/types"
import { Suspense } from "react"

function NuevaComprobacionInner() {
  const router = useRouter()
  const params = useSearchParams()
  const anticipoId = params.get("anticipo")
  const { catalogoGastos } = useCatalogos()

  const [anticipo, setAnticipo] = useState<Solicitud | null>(null)
  const [anticipos, setAnticipos] = useState<Solicitud[]>([])
  const [anticipoSel, setAnticipoSel] = useState<Solicitud | null>(null)
  const [items, setItems] = useState<CfdItem[]>([])
  const [enviando, setEnviando] = useState(false)
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 3500) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      sb.from("solicitudes")
        .select("id, concepto, monto, status, saldo_pendiente, fecha, tipo")
        .eq("usuario_id", user.id)
        .eq("tipo", "anticipo")
        .in("status", ["liberado", "parcial"])
        .gt("saldo_pendiente", 0)
        .order("fecha", { ascending: false })
        .then(({ data }) => {
          const mapped = (data || []).map(s => ({
            id: s.id, tipo: s.tipo as any, concepto: s.concepto, usuario: user.id,
            monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha), status: s.status as any,
            saldoPendiente: parseFloat(s.saldo_pendiente) || 0, cfdi: [],
          }))
          setAnticipos(mapped)
          if (anticipoId) {
            const found = mapped.find(a => a.id === anticipoId)
            if (found) setAnticipoSel(found)
          }
        })
    })
  }, [anticipoId])

  const handleAdd = (newItems: CfdItem[]) => {
    setItems(prev => [...prev, ...newItems])
  }

  const handleEnviar = async () => {
    if (!anticipoSel)              { showToast("⚠ Selecciona el anticipo a comprobar", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Agrega al menos un comprobante XML válido", false); return }
    if (total <= 0)                { showToast("⚠ El total es cero", false); return }
    const sinCom = itemsValidos.filter(it => isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones?.trim())
    if (sinCom.length > 0) { showToast("⚠ Indica número y nombre de comensales en gastos de alimentos", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const nuevoSaldo = Math.max(0, anticipoSel.saldoPendiente - total)
    const nuevoStatus = nuevoSaldo <= 0 ? "comprobado" : "parcial"
    const id = "CMP-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "comprobacion", concepto: `Comprobación de ${anticipoSel.id}`,
      usuario_id: user.id, monto: total, status: "solicitado",
      anticipo_ref: anticipoSel.id, saldo_pendiente: 0,
      comprobantes: itemsValidos.length, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    // Save CFDIs
    await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
      solicitud_id: id, uuid: it.uuid || `SIN-UUID-${Date.now()}`,
      emisor: it.emisor, concepto: it.concepto,
      subtotal: it.subtotal, iva: it.iva, total: it.total,
      cuenta: it.cuenta, confianza: it.confianza, archivo_url: it.archivoUrl,
      rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
    })))

    // Update anticipo saldo
    await sb.from("solicitudes")
      .update({ saldo_pendiente: nuevoSaldo, status: nuevoStatus, comprobantes: (anticipoSel as any).comprobantes + 1 })
      .eq("id", anticipoSel.id)

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Comprobación ${fmtMXN(total)} del anticipo ${anticipoSel.id}`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    const { data: pf } = await sb.from("usuarios").select("gerente_id, nombre").eq("id", user.id).single()
    if (pf?.gerente_id) {
      await notifyUsers([pf.gerente_id], "📎 Nueva comprobación por autorizar",
        `${pf.nombre} comprobó ${fmtMXN(total)} del anticipo ${anticipoSel.id}`, `/solicitudes/${id}`)
    }

    showToast("✓ Comprobación enviada a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  return (
    <div style={{ maxWidth: 900 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nueva comprobación</h1>
          <div className="page-sub">Sube los CFDIs para comprobar tu anticipo</div>
        </div>
      </div>

      {/* Anticipo selector */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 12 }}>Anticipo a comprobar</div>
        {anticipos.length === 0 ? (
          <div style={{ color: "var(--text-3)", fontSize: 13 }}>
            No tienes anticipos liberados pendientes de comprobar.
          </div>
        ) : anticipoSel ? (
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ fontWeight: 600 }}>{anticipoSel.id}</div>
              <div style={{ fontSize: 13, color: "var(--text-2)" }}>{anticipoSel.concepto}</div>
              <div style={{ fontSize: 12, color: "var(--warn)", marginTop: 2 }}>
                Saldo pendiente: {fmtMXN(anticipoSel.saldoPendiente)}
              </div>
            </div>
            <button className="btn ghost" onClick={() => setAnticipoSel(null)}>Cambiar</button>
          </div>
        ) : (
          <div style={{ display: "grid", gap: 8 }}>
            {anticipos.map(a => (
              <div key={a.id} className="card" style={{ cursor: "pointer", margin: 0 }}
                onClick={() => setAnticipoSel(a)}>
                <div className="spread">
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 13 }}>{a.id}</div>
                    <div style={{ fontSize: 12, color: "var(--text-2)" }}>{a.concepto}</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(a.saldoPendiente)}</div>
                    <div style={{ fontSize: 11, color: "var(--text-3)" }}>{fmtFecha(a.fecha)}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Uploader */}
      <div style={{ marginBottom: 16 }}>
        <CompUploader solicitudId={anticipoSel?.id} catalogoGastos={catalogoGastos} onAdd={handleAdd} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom: 16, padding: 0, overflow: "auto" }}>
          <table className="t" style={{ minWidth: 960 }}>
            <thead>
              <tr>
                <th style={{ minWidth: 100 }}>UUID</th>
                <th style={{ minWidth: 120 }}>Emisor</th>
                <th style={{ minWidth: 140 }}>Concepto</th>
                <th style={{ minWidth: 220 }}>Cuenta</th>
                <th style={{ minWidth: 220 }}>Comentarios</th>
                <th className="num" style={{ minWidth: 90 }}>Total</th>
                <th style={{ width: 32 }}></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => (
                <tr key={i} style={{ ...(it.duplicado ? { textDecoration: "line-through", opacity: 0.5 } : {}) }}>
                  <td className="mono" style={{ fontSize: 10, maxWidth: 120 }}>
                    <span title={it.uuid} onClick={() => navigator.clipboard.writeText(it.uuid)}
                      style={{ cursor: "pointer" }}>
                      {it.uuid ? it.uuid.slice(0, 18) + "…" : "—"}
                    </span>
                  </td>
                  <td style={{ fontSize: 12 }}>{it.emisor}</td>
                  <td style={{ fontSize: 11, maxWidth: 160, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {it.concepto}
                    {it.duplicado && <span style={{ color: "var(--danger)", fontSize: 10, marginLeft: 6 }}>⚠ {it.motivoDup}</span>}
                  </td>
                  <td>
                    {it.duplicado ? (
                      <span style={{ fontSize: 11 }}>{catalogoGastos.find(g => g.cuenta === it.cuenta)?.nombre}</span>
                    ) : (
                      <select className="select" value={it.cuenta}
                        onChange={e => setItems(prev => prev.map((x, j) => j === i ? { ...x, cuenta: e.target.value } : x))}
                        style={{ fontSize: 11, padding: "5px 6px",
                          borderColor: it.cuenta === "6121200001" ? "var(--warn)" : "var(--border)",
                          background: it.cuenta === "6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                        {catalogoGastos.map(g => <option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                      </select>
                    )}
                  </td>
                  <td>
                    <div>
                      <input
                        className="input"
                        value={(it as any).observaciones || ""}
                        onChange={e => setItems(prev => prev.map((x,j) => j===i ? {...x, observaciones: e.target.value} : x))}
                        placeholder={isComidas(it.cuenta, catalogoGastos) ? "Requerido: nombres y número de comensales" : "Opcional"}
                        style={{
                          fontSize:11, padding:"5px 6px",
                          borderColor: isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones ? "var(--danger)" : "var(--border)",
                          background: isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones ? "var(--danger-soft)" : "var(--surface)",
                        }}
                      />
                      {isComidas(it.cuenta, catalogoGastos) && !(it as any).observaciones && (
                        <div style={{fontSize:10,color:"var(--danger)",marginTop:2}}>
                          ⚠ Favor de indicar número y nombre de los comensales
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="num">{fmtMXN(it.total)}</td>
                  <td>
                    <button onClick={() => setItems(prev => prev.filter((_, j) => j !== i))}
                      style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 16 }}>×</button>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ textAlign: "right", fontWeight: 600, padding: "10px 12px" }}>Total a comprobar</td>
                <td className="num" style={{ fontWeight: 700, fontSize: 16 }}>{fmtMXN(total)}</td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div style={{ padding: "10px 14px", borderRadius: 8, marginBottom: 12, fontSize: 13,
          background: toast.ok ? "var(--success-soft)" : "var(--danger-soft)",
          color: toast.ok ? "var(--success)" : "var(--danger)" }}>
          {toast.msg}
        </div>
      )}

      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <button className="btn ghost" onClick={() => router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || !anticipoSel || total <= 0}
          style={{ opacity: enviando || !anticipoSel || total <= 0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : "Enviar comprobación →"}
        </button>
      </div>
    </div>
  )
}

export default function NuevaComprobacionPage() {
  return (
    <Suspense fallback={<div style={{ padding: 40, color: "var(--text-3)" }}>Cargando…</div>}>
      <NuevaComprobacionInner />
    </Suspense>
  )
}


FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/reembolso/page.tsx')
cat > 'src/app/(app)/solicitudes/reembolso/page.tsx' << 'FILEEOF'
"use client"
import { useState, useRef, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import { isComidas } from "@/lib/cuentaComidas"
import { notifyUsers } from "@/lib/notify"
import type { CfdItem } from "@/types"

interface ItemConObs extends CfdItem { observaciones?: string }

export default function NuevoReembolsoPage() {
  const router = useRouter()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [concepto,  setConcepto]  = useState("")
  const [items,     setItems]     = useState<ItemConObs[]>([])
  const [enviando,  setEnviando]  = useState(false)
  const [toast,     setToast]     = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 4000) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)
  const totalDups = items.filter(i => i.duplicado).reduce((a, i) => a + (i.total || 0), 0)

  const checkDuplicado = useCallback(async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    if (items.some(i => i.uuid === uuid)) return "Ya en la lista"
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id, solicitudes!inner(status)")
      .eq("uuid", uuid)
      .not("solicitudes.status", "eq", "rechazado")
      .limit(1)
    return data && data.length > 0 ? "Ya comprobado en otra solicitud" : null
  }, [items])

  const handleFiles = useCallback(async (files: FileList | null) => {
    if (!files) return
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    for (const file of Array.from(files)) {
      const isXml = file.name.toLowerCase().endsWith(".xml")
      const isPdf = file.name.toLowerCase().endsWith(".pdf")
      const isImg = file.type.startsWith("image/")
      if (!isXml && !isPdf && !isImg) continue

      let archivoUrl: string | null = null
      const ext = file.name.split(".").pop()
      const path = `${user.id}/${Date.now()}.${ext}`
      const { data: uploadData } = await sb.storage.from("comprobantes").upload(path, file, { upsert: true })
      if (uploadData) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }

      if (isXml) {
        const text = await file.text()
        const parsed = parseCFDIXml(text)
        if (!parsed) { showToast(`XML inválido: ${file.name}`, false); continue }
        parsed.archivoUrl = archivoUrl
        const motivoDup = await checkDuplicado(parsed.uuid)
        setItems(prev => [...prev, { ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined }])
      } else {
        setItems(prev => [...prev, {
          uuid: "", emisor: file.name, concepto: file.name,
          subtotal: 0, iva: 0, total: 0, cuenta: "6121200001",
          confianza: 0.5, archivoUrl, duplicado: false,
        } as ItemConObs])
      }
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [checkDuplicado])

  const handleEnviar = async () => {
    if (!concepto.trim())          { showToast("⚠ Agrega un concepto", false); return }
    if (items.length === 0)        { showToast("⚠ Agrega al menos un comprobante", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Todos son duplicados", false); return }
    if (total <= 0)                { showToast("⚠ Total cero — no se puede enviar", false); return }

    // Validate comidas observaciones
    const sinObs = itemsValidos.filter(it => isComidas(it.cuenta, catalogoGastos) && !it.observaciones?.trim())
    if (sinObs.length > 0) {
      showToast("⚠ Indica número y nombre de comensales en los gastos de alimentos", false); return
    }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const { data: perfil } = await sb.from("usuarios").select("centro_id, gerente_id, nombre").eq("id", user.id).single()
    const id = "REM-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "reembolso", concepto, usuario_id: user.id, monto: total,
      status: "solicitado", saldo_pendiente: 0, comprobantes: itemsValidos.length,
      centro_id: perfil?.centro_id ?? null, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    if (itemsValidos.length > 0) {
      await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
        solicitud_id: id,
        uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        emisor: it.emisor, concepto: it.concepto,
        subtotal: it.subtotal, iva: it.iva, total: it.total,
        cuenta: it.cuenta, confianza: it.confianza,
        archivo_url: it.archivoUrl,
        rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
        observaciones: it.observaciones || null,
            nombre_cuenta: catalogoGastos.find(g => g.cuenta === it.cuenta)?.nombre || null,
      })))
    }

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Reembolso ${fmtMXN(total)} · ${itemsValidos.length} comprobante(s)`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    if (perfil?.gerente_id) {
      await notifyUsers([perfil.gerente_id], "🧾 Nuevo reembolso por autorizar",
        `${perfil.nombre} solicitó ${fmtMXN(total)}`, `/solicitudes/${id}`)
    }

    showToast("✓ Reembolso enviado a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  return (
    <div style={{ maxWidth: 1000 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nuevo reembolso</h1>
          <div className="page-sub">Gastos pagados de tu bolsa sin anticipo previo</div>
        </div>
      </div>

      {/* Concepto */}
      <div className="card" style={{ marginBottom: 16 }}>
        <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:6, display:"block" }}>
          Concepto / descripción general *
        </label>
        <input className="input" value={concepto} onChange={e=>setConcepto(e.target.value)}
          placeholder="Ej: Gastos de viaje a Guadalajara — 28 mayo 2026" />
      </div>

      {/* Drop zone */}
      <div className="card" style={{ marginBottom:16, border:"2px dashed var(--border)",
           textAlign:"center", padding:"28px 20px", cursor:"pointer" }}
        onClick={() => fileRef.current?.click()}
        onDragOver={e=>{ e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e=>{ (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e=>{ e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; handleFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize:28, marginBottom:8 }}>📂</div>
        <div style={{ fontWeight:600, marginBottom:4 }}>Arrastra o haz clic para subir</div>
        <div style={{ fontSize:12, color:"var(--text-3)" }}>XML (CFDI), PDF o imágenes de ticket</div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e=>handleFiles(e.target.files)} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom:16, padding:0, overflow:"auto" }}>
          <table className="t" style={{ minWidth:900 }}>
            <thead>
              <tr>
                <th style={{ minWidth:120 }}>Emisor</th>
                <th style={{ minWidth:150 }}>Concepto</th>
                <th style={{ minWidth:220 }}>Cuenta contable</th>
                <th style={{ minWidth:220 }}>Comentarios</th>
                <th className="num" style={{ minWidth:100 }}>Total</th>
                <th style={{ width:32 }}></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => {
                const meta = catalogoGastos.find(g => g.cuenta === it.cuenta)
                return (
                  <tr key={i} style={{ ...(it.duplicado ? { textDecoration:"line-through", opacity:0.5 } : {}) }}>
                    <td style={{ fontSize:12 }}>
                      {it.emisor}
                      {it.duplicado && <span style={{ fontSize:10, color:"var(--danger)", marginLeft:6 }}>⚠ {it.motivoDup}</span>}
                    </td>
                    <td style={{ fontSize:12 }}>{it.concepto}</td>
                    <td>
                      {it.duplicado
                        ? <span style={{ fontSize:11 }}>{meta?.nombre}</span>
                        : <select className="select" value={it.cuenta}
                            onChange={e => setItems(prev => prev.map((x,j) => j===i ? {...x, cuenta:e.target.value} : x))}
                            style={{ fontSize:11, padding:"5px 6px",
                              borderColor: it.cuenta==="6121200001" ? "var(--warn)" : "var(--border)",
                              background: it.cuenta==="6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                            {catalogoGastos.map(g=><option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                          </select>}
                    </td>
                    <td>
                      {!it.duplicado && (
                        <div>
                          <input className="input"
                            value={it.observaciones || ""}
                            onChange={e => setItems(prev => prev.map((x,j) => j===i ? {...x, observaciones:e.target.value} : x))}
                            placeholder={isComidas(it.cuenta, catalogoGastos) ? "Requerido: nombres y № comensales" : "Opcional"}
                            style={{
                              fontSize:11, padding:"5px 6px",
                              borderColor: isComidas(it.cuenta, catalogoGastos) && !it.observaciones ? "var(--danger)" : "var(--border)",
                              background: isComidas(it.cuenta, catalogoGastos) && !it.observaciones ? "var(--danger-soft)" : "var(--surface)",
                            }}/>
                          {isComidas(it.cuenta, catalogoGastos) && !it.observaciones && (
                            <div style={{ fontSize:10, color:"var(--danger)", marginTop:2 }}>
                              ⚠ Favor de indicar número y nombre de los comensales
                            </div>
                          )}
                        </div>
                      )}
                    </td>
                    <td className="num">{fmtMXN(it.total)}</td>
                    <td>
                      <button onClick={() => setItems(prev => prev.filter((_,j)=>j!==i))}
                        style={{ background:"none", border:"none", color:"var(--text-3)", cursor:"pointer", fontSize:16 }}>×</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ textAlign:"right", fontWeight:600, padding:"10px 12px" }}>
                  Total a reembolsar
                  {totalDups>0 && <span style={{ fontSize:10, color:"var(--text-3)", fontWeight:400, marginLeft:6 }}>(excl. dup: {fmtMXN(totalDups)})</span>}
                </td>
                <td className="num" style={{ fontWeight:700, fontSize:16 }}>{fmtMXN(total)}</td>
                <td/>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {toast && (
        <div style={{ padding:"10px 14px", borderRadius:8, marginBottom:12, fontSize:13,
          background:toast.ok ? "var(--success-soft)" : "var(--danger-soft)",
          color:toast.ok ? "var(--success)" : "var(--danger)" }}>
          {toast.msg}
        </div>
      )}

      <div style={{ display:"flex", justifyContent:"flex-end", gap:10 }}>
        <button className="btn ghost" onClick={()=>router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || total<=0 || itemsValidos.length===0}
          style={{ opacity:enviando||total<=0||itemsValidos.length===0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : `Enviar reembolso · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}


FILEEOF

mkdir -p $(dirname 'src/lib/cuentaComidas.ts')
cat > 'src/lib/cuentaComidas.ts' << 'FILEEOF'
// Returns true if the given account should require "comensales" comment
// Matches by account NAME (flexible) rather than hardcoded code
// This handles catalogs where the comidas account may have a different code

const COMIDAS_PATTERNS = [
  /alimento/i,
  /comida/i,
  /restaurante/i,
  /cenar/i,
  /comer/i,
  /consumo/i,
  /food/i,
  /viático.*comida/i,
  /gastos.*representaci/i,
]

export function isComidas(cuenta: string, cuentaCatalogo?: Array<{ cuenta: string; nombre: string }>): boolean {
  if (cuentaCatalogo) {
    const entry = cuentaCatalogo.find(c => c.cuenta === cuenta)
    if (entry) return COMIDAS_PATTERNS.some(p => p.test(entry.nombre))
  }
  // Fallback: known codes
  return ["6122200001","6122200002","612220"].some(c => cuenta.startsWith(c))
}

FILEEOF

git add .
git commit -m "fix: comprobante detail shows account name+comments, comidas validation by name not hardcoded code"
git push
echo "✓ Done!"
echo ""
echo "Ejecutar en Supabase: add-nombre-cuenta.sql"