"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"

const ROLES = ["usuario","gerente","tesoreria","contador","admin"]

export default function AdminUsuariosPage() {
  const [usuarios, setUsuarios] = useState<any[]>([])
  const [centros, setCentros] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [editando, setEditando] = useState<any | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [busqueda, setBusqueda] = useState("")
  const [toast, setToast] = useState<string | null>(null)

  const showToast = (msg: string) => { setToast(msg); setTimeout(() => setToast(null), 3000) }

  const load = async () => {
    const sb = createClient()
    const [u, c] = await Promise.all([
      sb.from("usuarios").select("*").order("nombre"),
      sb.from("centros").select("id, nombre").eq("activo", true).order("nombre"),
    ])
    setUsuarios(u.data || [])
    setCentros(c.data || [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtrados = usuarios.filter(u =>
    !busqueda.trim() ||
    u.nombre?.toLowerCase().includes(busqueda.toLowerCase()) ||
    u.correo?.toLowerCase().includes(busqueda.toLowerCase()) ||
    u.rol?.toLowerCase().includes(busqueda.toLowerCase())
  )

  const guardar = async () => {
    if (!editando) return
    setGuardando(true)
    const sb = createClient()
    const row = {
      nombre: editando.nombre, rol: editando.rol,
      centro_id: editando.centro_id || null, gerente_id: editando.gerente_id || null,
      division: editando.division || "4105", clabe: editando.clabe || null,
      banco: editando.banco || null,
      iniciales: editando.nombre.split(" ").map((p: string) => p[0]).slice(0, 2).join("").toUpperCase(),
    }
    const { error } = await sb.from("usuarios").update(row).eq("id", editando.id)
    if (error) { showToast("⚠ Error: " + error.message) }
    else { showToast("✓ Usuario actualizado"); await load() }
    setEditando(null)
    setGuardando(false)
  }

  const desactivar = async (id: string, nombre: string) => {
    if (!confirm(`¿Desactivar a ${nombre}?`)) return
    const sb = createClient()
    await sb.from("usuarios").update({ activo: false }).eq("id", id)
    showToast("✓ Usuario desactivado")
    await load()
  }

  const ROL_COLOR: Record<string, string> = {
    admin: "var(--accent)", gerente: "var(--success)", tesoreria: "#60a5fa",
    contador: "#c084fc", usuario: "var(--text-3)",
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Usuarios</h1>
          <div className="page-sub">{usuarios.length} registrados</div>
        </div>
      </div>

      {toast && (
        <div style={{ padding: "10px 14px", borderRadius: 8, marginBottom: 12, fontSize: 13,
          background: toast.startsWith("✓") ? "var(--success-soft)" : "var(--danger-soft)",
          color: toast.startsWith("✓") ? "var(--success)" : "var(--danger)" }}>
          {toast}
        </div>
      )}

      {/* Edit modal */}
      {editando && (
        <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.6)", zIndex: 100,
          display: "grid", placeItems: "center", padding: 20 }}>
          <div className="card" style={{ width: "100%", maxWidth: 520, maxHeight: "90vh", overflowY: "auto" }}>
            <div style={{ fontWeight: 700, fontSize: 16, marginBottom: 16 }}>
              Editar · {editando.nombre}
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
              {[
                { label: "Nombre", key: "nombre", type: "text" },
                { label: "Correo", key: "correo", type: "email", disabled: true },
                { label: "División", key: "division", type: "select", options: ["4105","4106","4111","4113"] },
                { label: "CLABE", key: "clabe", type: "text" },
                { label: "Banco", key: "banco", type: "text" },
              ].map(({ label, key, type, disabled, options }) => (
                <div key={key}>
                  <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>
                    {label}
                  </label>
                  {type === "select" ? (
                    <select className="select" value={editando[key] || ""}
                      onChange={e => setEditando({ ...editando, [key]: e.target.value })}>
                      {(options || []).map(o => <option key={o} value={o}>{o}</option>)}
                    </select>
                  ) : (
                    <input className="input" type={type} value={editando[key] || ""}
                      disabled={disabled}
                      onChange={e => setEditando({ ...editando, [key]: e.target.value })} />
                  )}
                </div>
              ))}
              <div>
                <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>Rol</label>
                <select className="select" value={editando.rol}
                  onChange={e => setEditando({ ...editando, rol: e.target.value })}>
                  {ROLES.map(r => <option key={r} value={r} style={{ textTransform: "capitalize" }}>{r}</option>)}
                </select>
              </div>
              <div>
                <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>Centro</label>
                <select className="select" value={editando.centro_id || ""}
                  onChange={e => setEditando({ ...editando, centro_id: e.target.value || null })}>
                  <option value="">— Sin centro —</option>
                  {centros.map((c: any) => <option key={c.id} value={c.id}>{c.id} · {c.nombre}</option>)}
                </select>
              </div>
              <div>
                <label style={{ fontSize: 11, color: "var(--text-3)", display: "block", marginBottom: 4 }}>Gerente</label>
                <select className="select" value={editando.gerente_id || ""}
                  onChange={e => setEditando({ ...editando, gerente_id: e.target.value || null })}>
                  <option value="">— Sin gerente —</option>
                  {usuarios.filter(u => ["gerente","admin"].includes(u.rol) && u.id !== editando.id)
                    .map((u: any) => <option key={u.id} value={u.id}>{u.nombre}</option>)}
                </select>
              </div>
            </div>
            <div style={{ display: "flex", gap: 8, justifyContent: "flex-end", marginTop: 16 }}>
              <button className="btn ghost" onClick={() => setEditando(null)}>Cancelar</button>
              <button className="btn primary" onClick={guardar} disabled={guardando}>
                {guardando ? "Guardando…" : "Guardar cambios"}
              </button>
            </div>
          </div>
        </div>
      )}

      <input className="input" placeholder="Buscar por nombre, correo o rol…"
        value={busqueda} onChange={e => setBusqueda(e.target.value)}
        style={{ marginBottom: 14, maxWidth: 380 }} />

      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando…</div>
        ) : (
          <table className="t">
            <thead>
              <tr><th>Usuario</th><th>Correo</th><th>Rol</th><th>División</th><th></th></tr>
            </thead>
            <tbody>
              {filtrados.map((u: any) => (
                <tr key={u.id}>
                  <td>
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div style={{ width: 30, height: 30, borderRadius: "50%",
                        background: "var(--surface-2)", border: "1px solid var(--border)",
                        display: "grid", placeItems: "center", fontSize: 11, fontWeight: 700, flexShrink: 0 }}>
                        {u.iniciales || "??"}
                      </div>
                      <span style={{ fontWeight: 500 }}>{u.nombre}</span>
                    </div>
                  </td>
                  <td style={{ fontSize: 12, color: "var(--text-3)" }}>{u.correo}</td>
                  <td>
                    <span style={{ fontSize: 11, padding: "2px 10px", borderRadius: 12,
                      background: ROL_COLOR[u.rol] + "22", color: ROL_COLOR[u.rol], fontWeight: 600 }}>
                      {u.rol}
                    </span>
                  </td>
                  <td className="mono" style={{ fontSize: 12 }}>{u.division || "4105"}</td>
                  <td>
                    <div style={{ display: "flex", gap: 6 }}>
                      <button className="btn sm ghost" onClick={() => setEditando({ ...u })}>Editar</button>
                      <button className="btn sm ghost"
                        style={{ color: "var(--danger)", borderColor: "var(--danger)" }}
                        onClick={() => desactivar(u.id, u.nombre)}>
                        ×
                      </button>
                    </div>
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

