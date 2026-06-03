"use client"

import { useEffect, useState, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { catalogos, findUser } from "@/store/catalogos"
import type { Usuario, Centro, CuentaContable, Solicitud } from "@/types"

export function useCatalogos() {
  const [loaded, setLoaded] = useState(catalogos.dbLoaded)

  const load = useCallback(async () => {
    const sb = createClient()
    const [centrosRes, cuentasRes, usuariosRes] = await Promise.all([
      sb.from("centros").select("*").eq("activo", true),
      sb.from("cuentas_contables").select("*").eq("activo", true),
      sb.from("usuarios").select("*").eq("activo", true),
    ])
    if (centrosRes.error || cuentasRes.error || usuariosRes.error) return

    catalogos.centros = (centrosRes.data || []).map((c) => ({
      id: c.id, nombre: c.nombre, depto: c.depto, division: c.division,
    }))
    catalogos.catalogoGastos = (cuentasRes.data || []).map((c) => ({
      cuenta: c.cuenta, nombre: c.nombre, grupo: c.grupo, activo: c.activo,
    }))
    catalogos.usuarios = (usuariosRes.data || []).map((u) => ({
      id: u.id, nombre: u.nombre, correo: u.correo, rol: u.rol,
      iniciales: u.iniciales, centro: u.centro_id, gerente: u.gerente_id,
      division: u.division || "4105", clabe: u.clabe, banco: u.banco,
      suplanteId: u.suplente_id, suplantaDesde: u.suplente_desde, suplantaHasta: u.suplente_hasta,
    }))
    catalogos.dbLoaded = true
    setLoaded(true)
  }, [])

  useEffect(() => {
    if (!catalogos.dbLoaded) load()
  }, [load])

  return { loaded, reload: load, ...catalogos }
}

export function useSolicitudes(userId?: string, rol?: string) {
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!userId) return
    const sb = createClient()
    let query = sb.from("solicitudes")
      .select("*, cfdi:comprobantes_cfdi(*)")
      .order("fecha", { ascending: false })

    if (rol === "usuario") query = query.eq("usuario_id", userId)
    // gerente/admin: load all (filter in component)

    query.then(({ data, error }) => {
      if (error || !data) { setLoading(false); return }
      const mapped: Solicitud[] = data.map((s) => ({
        id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
        monto: parseFloat(s.monto) || 0,
        fecha: new Date(s.fecha),
        status: s.status,
        saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
        anticipoRef: s.anticipo_ref,
        motivoRechazo: s.motivo_rechazo,
        notas: s.notas,
        esCierre: !!(s.notas && s.notas.includes("CIERRE_DEPOSITO")),
        comprobantes: s.comprobantes || 0,
        centroId: s.centro_id,
        cfdi: (s.cfdi || []).map((c: any) => ({
          id: c.id, uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
          subtotal: parseFloat(c.subtotal) || 0,
          iva: parseFloat(c.iva) || 0,
          total: parseFloat(c.total) || 0,
          cuenta: c.cuenta, confianza: parseFloat(c.confianza) || 0.9,
          archivoUrl: c.archivo_url, archivoPdfUrl: c.archivo_pdf_url,
          archivoXmlUrl: c.archivo_xml_url,
          rfcEmisor: c.rfc_emisor, rfcReceptor: c.rfc_receptor, satEstado: c.sat_estado,
        })),
      }))
      catalogos.solicitudes = mapped
      setSolicitudes(mapped)
      setLoading(false)
    })
  }, [userId, rol])

  return { solicitudes, loading }
}

// Re-export finders for convenience
export { findUser, findCentro, findCuenta } from "@/store/catalogos"

