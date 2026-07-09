"use client"
import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { Layers, Plus, Edit2, Power, Trash2 } from "lucide-react"

interface Division {
  codigo: string
  nombre: string
  descripcion: string | null
  activo: boolean
  created_at?: string
}

// IMPORTANTE: FormField y Modal DEFINIDOS FUERA del componente
// para evitar remounts en cada render (focus loss en inputs)
const FormField = ({ label, children }: { label: string; children: React.ReactNode }) => (
  <div>
    <label style={{fontSize:11,color:"var(--text-3)",display:"block",marginBottom:4}}>{label}</label>
    {children}
  </div>
)

const Modal = ({ title, onClose, onSave, guardando, children }: any) => (
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

export default function AdminDivisionesPage() {
  const [divisiones, setDivisiones] = useState<Division[]>([])
  const [loading, setLoading] = useState(true)
  const [editando, setEditando] = useState<Division|null>(null)
  const [creando, setCreando] = useState(false)
  const [nuevoForm, setNuevoForm] = useState({ codigo:"", nombre:"", descripcion:"" })
  const [guardando, setGuardando] = useState(false)
  const [toast, setToast] = useState<string|null>(null)

  const showToast = (m: string) => { setToast(m); setTimeout(()=>setToast(null), 3500) }

  const load = async () => {
    const sb = createClient()
    const { data } = await sb.from("divisiones").select("*").order("codigo")
    setDivisiones(data || [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const crear = async () => {
    if (!nuevoForm.codigo.trim() || !nuevoForm.nombre.trim()) {
      showToast("⚠ Código y nombre son requeridos")
      return
    }
    setGuardando(true)
    try {
      const sb = createClient()
      const { error } = await sb.from("divisiones").insert({
        codigo: nuevoForm.codigo.trim(),
        nombre: nuevoForm.nombre.trim(),
        descripcion: nuevoForm.descripcion.trim() || null,
        activo: true,
      })
      if (error) throw error
      showToast("✓ División creada")
      setCreando(false)
      setNuevoForm({ codigo:"", nombre:"", descripcion:"" })
      await load()
    } catch (e: any) {
      showToast("⚠ " + (e.message.includes("duplicate") ? "Ya existe una división con ese código" : e.message))
    }
    setGuardando(false)
  }

  const guardarEdicion = async () => {
    if (!editando) return
    if (!editando.nombre.trim()) {
      showToast("⚠ El nombre es requerido")
      return
    }
    setGuardando(true)
    try {
      const sb = createClient()
      const { error } = await sb.from("divisiones").update({
        nombre: editando.nombre.trim(),
        descripcion: (editando.descripcion || "").trim() || null,
      }).eq("codigo", editando.codigo)
      if (error) throw error
      showToast("✓ División actualizada")
      setEditando(null)
      await load()
    } catch (e: any) {
      showToast("⚠ " + e.message)
    }
    setGuardando(false)
  }

  const toggleActivo = async (d: Division) => {
    const sb = createClient()
    await sb.from("divisiones").update({ activo: !d.activo }).eq("codigo", d.codigo)
    showToast(d.activo ? "División desactivada" : "División reactivada")
    await load()
  }

  if (loading) return <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>

  return (
    <>
      <div className="page-head" style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",flexWrap:"wrap",gap:10}}>
        <div>
          <h1 className="page-title" style={{display:"flex",alignItems:"center",gap:10}}>
            <Layers size={22} strokeWidth={1.75}/> Divisiones SAP
          </h1>
          <div className="page-sub">{divisiones.length} registradas · {divisiones.filter(d=>d.activo).length} activas</div>
        </div>
        <button className="btn primary" onClick={()=>setCreando(true)} style={{display:"flex",alignItems:"center",gap:6}}>
          <Plus size={14}/> Nueva división
        </button>
      </div>

      {toast && <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
        background: toast.startsWith("✓") ? "var(--success-soft)" : "var(--danger-soft)",
        color: toast.startsWith("✓") ? "var(--success)" : "var(--danger)"}}>{toast}</div>}

      <div className="card" style={{padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:600}}>
          <thead>
            <tr>
              <th>Código</th>
              <th>Nombre</th>
              <th>Descripción</th>
              <th>Estado</th>
              <th style={{width:120}}>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {divisiones.map(d => (
              <tr key={d.codigo} style={{opacity: d.activo ? 1 : 0.5}}>
                <td className="mono" style={{fontWeight:600}}>{d.codigo}</td>
                <td>{d.nombre}</td>
                <td style={{color:"var(--text-3)",fontSize:12}}>{d.descripcion || "—"}</td>
                <td>
                  <span style={{
                    fontSize:11, padding:"3px 8px", borderRadius:12,
                    background: d.activo ? "var(--success-soft)" : "var(--danger-soft)",
                    color: d.activo ? "var(--success)" : "var(--danger)",
                  }}>
                    {d.activo ? "Activa" : "Inactiva"}
                  </span>
                </td>
                <td>
                  <div style={{display:"flex",gap:6}}>
                    <button className="btn sm ghost" onClick={()=>setEditando(d)} title="Editar">
                      <Edit2 size={12}/>
                    </button>
                    <button className="btn sm ghost" onClick={()=>toggleActivo(d)} title={d.activo ? "Desactivar" : "Reactivar"}>
                      <Power size={12}/>
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Modal nuevo */}
      {creando && (
        <Modal
          title="Nueva división SAP"
          onClose={()=>setCreando(false)}
          onSave={crear}
          guardando={guardando}
        >
          <FormField label="Código SAP">
            <input className="input" value={nuevoForm.codigo} onChange={e=>setNuevoForm({...nuevoForm,codigo:e.target.value})} placeholder="Ej. 4105"/>
          </FormField>
          <FormField label="Nombre">
            <input className="input" value={nuevoForm.nombre} onChange={e=>setNuevoForm({...nuevoForm,nombre:e.target.value})} placeholder="Ej. Zapata"/>
          </FormField>
          <div style={{gridColumn:"1 / -1"}}>
            <FormField label="Descripción (opcional)">
              <input className="input" value={nuevoForm.descripcion} onChange={e=>setNuevoForm({...nuevoForm,descripcion:e.target.value})}/>
            </FormField>
          </div>
        </Modal>
      )}

      {/* Modal editar */}
      {editando && (
        <Modal
          title={`Editar división ${editando.codigo}`}
          onClose={()=>setEditando(null)}
          onSave={guardarEdicion}
          guardando={guardando}
        >
          <FormField label="Código SAP">
            <input className="input" value={editando.codigo} disabled/>
          </FormField>
          <FormField label="Nombre">
            <input className="input" value={editando.nombre} onChange={e=>setEditando({...editando,nombre:e.target.value})}/>
          </FormField>
          <div style={{gridColumn:"1 / -1"}}>
            <FormField label="Descripción">
              <input className="input" value={editando.descripcion||""} onChange={e=>setEditando({...editando,descripcion:e.target.value})}/>
            </FormField>
          </div>
        </Modal>
      )}
    </>
  )
}

