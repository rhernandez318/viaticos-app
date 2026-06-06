#!/bin/bash
set -e

mkdir -p $(dirname 'src/lib/cfdi.ts')
cat > 'src/lib/cfdi.ts' << 'FILEEOF'
// CFDI XML parsing utilities

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

// SAT ClaveProdServ prefix → semantic type
const SAT_CLAVESERV_TIPOS: [string, string][] = [
  ["9010", "alimentos"],   // 90101501 consumo alimentos, restaurante
  ["9011", "alimentos"],   // 90111500 servicios de comida
  ["5015", "hospedaje"],   // 50151500 hotel/alojamiento
  ["7810", "aereo"],       // 78101500 transporte aéreo
  ["7812", "taxi"],        // 78121500 transporte terrestre
  ["7813", "taxi"],        // 78131500 taxi local
  ["1517", "gasolina"],    // 15171500 combustibles
  ["7211", "peaje"],       // 72111500 peajes/autopistas
  ["7216", "estacionamiento"], // estacionamiento
]

// Text patterns → semantic type (for description/emisor matching)
const TEXTO_TIPOS: [RegExp, string][] = [
  [/(peaje|caseta|autopista|telepeaje|iave|pase)/i,         "peaje"],
  [/(estacionamiento|parking|parquímetro)/i,                "estacionamiento"],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i,    "gasolina"],
  [/(taxi|uber|didi|cabify|transporte local)/i,             "taxi"],
  [/(hotel|hospedaje|alojamiento)/i,                        "hospedaje"],
  [/(restaurante|alimentos|comida|consumo|viático)/i,       "alimentos"],
  [/(aéreo|vuelo|boleto.*avión|pasaje.*aéreo)/i,            "aereo"],
]

// Determine semantic type from SAT code and/or text
export function getTipoGasto(claveProdServ: string, texto: string): string | null {
  // SAT code takes priority (most reliable)
  for (const [prefix, tipo] of SAT_CLAVESERV_TIPOS) {
    if (claveProdServ.startsWith(prefix)) return tipo
  }
  // Fall back to text matching
  for (const [regex, tipo] of TEXTO_TIPOS) {
    if (regex.test(texto)) return tipo
  }
  return null
}

export function parseCFDIXml(xmlText: string): CfdItem | null {
  try {
    const doc = new DOMParser().parseFromString(xmlText, "application/xml")
    if (doc.querySelector("parsererror")) return null

    const comp = qn(doc, "Comprobante") || doc.documentElement
    const total       = parseFloat(attr(comp, "Total", "total") || "0")
    const fechaEmision = attr(comp, "Fecha", "fecha") || ""
    const subtotal = parseFloat(attr(comp, "SubTotal", "Subtotal", "subtotal") || "0")

    const emisorEl  = qn(doc, "Emisor")
    const emisor    = attr(emisorEl, "Nombre", "nombre") || ""
    const rfcEmisor = attr(emisorEl, "Rfc", "rfc") || ""

    const receptorEl  = qn(doc, "Receptor")
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

    const tfd  = qn(doc, "TimbreFiscalDigital")
    const uuid = (attr(tfd, "UUID", "uuid") || "").toUpperCase().trim()

    const conceptoEl   = qn(doc, "Concepto")
    const conceptoStr  = attr(conceptoEl, "Descripcion", "descripcion") || ""
    const claveProdServ = attr(conceptoEl, "ClaveProdServ", "claveProdServ") || ""

    // Determine semantic tipo — stored as __tipo__ for normalizaCuenta to resolve
    const matchText = (emisor + " " + conceptoStr).toLowerCase()
    const tipo = getTipoGasto(claveProdServ, matchText)

    // Use __tipo__ marker so normalizaCuenta can resolve it against the real catalog
    // This avoids returning a hardcoded code that may not exist in the client's catalog
    const cuentaHint = tipo ? `__${tipo}__` : "__nd__"

    return {
      uuid,
      uuidFull: uuid,
      emisor,
      concepto: conceptoStr || emisor,
      subtotal,
      iva,
      total,
      cuenta: cuentaHint,  // resolved by normalizaCuenta in the component
      confianza: tipo ? 0.9 : 0.4,
      archivoUrl: null,
      rfcEmisor,
      rfcReceptor,
      fechaEmision,
    } as CfdItem & { uuidFull: string }
  } catch {
    return null
  }
}

