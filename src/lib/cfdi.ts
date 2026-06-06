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

