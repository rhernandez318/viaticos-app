"use client"

import { useState, useRef, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import type { CfdItem } from "@/types"

export default function NuevoReembolsoPage() {
  const router = useRouter()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [concepto,  setConcepto]  = useState("")
  const [items,     setItems]     = useState<CfdItem[]>([])
  const [enviando,  setEnviando]  = useState(false)
  const [toast,     setToast]     = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 3500) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)
  const totalDups = items.filter(i => i.duplicado).reduce((a, i) => a + (i.total || 0), 0)

  const checkDuplicado = useCallback(async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    // Check in current list
    if (items.some(i => (i.uuid) === uuid)) return "Ya en la lista"
    // Check in DB
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

      // Upload to storage
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
        // PDF / image
        const id = `file-${Date.now()}-${Math.random().toString(36).slice(2)}`
        setItems(prev => [...prev, {
          id, uuid: "", emisor: file.name, concepto: file.name,
          subtotal: 0, iva: 0, total: 0, cuenta: "6121200001",
          confianza: 0.5, archivoUrl, duplicado: false,
        } as unknown as CfdItem])
      }
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [checkDuplicado])

  const handleEnviar = async () => {
    if (!concepto.trim())      { showToast("⚠ Agrega un concepto", false); return }
    if (items.length === 0)    { showToast("⚠ Agrega al menos un comprobante", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Todos son duplicados", false); return }
    if (total <= 0)            { showToast("⚠ Total cero — no se puede enviar", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const { data: perfil } = await sb.from("usuarios").select("centro_id").eq("id", user.id).single()
    const id = "REM-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "reembolso", concepto, usuario_id: user.id, monto: total,
      status: "solicitado", saldo_pendiente: 0, comprobantes: itemsValidos.length,
      centro_id: perfil?.centro_id ?? null, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    // Save CFDIs
    if (itemsValidos.length > 0) {
      await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
        solicitud_id: id,
        uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        emisor: it.emisor, concepto: it.concepto,
        subtotal: it.subtotal, iva: it.iva, total: it.total,
        cuenta: it.cuenta, confianza: it.confianza,
        archivo_url: it.archivoUrl,
        rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
      })))
    }

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Reembolso ${fmtMXN(total)} · ${itemsValidos.length} comprobante(s)`,
      ts: new Date().toISOString(),
    })

    showToast("✓ Reembolso enviado a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  const cuentaGastos = catalogoGastos

  return (
    <div style={{ maxWidth: 860 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nuevo reembolso</h1>
          <div className="page-sub">Gastos pagados de tu bolsa sin anticipo previo</div>
        </div>
      </div>

      {/* Concepto */}
      <div className="card" style={{ marginBottom: 16 }}>
        <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 6, display: "block" }}>
          Concepto / descripción general *
        </label>
        <input className="input" value={concepto} onChange={e => setConcepto(e.target.value)}
          placeholder="Ej: Gastos de viaje a Guadalajara — 28 mayo 2026" />
      </div>

      {/* Drop zone */}
      <div className="card" style={{ marginBottom: 16, border: "2px dashed var(--border)", textAlign: "center",
           padding: "28px 20px", cursor: "pointer" }}
        onClick={() => fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; handleFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize: 28, marginBottom: 8 }}>📂</div>
        <div style={{ fontWeight: 600, marginBottom: 4 }}>Arrastra o haz clic para subir</div>
        <div style={{ fontSize: 12, color: "var(--text-3)" }}>XML (CFDI), PDF o imágenes de ticket</div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => handleFiles(e.target.files)} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom: 16, padding: 0, overflow: "hidden" }}>
          <table className="t">
            <thead>
              <tr>
                <th>Emisor</th><th>Concepto</th><th style={{ minWidth: 220 }}>Cuenta contable</th>
                <th className="num">Total</th><th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => {
                const meta = cuentaGastos.find(g => g.cuenta === it.cuenta)
                return (
                  <tr key={i} style={{ ...(it.duplicado ? { textDecoration: "line-through", opacity: 0.5 } : {}) }}>
                    <td style={{ fontSize: 12 }}>
                      {it.emisor}
                      {it.duplicado && <span style={{ fontSize: 10, color: "var(--danger)", marginLeft: 6 }}>⚠ {it.motivoDup}</span>}
                    </td>
                    <td style={{ fontSize: 12, maxWidth: 180, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {it.concepto}
                    </td>
                    <td>
                      {it.duplicado
                        ? <span style={{ fontSize: 11 }}>{meta?.nombre}</span>
                        : <select className="select" value={it.cuenta}
                            onChange={e => setItems(prev => prev.map((x, j) => j === i ? { ...x, cuenta: e.target.value } : x))}
                            style={{ fontSize: 11, padding: "5px 6px",
                              borderColor: it.cuenta === "6121200001" ? "var(--warn)" : "var(--border)",
                              background: it.cuenta === "6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                            {cuentaGastos.map(g => <option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                          </select>}
                    </td>
                    <td className="num">{fmtMXN(it.total)}</td>
                    <td>
                      <button onClick={() => setItems(prev => prev.filter((_, j) => j !== i))}
                        style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 16 }}>×</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={3} style={{ textAlign: "right", fontWeight: 600, padding: "10px 12px" }}>
                  Total a reembolsar{totalDups > 0 && <span style={{ fontSize: 10, color: "var(--text-3)", fontWeight: 400, marginLeft: 6 }}>(excl. dup: {fmtMXN(totalDups)})</span>}
                </td>
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
          color: toast.ok ? "var(--success)" : "var(--danger)",
          border: `1px solid ${toast.ok ? "var(--success)" : "var(--danger)"}` }}>
          {toast.msg}
        </div>
      )}

      {/* Actions */}
      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <button className="btn ghost" onClick={() => router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || total <= 0 || itemsValidos.length === 0}
          style={{ opacity: enviando || total <= 0 || itemsValidos.length === 0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : `Enviar reembolso · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}

