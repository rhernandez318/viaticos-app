"use client"

import { notifyUsers } from "@/lib/notify"
import { useState, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { findCuenta } from "@/store/catalogos"
import { useCatalogos } from "@/hooks/useCatalogos"

interface DesgloseItem { id: string; cuenta: string; desc: string; monto: number }

const newItem = (): DesgloseItem => ({
  id: Math.random().toString(36).slice(2), cuenta: "6122200001", desc: "", monto: 0
})

export default function SolicitarAnticipoPage() {
  const router = useRouter()
  const { catalogoGastos, loaded } = useCatalogos()

  const [concepto, setConcepto]   = useState("")
  const [salida,   setSalida]     = useState("")
  const [regreso,  setRegreso]    = useState("")
  const [desglose, setDesglose]   = useState<DesgloseItem[]>([newItem()])
  const [enviando, setEnviando]   = useState(false)
  const [toast,    setToast]      = useState<string | null>(null)

  const showToast = (msg: string) => { setToast(msg); setTimeout(() => setToast(null), 3500) }

  const totalDesg = desglose.reduce((a, d) => a + (d.monto || 0), 0)

  const updItem = (id: string, field: keyof DesgloseItem, val: string | number) =>
    setDesglose(prev => prev.map(d => d.id === id ? { ...d, [field]: val } : d))

  const handleEnviar = async () => {
    if (!concepto.trim())  { showToast("⚠ Escribe un concepto"); return }
    if (totalDesg <= 0)    { showToast("⚠ Agrega al menos un concepto con monto"); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const { data: perfil } = await sb.from("usuarios").select("centro_id").eq("id", user.id).single()
    const id = "ANT-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "anticipo", concepto: concepto.trim(),
      usuario_id: user.id, monto: totalDesg, status: "solicitado",
      saldo_pendiente: totalDesg, centro_id: perfil?.centro_id ?? null,
      fecha: new Date().toISOString(),
    })

    if (error) { showToast("⚠ Error al guardar: " + error.message); setEnviando(false); return }

    if (desglose.some(d => d.monto > 0)) {
      await sb.from("solicitud_items").insert(
        desglose.filter(d => d.monto > 0).map((d, i) => ({
          solicitud_id: id, cuenta: d.cuenta,
          descripcion: d.desc || "", monto: d.monto, orden: i,
        }))
      )
    }

    // Registrar en bitácora
    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Anticipo creado por ${fmtMXN(totalDesg)}`, ts: new Date().toISOString(),
    })

    // Notify gerente
    const { data: pf } = await sb.from("usuarios").select("gerente_id, nombre").eq("id", user.id).single()
    if (pf?.gerente_id) {
      await notifyUsers([pf.gerente_id], "📋 Nuevo anticipo por autorizar",
        `${pf.nombre} solicitó ${fmtMXN(totalDesg)} — ${concepto.trim()}`, `/solicitudes/${id}`)
    }

    showToast("✓ Anticipo enviado a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  return (
    <div style={{ maxWidth: 720 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Solicitar anticipo</h1>
          <div className="page-sub">Completa el formulario y envía a tu gerente</div>
        </div>
      </div>

      {/* Datos generales */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 14 }}>Datos del viaje</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: 12 }}>
          <div>
            <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
              Motivo / Concepto *
            </label>
            <input className="input" value={concepto}
              onChange={e => setConcepto(e.target.value)}
              placeholder="Ej: Visita a cliente en Monterrey" />
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div>
              <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
                Fecha de salida
              </label>
              <input className="input" type="date" value={salida} onChange={e => setSalida(e.target.value)} />
            </div>
            <div>
              <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
                Fecha de regreso
              </label>
              <input className="input" type="date" value={regreso} onChange={e => setRegreso(e.target.value)} />
            </div>
          </div>
        </div>
      </div>

      {/* Desglose */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="spread" style={{ marginBottom: 14 }}>
          <div className="card-title">Desglose estimado de gastos</div>
          <button className="btn sm" onClick={() => setDesglose(prev => [...prev, newItem()])}>
            + Agregar línea
          </button>
        </div>
        <table className="t">
          <thead>
            <tr>
              <th style={{ width: "45%" }}>Cuenta contable</th>
              <th>Descripción</th>
              <th style={{ width: 110 }} className="num">Monto</th>
              <th style={{ width: 32 }}></th>
            </tr>
          </thead>
          <tbody>
            {desglose.map(d => (
              <tr key={d.id}>
                <td>
                  <select className="select" value={d.cuenta}
                    onChange={e => updItem(d.id, "cuenta", e.target.value)}
                    style={{
                      fontSize: 11, padding: "5px 6px",
                      borderColor: d.cuenta === "6121200001" ? "var(--warn)" : "var(--border)",
                      background: d.cuenta === "6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)",
                    }}>
                    {catalogoGastos.map(g => (
                      <option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>
                    ))}
                  </select>
                </td>
                <td>
                  <input className="input" style={{ fontSize: 12 }} value={d.desc}
                    onChange={e => updItem(d.id, "desc", e.target.value)}
                    placeholder="Descripción opcional" />
                </td>
                <td>
                  <input className="input mono" type="number" min="0" step="0.01"
                    style={{ textAlign: "right", fontSize: 13 }}
                    value={d.monto || ""}
                    onChange={e => updItem(d.id, "monto", parseFloat(e.target.value) || 0)} />
                </td>
                <td>
                  {desglose.length > 1 && (
                    <button onClick={() => setDesglose(prev => prev.filter(x => x.id !== d.id))}
                      style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 16 }}>
                      ×
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={2} style={{ textAlign: "right", fontSize: 13, fontWeight: 600, padding: "10px 12px" }}>
                Total solicitado
              </td>
              <td className="num" style={{ fontSize: 18, fontWeight: 700, color: "var(--accent)" }}>
                {fmtMXN(totalDesg)}
              </td>
              <td />
            </tr>
          </tfoot>
        </table>
      </div>

      {/* Toast */}
      {toast && (
        <div style={{ padding: "10px 14px", borderRadius: 8, marginBottom: 12,
          background: toast.startsWith("✓") ? "var(--success-soft)" : "var(--danger-soft)",
          color: toast.startsWith("✓") ? "var(--success)" : "var(--danger)",
          border: `1px solid ${toast.startsWith("✓") ? "var(--success)" : "var(--danger)"}`,
          fontSize: 13 }}>
          {toast}
        </div>
      )}

      {/* Actions */}
      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <button className="btn ghost" onClick={() => router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || totalDesg <= 0}
          style={{ opacity: enviando || totalDesg <= 0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : "Enviar a autorización →"}
        </button>
      </div>
    </div>
  )
}

