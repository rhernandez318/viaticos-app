import type { SolicitudStatus } from "@/types"

const LABELS: Record<string, string> = {
  solicitado: "Solicitado", autorizado: "Pend. Admin", validado: "Aut. Admin",
  liberado: "Liberado", comprobado: "Comprobado", rechazado: "Rechazado", parcial: "Parcial",
}

export function StatusBadge({ status }: { status: SolicitudStatus }) {
  return <span className={`badge ${status}`}>{LABELS[status] ?? status}</span>
}

export function TipoBadge({ tipo }: { tipo: string }) {
  const map: Record<string, string> = { anticipo: "ANT", comprobacion: "CMP", reembolso: "REE" }
  return <span className="badge tipo">{map[tipo] ?? tipo}</span>
}

