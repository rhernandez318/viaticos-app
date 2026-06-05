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