FILEEOF

mkdir -p $(dirname 'src/lib/ajustes.ts')
cat > 'src/lib/ajustes.ts' << 'FILEEOF'
import { createClient } from "@/lib/supabase/client"

const CACHE = new Map<string, { value: string; ts: number }>()
const TTL_MS = 60_000  // 1 minute cache

export async function getAjuste(clave: string, defaultValue: string): Promise<string> {
  const cached = CACHE.get(clave)
  if (cached && Date.now() - cached.ts < TTL_MS) return cached.value

  try {
    const sb = createClient()
    const { data } = await sb.from("ajustes").select("valor").eq("clave", clave).single()
    const value = data?.valor ?? defaultValue
    CACHE.set(clave, { value, ts: Date.now() })
    return value
  } catch {
    return defaultValue
  }
}

export async function getDiasMaxFactura(): Promise<number> {
  const v = await getAjuste("dias_max_factura", "30")
  const n = parseInt(v, 10)
  return Number.isFinite(n) && n > 0 ? n : 30
}

export function clearAjustesCache() { CACHE.clear() }

FILEEOF

mkdir -p $(dirname 'src/types/index.ts')
cat > 'src/types/index.ts' << 'FILEEOF'
// ─── Core domain types ────────────────────────────────────────────────────────

export type Rol = "usuario" | "gerente" | "tesoreria" | "contador" | "admin"

export type SolicitudStatus = "solicitado" | "autorizado" | "validado" | "liberado" | "comprobado" | "rechazado" | "parcial" | "devuelto" | "devuelto"

export type SolicitudTipo = "anticipo" | "reembolso" | "comprobacion"

export interface Usuario {
  id: string
  nombre: string
  correo: string
  rol: Rol
  iniciales: string
  centro: string | null
  gerente: string | null
  division: "4105" | "4106" | string
  clabe: string | null
  banco: string | null
  suplanteId: string | null
  suplantaDesde: string | null
  suplantaHasta: string | null
}

export interface Centro {
  id: string
  nombre: string
  depto: string
  division: string
}

export interface CuentaContable {
  cuenta: string
  nombre: string
  grupo: string
  activo: boolean
}

export interface CfdItem {
  fechaEmision?: string  // ISO date from CFDI
  id?: string
  uuid: string
  emisor: string
  concepto: string
  subtotal: number
  iva: number
  total: number
  cuenta: string
  confianza: number
  archivoUrl: string | null
  archivoPdfUrl?: string | null
  archivoXmlUrl?: string | null
  rfcEmisor?: string | null
  rfcReceptor?: string | null
  satEstado?: string | null
  duplicado?: boolean
  motivoDup?: string
  ocrLeido?: boolean
  ocrPendiente?: boolean
}

export interface Solicitud {
  id: string
  tipo: SolicitudTipo
  concepto: string
  usuario: string
  monto: number
  fecha: Date
  status: SolicitudStatus
  saldoPendiente: number
  division?: string
  anticipoRef?: string | null
  motivoRechazo?: string | null
  notas?: string | null
  esCierre?: boolean
  comprobantes?: number
  centroId?: string | null
  cfdi?: CfdItem[]
  items?: Array<{ cuenta: string; desc: string; monto: number }>
}

export interface BitacoraEntry {
  id: string
  solicitudId: string
  accion: string
  usuarioId: string
  detalle?: string
  ts: string
}

export interface PolizaLinea {
  poliza: string
  folio: string
  fecha: string
  centro: string
  area: string
  division: string
  cuenta: string
  nombreCuenta: string
  tipo: "C" | "A"  // Cargo / Abono
  debe: number
  haber: number
  concepto: string
  proveedor: string
  usuario: string
  ref: string
  _archivos?: Array<{ nombre: string; url: string | null; uuid: string | null; emisor?: string | null; total?: number }>
}


