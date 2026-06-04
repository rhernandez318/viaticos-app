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

