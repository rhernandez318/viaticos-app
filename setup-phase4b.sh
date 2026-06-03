#!/bin/bash
set -e

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

      <div className="card" style={{padding:0,overflow:"hidden"}}>
        <table className="t">
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

      <div className="card" style={{padding:0,overflow:"hidden"}}>
        <table className="t">
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

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/cierre/page.tsx')
cat > 'src/app/(app)/solicitudes/cierre/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef, Suspense } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import type { Solicitud } from "@/types"

function CierreInner() {
  const router = useRouter()
  const params = useSearchParams()
  const anticipoId = params.get("anticipo")
  const fileRef = useRef<HTMLInputElement>(null)

  const [anticipo, setAnticipo] = useState<Solicitud|null>(null)
  const [referencia, setReferencia] = useState("")
  const [fechaDeposito, setFechaDeposito] = useState(new Date().toISOString().slice(0,10))
  const [archivo, setArchivo] = useState<File|null>(null)
  const [enviando, setEnviando] = useState(false)
  const [toast, setToast] = useState<string|null>(null)

  const showToast = (m:string) => { setToast(m); setTimeout(()=>setToast(null),3500) }

  useEffect(()=>{
    if (!anticipoId) return
    const sb = createClient()
    sb.from("solicitudes").select("*").eq("id",anticipoId).single()
      .then(({data})=>{
        if (data) setAnticipo({
          id:data.id, tipo:data.tipo, concepto:data.concepto, usuario:data.usuario_id,
          monto:parseFloat(data.monto)||0, fecha:new Date(data.fecha), status:data.status,
          saldoPendiente:parseFloat(data.saldo_pendiente)||0, cfdi:[],
        })
      })
  },[anticipoId])

  const handleCierre = async () => {
    if (!anticipo) { showToast("⚠ Anticipo no encontrado"); return }
    if (!referencia.trim()) { showToast("⚠ Ingresa la referencia del depósito"); return }
    if (!fechaDeposito) { showToast("⚠ Ingresa la fecha del depósito"); return }
    const saldo = anticipo.saldoPendiente || 0
    if (saldo <= 0) { showToast("⚠ Este anticipo ya tiene saldo cero"); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    let archivoUrl: string|null = null
    if (archivo) {
      const ext = archivo.name.split(".").pop()
      const path = `cierres/${anticipo.id}-${Date.now()}.${ext}`
      const { data: up } = await sb.storage.from("comprobantes").upload(path, archivo, { upsert:true })
      if (up) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }
    }

    const id = "CIE-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)
    const { error } = await sb.from("solicitudes").insert({
      id, tipo:"comprobacion",
      concepto:`[CIERRE] Reintegro de saldo · ${anticipo.id}`,
      usuario_id:user.id, monto:saldo, status:"solicitado",
      anticipo_ref:anticipo.id, saldo_pendiente:0, comprobantes: archivoUrl?1:0,
      notas:`CIERRE_DEPOSITO · Ref: ${referencia.trim()} · Fecha: ${fechaDeposito}${archivoUrl?" · URL: "+archivoUrl:""}`,
      fecha:new Date().toISOString(),
    })
    if (error) { showToast("⚠ "+error.message); setEnviando(false); return }

    if (archivoUrl) {
      await sb.from("comprobantes_cfdi").insert({
        solicitud_id:id,
        uuid:`CIERRE-${id}`, emisor:user.email||"Usuario",
        concepto:`Depósito de reintegro · Ref: ${referencia.trim()} · ${fechaDeposito}`,
        subtotal:saldo, iva:0, total:saldo, cuenta:"1110000001", confianza:1.0,
        archivo_url:archivoUrl,
      })
    }

    await sb.from("bitacora").insert({
      solicitud_id:id, accion:"solicitado", usuario_id:user.id,
      detalle:`Cierre de anticipo ${anticipo.id} · saldo ${fmtMXN(saldo)} · ref ${referencia}`,
      ts:new Date().toISOString(),
    })

    showToast("✓ Cierre enviado a autorización")
    setTimeout(()=>router.push("/solicitudes"),1500)
  }

  if (!anticipoId) return (
    <div className="card" style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>
      No se especificó un anticipo. <a href="/solicitudes" style={{color:"var(--accent)"}}>← Mis solicitudes</a>
    </div>
  )

  return (
    <div style={{maxWidth:560}}>
      <div className="page-head">
        <div><h1 className="page-title">Cerrar anticipo</h1><div className="page-sub">Reintegra el saldo no comprobado</div></div>
      </div>

      {anticipo && (
        <div className="card" style={{marginBottom:16,borderColor:"var(--warn)"}}>
          <div className="spread">
            <div>
              <div style={{fontWeight:600}}>{anticipo.id}</div>
              <div style={{fontSize:13,color:"var(--text-2)"}}>{anticipo.concepto}</div>
              <div style={{fontSize:12,color:"var(--text-3)",marginTop:4}}>{fmtFecha(anticipo.fecha)}</div>
            </div>
            <div style={{textAlign:"right"}}>
              <div style={{fontSize:11,color:"var(--text-3)"}}>Saldo a reintegrar</div>
              <div style={{fontSize:22,fontWeight:700,color:"var(--warn)"}}>{fmtMXN(anticipo.saldoPendiente||0)}</div>
            </div>
          </div>
        </div>
      )}

      <div className="card" style={{marginBottom:16}}>
        <div style={{display:"grid",gap:14}}>
          <div>
            <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>Referencia del depósito *</label>
            <input className="input" value={referencia} onChange={e=>setReferencia(e.target.value)}
              placeholder="Ej: 1234567890 (número de operación bancaria)"/>
          </div>
          <div>
            <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>Fecha del depósito *</label>
            <input className="input" type="date" value={fechaDeposito} onChange={e=>setFechaDeposito(e.target.value)}/>
          </div>
          <div>
            <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>Comprobante del depósito (opcional)</label>
            <div style={{display:"flex",gap:8,alignItems:"center"}}>
              <button className="btn ghost" onClick={()=>fileRef.current?.click()}>
                📎 {archivo ? archivo.name : "Subir comprobante"}
              </button>
              {archivo && <button onClick={()=>setArchivo(null)} style={{background:"none",border:"none",color:"var(--text-3)",cursor:"pointer"}}>×</button>}
            </div>
            <input ref={fileRef} type="file" accept=".pdf,image/*" hidden onChange={e=>setArchivo(e.target.files?.[0]||null)}/>
          </div>
        </div>
      </div>

      {toast && <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background:toast.startsWith("✓")?"var(--success-soft)":"var(--danger-soft)",
        color:toast.startsWith("✓")?"var(--success)":"var(--danger)"}}>{toast}</div>}

      <div style={{display:"flex",justifyContent:"flex-end",gap:10}}>
        <button className="btn ghost" onClick={()=>router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleCierre} disabled={enviando||!anticipo}>
          {enviando?"Procesando…":"Enviar cierre →"}
        </button>
      </div>
    </div>
  )
}