FILEEOF

mkdir -p $(dirname 'src/components/ui/CompUploader.tsx')
cat > 'src/components/ui/CompUploader.tsx' << 'FILEEOF'
"use client"
import { useRef, useCallback, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { parseCFDIXml } from "@/lib/cfdi"
import { normalizaCuentaAsync } from "@/lib/normalizaCuenta"
import { getDiasMaxFactura } from "@/lib/ajustes"
import type { CfdItem } from "@/types"

const CUENTA_PATTERNS: [RegExp, string][] = [
  [/(peaje|caseta|autopista|telepeaje|iave)/i,          "__peaje__"],
  [/(estacionamiento|parking|parquímetro)/i,            "__estacionamiento__"],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i,"__gasolina__"],
  [/(taxi|uber|didi|cabify|transporte)/i,               "__taxi__"],
  [/(hotel|hospedaje|alojamiento)/i,                    "__hospedaje__"],
  [/(restaurante|alimentos|comida|cenar|comer)/i,       "__alimentos__"],
  [/(aéreo|vuelo|boleto|avión)/i,                       "__aereo__"],
]

function guessCuentaFromText(text: string): string {
  for (const [re, cuenta] of CUENTA_PATTERNS) {
    if (re.test(text)) return cuenta
  }
  return "__nd__"
}

function parseTotalFromOCR(text: string): number {
  // Look for total patterns like "Total: $1,234.56" or "TOTAL 1234.56"
  const patterns = [
    /total\s*[:$]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /importe\s*[:$]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /\$\s*([\d,]+\.\d{2})\s*$/m,
  ]
  for (const p of patterns) {
    const m = text.match(p)
    if (m) {
      const val = parseFloat(m[1].replace(/,/g, ""))
      if (val > 0 && val < 1000000) return val
    }
  }
  // Last number that looks like a price
  const nums = [...text.matchAll(/\$?\s*([\d,]+\.\d{2})/g)]
    .map(m => parseFloat(m[1].replace(/,/g,"")))
    .filter(v => v > 0 && v < 1000000)
  return nums.length ? Math.max(...nums) : 0
}

let tesseractLoaded = false

async function loadTesseract(): Promise<void> {
  if (tesseractLoaded || (window as any).Tesseract) { tesseractLoaded = true; return }
  await new Promise<void>((resolve, reject) => {
    const s = document.createElement("script")
    s.src = "https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js"
    s.onload = () => { tesseractLoaded = true; resolve() }
    s.onerror = reject
    document.head.appendChild(s)
  })
}

async function runOCR(file: File): Promise<{ text: string; total: number; cuenta: string }> {
  await loadTesseract()
  const Tesseract = (window as any).Tesseract
  if (!Tesseract) throw new Error("Tesseract not available")

  const url = URL.createObjectURL(file)
  const { data: { text } } = await Tesseract.recognize(url, "spa", { logger: () => {} })
  URL.revokeObjectURL(url)

  const total  = parseTotalFromOCR(text)
  const cuenta = guessCuentaFromText(text)
  return { text, total, cuenta }
}

interface Props {
  solicitudId?: string
  catalogoGastos: Array<{ cuenta: string; nombre: string }>
  onAdd: (items: CfdItem[]) => void
}

