// Formatting utilities - extracted from index.html

export const fmtMXN = (n: number): string => {
  return new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
    minimumFractionDigits: 2,
  }).format(n ?? 0)
}

export const fmtFecha = (d: Date | string | null): string => {
  if (!d) return "—"
  const date = d instanceof Date ? d : new Date(d)
  return date.toLocaleDateString("es-MX", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  })
}

export const fmtFechaCorta = (d: Date | string | null): string => {
  if (!d) return "—"
  const date = d instanceof Date ? d : new Date(d)
  return date.toLocaleDateString("es-MX", { day: "2-digit", month: "short" })
}

export const diasAtras = (n: number): Date => {
  const d = new Date()
  d.setDate(d.getDate() - n)
  return d
}

export const getBancosAccount = (division: string): string => {
  if (division === "4105") return "1110100001"
  if (division === "4106") return "1110100002"
  return "1110100001"
}

