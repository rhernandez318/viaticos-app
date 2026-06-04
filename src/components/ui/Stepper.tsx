"use client"
import { fmtFecha } from "@/lib/format"
import type { SolicitudStatus } from "@/types"

const STEPS = [
  { key: "solicitado", label: "Solicitado" },
  { key: "autorizado", label: "Aut. Gerente" },
  { key: "validado",   label: "Aut. Admin" },
  { key: "liberado",   label: "Liberado" },
  { key: "comprobado", label: "Comprobado" },
]

const ORDER: Record<string, number> = {
  solicitado: 0, autorizado: 1, validado: 2, liberado: 3, comprobado: 4, parcial: 3,
}

export function Stepper({ status, dates }: { status: SolicitudStatus; dates?: Record<string, Date | null> }) {
  if (status === "rechazado") {
    return (
      <div className="stepper">
        <div className="step done"><div className="dot">1</div><div className="label">Solicitado</div></div>
        <div className="step rejected"><div className="dot">✕</div><div className="label">Rechazado</div></div>
      </div>
    )
  }
  const cur = ORDER[status] ?? 0
  return (
    <div className="stepper">
      {STEPS.map((s, i) => {
        const cls = i < cur ? "done" : i === cur ? "active" : ""
        return (
          <div key={s.key} className={`step ${cls}`}>
            <div className="dot">{i < cur ? "✓" : i + 1}</div>
            <div className="label">{s.label}</div>
            {dates?.[s.key] && <div className="meta">{fmtFecha(dates[s.key])}</div>}
          </div>
        )
      })}
    </div>
  )
}