export function CompUploader({ solicitudId, catalogoGastos, onAdd }: Props) {
  const [uploading, setUploading] = useState(false)
  const [ocrProgress, setOcrProgress] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  const checkDuplicate = async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id")
      .eq("uuid", uuid)
      .limit(1)
    return data && data.length > 0 ? "Ya comprobado" : null
  }

  const processFiles = useCallback(async (files: FileList | null) => {
    if (!files || !files.length) return
    setUploading(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { setUploading(false); return }

    const newItems: CfdItem[] = []

    for (const file of Array.from(files)) {
      const isXml = file.name.toLowerCase().endsWith(".xml")
      const isPdf = file.name.toLowerCase().endsWith(".pdf")
      const isImg = file.type.startsWith("image/")
      if (!isXml && !isPdf && !isImg) continue

      // Upload file to Storage
      let archivoUrl: string | null = null
      const ext = file.name.split(".").pop()
      const path = `${solicitudId || "tmp"}/${Date.now()}.${ext}`
      const { data: up } = await sb.storage.from("comprobantes").upload(path, file, { upsert: true })
      if (up) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }

      if (isXml) {
        const text = await file.text()
        const parsed = parseCFDIXml(text)
        if (!parsed) continue
        parsed.archivoUrl = archivoUrl
        // Normalize tipo marker (__alimentos__) to real catalog code
        parsed.cuenta = await normalizaCuentaAsync(parsed.cuenta, catalogoGastos)
        const motivoDup = await checkDuplicate(parsed.uuid)

        // Validate factura age — vencida si > diasMax días
        let vencida = false
        let motivoVencida: string | undefined
        if (parsed.fechaEmision) {
          const diasMax = await getDiasMaxFactura()
          const fEmi = new Date(parsed.fechaEmision)
          const diff = Math.floor((Date.now() - fEmi.getTime()) / 86400000)
          if (diff > diasMax) {
            vencida = true
            motivoVencida = `Factura de hace ${diff} días (máx ${diasMax})`
          }
        }

        newItems.push({
          ...parsed,
          duplicado: !!motivoDup || vencida,
          motivoDup: motivoDup || motivoVencida || undefined,
          ...(vencida ? { vencida: true, motivoVencida } as any : {}),
        })

      } else if (isImg) {
        // Run OCR on images (tickets, receipts)
        setOcrProgress(`Leyendo ticket: ${file.name}…`)
        try {
          const { text, total, cuenta } = await runOCR(file)
          const iva = total > 0 ? Math.round(total * 16 / 116 * 100) / 100 : 0
          const subtotal = Math.round((total - iva) * 100) / 100
          const cuentaNorm = await normalizaCuentaAsync(cuenta, catalogoGastos)
          newItems.push({
            uuid: `OCR-${Date.now()}`,
            emisor: file.name.replace(/\.[^.]+$/, ""),
            concepto: text.slice(0, 60).replace(/\n/g, " ").trim() || "Ticket sin factura",
            subtotal, iva, total,
            cuenta: cuentaNorm, confianza: total > 0 ? 0.7 : 0.3,
            archivoUrl, duplicado: false,
            ocrLeido: true,
          } as unknown as CfdItem)
          setOcrProgress(null)
        } catch (e) {
          setOcrProgress(null)
          // Fallback: add without OCR
          newItems.push({
            uuid: `IMG-${Date.now()}`,
            emisor: file.name, concepto: "Imagen sin factura",
            subtotal: 0, iva: 0, total: 0,
            cuenta: "__nd__", confianza: 0.3,
            archivoUrl, duplicado: false,
          } as unknown as CfdItem)
        }

      } else {
        // PDF without OCR
        newItems.push({
          uuid: `PDF-${Date.now()}`,
          emisor: file.name, concepto: "PDF adjunto",
          subtotal: 0, iva: 0, total: 0,
          cuenta: "__nd__", confianza: 0.3,
          archivoUrl, duplicado: false,
        } as unknown as CfdItem)
      }
    }

    if (newItems.length > 0) onAdd(newItems)
    if (fileRef.current) fileRef.current.value = ""
    setUploading(false)
    setOcrProgress(null)
  }, [solicitudId, onAdd])

  return (
    <div>
      <div className="card"
        style={{ border:"2px dashed var(--border)", textAlign:"center", padding:"24px 20px",
          cursor: uploading ? "default" : "pointer" }}
        onClick={() => !uploading && fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; processFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize:24, marginBottom:6 }}>{uploading ? "⏳" : "📂"}</div>
        <div style={{ fontWeight:600, marginBottom:3, fontSize:13 }}>
          {ocrProgress ? ocrProgress : uploading ? "Procesando…" : "Arrastra o clic para subir"}
        </div>
        <div style={{ fontSize:11.5, color:"var(--text-3)" }}>
          XML (CFDI), PDF o imagen — tickets con OCR automático
        </div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => processFiles(e.target.files)} />
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
                    {it.duplicado && (
                      <span style={{
                        color: (it as any).vencida ? "#fbbf24" : "var(--danger)",
                        fontSize: 10, marginLeft: 6, fontWeight: 600,
                      }}>
                        {(it as any).vencida ? "⏰" : "⚠"} {it.motivoDup}
                      </span>
                    )}
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
import { getDiasMaxFactura } from "@/lib/ajustes"
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
        parsed.cuenta = await normalizaCuentaAsync(parsed.cuenta, catalogoGastos)
        const motivoDup = await checkDuplicado(parsed.uuid)

        let vencida = false; let motivoVencida: string | undefined
        if (parsed.fechaEmision) {
          const diasMax = await getDiasMaxFactura()
          const fEmi = new Date(parsed.fechaEmision)
          const diff = Math.floor((Date.now() - fEmi.getTime()) / 86400000)
          if (diff > diasMax) {
            vencida = true; motivoVencida = `Factura de hace ${diff} días (máx ${diasMax})`
          }
        }
        setItems(prev => [...prev, {
          ...parsed,
          duplicado: !!motivoDup || vencida,
          motivoDup: motivoDup || motivoVencida || undefined,
          ...(vencida ? { vencida: true } as any : {}),
        } as ItemConObs])
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
                      {it.duplicado && (
                        <span style={{
                          fontSize:10, fontWeight:600, marginLeft:6,
                          color: (it as any).vencida ? "#fbbf24" : "var(--danger)",
                        }}>
                          {(it as any).vencida ? "⏰" : "⚠"} {it.motivoDup}
                        </span>
                      )}
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

