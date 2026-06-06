#!/bin/bash
set -e

mkdir -p $(dirname 'src/lib/normalizaCuenta.ts')
cat > 'src/lib/normalizaCuenta.ts' << 'FILEEOF'
// Maps a guessed account code to the closest available one in the catalog

const TIPO_CATALOG_PATTERNS: Record<string, RegExp> = {
  alimentos:       /(alimento|comida|comidas|restaurante|consumo|viático|representaci)/i,
  hospedaje:       /(hotel|hospedaje|alojamiento|nacional|internacional)/i,
  peaje:           /(peaje|caseta|autopista|telepeaje)/i,
  estacionamiento: /(estacionamiento|parking)/i,
  gasolina:        /(gasolina|combustible|diésel|diesel|gas)/i,
  taxi:            /(taxi|transporte local|uber|didi|terrestre)/i,
  aereo:           /(aéreo|vuelo|boleto|avión|aéreo|pasaje.*aéreo|pasaje.*nac|pasaje.*int)/i,
}

// Known SAT/internal code → semantic type
const KNOWN_CODES: Record<string, string> = {
  "6122200001": "alimentos",
  "6122100001": "hospedaje",
  "6122700001": "peaje",
  "6122700002": "estacionamiento",
  "6122600001": "gasolina",
  "6122900002": "taxi",
  "6122400001": "aereo",
}

export function normalizaCuenta(
  guessedCode: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): string {
  if (!catalog?.length) return guessedCode

  // 1. Exact match → use it
  if (catalog.some(c => c.cuenta === guessedCode)) return guessedCode

  // 2. Find semantic type from guessed code
  const tipo = KNOWN_CODES[guessedCode]
  if (tipo) {
    const pattern = TIPO_CATALOG_PATTERNS[tipo]
    // Search catalog entries for name match
    const match = catalog.find(c => pattern.test(c.nombre))
    if (match) {
      console.log(`[normalizaCuenta] ${guessedCode} → ${match.cuenta} (${match.nombre})`)
      return match.cuenta
    }
  }

  // 3. No match found: return first in catalog (better than wrong default)
  // but only if it's not a "No Deducibles" catch-all
  const notNd = catalog.find(c => !/(no deducible|nd)/i.test(c.nombre))
  return (notNd ?? catalog[0])?.cuenta ?? guessedCode
}

// Async version: fetches catalog from Supabase if local catalog is empty
export async function normalizaCuentaAsync(
  guessedCode: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): Promise<string> {
  if (catalog?.length) return normalizaCuenta(guessedCode, catalog)

  // Catalog not loaded yet — fetch directly
  try {
    const { createClient } = await import("@/lib/supabase/client")
    const sb = createClient()
    const { data } = await sb
      .from("cuentas_contables")
      .select("cuenta,nombre")
      .eq("activo", true)
      .order("cuenta")
    if (data?.length) return normalizaCuenta(guessedCode, data)
  } catch {}
  return guessedCode
}

FILEEOF

mkdir -p $(dirname 'src/lib/cfdi.ts')
cat > 'src/lib/cfdi.ts' << 'FILEEOF'
// CFDI XML parsing utilities - extracted from index.html

import type { CfdItem } from "@/types"

function attr(el: Element | null, ...names: string[]): string {
  if (!el) return ""
  for (const n of names) {
    const v = el.getAttribute(n) || el.getAttribute(n.toLowerCase())
    if (v) return v
  }
  return ""
}

function qn(parent: Document | Element, localName: string): Element | null {
  const el = parent.querySelector(localName)
  if (el) return el
  const all = parent.getElementsByTagName("*")
  for (let i = 0; i < all.length; i++) {
    if (all[i].localName === localName) return all[i]
  }
  return null
}

// SAT ClaveProdServ prefixes → contable account type
const SAT_CLAVESERV_MAP: [string, string][] = [
  ["9010", "alimentos"],   // 90101501 = consumo alimentos, 90101800 = servicios comida
  ["5015", "hospedaje"],   // 50151500 = hotel/alojamiento
  ["7810", "aereo"],       // 78101500 = transporte aéreo
  ["7812", "taxi"],        // 78121500 = transporte terrestre
  ["7813", "taxi"],        // 78131500 = taxi local
  ["1517", "gasolina"],    // 15171500 = combustibles
  ["7211", "peaje"],       // 72111500 = peaje autopistas
]

