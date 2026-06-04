import { createClient } from "@/lib/supabase/client"

export interface LimiteViolacion {
  tipo: "solicitud" | "diario"
  cuenta: string
  nombreCuenta: string
  montoPropuesto: number
  limitePermitido: number
  limitNombre: string
}

export async function validarLimites(
  userId: string,
  items: Array<{ cuenta: string; monto: number; nombreCuenta?: string }>,
  fechaStr?: string
): Promise<LimiteViolacion[]> {
  if (!items.length) return []

  const sb = createClient()
  const [{ data: perfil }, { data: limites }, { data: gastosHoy }] = await Promise.all([
    sb.from("usuarios").select("rol").eq("id", userId).single(),
    sb.from("limites_gasto").select("*").eq("activo", true),
    sb.from("solicitudes")
      .select("monto, status, cfdi:comprobantes_cfdi(cuenta, total)")
      .eq("usuario_id", userId)
      .gte("fecha", new Date().toISOString().slice(0, 10) + "T00:00:00")
      .not("status", "eq", "rechazado"),
  ])

  if (!limites?.length) return []
  const rol = perfil?.rol || "usuario"
  const violaciones: LimiteViolacion[] = []

  // Group items by cuenta
  const byAccount: Record<string, number> = {}
  items.forEach(it => {
    byAccount[it.cuenta] = (byAccount[it.cuenta] || 0) + it.monto
  })
  const totalSolicitud = items.reduce((a, it) => a + it.monto, 0)

  // Calculate today's spending by account
  const gastadoHoyByCuenta: Record<string, number> = {}
  let gastadoHoyTotal = 0
  ;(gastosHoy || []).forEach((s: any) => {
    ;(s.cfdi || []).forEach((cf: any) => {
      gastadoHoyByCuenta[cf.cuenta] = (gastadoHoyByCuenta[cf.cuenta] || 0) + (parseFloat(cf.total) || 0)
      gastadoHoyTotal += parseFloat(cf.total) || 0
    })
    if (!s.cfdi?.length) {
      gastadoHoyTotal += parseFloat(s.monto) || 0
    }
  })

  for (const limite of limites) {
    // Skip if limit applies to a different role
    if (limite.aplica_rol && limite.aplica_rol !== rol) continue

    if (limite.cuenta) {
      // Per-account limits
      const montoCuenta = byAccount[limite.cuenta] || 0
      if (!montoCuenta) continue

      const nombreCuenta = items.find(i => i.cuenta === limite.cuenta)?.nombreCuenta || limite.cuenta

      // Per-request limit
      if (limite.limite_monto && montoCuenta > limite.limite_monto) {
        violaciones.push({
          tipo: "solicitud", cuenta: limite.cuenta, nombreCuenta,
          montoPropuesto: montoCuenta, limitePermitido: limite.limite_monto,
          limitNombre: limite.nombre,
        })
      }

      // Daily limit per account
      if (limite.limite_diario) {
        const totalConHoy = (gastadoHoyByCuenta[limite.cuenta] || 0) + montoCuenta
        if (totalConHoy > limite.limite_diario) {
          violaciones.push({
            tipo: "diario", cuenta: limite.cuenta, nombreCuenta,
            montoPropuesto: totalConHoy, limitePermitido: limite.limite_diario,
            limitNombre: limite.nombre,
          })
        }
      }
    } else {
      // Global limits (no specific account)
      if (limite.limite_monto && totalSolicitud > limite.limite_monto) {
        violaciones.push({
          tipo: "solicitud", cuenta: "todas", nombreCuenta: "Total solicitud",
          montoPropuesto: totalSolicitud, limitePermitido: limite.limite_monto,
          limitNombre: limite.nombre,
        })
      }
      if (limite.limite_diario) {
        const totalConHoy = gastadoHoyTotal + totalSolicitud
        if (totalConHoy > limite.limite_diario) {
          violaciones.push({
            tipo: "diario", cuenta: "todas", nombreCuenta: "Total del día",
            montoPropuesto: totalConHoy, limitePermitido: limite.limite_diario,
            limitNombre: limite.nombre,
          })
        }
      }
    }
  }

  return violaciones
}

