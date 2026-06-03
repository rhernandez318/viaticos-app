#!/bin/bash
set -e

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
              <div key={p.ref} className="card" style={{ padding: 0, overflow: "hidden" }}>
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

mkdir -p $(dirname 'src/app/(app)/contador/reportes/page.tsx')
cat > 'src/app/(app)/contador/reportes/page.tsx' << 'FILEEOF'
"use client"
import ReportesPage from "@/components/ReportesPage"
export default function Page() { return <ReportesPage /> }

FILEEOF

mkdir -p $(dirname 'src/app/(app)/gerente/reportes/page.tsx')
cat > 'src/app/(app)/gerente/reportes/page.tsx' << 'FILEEOF'
"use client"
import ReportesPage from "@/components/ReportesPage"
export default function Page() { return <ReportesPage /> }

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/reportes/page.tsx')
cat > 'src/app/(app)/tesoreria/reportes/page.tsx' << 'FILEEOF'
"use client"
import ReportesPage from "@/components/ReportesPage"
export default function Page() { return <ReportesPage /> }

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/reportes/page.tsx')
cat > 'src/app/(app)/admin/reportes/page.tsx' << 'FILEEOF'
"use client"
import ReportesPage from "@/components/ReportesPage"
export default function Page() { return <ReportesPage /> }

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/usuarios/page.tsx')
cat > 'src/app/(app)/admin/usuarios/page.tsx' << 'FILEEOF'
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

FILEEOF

mkdir -p $(dirname 'src/app/(app)/perfil/page.tsx')
cat > 'src/app/(app)/perfil/page.tsx' << 'FILEEOF'
import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"
import { fmtMXN } from "@/lib/format"