mkdir -p $(dirname 'src/app/(app)/admin/ajustes/page.tsx')
cat > 'src/app/(app)/admin/ajustes/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { clearAjustesCache } from "@/lib/ajustes"

interface Ajuste { clave: string; valor: string; descripcion?: string }

export default function AjustesPage() {
  const [ajustes,  setAjustes]  = useState<Record<string, Ajuste>>({})
  const [loading,  setLoading]  = useState(true)
  const [saving,   setSaving]   = useState(false)
  const [toast,    setToast]    = useState<string | null>(null)

  const load = async () => {
    const sb = createClient()
    const { data } = await sb.from("ajustes").select("*").order("clave")
    const map: Record<string,Ajuste> = {}
    ;(data || []).forEach((a: any) => { map[a.clave] = a })
    setAjustes(map)
    setLoading(false)
  }
  useEffect(()=>{ load() },[])

  const guardar = async (clave: string) => {
    setSaving(true)
    const sb = createClient()
    const a = ajustes[clave]
    await sb.from("ajustes").upsert({
      clave, valor: a.valor, descripcion: a.descripcion,
      updated_at: new Date().toISOString(),
    })
    clearAjustesCache()
    setSaving(false)
    setToast(`✓ ${clave} actualizado`)
    setTimeout(()=>setToast(null),3000)
  }

  const update = (clave: string, valor: string) => {
    setAjustes(prev => ({...prev, [clave]: { ...prev[clave], valor }}))
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Ajustes del sistema</h1>
          <div className="page-sub">Configuración global de reglas de negocio</div>
        </div>
      </div>

      {toast && (
        <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
          background:"var(--success-soft)",color:"var(--success)"}}>{toast}</div>
      )}

      {loading ? (
        <div className="card" style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
      ) : (
        <div style={{display:"grid",gap:14,maxWidth:600}}>
          {Object.values(ajustes).map(a => (
            <div key={a.clave} className="card">
              <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:14}}>
                <div style={{flex:1,minWidth:0}}>
                  <div style={{fontWeight:600,fontSize:14,marginBottom:4}}>{a.clave}</div>
                  {a.descripcion && (
                    <div style={{fontSize:12,color:"var(--text-3)",marginBottom:10,lineHeight:1.5}}>
                      {a.descripcion}
                    </div>
                  )}
                  <input className="input" type="text" value={a.valor}
                    onChange={e => update(a.clave, e.target.value)}
                    style={{maxWidth:200}}/>
                </div>
                <button className="btn primary" disabled={saving}
                  onClick={()=>guardar(a.clave)}>
                  Guardar
                </button>
              </div>
            </div>
          ))}
          {Object.values(ajustes).length === 0 && (
            <div className="card" style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>
              Sin ajustes configurados. Ejecuta create-ajustes.sql en Supabase.
            </div>
          )}
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/layout/AppShell.tsx')
cat > 'src/components/layout/AppShell.tsx' << 'FILEEOF'
"use client"

