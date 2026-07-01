"use client"
import { AlertTriangle } from "lucide-react"
import { useState, useEffect, useRef, useCallback } from "react"
import { useRouter, useParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import { isComidas } from "@/lib/cuentaComidas"
import { notifyUsers } from "@/lib/notify"
import type { CfdItem } from "@/types"

interface ItemConObs extends CfdItem { observaciones?: string }

export default function CorregirComprobacionPage() {
  const router  = useRouter()
  const { id }  = useParams<{ id: string }>()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [solicitud, setSolicitud]   = useState<any>(null)
  const [items,     setItems]       = useState<ItemConObs[]>([])
  const [enviando,  setEnviando]    = useState(false)
  const [toast,     setToast]       = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({msg,ok}); setTimeout(()=>setToast(null),4000) }

  useEffect(() => {
    const sb = createClient()
    sb.from("solicitudes")
      .select("*,comprobantes_cfdi(*)")
      .eq("id", id).single()
      .then(({ data }) => {
        if (!data || data.status !== "devuelto") { router.push(`/solicitudes/${id}`); return }
        setSolicitud(data)
        setItems((data.comprobantes_cfdi || []).map((c: any) => ({
          uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
          subtotal: c.subtotal, iva: c.iva, total: c.total,
          cuenta: c.cuenta, confianza: c.confianza,
          archivoUrl: c.archivo_url, rfcEmisor: c.rfc_emisor,
          rfcReceptor: c.rfc_receptor, duplicado: false,
          observaciones: c.observaciones || "",
        } as ItemConObs)))
      })
  }, [id, router])

  const handleFiles = useCallback(async (files: FileList | null) => {
    if (!files) return
    for (const file of Array.from(files)) {
      if (!file.name.toLowerCase().endsWith(".xml")) continue
      const text = await file.text()
      const parsed = parseCFDIXml(text)
      if (!parsed) { showToast(`XML inválido: ${file.name}`, false); continue }
      setItems(prev => [...prev, { ...parsed, duplicado: false } as ItemConObs])
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [])

  const handleReenviar = async () => {
    const validos = items.filter(i => !i.duplicado)
    if (!validos.length) { showToast("⚠ Sin comprobantes válidos", false); return }

    const sinObs = validos.filter(it => isComidas(it.cuenta, catalogoGastos) && !it.observaciones?.trim())
    if (sinObs.length) { showToast("⚠ Indica comensales en los gastos de alimentos", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    const total = validos.reduce((a, i) => a + i.total, 0)

    // Delete existing comprobantes and reinsert
    await sb.from("comprobantes_cfdi").delete().eq("solicitud_id", id)
    await sb.from("comprobantes_cfdi").insert(validos.map(it => ({
      solicitud_id: id,
      uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      emisor: it.emisor, concepto: it.concepto,
      subtotal: it.subtotal, iva: it.iva, total: it.total,
      cuenta: it.cuenta, confianza: it.confianza,
      archivo_url: it.archivoUrl, rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
      observaciones: it.observaciones || null,
    })))

    // Reset to solicitado
    await sb.from("solicitudes")
      .update({ status: "solicitado", monto: total, motivo_rechazo: null })
      .eq("id", id)

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Comprobación corregida y reenviada · ${fmtMXN(total)}`,
      ts: new Date().toISOString(),
    })

    // Notify gerente
    const { data: perfil } = await sb.from("usuarios")
      .select("gerente_id, nombre").eq("id", user.id).single()
    if (perfil?.gerente_id) {
      await notifyUsers([perfil.gerente_id],
        "📎 Comprobación corregida para revisar",
        `${perfil.nombre} corrigió y reenvió la comprobación ${id}`,
        `/solicitudes/${id}`)
    }

    showToast("✓ Comprobación reenviada a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  if (!solicitud) return (
    <div style={{padding:60,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>
  )

  const total = items.filter(i=>!i.duplicado).reduce((a,i)=>a+i.total,0)

  return (
    <div style={{ maxWidth:1000 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">↩️ Corregir comprobación</h1>
          <div className="page-sub">{id} · {solicitud.concepto}</div>
        </div>
      </div>

      {solicitud.motivo_rechazo && (
        <div style={{padding:"12px 16px",background:"rgba(251,191,36,.1)",
          border:"1px solid #fbbf24",borderRadius:10,marginBottom:16,fontSize:13}}>
          <strong>Motivo de devolución:</strong> {solicitud.motivo_rechazo}
        </div>
      )}

      {/* Add more comprobantes */}
      <div className="card" style={{marginBottom:16,border:"2px dashed var(--border)",
        textAlign:"center",padding:"20px",cursor:"pointer"}}
        onClick={()=>fileRef.current?.click()}>
        <div style={{fontSize:24,marginBottom:6}}>➕</div>
        <div style={{fontWeight:600,fontSize:13}}>Agregar o reemplazar XMLs</div>
        <div style={{fontSize:12,color:"var(--text-3)"}}>Haz clic o arrastra archivos XML</div>
        <input ref={fileRef} type="file" accept=".xml" multiple hidden
          onChange={e=>handleFiles(e.target.files)}/>
      </div>

      {/* Items table */}
      <div className="card" style={{marginBottom:16,padding:0,overflow:"auto"}}>
        <table className="t" style={{minWidth:860}}>
          <thead>
            <tr>
              <th>Emisor</th><th>Concepto</th>
              <th style={{minWidth:200}}>Cuenta</th>
              <th style={{minWidth:200}}>Comentarios</th>
              <th className="num">Total</th><th style={{width:32}}></th>
            </tr>
          </thead>
          <tbody>
            {items.map((it,i)=>(
              <tr key={i}>
                <td style={{fontSize:12}}>{it.emisor}</td>
                <td style={{fontSize:12}}>{it.concepto}</td>
                <td>
                  <select className="select" value={it.cuenta}
                    onChange={e=>setItems(prev=>prev.map((x,j)=>j===i?{...x,cuenta:e.target.value}:x))}
                    style={{fontSize:11,padding:"5px 6px"}}>
                    {catalogoGastos.map(g=><option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                  </select>
                </td>
                <td>
                  <input className="input"
                    value={it.observaciones||""}
                    onChange={e=>setItems(prev=>prev.map((x,j)=>j===i?{...x,observaciones:e.target.value}:x))}
                    placeholder={isComidas(it.cuenta, catalogoGastos)?"Requerido: nombres y № comensales":"Opcional"}
                    style={{fontSize:11,padding:"5px 6px",
                      borderColor:isComidas(it.cuenta, catalogoGastos)&&!it.observaciones?"var(--danger)":"var(--border)"}}/>
                  {isComidas(it.cuenta, catalogoGastos)&&!it.observaciones&&(
                    <div style={{fontSize:10,color:"var(--danger)",marginTop:2}}><AlertTriangle size={12} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/>Favor de indicar número y nombre de los comensales
                    </div>
                  )}
                </td>
                <td className="num">{fmtMXN(it.total)}</td>
                <td>
                  <button onClick={()=>setItems(p=>p.filter((_,j)=>j!==i))}
                    style={{background:"none",border:"none",color:"var(--text-3)",cursor:"pointer",fontSize:16}}>×</button>
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={4} style={{textAlign:"right",fontWeight:600,padding:"10px 12px"}}>Total</td>
              <td className="num" style={{fontWeight:700,fontSize:16}}>{fmtMXN(total)}</td>
              <td/>
            </tr>
          </tfoot>
        </table>
      </div>

      {toast&&(
        <div style={{padding:"10px 14px",borderRadius:8,marginBottom:12,fontSize:13,
          background:toast.ok?"var(--success-soft)":"var(--danger-soft)",
          color:toast.ok?"var(--success)":"var(--danger)"}}>
          {toast.msg}
        </div>
      )}

      <div style={{display:"flex",justifyContent:"flex-end",gap:10}}>
        <button className="btn ghost" onClick={()=>router.push(`/solicitudes/${id}`)}>Cancelar</button>
        <button className="btn primary" onClick={handleReenviar}
          disabled={enviando||total<=0}
          style={{opacity:enviando||total<=0?0.5:1}}>
          {enviando?"Reenviando…":`Reenviar comprobación · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}

