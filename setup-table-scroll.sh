#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/(app)/admin/usuarios/page.tsx')
cat > 'src/app/(app)/admin/usuarios/page.tsx' << 'FILEEOF'
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
          <FormField label="Centro de beneficio">
            <select className="select" value={nuevoForm.centro_id} onChange={e=>setNuevoForm({...nuevoForm,centro_id:e.target.value})}>
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
            <select className="select" value={editando.centro_id||""} onChange={e=>setEditando({...editando,centro_id:e.target.value||null})}>
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

      <div className="card" style={{padding:0,overflow:"auto"}}>
        {loading ? (
          <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
        ) : (
          <table className="t" style={{minWidth:700}}>
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/centros/page.tsx')
cat > 'src/app/(app)/admin/centros/page.tsx' << 'FILEEOF'
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/catalogo/page.tsx')
cat > 'src/app/(app)/admin/catalogo/page.tsx' << 'FILEEOF'
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/limites/page.tsx')
cat > 'src/app/(app)/admin/limites/page.tsx' << 'FILEEOF'
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/catalogo/page.tsx')
cat > 'src/app/(app)/contador/catalogo/page.tsx' << 'FILEEOF'
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/pagados/page.tsx')
cat > 'src/app/(app)/tesoreria/pagados/page.tsx' << 'FILEEOF'
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


FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/page.tsx')
cat > 'src/app/(app)/solicitudes/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect, useReducer } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import { fmtMXN, fmtFecha } from "@/lib/format"
import type { Solicitud, SolicitudStatus } from "@/types"

export default function MisSolicitudesPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)
  const [filtroTipo, setFiltroTipo] = useState("todos")
  const [filtroStatus, setFiltroStatus] = useState("todos")
  const [busqueda, setBusqueda] = useState("")

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      sb.from("solicitudes")
        .select("*, cfdi:comprobantes_cfdi(id, uuid, emisor, total, cuenta, archivo_url, rfc_emisor, rfc_receptor)")
        .eq("usuario_id", user.id)
        .order("fecha", { ascending: false })
        .then(({ data }) => {
          if (!data) { setLoading(false); return }
          setSolicitudes(data.map(s => ({
            id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
            monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha), status: s.status,
            saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
            anticipoRef: s.anticipo_ref, motivoRechazo: s.motivo_rechazo,
            cfdi: s.cfdi || [],
          })))
          setLoading(false)
        })
    })
  }, [])

  const filtradas = solicitudes
    .filter(s => {
      if (filtroTipo !== "todos" && s.tipo !== filtroTipo) return false
      if (filtroStatus !== "todos" && s.status !== filtroStatus) return false
      if (busqueda.trim()) {
        const q = busqueda.toLowerCase()
        if (!s.id.toLowerCase().includes(q) && !s.concepto.toLowerCase().includes(q)) return false
      }
      return true
    })
    .sort((a, b) => b.fecha.getTime() - a.fecha.getTime())

  const totalAbierto = solicitudes
    .filter(s => ["liberado","parcial"].includes(s.status) && (s.saldoPendiente || 0) > 0)
    .reduce((a, s) => a + (s.saldoPendiente || 0), 0)
  const totalGestionado = solicitudes
    .filter(s => ["liberado","comprobado"].includes(s.status))
    .reduce((a, s) => a + (s.monto || 0), 0)
  const enProceso = solicitudes.filter(s => ["solicitado","autorizado","validado","devuelto"].includes(s.status)).length
  const rechazadas = solicitudes.filter(s => s.status === "rechazado").length

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Mis solicitudes</h1>
          <div className="page-sub">Historial completo · {solicitudes.length} registros</div>
        </div>
        <button className="btn primary" onClick={() => router.push("/solicitudes/anticipo")}>
          + Nuevo anticipo
        </button>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 12, marginBottom: 16 }}>
        {[
          { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : "var(--success)" },
          { label: "En proceso", value: String(enProceso), color: undefined },
          { label: "Rechazadas", value: String(rechazadas), color: rechazadas > 0 ? "var(--danger)" : undefined },
        ].map(k => (
          <div key={k.label} className="card" style={{ textAlign: "center", padding: "14px 12px" }}>
            <div style={{ fontSize: 22, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: k.color }}>{k.value}</div>
            <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
          </div>
        ))}
      </div>

      {/* Filtros */}
      <div className="row" style={{ marginBottom: 14, gap: 8, flexWrap: "wrap" }}>
        <input className="input" style={{ flex: "1 1 160px" }} placeholder="Buscar por folio o concepto…"
          value={busqueda} onChange={e => setBusqueda(e.target.value)} />
        <select className="select" style={{ width: 160 }} value={filtroTipo} onChange={e => setFiltroTipo(e.target.value)}>
          <option value="todos">Todos los tipos</option>
          <option value="anticipo">Anticipos</option>
          <option value="comprobacion">Comprobaciones</option>
          <option value="reembolso">Reembolsos</option>
        </select>
        <select className="select" style={{ width: 160 }} value={filtroStatus} onChange={e => setFiltroStatus(e.target.value)}>
          <option value="todos">Todos los status</option>
          {["solicitado","autorizado","validado","liberado","parcial","comprobado","rechazado","devuelto"].map(s => (
            <option key={s} value={s} style={{ textTransform: "capitalize" }}>{s.charAt(0).toUpperCase()+s.slice(1)}</option>
          ))}
        </select>
      </div>

      {/* Tabla */}
      <div className="card" style={{ padding: 0, overflow: "auto" }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando solicitudes…</div>
        ) : filtradas.length === 0 ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Sin solicitudes con ese filtro</div>
        ) : (
          <table className="t" style={{minWidth:800}}>
            <thead>
              <tr>
                <th>Folio</th><th>Tipo</th><th>Concepto</th>
                <th>Fecha</th><th className="num">Monto</th>
                <th className="num">Saldo</th><th>Status</th><th></th>
              </tr>
            </thead>
            <tbody>
              {filtradas.map(s => (
                <tr key={s.id} style={{ cursor: "pointer" }}
                  onClick={() => router.push(`/solicitudes/${s.id}`)}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td><TipoBadge tipo={s.tipo} /></td>
                  <td style={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {s.concepto}
                  </td>
                  <td className="muted mono" style={{ fontSize: 12 }}>{fmtFecha(s.fecha)}</td>
                  <td className="num">{fmtMXN(s.monto)}</td>
                  <td className="num">
                    {s.tipo === "anticipo" && (s.saldoPendiente || 0) > 0
                      ? <span style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(s.saldoPendiente!)}</span>
                      : <span className="muted">—</span>}
                  </td>
                  <td><StatusBadge status={s.status} /></td>
                  <td className="num" onClick={e => e.stopPropagation()}>
                    {s.motivoRechazo && (
                      <span title={s.motivoRechazo} style={{ color: "var(--danger)", fontSize: 12, cursor: "help" }}>⚠</span>
                    )}
                    {["liberado","parcial"].includes(s.status) && s.tipo === "anticipo" && (
                      <>
                        {s.status === "parcial" && (
                          <button className="btn sm ghost" style={{ marginLeft: 4 }}
                            onClick={() => router.push(`/solicitudes/cierre?anticipo=${s.id}`)}>
                            Cerrar
                          </button>
                        )}
                        <button className="btn sm primary" style={{ marginLeft: 4 }}
                          onClick={() => router.push(`/solicitudes/comprobacion?anticipo=${s.id}`)}>
                          Comprobar
                        </button>
                      </>
                    )}
                    {s.tipo === "reembolso" && s.status === "solicitado" && (
                      <button className="btn sm ghost" style={{ marginLeft: 4 }}
                        onClick={() => router.push(`/solicitudes/reembolso?edit=${s.id}`)}>
                        Ver
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  )
}


FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/polizas/page.tsx')
cat > 'src/app/(app)/contador/polizas/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect, useMemo } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { generarPolizas, agruparPorPoliza } from "@/lib/polizas"
import { useCatalogos } from "@/hooks/useCatalogos"
import type { Solicitud, PolizaLinea } from "@/types"

export default function ContadorPolizasPage() {
  const { catalogoGastos, centros, usuarios, loaded } = useCatalogos()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loadingData, setLoadingData] = useState(true)
  const [expanded, setExpanded] = useState<string | null>(null)

  const hoy = new Date()
  const primerDiaMes = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, "0")}-01`
  const hoyStr = hoy.toISOString().slice(0, 10)

  const [fechaIni, setFechaIni] = useState(primerDiaMes)
  const [fechaFin, setFechaFin] = useState(hoyStr)
  const [centro, setCentro] = useState("todos")

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("*, cfdi:comprobantes_cfdi(*), items:solicitud_items(*)")
      .not("status", "in", '("solicitado","rechazado")')
      .order("fecha", { ascending: false })
      .then(({ data }) => {
        const mapped: Solicitud[] = (data || []).map((s: any) => ({
          id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
          monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha),
          status: s.status, saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
          anticipoRef: s.anticipo_ref, notas: s.notas,
          esCierre: !!(s.notas && s.notas.includes("CIERRE_DEPOSITO")),
          cfdi: (s.cfdi || []).map((c: any) => ({
            uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
            total: parseFloat(c.total) || 0, cuenta: c.cuenta,
            archivoUrl: c.archivo_url, rfcEmisor: c.rfc_emisor, rfcReceptor: c.rfc_receptor,
          })),
          items: (s.items || []).map((i: any) => ({
            cuenta: i.cuenta, desc: i.descripcion, monto: parseFloat(i.monto) || 0,
          })),
        }))
        setSolicitudes(mapped)
        setLoadingData(false)
      })
  }, [])

  const polizas = useMemo(() => {
    if (!loaded || loadingData) return []
    return agruparPorPoliza(generarPolizas(solicitudes, usuarios, centros, catalogoGastos, {
      desde: new Date(fechaIni + "T00:00:00"),
      hasta: new Date(fechaFin + "T23:59:59"),
      centro,
    }))
  }, [solicitudes, usuarios, centros, catalogoGastos, fechaIni, fechaFin, centro, loaded, loadingData])

  const exportarCSV = () => {
    const headers = ["Póliza","Folio","Fecha","Centro","División","Cuenta","Nombre Cuenta","T/D","Debe","Haber","Concepto","Proveedor"]
    const rows = polizas.flatMap(p => p.movs.map((l: PolizaLinea) => [
      l.poliza, l.folio, l.fecha, l.centro, l.division,
      l.cuenta, l.nombreCuenta, l.tipo === "C" ? "Cargo" : "Abono",
      l.debe || "", l.haber || "", l.concepto, l.proveedor,
    ]))
    const csv = [headers, ...rows].map(r => r.map(v => `"${v}"`).join(",")).join("\n")
    const a = document.createElement("a")
    a.href = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }))
    a.download = `polizas_${fechaIni}_${fechaFin}.csv`
    a.click()
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Pólizas contables</h1>
          <div className="page-sub">Asientos para carga en SAP (RFBIBL00)</div>
        </div>
        <button className="btn primary" onClick={exportarCSV} disabled={polizas.length === 0}>
          ↓ Exportar CSV
        </button>
      </div>

      {/* Filters */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          {[
            { label: "Desde", value: fechaIni, set: setFechaIni },
            { label: "Hasta", value: fechaFin, set: setFechaFin },
          ].map(({ label, value, set }) => (
            <div key={label}>
              <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>{label}</label>
              <input className="input" type="date" value={value} onChange={e => set(e.target.value)}
                style={{ width: 160 }} />
            </div>
          ))}
          <div>
            <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>Centro</label>
            <select className="select" value={centro} onChange={e => setCentro(e.target.value)} style={{ width: 200 }}>
              <option value="todos">Todos los centros</option>
              {centros.map(c => <option key={c.id} value={c.id}>{c.id} · {c.nombre}</option>)}
            </select>
          </div>
        </div>
      </div>

      {/* Summary */}
      {polizas.length > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 12, marginBottom: 16 }}>
          {[
            { label: "Pólizas", value: polizas.length },
            { label: "Total debe", value: fmtMXN(polizas.reduce((a, p) => a + p.debe, 0)) },
            { label: "Total haber", value: fmtMXN(polizas.reduce((a, p) => a + p.haber, 0)) },
          ].map(k => (
            <div key={k.label} className="card" style={{ textAlign: "center", padding: "12px" }}>
              <div style={{ fontSize: 20, fontWeight: 700 }}>{k.value}</div>
              <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>{k.label}</div>
            </div>
          ))}
        </div>
      )}

      {/* Polizas list */}
      {loadingData || !loaded ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>
          Cargando datos…
        </div>
      ) : polizas.length === 0 ? (
        <div className="card" style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>
          Sin pólizas en el período seleccionado
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {polizas.map(p => {
            const cuadrada = Math.abs(p.debe - p.haber) < 0.01
            const isOpen = expanded === p.ref
            return (
              <div key={p.ref} className="card" style={{ padding: 0, overflow: "auto" }}>
                {/* Header */}
                <div style={{ padding: "12px 16px", display: "flex", alignItems: "center",
                  gap: 12, cursor: "pointer" }}
                  onClick={() => setExpanded(isOpen ? null : p.ref)}>
                  <span className="mono" style={{ fontSize: 12, fontWeight: 700, color: "var(--accent)" }}>
                    {p.ref}
                  </span>
                  <span className="mono" style={{ fontSize: 11, color: "var(--text-3)" }}>{p.folio}</span>
                  <span style={{ fontSize: 12, flex: 1 }}>{p.fecha}</span>
                  <span style={{ fontWeight: 600 }}>{fmtMXN(p.debe)}</span>
                  <span style={{ fontSize: 10, padding: "2px 8px", borderRadius: 10, fontWeight: 600,
                    background: cuadrada ? "var(--success-soft)" : "var(--danger-soft)",
                    color: cuadrada ? "var(--success)" : "var(--danger)" }}>
                    {cuadrada ? "✓ Cuadrada" : "⚠ Descuadrada"}
                  </span>
                  <span style={{ color: "var(--text-3)", fontSize: 12 }}>{isOpen ? "▲" : "▼"}</span>
                </div>

                {/* Movimientos */}
                {isOpen && (
                  <div style={{ borderTop: "1px solid var(--border)" }}>
                    <table className="t">
                      <thead>
                        <tr>
                          <th>Cuenta</th><th>Descripción</th><th>T/D</th>
                          <th className="num">Debe</th><th className="num">Haber</th>
                          <th>Concepto</th>
                        </tr>
                      </thead>
                      <tbody>
                        {p.movs.map((l: PolizaLinea, i: number) => (
                          <tr key={i} style={{
                            background: l.tipo === "C" ? "rgba(100,200,100,.03)" : "rgba(100,150,255,.03)"
                          }}>
                            <td className="mono" style={{ fontSize: 11 }}>{l.cuenta}</td>
                            <td style={{ fontSize: 12 }}>{l.nombreCuenta}</td>
                            <td style={{ fontSize: 11, fontWeight: 600,
                              color: l.tipo === "C" ? "var(--success)" : "var(--accent)" }}>
                              {l.tipo === "C" ? "Cargo" : "Abono"}
                            </td>
                            <td className="num">{l.debe > 0 ? fmtMXN(l.debe) : "—"}</td>
                            <td className="num">{l.haber > 0 ? fmtMXN(l.haber) : "—"}</td>
                            <td style={{ fontSize: 11, maxWidth: 200, overflow: "hidden",
                              textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{l.concepto}</td>
                          </tr>
                        ))}
                      </tbody>
                      <tfoot>
                        <tr style={{ fontWeight: 700, borderTop: "2px solid var(--border)" }}>
                          <td colSpan={3} style={{ textAlign: "right", padding: "8px 12px", fontSize: 12 }}>Total</td>
                          <td className="num">{fmtMXN(p.debe)}</td>
                          <td className="num">{fmtMXN(p.haber)}</td>
                          <td />
                        </tr>
                      </tfoot>
                    </table>

                    {/* Adjuntos */}
                    {(() => {
                      const archivos = p.movs.flatMap((l: PolizaLinea) => l._archivos || [])
                        .filter((a: any) => a.url)
                        .filter((a: any, i: number, arr: any[]) => arr.findIndex((x: any) => x.url === a.url) === i)
                      if (!archivos.length) return null
                      return (
                        <div style={{ padding: "12px 16px", borderTop: "1px solid var(--border)",
                          background: "var(--surface-2)" }}>
                          <div style={{ fontSize: 11, fontWeight: 600, textTransform: "uppercase",
                            letterSpacing: ".06em", color: "var(--text-3)", marginBottom: 8 }}>
                            Comprobantes · {archivos.length}
                          </div>
                          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                            {archivos.map((a: any, i: number) => (
                              <a key={i} href={a.url} target="_blank" rel="noopener"
                                className="btn sm ghost" style={{ fontSize: 11 }}>
                                ↓ {a.emisor || a.nombre || `Archivo ${i + 1}`}
                              </a>
                            ))}
                          </div>
                        </div>
                      )
                    })()}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}


FILEEOF

git add .
git commit -m "fix: all admin/counter tables get overflow:auto + minWidth for mobile horizontal scroll"
git push
echo "✓ Done"