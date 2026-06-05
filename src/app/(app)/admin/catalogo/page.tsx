"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

const GRUPOS = ["Transporte","Hospedaje","Alimentos","Combustible","Estacionamiento","Peaje","Servicios","No Deducibles","Otros"]

export default function AdminCatalogoPage() {
  const [cuentas, setCuentas] = useState<any[]>([])
  const [editing, setEditing] = useState<any|null>(null)
  const [busqueda, setBusqueda] = useState("")
  const [guardando, setGuardando] = useState(false)
  const [toast, setToast] = useState<string|null>(null)
  const [filtroGrupo, setFiltroGrupo] = useState("todos")

  const showToast = (m:string) => { setToast(m); setTimeout(()=>setToast(null),3000) }
  const load = async () => {
    const sb = createClient()
    const { data } = await sb.from("cuentas_contables").select("*").order("cuenta")
    setCuentas(data || [])
  }
  useEffect(()=>{ load() },[])

  const openNuevo = () => setEditing({ cuenta:"", nombre:"", grupo:"Transporte", activo:true })

  const guardar = async () => {
    if (!editing.cuenta.trim() || !editing.nombre.trim()) { showToast("⚠ Cuenta y nombre requeridos"); return }
    setGuardando(true)
    const sb = createClient()
    const exists = cuentas.find(c=>c.cuenta===editing.cuenta)
    const row = { cuenta: editing.cuenta.trim(), nombre: editing.nombre, grupo: editing.grupo, activo: editing.activo ?? true }
    const { error } = exists
      ? await sb.from("cuentas_contables").update(row).eq("cuenta", editing.cuenta)
      : await sb.from("cuentas_contables").insert(row)
    if (error) showToast("⚠ " + error.message)
    else { showToast("✓ Guardado"); await load() }
    setEditing(null); setGuardando(false)
  }

  const toggleActivo = async (c:any) => {
    const sb = createClient()
    await sb.from("cuentas_contables").update({ activo: !c.activo }).eq("cuenta", c.cuenta)
    await load()
  }

  const exportarCSV = () => {
    const rows = [["Cuenta","Nombre","Grupo","Activo"], ...cuentas.map(c=>[c.cuenta,c.nombre,c.grupo,c.activo?"Sí":"No"])]
    const csv = rows.map(r=>r.map(v=>`"${v}"`).join(",")).join("\n")
    const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob(["\uFEFF"+csv],{type:"text/csv"}))
    a.download = `catalogo_gastos_${new Date().toISOString().slice(0,10)}.csv`; a.click()
  }

  const grupos = ["todos", ...Array.from(new Set(cuentas.map(c=>c.grupo))).sort()]
  const filtradas = cuentas.filter(c=>
    (filtroGrupo==="todos"||c.grupo===filtroGrupo) &&
    (!busqueda || c.cuenta?.includes(busqueda) || c.nombre?.toLowerCase().includes(busqueda.toLowerCase())))

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Catálogo de gastos</h1><div className="page-sub">{cuentas.length} cuentas</div></div>
        <div style={{display:"flex",gap:8}}>
          <button className="btn ghost" onClick={exportarCSV}>↓ CSV</button>
          <button className="btn primary" onClick={openNuevo}>+ Nueva cuenta</button>
        </div>
      </div>

      {toast && <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background:toast.startsWith("✓")?"var(--success-soft)":"var(--danger-soft)",
        color:toast.startsWith("✓")?"var(--success)":"var(--danger)"}}>{toast}</div>}

      {editing && (
        <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center",padding:20}}>
          <div className="card" style={{width:"100%",maxWidth:460}}>
            <div style={{fontWeight:700,fontSize:16,marginBottom:16}}>{cuentas.find(c=>c.cuenta===editing.cuenta)?"Editar":"Nueva"} cuenta</div>
            <div style={{display:"grid",gap:12}}>
              {[
                {label:"Número de cuenta",key:"cuenta",disabled:!!cuentas.find(c=>c.cuenta===editing.cuenta)},
                {label:"Nombre",key:"nombre"},
              ].map(({label,key,disabled})=>(
                <div key={key}>
                  <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>{label}</label>
                  <input className="input mono" value={editing[key]||""} disabled={disabled}
                    onChange={e=>setEditing({...editing,[key]:e.target.value})}/>
                </div>
              ))}
              <div>
                <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>Grupo</label>
                <select className="select" value={editing.grupo||""} onChange={e=>setEditing({...editing,grupo:e.target.value})}>
                  {GRUPOS.map(g=><option key={g}>{g}</option>)}
                </select>
              </div>
            </div>
            <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:16}}>
              <button className="btn ghost" onClick={()=>setEditing(null)}>Cancelar</button>
              <button className="btn primary" onClick={guardar} disabled={guardando}>{guardando?"Guardando…":"Guardar"}</button>
            </div>
          </div>
        </div>
      )}

      <div style={{display:"flex",gap:8,marginBottom:14,flexWrap:"wrap"}}>
        <input className="input" placeholder="Buscar por número o nombre…" value={busqueda}
          onChange={e=>setBusqueda(e.target.value)} style={{flex:"1 1 200px",maxWidth:320}}/>
        <select className="select" style={{width:160}} value={filtroGrupo} onChange={e=>setFiltroGrupo(e.target.value)}>
          {grupos.map(g=><option key={g} value={g}>{g==="todos"?"Todos los grupos":g}</option>)}
        </select>
      </div>

      <div className="card" style={{padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:650}}>
          <thead><tr><th>Cuenta</th><th>Nombre</th><th>Grupo</th><th>Activo</th><th></th></tr></thead>
          <tbody>
            {filtradas.map((c:any)=>(
              <tr key={c.cuenta} style={{opacity:c.activo?1:.5}}>
                <td className="mono" style={{fontWeight:700,color:"var(--accent)"}}>{c.cuenta}</td>
                <td style={{fontWeight:500}}>{c.nombre}</td>
                <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,background:"var(--surface-2)",color:"var(--text-2)"}}>{c.grupo}</span></td>
                <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,fontWeight:600,
                  background:c.activo?"var(--success-soft)":"var(--surface-2)",
                  color:c.activo?"var(--success)":"var(--text-3)"}}>{c.activo?"Activa":"Inactiva"}</span></td>
                <td><div style={{display:"flex",gap:6}}>
                  <button className="btn sm ghost" onClick={()=>setEditing({...c})}>Editar</button>
                  <button className="btn sm ghost" style={{color:c.activo?"var(--danger)":"var(--success)"}} onClick={()=>toggleActivo(c)}>
                    {c.activo?"Desactivar":"Activar"}
                  </button>
                </div></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}


