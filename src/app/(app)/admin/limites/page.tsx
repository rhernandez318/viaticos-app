"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

const ROLES = ["(todos)","usuario","gerente","tesoreria","contador","admin"]

export default function LimitesPage() {
  const [limites, setLimites] = useState<any[]>([])
  const [cuentas, setCuentas] = useState<any[]>([])
  const [editing, setEditing] = useState<any|null>(null)
  const [guardando, setGuardando] = useState(false)
  const [toast, setToast] = useState<string|null>(null)

  const showToast = (m:string)=>{ setToast(m); setTimeout(()=>setToast(null),3000) }
  const load = async () => {
    const sb = createClient()
    const [l,c] = await Promise.all([
      sb.from("limites_gasto").select("*").order("nombre"),
      sb.from("cuentas_contables").select("cuenta,nombre").eq("activo",true).order("cuenta"),
    ])
    setLimites(l.data||[]); setCuentas(c.data||[])
  }
  useEffect(()=>{ load() },[])

  const openNuevo = () => setEditing({ nombre:"", cuenta:null, limite_monto:null, limite_diario:null, aplica_rol:null, activo:true })

  const guardar = async () => {
    if (!editing.nombre.trim()) { showToast("⚠ Nombre requerido"); return }
    setGuardando(true)
    const sb = createClient()
    const row = {
      nombre: editing.nombre,
      cuenta: editing.cuenta||null,
      limite_monto: editing.limite_monto ? parseFloat(editing.limite_monto) : null,
      limite_diario: editing.limite_diario ? parseFloat(editing.limite_diario) : null,
      aplica_rol: editing.aplica_rol||null,
      activo: editing.activo ?? true,
    }
    const { error } = editing.id
      ? await sb.from("limites_gasto").update(row).eq("id",editing.id)
      : await sb.from("limites_gasto").insert(row)
    if (error) showToast("⚠ "+error.message)
    else { showToast("✓ Guardado"); await load() }
    setEditing(null); setGuardando(false)
  }

  const toggleActivo = async (l:any) => {
    const sb = createClient()
    await sb.from("limites_gasto").update({ activo:!l.activo }).eq("id",l.id)
    await load()
  }

  const Field = ({ label, children }: any) => (
    <div>
      <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>{label}</label>
      {children}
    </div>
  )

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Límites de gasto</h1>
          <div className="page-sub">Reglas de negocio por cuenta contable y por día</div>
        </div>
        <button className="btn primary" onClick={openNuevo}>+ Nuevo límite</button>
      </div>

      {toast&&<div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background:toast.startsWith("✓")?"var(--success-soft)":"var(--danger-soft)",
        color:toast.startsWith("✓")?"var(--success)":"var(--danger)"}}>{toast}</div>}

      {editing&&(
        <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center",padding:20}}>
          <div className="card" style={{width:"100%",maxWidth:500}}>
            <div style={{fontWeight:700,fontSize:16,marginBottom:16}}>{editing.id?"Editar":"Nuevo"} límite</div>
            <div style={{display:"grid",gap:12}}>
              <Field label="Nombre del límite *">
                <input className="input" value={editing.nombre||""} onChange={e=>setEditing({...editing,nombre:e.target.value})} placeholder="Ej: Alimentos por viaje"/>
              </Field>
              <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:12}}>
                <Field label="Cuenta contable (opcional)">
                  <select className="select" value={editing.cuenta||""} onChange={e=>setEditing({...editing,cuenta:e.target.value||null})}>
                    <option value="">— Todas las cuentas —</option>
                    {cuentas.map((c:any)=><option key={c.cuenta} value={c.cuenta}>{c.cuenta} · {c.nombre}</option>)}
                  </select>
                </Field>
                <Field label="Aplica a rol">
                  <select className="select" value={editing.aplica_rol||""} onChange={e=>setEditing({...editing,aplica_rol:e.target.value||null})}>
                    {ROLES.map(r=><option key={r} value={r==="(todos)"?"":r}>{r}</option>)}
                  </select>
                </Field>
                <Field label="Límite por solicitud ($)">
                  <input className="input mono" type="number" min="0" value={editing.limite_monto||""} onChange={e=>setEditing({...editing,limite_monto:e.target.value})} placeholder="Sin límite"/>
                </Field>
                <Field label="Límite diario ($)">
                  <input className="input mono" type="number" min="0" value={editing.limite_diario||""} onChange={e=>setEditing({...editing,limite_diario:e.target.value})} placeholder="Sin límite"/>
                </Field>
              </div>
            </div>
            <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:16}}>
              <button className="btn ghost" onClick={()=>setEditing(null)}>Cancelar</button>
              <button className="btn primary" onClick={guardar} disabled={guardando}>{guardando?"Guardando…":"Guardar"}</button>
            </div>
          </div>
        </div>
      )}

      <div className="card" style={{padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:700}}>
          <thead><tr><th>Nombre</th><th>Cuenta</th><th>Rol</th><th className="num">Por solicitud</th><th className="num">Diario</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            {limites.map((l:any)=>{
              const c = cuentas.find((x:any)=>x.cuenta===l.cuenta)
              return (
                <tr key={l.id} style={{opacity:l.activo?1:.5}}>
                  <td style={{fontWeight:500}}>{l.nombre}</td>
                  <td style={{fontSize:11,color:"var(--text-3)"}}>{c?`${c.cuenta} · ${c.nombre}`:"Todas"}</td>
                  <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,background:"var(--surface-2)"}}>{l.aplica_rol||"Todos"}</span></td>
                  <td className="num">{l.limite_monto?fmtMXN(l.limite_monto):"—"}</td>
                  <td className="num">{l.limite_diario?fmtMXN(l.limite_diario):"—"}</td>
                  <td><span style={{fontSize:11,padding:"2px 8px",borderRadius:10,fontWeight:600,
                    background:l.activo?"var(--success-soft)":"var(--surface-2)",
                    color:l.activo?"var(--success)":"var(--text-3)"}}>{l.activo?"Activo":"Inactivo"}</span></td>
                  <td><div style={{display:"flex",gap:6}}>
                    <button className="btn sm ghost" onClick={()=>setEditing({...l})}>Editar</button>
                    <button className="btn sm ghost" style={{color:l.activo?"var(--danger)":"var(--success)"}} onClick={()=>toggleActivo(l)}>
                      {l.activo?"Desactivar":"Activar"}
                    </button>
                  </div></td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </>
  )
}


