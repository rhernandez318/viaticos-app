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