import { usePathname } from "next/navigation"
import Link from "next/link"
import Image from "next/image"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"
import { ThemePanel } from "@/components/ui/ThemePanel"
import { NotificationBell } from "@/components/ui/NotificationBell"
import { PushNotifications } from "@/components/ui/PushNotifications"
import { useState } from "react"

interface NavItem { id: string; label: string; icon: string; href: string }

const NAV_BY_ROL: Record<string, NavItem[]> = {
  usuario: [
    { id:"dashboard",   label:"Inicio",             icon:"🏠", href:"/dashboard" },
    { id:"anticipo",    label:"Solicitar anticipo",  icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",   label:"Reembolso",           icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"solicitudes", label:"Mis solicitudes",     icon:"📋", href:"/solicitudes" },
    { id:"perfil",      label:"Mi perfil",           icon:"⚙️", href:"/perfil" },
  ],
  gerente: [
    { id:"bandeja",      label:"Por aprobar",        icon:"✅", href:"/gerente" },
    { id:"equipo",       label:"Mi equipo",           icon:"👥", href:"/gerente/equipo" },
    { id:"anticipo",     label:"Anticipo",            icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",    label:"Reembolso",           icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"comprobacion", label:"Comprobaciones",      icon:"📎", href:"/solicitudes/comprobacion" },
    { id:"solicitudes",  label:"Mis solicitudes",     icon:"📋", href:"/solicitudes" },
    { id:"reportes",     label:"Reportes",            icon:"📊", href:"/gerente/reportes" },
    { id:"perfil",       label:"Mi perfil",           icon:"⚙️", href:"/perfil" },
  ],
  tesoreria: [
    { id:"workflow",  label:"Workflow",         icon:"🗂", href:"/dashboard" },
    { id:"todas",     label:"Todas las sol.",   icon:"📂", href:"/solicitudes/todas" },
    { id:"liberar",   label:"Liberar pagos",    icon:"💵", href:"/tesoreria" },
    { id:"pagados",  label:"Pagados",        icon:"✅", href:"/tesoreria/pagados" },
    { id:"deudores", label:"Deudores",       icon:"⚑",  href:"/tesoreria/deudores" },
    { id:"reportes", label:"Reportes",       icon:"📊", href:"/tesoreria/reportes" },
    { id:"perfil",   label:"Mi perfil",      icon:"⚙️", href:"/perfil" },
  ],
  contador: [
    { id:"workflow",         label:"Workflow",             icon:"🗂", href:"/dashboard" },
    { id:"todas",            label:"Todas las sol.",      icon:"📂", href:"/solicitudes/todas" },
    { id:"polizas",          label:"Pólizas contables",   icon:"📒", href:"/contador/polizas" },
    { id:"trazabilidad",     label:"Trazabilidad",       icon:"🔍", href:"/contador/trazabilidad" },
    { id:"validacion-sat",   label:"Validación SAT",     icon:"🛡", href:"/contador/validacion-sat" },
    { id:"conciliacion-sat", label:"Conciliación SAT",   icon:"📊", href:"/contador/conciliacion-sat" },
    { id:"reportes",         label:"Reportes",           icon:"📊", href:"/contador/reportes" },
    { id:"catalogo",         label:"Catálogo",           icon:"📋", href:"/contador/catalogo" },
    { id:"perfil",           label:"Mi perfil",          icon:"⚙️", href:"/perfil" },
  ],
  admin: [
    { id:"dashboard",    label:"Inicio",           icon:"🏠", href:"/dashboard" },
    { id:"bandeja",      label:"Por aprobar",        icon:"✅", href:"/gerente" },
    { id:"validar",      label:"Validar (Admin)",    icon:"🔐", href:"/admin/validar" },
    { id:"liberar",      label:"Liberar pagos",      icon:"💵", href:"/tesoreria" },
    { id:"anticipo",     label:"Anticipo",          icon:"💵", href:"/solicitudes/anticipo" },
    { id:"reembolso",    label:"Reembolso",         icon:"🧾", href:"/solicitudes/reembolso" },
    { id:"comprobacion", label:"Comprobaciones",    icon:"📎", href:"/solicitudes/comprobacion" },
    { id:"solicitudes",  label:"Mis solicitudes",   icon:"📋", href:"/solicitudes" },
    { id:"todas",         label:"Todas las sol.",    icon:"📂", href:"/solicitudes/todas" },
    { id:"usuarios",     label:"Usuarios",          icon:"👥", href:"/admin/usuarios" },
    { id:"centros",      label:"Centros",           icon:"🏢", href:"/admin/centros" },
    { id:"catalogo",     label:"Catálogo",           icon:"📋", href:"/admin/catalogo" },
    { id:"limites",      label:"Límites de gasto",   icon:"🚦", href:"/admin/limites" },
    { id:"reportes",     label:"Reportes",          icon:"📊", href:"/admin/reportes" },
    { id:"polizas",      label:"Pólizas",           icon:"📒", href:"/contador/polizas" },
    { id:"perfil",       label:"Mi perfil",         icon:"⚙️", href:"/perfil" },
  ],
}

export default function AppShell({ user, children }: { user: any; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const navItems = NAV_BY_ROL[user.rol] || []
  const [showUserMenu, setShowUserMenu] = useState(false)

  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href)

  const handleLogout = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  return (
    <div className="app-layout">
      {/* ── Sidebar (desktop) ──────────────────────────────── */}
      <aside className="sidebar">
        <div style={{ padding:"8px 12px 16px", display:"flex", alignItems:"center", gap:10 }}>
          <Image src="/logo.png" alt="Grupo Zapata" width={36} height={36}
            style={{ borderRadius:8, objectFit:"cover" }} />
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ fontSize:13, fontWeight:700, letterSpacing:"-0.02em" }}>Grupo Zapata</div>
            <div style={{ fontSize:10, color:"var(--text-3)" }}>Viáticos</div>
          </div>
          <div style={{ display:"flex", gap:4, alignItems:"center" }}>
            <NotificationBell userId={user.id}/>
            <ThemePanel/>
          </div>
        </div>

        <nav style={{ flex:1, display:"flex", flexDirection:"column", gap:1 }}>
          {navItems.map(item => (
            <Link key={item.id} href={item.href}
              className={`nav-item ${isActive(item.href) ? "active" : ""}`}>
              <span style={{ fontSize:15, width:20, textAlign:"center" }}>{item.icon}</span>
              {item.label}
            </Link>
          ))}
        </nav>

        <div style={{ borderTop:"1px solid var(--border)", paddingTop:12, marginTop:8 }}>
          <div style={{ display:"flex", alignItems:"center", gap:10, padding:"6px 12px" }}>
            <div style={{ width:30, height:30, borderRadius:"50%", background:"var(--accent-soft)",
              color:"var(--accent)", display:"grid", placeItems:"center", fontSize:12, fontWeight:700 }}>
              {user.iniciales}
            </div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontSize:12, fontWeight:500, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>
                {user.nombre}
              </div>
              <div style={{ fontSize:10, color:"var(--text-3)", textTransform:"capitalize" }}>{user.rol}</div>
            </div>
          </div>
          <button className="btn ghost" onClick={handleLogout}
            style={{ width:"100%", justifyContent:"center", fontSize:12, marginTop:4, gap:6 }}>
            🚪 Cerrar sesión
          </button>
        </div>
      </aside>

      {/* ── Push notifications (registers FCM + shows toasts) */}
      <PushNotifications userId={user.id}/>

      {/* ── Mobile bottom nav ──────────────────────────────── */}
      <nav className="mobile-nav">
        {navItems.slice(0, 4).map(item => (
          <Link key={item.id} href={item.href}
            className={`mobile-nav-item ${isActive(item.href) ? "active" : ""}`}>
            <span className="icon">{item.icon}</span>
            <span className="label">{item.label.split(" ")[0]}</span>
          </Link>
        ))}
        {/* User menu button (mobile) */}
        <button className={`mobile-nav-item ${showUserMenu ? "active" : ""}`}
          onClick={() => setShowUserMenu(!showUserMenu)}>
          <span className="icon">👤</span>
          <span className="label">Cuenta</span>
        </button>
      </nav>

      {/* ── Mobile user menu ───────────────────────────────── */}
      {showUserMenu && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:80, background:"rgba(0,0,0,.5)" }}
            onClick={() => setShowUserMenu(false)}/>
          <div style={{ position:"fixed", bottom:65, left:0, right:0, zIndex:90,
            background:"var(--surface)", borderTop:"1px solid var(--border)",
            borderRadius:"20px 20px 0 0", padding:"16px 20px 24px",
            boxShadow:"0 -8px 32px rgba(0,0,0,.4)" }}>
            <div style={{ width:36, height:4, borderRadius:2, background:"var(--border)",
              margin:"0 auto 16px" }}/>
            {/* User info */}
            <div style={{ display:"flex", alignItems:"center", gap:12, marginBottom:16 }}>
              <div style={{ width:42, height:42, borderRadius:"50%", background:"var(--accent-soft)",
                color:"var(--accent)", display:"grid", placeItems:"center",
                fontSize:15, fontWeight:700 }}>
                {user.iniciales}
              </div>
              <div>
                <div style={{ fontWeight:600 }}>{user.nombre}</div>
                <div style={{ fontSize:12, color:"var(--text-3)", textTransform:"capitalize" }}>{user.rol}</div>
              </div>
            </div>
            {/* Nav items */}
            <div style={{ display:"flex", flexDirection:"column", gap:4, marginBottom:12 }}>
              {[
                { id:"perfil", label:"Mi perfil", icon:"⚙️", href:"/perfil" } as NavItem,
                ...navItems.slice(4).filter(i => i.id !== "perfil"),
              ].map(item => (
                <Link key={item.id} href={item.href}
                  onClick={() => setShowUserMenu(false)}
                  style={{ display:"flex", alignItems:"center", gap:12, padding:"10px 12px",
                    borderRadius:10, color:"var(--text)", textDecoration:"none",
                    background: isActive((item as any).href) ? "var(--accent-soft)" : "transparent" }}>
                  <span style={{ fontSize:18 }}>{item.icon}</span>
                  <span style={{ fontSize:14 }}>{item.label}</span>
                </Link>
              ))}
            </div>
            <div style={{ height:1, background:"var(--border)", margin:"8px 0 12px" }}/>
            <button onClick={handleLogout}
              style={{ width:"100%", padding:"12px", borderRadius:10, border:"none",
                background:"var(--danger-soft)", color:"var(--danger)",
                fontSize:14, fontWeight:600, cursor:"pointer", display:"flex",
                alignItems:"center", justifyContent:"center", gap:8 }}>
              🚪 Cerrar sesión
            </button>
          </div>
        </>
      )}

      {/* ── Top bar mobile (bell + theme) ─────────────────── */}
      <div className="mobile-topbar">
        <div style={{ display:"flex", alignItems:"center", gap:8 }}>
          <Image src="/logo.png" alt="GZ" width={24} height={24} style={{ borderRadius:4, objectFit:"cover" }}/>
          <span style={{ fontSize:13, fontWeight:700 }}>Grupo Zapata</span>
        </div>
        <div style={{ display:"flex", gap:6 }}>
          <NotificationBell userId={user.id}/>
          <ThemePanel/>
        </div>
      </div>

      {/* ── Main content ───────────────────────────────────── */}
      <main className="main-content">
        {children}
      </main>
    </div>
  )
}


FILEEOF

git add .
git commit -m "feat: factura vencida validation (configurable in admin/ajustes)"
git push
echo "✓ Done"
echo ""
echo "Ejecutar en Supabase: create-ajustes.sql"