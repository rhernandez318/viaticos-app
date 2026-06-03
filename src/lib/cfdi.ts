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

const CUENTA_PATTERNS: [RegExp, string, number][] = [
  [/(peaje|caseta|autopista|telepeaje|iave|pase)/i, "6122700001", 0.9],
  [/(estacionamiento|parking|parquímetro|pensión)/i, "6122700002", 0.9],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i, "6122600001", 0.9],
  [/(taxi|uber|didi|cabify|transporte)/i, "6122900002", 0.85],
  [/(hotel|hospedaje|alojamiento)/i, "6122100001", 0.85],
  [/(restaurante|alimentos|comida|viáticos)/i, "6122200001", 0.8],
  [/(aéreo|vuelo|boleto|avión)/i, "6122400001", 0.85],
]

function guessCuenta(text: string): [string, number] {
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
    const [cuenta, confianza] = guessCuenta(matchText)

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
