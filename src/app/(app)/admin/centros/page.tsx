"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

const DIVISIONES = ["4105","4106","4111","4113"]
const DEPTOS = ["Operaciones","Administración","Ventas","Finanzas","Recursos Humanos","Sistemas","Dirección"]

export default function AdminCentrosPage() {
  const [centros, setCentros] = useState<any[]>([])
  const [editing, setEditing] = useState<any|null>(null)
  const [busqueda, setBusqueda] = useState("")
  const [guardando, setGuardando] = useState(false)
  const [toast, setToast] = useState<string|null>(null)

  const showToast = (m: string) => { setToast(m); setTimeout(()=>setToast(null),3000) }

  const load = async () => {
    const sb = createClient()
    const { data } = await sb.from("centros").select("*").order("id")
    setCentros(data || [])
  }
  useEffect(() => { load() }, [])

  const openNuevo = () => setEditing({ id:"", nombre:"", depto:"Operaciones", division:"4105", activo:true })

  const guardar = async () => {
    if (!editing.id.trim() || !editing.nombre.trim()) { showToast("⚠ ID y nombre requeridos"); return }
    setGuardando(true)
    const sb = createClient()
    const exists = centros.find(c => c.id === editing.id)
    const row = { id: editing.id.toUpperCase().trim(), nombre: editing.nombre, depto: editing.depto, division: editing.division, activo: editing.activo ?? true }
    const { error } = exists
      ? await sb.from("centros").update(row).eq("id", editing.id)
      : await sb.from("centros").insert(row)
    if (error) showToast("⚠ " + error.message)
    else { showToast("✓ Guardado"); await load() }
    setEditing(null); setGuardando(false)
  }

  const toggleActivo = async (c: any) => {
    const sb = createClient()
    await sb.from("centros").update({ activo: !c.activo }).eq("id", c.id)
    showToast(c.activo ? "Centro desactivado" : "Centro activado")
    await load()
  }

  const filtrados = centros.filter(c =>
    !busqueda || c.id?.toLowerCase().includes(busqueda.toLowerCase()) ||
    c.nombre?.toLowerCase().includes(busqueda.toLowerCase()))

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Centros de beneficio</h1><div className="page-sub">{centros.length} registrados</div></div>
        <button className="btn primary" onClick={openNuevo}>+ Nuevo centro</button>
      </div>

      {toast && <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background:toast.startsWith("✓")?"var(--success-soft)":"var(--danger-soft)",
        color:toast.startsWith("✓")?"var(--success)":"var(--danger)"}}>{toast}</div>}

      {editing && (
        <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center",padding:20}}>
          <div className="card" style={{width:"100%",maxWidth:460}}>
            <div style={{fontWeight:700,fontSize:16,marginBottom:16}}>{centros.find(c=>c.id===editing.id)?"Editar":"Nuevo"} centro</div>
            <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:12}}>
              {[
                {label:"Clave (ID)",key:"id",disabled:!!centros.find(c=>c.id===editing.id)},
                {label:"Nombre",key:"nombre"},
              ].map(({label,key,disabled})=>(
                <div key={key}>
                  <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>{label}</label>
                  <input className="input" value={editing[key]||""} disabled={disabled}
                    onChange={e=>setEditing({...editing,[key]:e.target.value})} style={{textTransform:key==="id"?"uppercase":"none"}}/>
                </div>
              ))}
              <div>
                <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>Departamento</label>
                <select className="select" value={editing.depto||""} onChange={e=>setEditing({...editing,depto:e.target.value})}>
                  {DEPTOS.map(d=><option key={d}>{d}</option>)}
                </select>
              </div>
              <div>
                <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>División SAP</label>
                <select className="select" value={editing.division||"4105"} onChange={e=>setEditing({...editing,division:e.target.value})}>
                  {DIVISIONES.map(d=><option key={d}>{d}</option>)}
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

      <input className="input" placeholder="Buscar por clave o nombre…" value={busqueda}
        onChange={e=>setBusqueda(e.target.value)} style={{marginBottom:14,maxWidth:340}}/>

      <div className="card" style={{padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:600}}>
          <thead><tr><th>Clave</th><th>Nombre</th><th>Depto</th><th>División</th><th>Activo</th><th></th></tr></thead>
          <tbody>
            {filtrados.map((c:any)=>(
              <tr key={c.id} style={{opacity:c.activo?1:.5}}>
                <td className="mono" style={{fontWeight:700}}>{c.id}</td>
                <td style={{fontWeight:500}}>{c.nombre}</td>
                <td style={{fontSize:12,color:"var(--text-3)"}}>{c.depto}</td>
                <td className="mono" style={{fontSize:12}}>{c.division}</td>
                <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,fontWeight:600,
                  background:c.activo?"var(--success-soft)":"var(--surface-2)",
                  color:c.activo?"var(--success)":"var(--text-3)"}}>{c.activo?"Activo":"Inactivo"}</span></td>
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


