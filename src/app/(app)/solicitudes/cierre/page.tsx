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