export default function CierrePage() {
  return <Suspense fallback={<div style={{padding:40,color:"var(--text-3)"}}>Cargando…</div>}><CierreInner/></Suspense>
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/validacion-sat/page.tsx')
cat > 'src/app/(app)/contador/validacion-sat/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useMemo } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export default function ValidacionSATPage() {
  const [cfdis, setCfdis] = useState<any[]>([])
  const [resultados, setResultados] = useState<any[]|null>(null)
  const [validando, setValidando] = useState(false)
  const [progreso, setProgreso] = useState(0)
  const [mes, setMes] = useState(()=>new Date().toISOString().slice(0,7))
  const [loading, setLoading] = useState(true)

  useEffect(()=>{
    const sb = createClient()
    sb.from("comprobantes_cfdi")
      .select("uuid, rfc_emisor, rfc_receptor, total, emisor, solicitud_id, solicitudes!inner(fecha)")
      .not("uuid","like","CIERRE%").then(({data})=>{
        setCfdis(data||[]); setLoading(false)
      })
  },[])

  const cfdisDelMes = useMemo(()=>{
    return cfdis.filter(c=>{
      const uuid = (c.uuid||"").trim()
      if (!uuid||uuid.endsWith("…")||uuid.endsWith("...")||!UUID_RE.test(uuid)) return false
      const fecha = c.solicitudes?.fecha
      if (!fecha) return false
      return fecha.slice(0,7) === mes
    }).reduce((acc:any[],c)=>{
      if (!acc.find(x=>x.uuid===c.uuid)) acc.push(c)
      return acc
    },[])
  },[cfdis,mes])

  const validar = async () => {
    if (!cfdisDelMes.length) return
    setValidando(true); setResultados(null); setProgreso(0)
    const LOTE = 20
    const todos: any[] = []
    for (let i=0; i<cfdisDelMes.length; i+=LOTE) {
      const lote = cfdisDelMes.slice(i,i+LOTE).map(c=>({
        uuid:c.uuid, rfcEmisor:c.rfc_emisor||"", rfcReceptor:c.rfc_receptor||"", total:c.total||0,
        emisor:c.emisor||"", folio:c.solicitud_id,
      }))
      const res = await fetch("/api/sat/validate", {
        method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({cfdis:lote})
      })
      const data = await res.json()
      todos.push(...(data.resultados||[]).map((r:any,j:number)=>({...r, emisor:lote[j]?.emisor, folio:lote[j]?.folio})))
      setProgreso(Math.round(((i+lote.length)/cfdisDelMes.length)*100))
    }
    setResultados(todos); setValidando(false)
  }

  const exportCSV = () => {
    if (!resultados) return
    const rows = [["Folio","UUID","Emisor","Estado","Método","URL Verificación"],
      ...resultados.map(r=>[r.folio||"",r.uuid,r.emisor||"",r.estado,r.metodo||"",r.urlVerificacionSAT||""])]
    const csv = rows.map(r=>r.map(v=>`"${v}"`).join(",")).join("\n")
    const a = document.createElement("a"); a.href=URL.createObjectURL(new Blob(["\uFEFF"+csv],{type:"text/csv"}))
    a.download=`validacion_sat_${mes}.csv`; a.click()
  }

  const resumen = useMemo(()=>{
    if (!resultados) return null
    return {
      vigentes: resultados.filter(r=>r.estado==="Vigente").length,
      cancelados: resultados.filter(r=>r.estado==="Cancelado").length,
      noEncontrados: resultados.filter(r=>r.estado==="No Encontrado").length,
      locales: resultados.filter(r=>r.metodo==="local"&&r.valido!==false).length,
      errores: resultados.filter(r=>!r.valido||r.estado==="Error").length,
    }
  },[resultados])

  const estadoColor = (e:string) => ({
    "Vigente":"var(--success)","Cancelado":"var(--danger)",
    "No Encontrado":"var(--warn)","Estructura válida":"var(--accent)","Error":"var(--text-3)"
  }[e]||"var(--text-3)")

  const pdfsOImagenes = cfdis.filter(c=>{
    const uuid=(c.uuid||"").trim()
    const fecha=c.solicitudes?.fecha
    return (!fecha||fecha.slice(0,7)===mes)&&(!uuid||!UUID_RE.test(uuid))&&!uuid.startsWith("CIERRE")
  }).length

  const truncados = cfdis.filter(c=>{
    const uuid=(c.uuid||"").trim()
    const fecha=c.solicitudes?.fecha
    return (fecha?.slice(0,7)===mes)&&(uuid.endsWith("…")||uuid.endsWith("..."))
  }).length

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Validación SAT</h1><div className="page-sub">Verifica el estatus de CFDIs ante el SAT</div></div>
        {resultados && <button className="btn ghost" onClick={exportCSV}>↓ CSV</button>}
      </div>

      {(pdfsOImagenes>0||truncados>0) && (
        <div className="card" style={{marginBottom:16,fontSize:12.5}}>
          <div style={{fontWeight:600,marginBottom:6}}>📋 Resumen del mes {mes}</div>
          <div style={{color:"var(--text-2)",lineHeight:1.7}}>
            <div>✓ <strong>{cfdisDelMes.length}</strong> CFDIs con UUID válido — serán validados</div>
            {pdfsOImagenes>0&&<div>📎 <strong>{pdfsOImagenes}</strong> PDFs/imágenes — no aplica validación SAT</div>}
            {truncados>0&&<div style={{color:"var(--warn)"}}>⚠ <strong>{truncados}</strong> UUIDs truncados en BD — sube el XML de nuevo</div>}
          </div>
        </div>
      )}

      <div className="card" style={{marginBottom:16}}>
        <div style={{display:"flex",gap:12,alignItems:"flex-end",flexWrap:"wrap"}}>
          <div>
            <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>Mes a validar</label>
            <input className="input" type="month" value={mes} onChange={e=>{setMes(e.target.value);setResultados(null)}} style={{width:160}}/>
          </div>
          <button className="btn primary" onClick={validar} disabled={validando||cfdisDelMes.length===0}>
            {validando?`Validando… ${progreso}%`:`Validar ${cfdisDelMes.length} CFDIs ante SAT`}
          </button>
          {validando && (
            <div style={{flex:1,height:6,background:"var(--border)",borderRadius:4,minWidth:160}}>
              <div style={{height:"100%",width:progreso+"%",background:"var(--accent)",borderRadius:4,transition:"width .3s"}}/>
            </div>
          )}
        </div>
      </div>

      {resumen && (
        <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(120px,1fr))",gap:10,marginBottom:16}}>
          {[
            {label:"Vigentes",value:resumen.vigentes,color:"var(--success)"},
            {label:"Cancelados",value:resumen.cancelados,color:"var(--danger)"},
            {label:"No encontrados",value:resumen.noEncontrados,color:"var(--warn)"},
            {label:"Solo local *",value:resumen.locales,color:"var(--accent)"},
          ].map(k=>(
            <div key={k.label} className="card" style={{textAlign:"center",padding:"12px 8px"}}>
              <div style={{fontSize:24,fontWeight:700,color:k.color}}>{k.value}</div>
              <div style={{fontSize:11,color:"var(--text-3)",marginTop:2}}>{k.label}</div>
            </div>
          ))}
        </div>
      )}

      {resultados && (
        <div className="card" style={{padding:0,overflow:"auto"}}>
          <table className="t" style={{fontSize:12}}>
            <thead><tr>
              <th>Folio</th>
              <th style={{minWidth:295}}>UUID</th>
              <th>Emisor</th>
              <th>Estado</th>
              <th>Método</th>
              <th>SAT.gob</th>
            </tr></thead>
            <tbody>
              {resultados.map((r,i)=>(
                <tr key={i}>
                  <td className="mono" style={{fontSize:10}}>{r.folio}</td>
                  <td style={{fontFamily:"monospace",fontSize:10.5,wordBreak:"break-all"}}>
                    <span onClick={()=>navigator.clipboard.writeText(r.uuid)}
                      style={{cursor:"pointer",padding:"2px 6px",borderRadius:4,display:"inline-block"}}
                      title="Clic para copiar">{r.uuid}</span>
                  </td>
                  <td style={{fontSize:11}}>{r.emisor||"—"}</td>
                  <td>
                    <span style={{fontSize:10,padding:"2px 8px",borderRadius:10,fontWeight:600,
                      background:estadoColor(r.estado)+"22",color:estadoColor(r.estado)}}>
                      {r.estado==="Vigente"?"✓ Vigente":r.estado==="Cancelado"?"✗ Cancelado":r.estado}
                    </span>
                  </td>
                  <td>
                    <span style={{fontSize:10,padding:"2px 6px",borderRadius:8,
                      background:r.metodo==="sat-soap"?"var(--success-soft)":"var(--surface-2)",
                      color:r.metodo==="sat-soap"?"var(--success)":"var(--text-3)"}}>
                      {r.metodo==="sat-soap"?"SAT":"Local"}
                    </span>
                  </td>
                  <td>
                    {r.urlVerificacionSAT
                      ? <a href={r.urlVerificacionSAT} target="_blank" rel="noopener"
                          style={{fontSize:11,color:"var(--accent)"}}>Verificar ↗</a>
                      : <span style={{fontSize:10,color:"var(--text-3)"}}>Sin RFC</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {!resultados && !validando && cfdisDelMes.length>0 && (
        <div className="card" style={{padding:32,textAlign:"center",color:"var(--text-3)"}}>
          <div style={{fontSize:32,marginBottom:12}}>🛡</div>
          <div style={{fontWeight:600,marginBottom:6}}>{cfdisDelMes.length} CFDIs listos para validar</div>
          <div style={{fontSize:12.5,lineHeight:1.6}}>
            Se verificará RFC, monto y estructura localmente. Si el SAT responde, también se consulta el estatus de cancelación.
          </div>
          {truncados>0&&<div style={{marginTop:10,fontSize:11.5,color:"var(--text-3)",padding:"8px 12px",background:"var(--surface-2)",borderRadius:8}}>
            * CFDIs "Solo local" tienen estructura válida pero el SAT no respondió. Usa "Verificar ↗" en tu navegador.
          </div>}
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/conciliacion-sat/page.tsx')
cat > 'src/app/(app)/contador/conciliacion-sat/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef } from "react"
import { createClient } from "@/lib/supabase/client"

export default function ConciliacionSATPage() {
  const [sistemaCfdis, setSistemaCfdis] = useState<Set<string>>(new Set())
  const [resultado, setResultado] = useState<any|null>(null)
  const [procesando, setProcesando] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  useEffect(()=>{
    const sb = createClient()
    sb.from("comprobantes_cfdi").select("uuid")
      .not("uuid","like","CIERRE%").not("uuid","like","SIN-UUID%")
      .then(({data})=>{
        setSistemaCfdis(new Set((data||[]).map((c:any)=>(c.uuid||"").toUpperCase().trim()).filter(Boolean)))
      })
  },[])

  const procesarMetadata = async (file: File) => {
    setProcesando(true)
    const text = await file.text()
    const lines = text.split(/\r?\n/).filter(Boolean)
    if (!lines.length) { setProcesando(false); return }

    // Detect separator and header
    const sep = lines[0].includes("\t") ? "\t" : ","
    const headers = lines[0].split(sep).map(h=>h.toLowerCase().replace(/["\s]/g,""))
    const rows = lines.slice(1).map(l=>l.split(sep).map(v=>v.replace(/^"|"$/g,"").trim()))

    const getCol = (row: string[], ...names: string[]) => {
      for (const n of names) {
        const i = headers.findIndex(h=>h.includes(n.toLowerCase()))
        if (i>=0) return row[i]||""
      }
      return ""
    }

    const satUuids: Map<string,any> = new Map()
    rows.forEach(row=>{
      const uuid = getCol(row,"uuid","folio","folioFiscal").toUpperCase().trim()
      if (!uuid||uuid.length<30) return
      satUuids.set(uuid,{
        uuid, rfcEmisor:getCol(row,"rfcemisor","rfcE","emisor"),
        razonSocial:getCol(row,"nombreemisor","razonsocial","emisor"),
        total:getCol(row,"total","monto"),
        fecha:getCol(row,"fechaemision","fecha"),
        estado:getCol(row,"estado","estatus"),
      })
    })

    // Cross-reference
    const enSATNoSistema: any[] = []
    const enSistemaNoSAT: string[] = []
    const coinciden: number[] = []

    satUuids.forEach((v,uuid)=>{
      if (sistemaCfdis.has(uuid)) coinciden.push(1)
      else enSATNoSistema.push(v)
    })
    sistemaCfdis.forEach(uuid=>{
      if (!satUuids.has(uuid)) enSistemaNoSAT.push(uuid)
    })

    setResultado({ total:satUuids.size, enSATNoSistema, enSistemaNoSAT, coinciden:coinciden.length })
    setProcesando(false)
  }

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Conciliación SAT</h1>
          <div className="page-sub">Cruza el Metadata del portal SAT contra los CFDIs del sistema</div></div>
      </div>

      <div className="card" style={{marginBottom:16}}>
        <div style={{fontSize:13,color:"var(--text-2)",marginBottom:12,lineHeight:1.6}}>
          Descarga el archivo <strong>Metadata</strong> desde el Portal del SAT:<br/>
          <span style={{fontSize:11.5,color:"var(--text-3)"}}>Facturas → Consultar → Descarga masiva → Metadata → Exportar CSV o TXT</span>
        </div>
        <div style={{display:"flex",gap:10,alignItems:"center"}}>
          <button className="btn primary" onClick={()=>fileRef.current?.click()} disabled={procesando}>
            📂 {procesando?"Procesando…":"Subir Metadata SAT"}
          </button>
          <span style={{fontSize:12,color:"var(--text-3)"}}>Formatos: .csv, .txt, .xlsx</span>
          <input ref={fileRef} type="file" accept=".csv,.txt,.xlsx" hidden
            onChange={e=>{ const f=e.target.files?.[0]; if(f) procesarMetadata(f) }}/>
        </div>
      </div>

      {resultado && (
        <>
          {/* Summary cards */}
          <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:10,marginBottom:16}}>
            {[
              {label:"En SAT",value:resultado.total,color:undefined},
              {label:"Coinciden",value:resultado.coinciden,color:"var(--success)"},
              {label:"En SAT, no en sistema",value:resultado.enSATNoSistema.length,color:resultado.enSATNoSistema.length>0?"var(--warn)":undefined},
              {label:"En sistema, no en SAT",value:resultado.enSistemaNoSAT.length,color:resultado.enSistemaNoSAT.length>0?"var(--danger)":undefined},
            ].map(k=>(
              <div key={k.label} className="card" style={{textAlign:"center",padding:"12px 8px"}}>
                <div style={{fontSize:24,fontWeight:700,color:k.color}}>{k.value}</div>
                <div style={{fontSize:11,color:"var(--text-3)",marginTop:2}}>{k.label}</div>
              </div>
            ))}
          </div>

          {/* En SAT pero no en sistema */}
          {resultado.enSATNoSistema.length>0&&(
            <div className="card" style={{marginBottom:16}}>
              <div style={{fontWeight:600,marginBottom:10,color:"var(--warn)"}}>
                ⚠ Facturas en SAT que no están en el sistema ({resultado.enSATNoSistema.length})
              </div>
              <div style={{fontSize:12,color:"var(--text-3)",marginBottom:10}}>
                Estas facturas fueron emitidas a tu RFC pero nadie las comprobó en el sistema.
              </div>
              <table className="t">
                <thead><tr><th>UUID</th><th>Emisor</th><th>Total</th><th>Fecha</th><th>Estado</th></tr></thead>
                <tbody>
                  {resultado.enSATNoSistema.slice(0,50).map((c:any)=>(
                    <tr key={c.uuid}>
                      <td className="mono" style={{fontSize:10}}>{c.uuid.slice(0,20)}…</td>
                      <td style={{fontSize:11}}>{c.razonSocial||c.rfcEmisor||"—"}</td>
                      <td className="num">{c.total}</td>
                      <td style={{fontSize:11}}>{c.fecha}</td>
                      <td><span style={{fontSize:10,padding:"2px 6px",borderRadius:8,
                        background:"var(--warn-soft)",color:"var(--warn)"}}>{c.estado||"—"}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* En sistema pero no en SAT */}
          {resultado.enSistemaNoSAT.length>0&&(
            <div className="card">
              <div style={{fontWeight:600,marginBottom:10,color:"var(--danger)"}}>
                ✗ Comprobantes en sistema sin CFDI en SAT ({resultado.enSistemaNoSAT.length})
              </div>
              <div style={{fontSize:12,color:"var(--text-3)",marginBottom:10}}>
                Estos UUIDs están en el sistema pero no aparecen en el Metadata del SAT. Podrían ser cancelados o con UUID incorrecto.
              </div>
              <div style={{display:"flex",flexWrap:"wrap",gap:6}}>
                {resultado.enSistemaNoSAT.slice(0,30).map((uuid:string)=>(
                  <span key={uuid} className="mono" style={{fontSize:10,padding:"3px 8px",borderRadius:6,
                    background:"var(--danger-soft)",color:"var(--danger)"}}>{uuid.slice(0,18)}…</span>
                ))}
              </div>
            </div>
          )}
        </>
      )}

      {!resultado && (
        <div className="card" style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>
          <div style={{fontSize:32,marginBottom:12}}>📊</div>
          <div style={{fontWeight:600,marginBottom:6}}>Sube el Metadata del SAT para comenzar</div>
          <div style={{fontSize:12.5}}>El sistema tiene <strong>{sistemaCfdis.size}</strong> CFDIs registrados listos para cruzar.</div>
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/trazabilidad/page.tsx')
cat > 'src/app/(app)/contador/trazabilidad/page.tsx' << 'FILEEOF'
"use client"
import { useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import Link from "next/link"

export default function TrazabilidadPage() {
  const [folio, setFolio] = useState("")
  const [buscando, setBuscando] = useState(false)
  const [resultado, setResultado] = useState<any|null>(null)
  const [error, setError] = useState<string|null>(null)

  const buscar = async (id?: string) => {
    const f = (id || folio).trim().toUpperCase()
    if (!f) return
    setBuscando(true); setResultado(null); setError(null)
    const sb = createClient()

    const { data: sol } = await sb.from("solicitudes")
      .select("*, cfdi:comprobantes_cfdi(*), items:solicitud_items(*)")
      .eq("id", f).maybeSingle()

    if (!sol) { setError(`No encontrado: ${f}`); setBuscando(false); return }

    const [bitacoraRes, usuarioRes, anticipoRes, compsRes] = await Promise.all([
      sb.from("bitacora").select("*, actor:usuarios!usuario_id(nombre)").eq("solicitud_id",f).order("ts",{ascending:true}),
      sb.from("usuarios").select("nombre,iniciales,division,rol").eq("id",sol.usuario_id).maybeSingle(),
      sol.anticipo_ref ? sb.from("solicitudes").select("id,concepto,monto,status").eq("id",sol.anticipo_ref).maybeSingle() : Promise.resolve({data:null}),
      sb.from("solicitudes").select("id,concepto,monto,status,tipo").eq("anticipo_ref",f),
    ])

    setResultado({
      sol, bitacora:bitacoraRes.data||[], usuario:usuarioRes.data,
      anticipoPadre:anticipoRes.data, comprobacionesLigadas:compsRes.data||[],
    })
    setBuscando(false)
  }

  const { sol, bitacora, usuario, anticipoPadre, comprobacionesLigadas } = resultado || {}

  const ACCION_COLOR: Record<string,string> = {
    solicitado:"var(--text-3)",autorizado:"var(--accent)",liberado:"#60a5fa",
    comprobado:"var(--success)",rechazado:"var(--danger)",
  }

  return (
    <div style={{maxWidth:800}}>
      <div className="page-head">
        <div><h1 className="page-title">Trazabilidad</h1><div className="page-sub">Rastrea el ciclo completo de una solicitud</div></div>
      </div>

      {/* Search */}
      <div className="card" style={{marginBottom:16}}>
        <div style={{display:"flex",gap:10}}>
          <input className="input" value={folio} onChange={e=>setFolio(e.target.value.toUpperCase())}
            onKeyDown={e=>e.key==="Enter"&&buscar()}
            placeholder="Ej: ANT-2026-1234 o REE-2026-5678"
            style={{flex:1,fontFamily:"monospace"}}/>
          <button className="btn primary" onClick={()=>buscar()} disabled={buscando||!folio.trim()}>
            {buscando?"Buscando…":"🔍 Rastrear"}
          </button>
        </div>
      </div>

      {error && <div style={{padding:"10px 14px",borderRadius:8,marginBottom:16,background:"var(--danger-soft)",color:"var(--danger)",fontSize:13}}>{error}</div>}

      {resultado && (
        <>
          {/* Header */}
          <div className="card" style={{marginBottom:12}}>
            <div style={{display:"flex",gap:10,alignItems:"center",marginBottom:8}}>
              <TipoBadge tipo={sol.tipo}/>
              <StatusBadge status={sol.status}/>
              {sol.notas?.includes("CIERRE_DEPOSITO")&&<span style={{fontSize:11,padding:"2px 8px",borderRadius:12,background:"var(--accent-soft)",color:"var(--accent)",fontWeight:600}}>🏦 CIERRE</span>}
              <span className="mono" style={{fontSize:11,color:"var(--text-3)"}}>{sol.id}</span>
            </div>
            <div style={{fontWeight:600,fontSize:16,marginBottom:4}}>{sol.concepto}</div>
            <div style={{display:"flex",gap:20,fontSize:12,color:"var(--text-3)"}}>
              <span>👤 {usuario?.nombre||"—"}</span>
              <span>📅 {fmtFecha(sol.fecha)}</span>
              <span>💵 {fmtMXN(parseFloat(sol.monto))}</span>
            </div>
            {anticipoPadre&&<div style={{marginTop:8,padding:"8px 12px",background:"var(--warn-soft)",borderRadius:8,fontSize:12}}>
              Comprobación del anticipo: <button onClick={()=>{setFolio(anticipoPadre.id);buscar(anticipoPadre.id)}}
                style={{background:"none",border:"none",color:"var(--warn)",fontWeight:600,cursor:"pointer",fontFamily:"monospace"}}>{anticipoPadre.id}</button>
            </div>}
          </div>

          {/* Timeline */}
          <div className="card" style={{marginBottom:12}}>
            <div style={{fontWeight:600,fontSize:13,marginBottom:14}}>Línea de tiempo</div>
            {bitacora.length===0 ? (
              <div style={{color:"var(--text-3)",fontSize:12}}>Sin registros en bitácora. Las nuevas transacciones sí quedan registradas.</div>
            ) : (
              <div style={{display:"flex",flexDirection:"column",gap:0}}>
                {bitacora.map((b:any,i:number)=>(
                  <div key={b.id} style={{display:"flex",gap:14,paddingBottom:i<bitacora.length-1?16:0,position:"relative"}}>
                    {i<bitacora.length-1&&<div style={{position:"absolute",left:11,top:24,width:2,height:"calc(100% - 8px)",background:"var(--border)"}}/>}
                    <div style={{width:24,height:24,borderRadius:"50%",flexShrink:0,
                      background:ACCION_COLOR[b.accion]||"var(--text-3)",
                      display:"grid",placeItems:"center",fontSize:10,color:"#000",fontWeight:700,position:"relative",zIndex:1}}>
                      {i+1}
                    </div>
                    <div style={{flex:1,paddingTop:3}}>
                      <div style={{fontSize:13,fontWeight:600,textTransform:"capitalize",color:ACCION_COLOR[b.accion]||"var(--text)"}}>{b.accion}</div>
                      <div style={{fontSize:11,color:"var(--text-3)",marginTop:1}}>{b.actor?.nombre||"Sistema"} · {fmtFecha(b.ts)}</div>
                      {b.detalle&&<div style={{fontSize:11,color:"var(--text-2)",marginTop:2}}>{b.detalle}</div>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* CFDIs */}
          {sol.cfdi?.length>0&&(
            <div className="card" style={{marginBottom:12}}>
              <div style={{fontWeight:600,fontSize:13,marginBottom:12}}>Comprobantes · {sol.cfdi.length}</div>
              <table className="t">
                <thead><tr><th>UUID</th><th>Emisor</th><th>Cuenta</th><th className="num">Total</th><th>SAT</th><th></th></tr></thead>
                <tbody>
                  {sol.cfdi.map((cf:any)=>(
                    <tr key={cf.id}>
                      <td className="mono" style={{fontSize:10}}>{cf.uuid?cf.uuid.slice(0,20)+"…":"—"}</td>
                      <td style={{fontSize:11}}>{cf.emisor||"—"}</td>
                      <td className="mono" style={{fontSize:10}}>{cf.cuenta}</td>
                      <td className="num">{fmtMXN(parseFloat(cf.total))}</td>
                      <td>{cf.sat_estado&&<span style={{fontSize:10,padding:"2px 6px",borderRadius:8,
                        background:cf.sat_estado==="Vigente"?"var(--success-soft)":"var(--warn-soft)",
                        color:cf.sat_estado==="Vigente"?"var(--success)":"var(--warn)"}}>{cf.sat_estado}</span>}</td>
                      <td>{cf.archivo_url&&<a href={cf.archivo_url} target="_blank" rel="noopener" className="btn sm ghost" style={{fontSize:11}}>↓</a>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Comprobaciones ligadas */}
          {comprobacionesLigadas.length>0&&(
            <div className="card">
              <div style={{fontWeight:600,fontSize:13,marginBottom:12}}>Comprobaciones ligadas · {comprobacionesLigadas.length}</div>
              {comprobacionesLigadas.map((c:any)=>(
                <div key={c.id} style={{display:"flex",justifyContent:"space-between",padding:"8px 0",borderBottom:"1px solid var(--border)",alignItems:"center"}}>
                  <div>
                    <button onClick={()=>{setFolio(c.id);buscar(c.id)}}
                      style={{background:"none",border:"none",color:"var(--accent)",fontWeight:600,cursor:"pointer",fontFamily:"monospace",fontSize:12}}>
                      {c.id}
                    </button>
                    <span style={{fontSize:12,color:"var(--text-3)",marginLeft:8}}>{c.concepto}</span>
                  </div>
                  <div style={{display:"flex",gap:8,alignItems:"center"}}>
                    <span className={`badge ${c.status}`}>{c.status}</span>
                    <span style={{fontWeight:600}}>{fmtMXN(parseFloat(c.monto))}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/gerente/equipo/page.tsx')
cat > 'src/app/(app)/gerente/equipo/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

export default function GerenteEquipoPage() {
  const router = useRouter()
  const [equipo, setEquipo] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(()=>{
    const sb = createClient()
    sb.auth.getUser().then(({data:{user}})=>{
      if(!user) return
      sb.from("usuarios").select("id,nombre,iniciales,correo,rol,division,solicitudes(id,status,monto,saldo_pendiente,tipo)")
        .eq("gerente_id",user.id).eq("activo",true).order("nombre")
        .then(({data})=>{ setEquipo(data||[]); setLoading(false) })
    })
  },[])

  return (
    <>
      <div className="page-head">
        <div><h1 className="page-title">Mi equipo</h1><div className="page-sub">{equipo.length} personas</div></div>
      </div>
      {loading ? (
        <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
      ) : equipo.length===0 ? (
        <div className="card" style={{padding:48,textAlign:"center"}}>
          <div style={{fontSize:36,marginBottom:12}}>👥</div>
          <div style={{fontWeight:600}}>Sin equipo asignado</div>
          <div style={{color:"var(--text-3)",fontSize:13,marginTop:6}}>No tienes usuarios bajo tu gerencia</div>
        </div>
      ) : (
        <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(280px,1fr))",gap:12}}>
          {equipo.map((u:any)=>{
            const sols = u.solicitudes||[]
            const activas = sols.filter((s:any)=>["solicitado","autorizado","liberado","parcial"].includes(s.status))
            const saldo = sols.filter((s:any)=>s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0)
              .reduce((a:number,s:any)=>a+(parseFloat(s.saldo_pendiente)||0),0)
            return (
              <div key={u.id} className="card">
                <div style={{display:"flex",alignItems:"center",gap:12,marginBottom:12}}>
                  <div style={{width:40,height:40,borderRadius:"50%",background:"var(--accent-soft)",color:"var(--accent)",
                    display:"grid",placeItems:"center",fontSize:14,fontWeight:700,flexShrink:0}}>
                    {u.iniciales}
                  </div>
                  <div>
                    <div style={{fontWeight:600,fontSize:14}}>{u.nombre}</div>
                    <div style={{fontSize:11,color:"var(--text-3)"}}>{u.correo}</div>
                  </div>
                </div>
                <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:8}}>
                  {[
                    {label:"Solicitudes activas",value:activas.length,color:activas.length>0?"var(--warn)":undefined},
                    {label:"Saldo por comprobar",value:fmtMXN(saldo),color:saldo>0?"var(--danger)":undefined},
                  ].map(k=>(
                    <div key={k.label} style={{padding:"8px 10px",background:"var(--surface-2)",borderRadius:8}}>
                      <div style={{fontSize:16,fontWeight:700,color:k.color}}>{k.value}</div>
                      <div style={{fontSize:10,color:"var(--text-3)",marginTop:2}}>{k.label}</div>
                    </div>
                  ))}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}

FILEEOF

mkdir -p $(dirname 'src/lib/polizas.ts')
cat > 'src/lib/polizas.ts' << 'FILEEOF'
// Pólizas generation logic - extracted from ContadorPolizas
// This runs server-side or client-side with real DB data

import { fmtFecha, getBancosAccount } from "@/lib/format"
import type { Solicitud, CuentaContable, Usuario, Centro, PolizaLinea } from "@/types"

const PROVEEDOR_UNICO = "6000000"

export function generarPolizas(
  solicitudes: Solicitud[],
  usuarios: Usuario[],
  centros: Centro[],
  catalogo: CuentaContable[],
  filtros: { desde: Date; hasta: Date; centro: string }
): PolizaLinea[] {
  const { desde, hasta, centro } = filtros
  const findUser = (id: string) => usuarios.find(u => u.id === id)
  const findCentro = (id: string) => centros.find(c => c.id === id)
  const findCuenta = (cta: string) => catalogo.find(c => c.cuenta === cta)

  const filtered = solicitudes.filter(s => {
    if (s.tipo === "anticipo") {
      if (s.status !== "liberado") return false
    } else if (s.tipo === "comprobacion" || s.tipo === "reembolso") {
      if (s.status === "rechazado" || s.status === "solicitado") return false
    } else return false
    if (s.fecha < desde || s.fecha > hasta) return false
    if (centro !== "todos") {
      const u = findUser(s.usuario)
      if (!u || u.centro !== centro) return false
    }
    return true
  })

  const lineas: PolizaLinea[] = []
  let numPoliza = 1

  filtered.forEach(s => {
    const u = findUser(s.usuario)
    if (!u) return
    const c = findCentro(u.centro || "")
    const centroId = c ? c.id : u.centro || ""
    const fechaFmt = fmtFecha(s.fecha)
    const polRef = `POL-${String(numPoliza).padStart(4, "0")}`
    const base = { poliza: polRef, folio: s.id, fecha: fechaFmt, centro: centroId, area: c?.nombre || centroId }

    if (s.tipo === "anticipo") {
      const division = u.division || "4105"
      const cuentaBanco = getBancosAccount(division)
      const cuentaBancoNombre = findCuenta(cuentaBanco)?.nombre || `Bancos ${division}`
      lineas.push({ ...base, division, cuenta: u.id,
        nombreCuenta: `Deudor ${u.nombre} (${u.id})`,
        tipo: "C", debe: s.monto, haber: 0,
        concepto: s.concepto, proveedor: u.nombre, usuario: u.nombre, ref: s.id, _archivos: [] })
      lineas.push({ ...base, division, cuenta: cuentaBanco,
        nombreCuenta: cuentaBancoNombre,
        tipo: "A", debe: 0, haber: s.monto,
        concepto: `Dispersión SPEI · ${s.id}`, proveedor: u.nombre, usuario: u.nombre, ref: s.id, _archivos: [] })

    } else {
      // Comprobacion / Reembolso
      const esCierre = !!(s.esCierre || (s.concepto && s.concepto.includes("[CIERRE]")))
      const division = u.division || "4105"
      const cuentaBanco = getBancosAccount(division)
      const cuentaBancoNombre = findCuenta(cuentaBanco)?.nombre || `Bancos ${division}`

      if (esCierre) {
        // Cierre: Bancos (cargo) vs Deudor (abono)
        const archivos = (s.cfdi || []).map((cf, i) => ({
          nombre: `${s.id}_deposito_${i + 1}`,
          url: cf.archivoUrl || null, uuid: cf.uuid || null, total: cf.total || s.monto,
        }))
        lineas.push({ ...base, division, cuenta: cuentaBanco, nombreCuenta: cuentaBancoNombre,
          tipo: "C", debe: s.monto, haber: 0,
          concepto: `Reintegro de saldo · ${u.nombre}`, proveedor: u.nombre, usuario: u.nombre,
          ref: s.id, _archivos: archivos })
        lineas.push({ ...base, division, cuenta: u.id,
          nombreCuenta: `Deudor ${u.nombre}`,
          tipo: "A", debe: 0, haber: s.monto,
          concepto: `Cancelación deudor por reintegro · ${s.anticipoRef || s.id}`,
          proveedor: u.nombre, usuario: u.nombre, ref: s.id, _archivos: archivos })
      } else {
        // Normal: Gastos vs Proveedor Único
        const items = s.cfdi && s.cfdi.length > 0
          ? s.cfdi.map(cf => ({ cuenta: cf.cuenta, desc: cf.concepto || cf.emisor || "", monto: cf.total || 0,
              uuid: cf.uuid, emisor: cf.emisor, archivoUrl: cf.archivoUrl }))
          : (s.items || []).map(it => ({ cuenta: it.cuenta, desc: it.desc, monto: it.monto,
              uuid: undefined, emisor: undefined, archivoUrl: null }))

        const archivos = (s.cfdi || [])
          .filter(cf => cf.archivoUrl)
          .map((cf, i) => ({
            nombre: `${s.id}_${(cf.emisor || "cfdi").replace(/[^a-z0-9]/gi, "_").slice(0, 20)}_${i + 1}`,
            url: cf.archivoUrl || null, uuid: cf.uuid || null, emisor: cf.emisor || null, total: cf.total || 0,
          }))

        items.forEach(it => {
          if (it.monto <= 0) return
          const meta = findCuenta(it.cuenta) || { nombre: it.cuenta }
          lineas.push({ ...base, division, cuenta: it.cuenta, nombreCuenta: meta.nombre,
            tipo: "C", debe: it.monto, haber: 0,
            concepto: it.desc || s.concepto, proveedor: u.nombre, usuario: u.nombre,
            ref: s.id, _archivos: archivos })
        })

        const totalItems = items.reduce((a, it) => a + it.monto, 0)
        if (totalItems > 0) {
          lineas.push({ ...base, division, cuenta: PROVEEDOR_UNICO, nombreCuenta: "Proveedor único",
            tipo: "A", debe: 0, haber: totalItems,
            concepto: s.concepto, proveedor: u.nombre, usuario: u.nombre,
            ref: s.id, _archivos: archivos })
        }
      }
    }
    numPoliza++
  })

  return lineas
}

// Group lineas by poliza reference
export function agruparPorPoliza(lineas: PolizaLinea[]) {
  const grupos: Record<string, PolizaLinea[]> = {}
  lineas.forEach(l => {
    if (!grupos[l.poliza]) grupos[l.poliza] = []
    grupos[l.poliza].push(l)
  })
  return Object.entries(grupos).map(([ref, movs]) => ({
    ref,
    folio: movs[0]?.folio,
    fecha: movs[0]?.fecha,
    debe: movs.reduce((a, l) => a + l.debe, 0),
    haber: movs.reduce((a, l) => a + l.haber, 0),
    movs,
  }))
}

FILEEOF

echo "✓ Phase 4 (complete) files updated"
git add . && git commit -m "feat: complete migration - admin CRUD, SAT tools, trazabilidad, cierre" && git push