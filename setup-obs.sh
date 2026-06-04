#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/solicitudes/reembolso/page.tsx')
cat > 'src/app/(app)/solicitudes/reembolso/page.tsx' << 'FILEEOF'
"use client"
import { useState, useRef, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import { notifyUsers } from "@/lib/notify"
import type { CfdItem } from "@/types"

const CUENTA_COMIDAS = "6122200001"

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
    const sinObs = itemsValidos.filter(it => it.cuenta === CUENTA_COMIDAS && !it.observaciones?.trim())
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
                            placeholder={it.cuenta===CUENTA_COMIDAS ? "Requerido: nombres y № comensales" : "Opcional"}
                            style={{
                              fontSize:11, padding:"5px 6px",
                              borderColor: it.cuenta===CUENTA_COMIDAS && !it.observaciones ? "var(--danger)" : "var(--border)",
                              background: it.cuenta===CUENTA_COMIDAS && !it.observaciones ? "var(--danger-soft)" : "var(--surface)",
                            }}/>
                          {it.cuenta===CUENTA_COMIDAS && !it.observaciones && (
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
    const sinCom = itemsValidos.filter(it => it.cuenta === "6122200001" && !(it as any).observaciones?.trim())
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
                        placeholder={it.cuenta === "6122200001" ? "Requerido: nombres y número de comensales" : "Opcional"}
                        style={{
                          fontSize:11, padding:"5px 6px",
                          borderColor: it.cuenta === "6122200001" && !(it as any).observaciones ? "var(--danger)" : "var(--border)",
                          background: it.cuenta === "6122200001" && !(it as any).observaciones ? "var(--danger-soft)" : "var(--surface)",
                        }}
                      />
                      {it.cuenta === "6122200001" && !(it as any).observaciones && (
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
      // Comprobaciones sin anticipo ref van a comprobado; todo lo demás a liberado
      const newStatus = (s.tipo === "comprobacion" && !s.anticipoRef) ? "comprobado" : "liberado"
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

FILEEOF

mkdir -p $(dirname 'src/lib/polizas.ts')
cat > 'src/lib/polizas.ts' << 'FILEEOF'
// Pólizas generation logic - extracted from ContadorPolizas
// This runs server-side or client-side with real DB data

import { fmtFecha, getBancosAccount } from "@/lib/format"
import type { Solicitud, CuentaContable, Usuario, Centro, PolizaLinea } from "@/types"

const PROVEEDOR_UNICO = "6000000"

export function generarPolizas(
  solicitudes: Solicitud[],
  usuarios: Usuario[],
  centros: Centro[],
  catalogo: CuentaContable[],
  filtros: { desde: Date; hasta: Date; centro: string }
): PolizaLinea[] {
  const { desde, hasta, centro } = filtros
  const findUser = (id: string) => usuarios.find(u => u.id === id)
  const findCentro = (id: string) => centros.find(c => c.id === id)
  const findCuenta = (cta: string) => catalogo.find(c => c.cuenta === cta)

  const filtered = solicitudes.filter(s => {
    if (s.tipo === "anticipo") {
      if (s.status !== "liberado") return false
    } else if (s.tipo === "comprobacion" || s.tipo === "reembolso") {
      if (s.status === "rechazado" || s.status === "solicitado") return false
    } else return false
    if (s.fecha < desde || s.fecha > hasta) return false
    if (centro !== "todos") {
      const u = findUser(s.usuario)
      if (!u || u.centro !== centro) return false
    }
    return true
  })

  const lineas: PolizaLinea[] = []
  let numPoliza = 1

  filtered.forEach(s => {
    const u = findUser(s.usuario)
    if (!u) return
    const c = findCentro(u.centro || "")
    const centroId = c ? c.id : u.centro || ""
    const fechaFmt = fmtFecha(s.fecha)
    const polRef = `POL-${String(numPoliza).padStart(4, "0")}`
    const base = { poliza: polRef, folio: s.id, fecha: fechaFmt, centro: centroId, area: c?.nombre || centroId }

    if (s.tipo === "anticipo") {
      const division = u.division || "4105"
      const cuentaBanco = getBancosAccount(division)
      const cuentaBancoNombre = findCuenta(cuentaBanco)?.nombre || `Bancos ${division}`
      lineas.push({ ...base, division, cuenta: u.id,
        nombreCuenta: `Deudor ${u.nombre} (${u.id})`,
        tipo: "C", debe: s.monto, haber: 0,
        concepto: s.concepto, proveedor: u.nombre, usuario: u.nombre, ref: s.id, _archivos: [] })
      lineas.push({ ...base, division, cuenta: cuentaBanco,
        nombreCuenta: cuentaBancoNombre,
        tipo: "A", debe: 0, haber: s.monto,
        concepto: `Dispersión SPEI · ${s.id}`, proveedor: u.nombre, usuario: u.nombre, ref: s.id, _archivos: [] })

    } else {
      // Comprobacion / Reembolso
      const esCierre = !!(s.esCierre || (s.concepto && s.concepto.includes("[CIERRE]")))
      const division = u.division || "4105"
      const cuentaBanco = getBancosAccount(division)
      const cuentaBancoNombre = findCuenta(cuentaBanco)?.nombre || `Bancos ${division}`

      if (esCierre) {
        // Cierre: Bancos (cargo) vs Deudor (abono)
        const archivos = (s.cfdi || []).map((cf, i) => ({
          nombre: `${s.id}_deposito_${i + 1}`,
          url: cf.archivoUrl || null, uuid: cf.uuid || null, total: cf.total || s.monto,
        }))
        lineas.push({ ...base, division, cuenta: cuentaBanco, nombreCuenta: cuentaBancoNombre,
          tipo: "C", debe: s.monto, haber: 0,
          concepto: `Reintegro de saldo · ${u.nombre}`, proveedor: u.nombre, usuario: u.nombre,
          ref: s.id, _archivos: archivos })
        lineas.push({ ...base, division, cuenta: u.id,
          nombreCuenta: `Deudor ${u.nombre}`,
          tipo: "A", debe: 0, haber: s.monto,
          concepto: `Cancelación deudor por reintegro · ${s.anticipoRef || s.id}`,
          proveedor: u.nombre, usuario: u.nombre, ref: s.id, _archivos: archivos })
      } else {
        // Normal: Gastos vs Proveedor Único
        const items = s.cfdi && s.cfdi.length > 0
          ? s.cfdi.map(cf => ({ cuenta: cf.cuenta, desc: cf.concepto || cf.emisor || "", monto: cf.total || 0,
              uuid: cf.uuid, emisor: cf.emisor, archivoUrl: cf.archivoUrl }))
          : (s.items || []).map(it => ({ cuenta: it.cuenta, desc: it.desc, monto: it.monto,
              uuid: undefined, emisor: undefined, archivoUrl: null }))

        const archivos = (s.cfdi || [])
          .filter(cf => cf.archivoUrl)
          .map((cf, i) => ({
            nombre: `${s.id}_${(cf.emisor || "cfdi").replace(/[^a-z0-9]/gi, "_").slice(0, 20)}_${i + 1}`,
            url: cf.archivoUrl || null, uuid: cf.uuid || null, emisor: cf.emisor || null, total: cf.total || 0,
          }))

        items.forEach(it => {
          if (it.monto <= 0) return
          const meta = findCuenta(it.cuenta) || { nombre: it.cuenta }
          lineas.push({ ...base, division, cuenta: it.cuenta, nombreCuenta: meta.nombre,
            tipo: "C", debe: it.monto, haber: 0,
            concepto: [it.desc || s.concepto, (it as any).observaciones].filter(Boolean).join(' — '), proveedor: u.nombre, usuario: u.nombre,
            ref: s.id, _archivos: archivos })
        })

        const totalItems = items.reduce((a, it) => a + it.monto, 0)
        if (totalItems > 0) {
          lineas.push({ ...base, division, cuenta: PROVEEDOR_UNICO, nombreCuenta: "Proveedor único",
            tipo: "A", debe: 0, haber: totalItems,
            concepto: s.concepto, proveedor: u.nombre, usuario: u.nombre,
            ref: s.id, _archivos: archivos })
        }
      }
    }
    numPoliza++
  })

  return lineas
}

// Group lineas by poliza reference
export function agruparPorPoliza(lineas: PolizaLinea[]) {
  const grupos: Record<string, PolizaLinea[]> = {}
  lineas.forEach(l => {
    if (!grupos[l.poliza]) grupos[l.poliza] = []
    grupos[l.poliza].push(l)
  })
  return Object.entries(grupos).map(([ref, movs]) => ({
    ref,
    folio: movs[0]?.folio,
    fecha: movs[0]?.fecha,
    debe: movs.reduce((a, l) => a + l.debe, 0),
    haber: movs.reduce((a, l) => a + l.haber, 0),
    movs,
  }))
}

FILEEOF

git add .
git commit -m "fix: reembolso status liberado, observaciones column, table scroll, comidas validation"
git push
echo "✓ Done!"
echo ""
echo "Ejecutar en Supabase: add-observaciones.sql"