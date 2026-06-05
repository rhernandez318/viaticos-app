"use client"
import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"

export default function TesoreriaPagadosPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [usuarios, setUsuarios] = useState<Record<string,any>>({})
  const [loading, setLoading] = useState(true)
  const [busqueda, setBusqueda] = useState("")
  const [filtroTipo, setFiltroTipo] = useState("todos")

  useEffect(() => {
    const sb = createClient()
    Promise.all([
      sb.from("solicitudes")
        .select("id, tipo, concepto, monto, fecha, status, usuario_id")
        .in("status", ["liberado","comprobado","parcial"])
        .order("fecha", { ascending: false })
        .limit(300),
      sb.from("usuarios").select("id, nombre, iniciales"),
    ]).then(([s, u]) => {
      const usrMap: Record<string,any> = {}
      ;(u.data||[]).forEach((usr:any) => { usrMap[usr.id] = usr })
      setUsuarios(usrMap)
      setSolicitudes(s.data || [])
      setLoading(false)
    })
  }, [])

  const filtradas = solicitudes.filter(s => {
    const q = busqueda.toLowerCase()
    const u = usuarios[s.usuario_id]
    const matchQ = !busqueda ||
      s.id.toLowerCase().includes(q) ||
      s.concepto.toLowerCase().includes(q) ||
      u?.nombre?.toLowerCase().includes(q)
    const matchTipo = filtroTipo === "todos" || s.tipo === filtroTipo
    return matchQ && matchTipo
  })

  const totalFiltrado = filtradas.reduce((a:number,s:any) => a + parseFloat(s.monto||0), 0)

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Pagados</h1>
          <div className="page-sub">Historial de solicitudes liberadas</div>
        </div>
        <div style={{ textAlign:"right" }}>
          <div style={{ fontSize:18, fontWeight:700 }}>{fmtMXN(totalFiltrado)}</div>
          <div style={{ fontSize:11, color:"var(--text-3)" }}>{filtradas.length} registros</div>
        </div>
      </div>

      <div style={{ display:"flex", gap:8, marginBottom:14, flexWrap:"wrap" }}>
        <input className="input" placeholder="Buscar por folio, concepto o usuario…"
          value={busqueda} onChange={e => setBusqueda(e.target.value)}
          style={{ flex:"1 1 200px", maxWidth:340 }}/>
        <select className="select" style={{ width:160 }} value={filtroTipo}
          onChange={e => setFiltroTipo(e.target.value)}>
          <option value="todos">Todos los tipos</option>
          <option value="anticipo">Anticipos</option>
          <option value="comprobacion">Comprobaciones</option>
          <option value="reembolso">Reembolsos</option>
        </select>
      </div>

      <div className="card" style={{ padding:0, overflow:"auto" }}>
        {loading ? (
          <div style={{ padding:40, textAlign:"center", color:"var(--text-3)" }}>Cargando…</div>
        ) : (
          <table className="t" style={{minWidth:700}}>
            <thead>
              <tr>
                <th>Folio</th>
                <th>Usuario</th>
                <th>Tipo</th>
                <th>Concepto</th>
                <th>Fecha</th>
                <th className="num">Monto</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filtradas.map((s:any) => {
                const u = usuarios[s.usuario_id]
                return (
                  <tr key={s.id} style={{ cursor:"pointer" }}
                    onClick={() => router.push(`/solicitudes/${s.id}`)}>
                    <td className="mono" style={{ fontSize:11 }}>{s.id}</td>
                    <td>
                      {u ? (
                        <div style={{ display:"flex", alignItems:"center", gap:8 }}>
                          <div style={{ width:24, height:24, borderRadius:"50%", flexShrink:0,
                            background:"var(--surface-2)", border:"1px solid var(--border)",
                            display:"grid", placeItems:"center", fontSize:9, fontWeight:700 }}>
                            {u.iniciales}
                          </div>
                          <span style={{ fontSize:12, fontWeight:500 }}>{u.nombre}</span>
                        </div>
                      ) : <span className="muted">—</span>}
                    </td>
                    <td><TipoBadge tipo={s.tipo}/></td>
                    <td style={{ maxWidth:200, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", fontSize:12 }}>
                      {s.concepto}
                    </td>
                    <td className="muted" style={{ fontSize:12 }}>{fmtFecha(s.fecha)}</td>
                    <td className="num" style={{ fontWeight:600 }}>{fmtMXN(parseFloat(s.monto))}</td>
                    <td><StatusBadge status={s.status}/></td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}


