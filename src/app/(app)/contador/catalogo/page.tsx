"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

export default function ContadorCatalogoPage() {
  const [cuentas, setCuentas] = useState<any[]>([])
  const [busqueda, setBusqueda] = useState("")
  const [filtroGrupo, setFiltroGrupo] = useState("todos")
  const [loading, setLoading] = useState(true)

  useEffect(()=>{
    const sb = createClient()
    sb.from("cuentas_contables").select("*").eq("activo",true).order("cuenta")
      .then(({data})=>{ setCuentas(data||[]); setLoading(false) })
  },[])

  const grupos = ["todos", ...Array.from(new Set(cuentas.map((c:any)=>c.grupo))).sort() as string[]]
  const filtradas = cuentas.filter((c:any)=>
    (filtroGrupo==="todos"||c.grupo===filtroGrupo)&&
    (!busqueda||c.cuenta?.includes(busqueda)||c.nombre?.toLowerCase().includes(busqueda.toLowerCase())))

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Catálogo de gastos</h1>
          <div className="page-sub">{cuentas.length} cuentas activas</div></div>
      </div>
      <div style={{display:"flex",gap:8,marginBottom:14,flexWrap:"wrap"}}>
        <input className="input" placeholder="Buscar…" value={busqueda} onChange={e=>setBusqueda(e.target.value)} style={{flex:"1 1 200px",maxWidth:320}}/>
        <select className="select" style={{width:160}} value={filtroGrupo} onChange={e=>setFiltroGrupo(e.target.value)}>
          {grupos.map(g=><option key={g} value={g}>{g==="todos"?"Todos los grupos":g}</option>)}
        </select>
      </div>
      <div className="card" style={{padding:0,overflow:"auto"}}>
        {loading ? <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div> : (
          <table className="t" style={{minWidth:650}}>
            <thead><tr><th>Cuenta</th><th>Nombre</th><th>Grupo</th></tr></thead>
            <tbody>{filtradas.map((c:any)=>(
              <tr key={c.cuenta}>
                <td className="mono" style={{fontWeight:700,color:"var(--accent)"}}>{c.cuenta}</td>
                <td>{c.nombre}</td>
                <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,background:"var(--surface-2)",color:"var(--text-2)"}}>{c.grupo}</span></td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
    </>
  )
}


