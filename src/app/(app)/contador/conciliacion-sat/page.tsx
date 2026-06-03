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

