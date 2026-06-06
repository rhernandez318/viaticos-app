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


