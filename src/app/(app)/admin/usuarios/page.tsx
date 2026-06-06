"use client"
import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"

const ROLES = ["usuario","gerente","tesoreria","contador","admin"]
const DIVISIONES = ["4105","4106","4111","4113"]
const WORKER_URL = process.env.NEXT_PUBLIC_WORKER_URL || ""
const WORKER_SECRET = "viaticos-zapata-push-2026"

async function callWorker(action: string, payload: any) {
  const res = await fetch(WORKER_URL + "/" + action, {
    method:"POST",
    headers:{"Content-Type":"application/json","Authorization":"Bearer "+WORKER_SECRET},
    body: JSON.stringify(payload),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data.error || "Error Worker")
  return data
}

const ROL_COLOR: Record<string,string> = {
  admin:"var(--accent)",gerente:"var(--success)",tesoreria:"#60a5fa",contador:"#c084fc",usuario:"var(--text-3)"
}

export default function AdminUsuariosPage() {
  const [usuarios, setUsuarios] = useState<any[]>([])
  const [centros, setCentros] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [editando, setEditando] = useState<any|null>(null)
  const [creando, setCreando] = useState(false)
  const [nuevoForm, setNuevoForm] = useState({ nombre:"", correo:"", password:"", rol:"usuario", centro_id:"", gerente_id:"", division:"4105" })
  const [guardando, setGuardando] = useState(false)
  const [busqueda, setBusqueda] = useState("")
  const [toast, setToast] = useState<string|null>(null)

  const showToast = (m:string) => { setToast(m); setTimeout(()=>setToast(null),3500) }

  const load = useCallback(async () => {
    const sb = createClient()
    const [u,c] = await Promise.all([
      sb.from("usuarios").select("*").eq("activo",true).order("nombre"),
      sb.from("centros").select("id,nombre").eq("activo",true).order("nombre"),
    ])
    setUsuarios(u.data||[]); setCentros(c.data||[]); setLoading(false)
  },[])
  useEffect(()=>{ load() },[load])

  const guardar = async () => {
    if (!editando) return
    if (!editando.centro_id) { alert("⚠ Debe asignar un Centro de beneficio al usuario"); return }
    setGuardando(true)
    const sb = createClient()
    const row = {
      nombre:editando.nombre, rol:editando.rol,
      centro_id:editando.centro_id||null, gerente_id:editando.gerente_id||null,
      division:editando.division||"4105", clabe:editando.clabe||null, banco:editando.banco||null,
      iniciales:editando.nombre.split(" ").map((p:string)=>p[0]).slice(0,2).join("").toUpperCase(),
    }
    const { error } = await sb.from("usuarios").update(row).eq("id",editando.id)
    if (error) showToast("⚠ "+error.message)
    else { showToast("✓ Actualizado"); await load() }
    setEditando(null); setGuardando(false)
  }

  const crearUsuario = async () => {
    const { nombre,correo,password,rol,centro_id,gerente_id,division } = nuevoForm
    if (!centro_id) { alert("⚠ Debe asignar un Centro de beneficio al usuario"); return }
    if (!nombre.trim() || !correo.trim() || !password) { alert("⚠ Nombre, correo y contraseña son obligatorios"); return }
    if (!nombre.trim()||!correo.trim()||!password.trim()) { showToast("⚠ Nombre, correo y contraseña requeridos"); return }
    setGuardando(true)
    try {
      await callWorker("createUser", { nombre,email:correo,password,rol,centro:centro_id||null,gerente:gerente_id||null,division })
      showToast("✓ Usuario creado")
      setCreando(false)
      setNuevoForm({ nombre:"",correo:"",password:"",rol:"usuario",centro_id:"",gerente_id:"",division:"4105" })
      await load()
    } catch(e:any) { showToast("⚠ "+e.message) }
    setGuardando(false)
  }

  const resetPassword = async (userId:string) => {
    const pwd = prompt("Nueva contraseña (mínimo 6 caracteres):")
    if (!pwd || pwd.length < 6) return
    try {
      await callWorker("resetPassword", { userId, newPassword:pwd })
      showToast("✓ Contraseña actualizada")
    } catch(e:any) { showToast("⚠ "+e.message) }
  }

  const desactivar = async (id:string, nombre:string) => {
    if (!confirm(`¿Desactivar a ${nombre}?`)) return
    const sb = createClient()
    await sb.from("usuarios").update({ activo:false }).eq("id",id)
    showToast("Usuario desactivado")
    await load()
  }

  const filtrados = usuarios.filter(u =>
    !busqueda || u.nombre?.toLowerCase().includes(busqueda.toLowerCase()) ||
    u.correo?.toLowerCase().includes(busqueda.toLowerCase()) ||
    u.rol?.toLowerCase().includes(busqueda.toLowerCase()))

  const FormField = ({ label, children }: { label: string; children: React.ReactNode }) => (
    <div>
      <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>{label}</label>
      {children}
    </div>
  )

  const Modal = ({ title, onClose, onSave, children }: any) => (
    <div style={{position:"fixed",inset:0,background:"rgba(0,0,0,.6)",zIndex:100,display:"grid",placeItems:"center",padding:20}}>
      <div className="card" style={{width:"100%",maxWidth:520,maxHeight:"90vh",overflowY:"auto"}}>
        <div style={{fontWeight:700,fontSize:16,marginBottom:16}}>{title}</div>
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:12}}>{children}</div>
        <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:16}}>
          <button className="btn ghost" onClick={onClose}>Cancelar</button>
          <button className="btn primary" onClick={onSave} disabled={guardando}>{guardando?"Guardando…":"Guardar"}</button>
        </div>
      </div>
    </div>
  )

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Usuarios</h1><div className="page-sub">{usuarios.length} registrados</div></div>
        <button className="btn primary" onClick={()=>setCreando(true)}>+ Nuevo usuario</button>
      </div>

      {toast && <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background:toast.startsWith("✓")?"var(--success-soft)":"var(--danger-soft)",
        color:toast.startsWith("✓")?"var(--success)":"var(--danger)"}}>{toast}</div>}

      {/* Modal nuevo usuario */}
      {creando && (
        <Modal title="Nuevo usuario" onClose={()=>setCreando(false)} onSave={crearUsuario}>
          <FormField label="Nombre completo">
            <input className="input" value={nuevoForm.nombre} onChange={e=>setNuevoForm({...nuevoForm,nombre:e.target.value})}/>
          </FormField>
          <FormField label="Correo electrónico">
            <input className="input" type="email" value={nuevoForm.correo} onChange={e=>setNuevoForm({...nuevoForm,correo:e.target.value})}/>
          </FormField>
          <FormField label="Contraseña inicial">
            <input className="input" type="password" value={nuevoForm.password} onChange={e=>setNuevoForm({...nuevoForm,password:e.target.value})}/>
          </FormField>
          <FormField label="Rol">
            <select className="select" value={nuevoForm.rol} onChange={e=>setNuevoForm({...nuevoForm,rol:e.target.value})}>
              {ROLES.map(r=><option key={r} value={r}>{r}</option>)}
            </select>
          </FormField>
          <FormField label="División SAP">
            <select className="select" value={nuevoForm.division} onChange={e=>setNuevoForm({...nuevoForm,division:e.target.value})}>
              {DIVISIONES.map(d=><option key={d}>{d}</option>)}
            </select>
          </FormField>
          <FormField label="Centro de beneficio *">
            <select className="select" required value={nuevoForm.centro_id} onChange={e=>setNuevoForm({...nuevoForm,centro_id:e.target.value})} style={{borderColor:!nuevoForm.centro_id?"var(--danger)":"var(--border)"}}>
              <option value="">— Sin centro —</option>
              {centros.map((c:any)=><option key={c.id} value={c.id}>{c.id} · {c.nombre}</option>)}
            </select>
          </FormField>
          <FormField label="Gerente directo">
            <select className="select" value={nuevoForm.gerente_id} onChange={e=>setNuevoForm({...nuevoForm,gerente_id:e.target.value})}>
              <option value="">— Sin gerente —</option>
              {usuarios.filter(u=>["gerente","admin"].includes(u.rol)).map((u:any)=><option key={u.id} value={u.id}>{u.nombre}</option>)}
            </select>
          </FormField>
        </Modal>
      )}

      {/* Modal editar */}
      {editando && (
        <Modal title={`Editar · ${editando.nombre}`} onClose={()=>setEditando(null)} onSave={guardar}>
          <FormField label="Nombre">
            <input className="input" value={editando.nombre||""} onChange={e=>setEditando({...editando,nombre:e.target.value})}/>
          </FormField>
          <FormField label="Correo">
            <input className="input" type="email" value={editando.correo||""} disabled/>
          </FormField>
          <FormField label="Rol">
            <select className="select" value={editando.rol} onChange={e=>setEditando({...editando,rol:e.target.value})}>
              {ROLES.map(r=><option key={r}>{r}</option>)}
            </select>
          </FormField>
          <FormField label="División">
            <select className="select" value={editando.division||"4105"} onChange={e=>setEditando({...editando,division:e.target.value})}>
              {DIVISIONES.map(d=><option key={d}>{d}</option>)}
            </select>
          </FormField>
          <FormField label="Centro">
            <select className="select" required value={editando.centro_id||""} onChange={e=>setEditando({...editando,centro_id:e.target.value||null})} style={{borderColor:!editando.centro_id?"var(--danger)":"var(--border)"}}>
              <option value="">— Sin centro —</option>
              {centros.map((c:any)=><option key={c.id} value={c.id}>{c.id} · {c.nombre}</option>)}
            </select>
          </FormField>
          <FormField label="Gerente">
            <select className="select" value={editando.gerente_id||""} onChange={e=>setEditando({...editando,gerente_id:e.target.value||null})}>
              <option value="">— Sin gerente —</option>
              {usuarios.filter(u=>["gerente","admin"].includes(u.rol)&&u.id!==editando.id).map((u:any)=><option key={u.id} value={u.id}>{u.nombre}</option>)}
            </select>
          </FormField>
          <FormField label="CLABE">
            <input className="input mono" value={editando.clabe||""} onChange={e=>setEditando({...editando,clabe:e.target.value})}/>
          </FormField>
          <FormField label="Banco">
            <input className="input" value={editando.banco||""} onChange={e=>setEditando({...editando,banco:e.target.value})}/>
          </FormField>
        </Modal>
      )}

      <input className="input" placeholder="Buscar por nombre, correo o rol…" value={busqueda}
        onChange={e=>setBusqueda(e.target.value)} style={{marginBottom:14,maxWidth:380}}/>

      <div className="card" style={{padding:0,overflow:"hidden"}}>
        {loading ? (
          <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
        ) : (
          <table className="t">
            <thead><tr><th>Usuario</th><th>Correo</th><th>Rol</th><th>División</th><th>Centro</th><th></th></tr></thead>
            <tbody>
              {filtrados.map((u:any)=>(
                <tr key={u.id}>
                  <td><div style={{display:"flex",alignItems:"center",gap:10}}>
                    <div style={{width:30,height:30,borderRadius:"50%",background:"var(--surface-2)",border:"1px solid var(--border)",display:"grid",placeItems:"center",fontSize:11,fontWeight:700,flexShrink:0}}>{u.iniciales||"??"}</div>
                    <span style={{fontWeight:500}}>{u.nombre}</span>
                  </div></td>
                  <td style={{fontSize:12,color:"var(--text-3)"}}>{u.correo}</td>
                  <td><span style={{fontSize:11,padding:"2px 10px",borderRadius:12,background:ROL_COLOR[u.rol]+"22",color:ROL_COLOR[u.rol],fontWeight:600}}>{u.rol}</span></td>
                  <td className="mono" style={{fontSize:12}}>{u.division||"4105"}</td>
                  <td style={{fontSize:12,color:"var(--text-3)"}}>{centros.find((c:any)=>c.id===u.centro_id)?.nombre||"—"}</td>
                  <td><div style={{display:"flex",gap:4}}>
                    <button className="btn sm ghost" onClick={()=>setEditando({...u})}>Editar</button>
                    <button className="btn sm ghost" onClick={()=>resetPassword(u.id)} title="Cambiar contraseña">🔑</button>
                    <button className="btn sm ghost" style={{color:"var(--danger)",borderColor:"var(--danger)"}} onClick={()=>desactivar(u.id,u.nombre)}>×</button>
                  </div></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}


