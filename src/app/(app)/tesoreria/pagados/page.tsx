"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"

export default function TesoreriaPagadosPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [busqueda, setBusqueda] = useState("")

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("id, tipo, concepto, monto, fecha, status, usuario_id")
      .in("status", ["liberado","comprobado","parcial"])
      .order("fecha", { ascending: false })
      .limit(200)
      .then(({ data }) => { setSolicitudes(data || []); setLoading(false) })
  }, [])

  const filtradas = solicitudes.filter(s =>
    !busqueda.trim() ||
    s.id.toLowerCase().includes(busqueda.toLowerCase()) ||
    s.concepto.toLowerCase().includes(busqueda.toLowerCase())
  )

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Pagados</h1>
          <div className="page-sub">Historial de solicitudes liberadas</div>
        </div>
      </div>
      <input className="input" placeholder="Buscar por folio o concepto…"
        value={busqueda} onChange={e => setBusqueda(e.target.value)}
        style={{ marginBottom: 14, maxWidth: 400 }} />
      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando…</div>
        ) : (
          <table className="t">
            <thead>
              <tr><th>Folio</th><th>Tipo</th><th>Concepto</th><th>Fecha</th><th className="num">Monto</th><th>Status</th></tr>
            </thead>
            <tbody>
              {filtradas.map((s: any) => (
                <tr key={s.id} style={{ cursor: "pointer" }}
                  onClick={() => router.push(`/solicitudes/${s.id}`)}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td><TipoBadge tipo={s.tipo} /></td>
                  <td style={{ maxWidth: 240, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {s.concepto}
                  </td>
                  <td className="muted" style={{ fontSize: 12 }}>{fmtFecha(s.fecha)}</td>
                  <td className="num">{fmtMXN(parseFloat(s.monto))}</td>
                  <td><StatusBadge status={s.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}