export default async function PerfilPage() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  const [{ data: u }, { data: sols }] = await Promise.all([
    sb.from("usuarios").select("*, centro:centros(*), gerente:usuarios!gerente_id(nombre)").eq("id", user.id).single(),
    sb.from("solicitudes").select("id, tipo, status, monto, saldo_pendiente").eq("usuario_id", user.id),
  ])

  if (!u) redirect("/login")

  const totalAbierto = (sols || [])
    .filter(s => ["liberado","parcial"].includes(s.status) && parseFloat(s.saldo_pendiente) > 0)
    .reduce((a, s) => a + parseFloat(s.saldo_pendiente), 0)

  const ROL_COLOR: Record<string, string> = {
    admin: "var(--accent)", gerente: "var(--success)", tesoreria: "#60a5fa",
    contador: "#c084fc", usuario: "var(--text-3)",
  }

  return (
    <div style={{ maxWidth: 620 }}>
      <div className="page-head">
        <h1 className="page-title">Mi perfil</h1>
      </div>

      {/* Avatar + name */}
      <div className="card" style={{ textAlign: "center", marginBottom: 16, padding: "28px 20px" }}>
        <div style={{ width: 68, height: 68, borderRadius: "50%", margin: "0 auto 14px",
          background: "var(--accent-soft)", color: "var(--accent)",
          display: "grid", placeItems: "center", fontSize: 24, fontWeight: 700 }}>
          {u.iniciales}
        </div>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 4 }}>{u.nombre}</div>
        <div style={{ fontSize: 13, color: "var(--text-3)", marginBottom: 10 }}>{u.correo}</div>
        <span style={{ fontSize: 12, padding: "3px 14px", borderRadius: 20, fontWeight: 600,
          background: ROL_COLOR[u.rol] + "22", color: ROL_COLOR[u.rol] }}>
          {u.rol}
        </span>
      </div>

      {/* Info */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Cuenta</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14 }}>
          {[
            { label: "Centro de beneficio", value: u.centro ? `${u.centro.id} · ${u.centro.nombre}` : "—" },
            { label: "Departamento", value: u.centro?.depto || "—" },
            { label: "Gerente", value: (u.gerente as any)?.nombre || "—" },
            { label: "División SAP", value: u.division || "4105" },
            { label: "Banco", value: u.banco || "—" },
            { label: "CLABE", value: u.clabe ? "•••• " + u.clabe.slice(-4) : "—" },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: 11, color: "var(--text-3)", textTransform: "uppercase",
                letterSpacing: ".05em", marginBottom: 3 }}>{label}</div>
              <div style={{ fontSize: 13, fontWeight: 500 }}>{value}</div>
            </div>
          ))}
        </div>
        <div style={{ marginTop: 10, fontSize: 11.5, color: "var(--text-3)", fontStyle: "italic" }}>
          Para cambiar CLABE o banco, contacta a Tesorería.
        </div>
      </div>

      {/* Activity summary */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Resumen de actividad</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12 }}>
          {[
            { label: "Total solicitudes", value: (sols || []).length },
            { label: "Anticipos abiertos", value: (sols || []).filter(s => s.tipo === "anticipo" && parseFloat(s.saldo_pendiente) > 0).length },
            { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : undefined },
          ].map(k => (
            <div key={k.label} className="card" style={{ margin: 0, textAlign: "center", padding: "12px 8px" }}>
              <div style={{ fontSize: 18, fontWeight: 700, color: k.color }}>{k.value}</div>
              <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ReportesPage.tsx')
cat > 'src/components/ReportesPage.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"

export default function ReportesPage() {
  const [data, setData] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [periodo, setPeriodo] = useState(() => new Date().toISOString().slice(0, 7))

  useEffect(() => {
    const sb = createClient()
    const desde = new Date(periodo + "-01T00:00:00").toISOString()
    const hasta = new Date(new Date(periodo + "-01").setMonth(new Date(periodo + "-01").getMonth() + 1)).toISOString()

    sb.from("solicitudes")
      .select("tipo, status, monto, saldo_pendiente, usuario_id")
      .gte("fecha", desde).lt("fecha", hasta)
      .then(({ data }) => {
        setData(data || [])
        setLoading(false)
      })
  }, [periodo])

  const total = (tipo?: string, status?: string) =>
    data.filter(s => (!tipo || s.tipo === tipo) && (!status || s.status === status))
       .reduce((a, s) => a + (parseFloat(s.monto) || 0), 0)

  const count = (tipo?: string, status?: string) =>
    data.filter(s => (!tipo || s.tipo === tipo) && (!status || s.status === status)).length

  const KPIs = [
    { label: "Anticipos liberados", value: fmtMXN(total("anticipo","liberado")), sub: count("anticipo","liberado") + " solicitudes" },
    { label: "Comprobado", value: fmtMXN(total(undefined,"comprobado")), sub: count(undefined,"comprobado") + " solicitudes" },
    { label: "Reembolsos", value: fmtMXN(total("reembolso")), sub: count("reembolso") + " solicitudes" },
    { label: "Saldo pendiente", value: fmtMXN(data.reduce((a,s)=>a+(parseFloat(s.saldo_pendiente)||0),0)),
      sub: "en anticipos abiertos", color: "var(--warn)" },
    { label: "Rechazadas", value: count(undefined,"rechazado"), sub: "solicitudes" },
    { label: "Total del período", value: fmtMXN(data.reduce((a,s)=>a+(parseFloat(s.monto)||0),0)), sub: data.length + " solicitudes" },
  ]

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Reportes</h1>
          <div className="page-sub">Resumen del período seleccionado</div>
        </div>
        <input className="input" type="month" value={periodo}
          onChange={e => setPeriodo(e.target.value)} style={{ width: 160 }} />
      </div>

      {loading ? (
        <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando…</div>
      ) : (
        <>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px,1fr))", gap: 12, marginBottom: 24 }}>
            {KPIs.map(k => (
              <div key={k.label} className="card" style={{ textAlign: "center" }}>
                <div style={{ fontSize: 22, fontWeight: 700, color: k.color }}>{k.value}</div>
                <div style={{ fontSize: 12, fontWeight: 600, marginTop: 4 }}>{k.label}</div>
                <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>{k.sub}</div>
              </div>
            ))}
          </div>

          {/* By tipo breakdown */}
          <div className="card">
            <div className="card-title" style={{ marginBottom: 14 }}>Desglose por tipo</div>
            <table className="t">
              <thead><tr><th>Tipo</th><th>Status</th><th className="num">Cantidad</th><th className="num">Monto</th></tr></thead>
              <tbody>
                {[
                  { tipo: "anticipo", status: "liberado" },
                  { tipo: "anticipo", status: "autorizado" },
                  { tipo: "comprobacion", status: "comprobado" },
                  { tipo: "comprobacion", status: "autorizado" },
                  { tipo: "reembolso", status: "comprobado" },
                  { tipo: "reembolso", status: "liberado" },
                ].filter(({ tipo, status }) => count(tipo, status) > 0).map(({ tipo, status }) => (
                  <tr key={`${tipo}-${status}`}>
                    <td><span className="badge tipo">{tipo === "anticipo" ? "ANT" : tipo === "comprobacion" ? "CMP" : "REE"}</span></td>
                    <td><span className={`badge ${status}`}>{status}</span></td>
                    <td className="num">{count(tipo, status)}</td>
                    <td className="num">{fmtMXN(total(tipo, status))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
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

echo "✓ Phase 4 files updated"
git add . && git commit -m "feat: phase 4 - contador, admin, reportes, perfil" && git push