const CUENTA_PATTERNS: [RegExp, string, number][] = [
  [/(peaje|caseta|autopista|telepeaje|iave|pase)/i,             "6122700001", 0.9],
  [/(estacionamiento|parking|parquímetro|pensión)/i,            "6122700002", 0.9],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i,        "6122600001", 0.9],
  [/(taxi|uber|didi|cabify|transporte local)/i,                 "6122900002", 0.85],
  [/(hotel|hospedaje|alojamiento)/i,                            "6122100001", 0.85],
  [/(restaurante|alimentos|comida|viático|consumo)/i,           "6122200001", 0.85],
  [/(aéreo|vuelo|boleto.*avión|pasaje.*aéreo)/i,                "6122400001", 0.85],
]

// Map SAT service code prefix to concept type
function getTypeFromClave(clave: string): string | null {
  for (const [prefix, type] of SAT_CLAVESERV_MAP) {
    if (clave.startsWith(prefix)) return type
  }
  return null
}

function guessCuenta(text: string, claveProdServ?: string): [string, number] {
  // First try SAT ClaveProdServ (most reliable)
  if (claveProdServ) {
    const type = getTypeFromClave(claveProdServ)
    if (type) {
      const byType: Record<string, string> = {
        alimentos: "6122200001", hospedaje: "6122100001",
        aereo: "6122400001",    taxi: "6122900002",
        gasolina: "6122600001", peaje: "6122700001",
      }
      if (byType[type]) return [byType[type], 0.95]
    }
  }
  // Then try text patterns
  for (const [regex, cuenta, conf] of CUENTA_PATTERNS) {
    if (regex.test(text)) return [cuenta, conf]
  }
  return ["6121200001", 0.5] // No Deducibles as fallback
}

export function parseCFDIXml(xmlText: string): CfdItem | null {
  try {
    const doc = new DOMParser().parseFromString(xmlText, "application/xml")
    if (doc.querySelector("parsererror")) return null

    const comp = qn(doc, "Comprobante") || doc.documentElement
    const total = parseFloat(attr(comp, "Total", "total") || "0")
    const subtotal = parseFloat(attr(comp, "SubTotal", "Subtotal", "subtotal") || "0")

    const emisorEl = qn(doc, "Emisor")
    const emisor = attr(emisorEl, "Nombre", "nombre") || attr(emisorEl, "nombre") || ""
    const rfcEmisor = attr(emisorEl, "Rfc", "rfc") || ""

    const receptorEl = qn(doc, "Receptor")
    const rfcReceptor = attr(receptorEl, "Rfc", "rfc") || ""

    let iva = 0
    const traslados = doc.querySelectorAll("Traslado,traslado")
    traslados.forEach((t) => {
      const imp = attr(t, "Impuesto", "impuesto")
      if (imp === "002" || imp.toUpperCase() === "IVA") {
        iva += parseFloat(attr(t, "Importe", "importe") || "0") || 0
      }
    })
    if (!iva && total && subtotal) iva = Math.round((total - subtotal) * 100) / 100

    const tfd = qn(doc, "TimbreFiscalDigital")
    const uuid = (attr(tfd, "UUID", "uuid") || "").toUpperCase().trim()

    const conceptoEl = qn(doc, "Concepto")
    const conceptoStr = attr(conceptoEl, "Descripcion", "descripcion") || ""
    const claveProdServ = attr(conceptoEl, "ClaveProdServ", "claveProdServ") || ""

    const matchText = (emisor + " " + conceptoStr + " " + claveProdServ + " " + rfcEmisor).toLowerCase()
    const [cuenta, confianza] = guessCuenta(matchText, claveProdServ)

    return {
      uuid,
      uuidFull: uuid,
      emisor,
      concepto: conceptoStr || emisor,
      subtotal,
      iva,
      total,
      cuenta,
      confianza,
      archivoUrl: null,
      rfcEmisor,
      rfcReceptor,
    } as CfdItem & { uuidFull: string }
  } catch {
    return null
  }
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
import { normalizaCuentaAsync } from "@/lib/normalizaCuenta"
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
import { normalizaCuentaAsync } from "@/lib/normalizaCuenta"
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
        // Normalize parsed account code to one that exists in the catalog
        parsed.cuenta = await normalizaCuentaAsync(parsed.cuenta, catalogoGastos)
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

git add .
git commit -m "fix: async catalog normalization, better comidas pattern matching 6122900005"
git push
echo "✓ Done — subir el XML de nuevo para verificar que mapea a Comidas"