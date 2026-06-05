#!/bin/bash
set -e

cat > 'src/components/ReportesPage.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useMemo } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  LineChart, Line, CartesianGrid, PieChart, Pie, Cell, Legend,
} from "recharts"

const COLORS = ["#c5f24d","#60a5fa","#f97316","#c084fc","#4ade80","#fb923c","#38bdf8","#a78bfa"]
const MESES = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]

type Tab = "resumen" | "antiguedad" | "mensual" | "area" | "deudores"

export default function ReportesPage() {
  const [tab, setTab] = useState<Tab>("resumen")
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [centros, setCentros] = useState<any[]>([])
  const [usuarios, setUsuarios] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [anio, setAnio] = useState(new Date().getFullYear())

  useEffect(() => {
    const sb = createClient()
    Promise.all([
      sb.from("solicitudes").select("id,tipo,status,monto,fecha,usuario_id,saldo_pendiente,anticipo_ref,centro_id").order("fecha",{ascending:false}),
      sb.from("centros").select("id,nombre,division"),
      sb.from("usuarios").select("id,nombre,iniciales,centro_id"),
    ]).then(([s,c,u]) => {
      setSolicitudes(s.data||[])
      setCentros(c.data||[])
      setUsuarios(u.data||[])
      setLoading(false)
    })
  }, [])

  const del_anio = useMemo(() =>
    solicitudes.filter(s => new Date(s.fecha).getFullYear() === anio), [solicitudes, anio])

  // ── Resumen KPIs ──────────────────────────────────────────
  const PAGADOS = ["liberado","comprobado"]
  const kpis = useMemo(() => {
    // Only count liberado + comprobado for financial KPIs (not rechazado, not in-flight)
    const pagados = del_anio.filter(s => PAGADOS.includes(s.status))
    const total = (tipo?: string) =>
      pagados.filter(s => !tipo || s.tipo === tipo)
             .reduce((a:number,s:any) => a + parseFloat(s.monto||0), 0)
    const count = (tipo?: string) =>
      pagados.filter(s => !tipo || s.tipo === tipo).length
    const rechazadas = del_anio.filter(s => s.status === "rechazado").length
    return [
      { label:"Total gestionado", value:fmtMXN(total()), sub:`${count()} liberadas/comprobadas`, color:"var(--accent)" },
      { label:"Anticipos", value:fmtMXN(total("anticipo")), sub:`${count("anticipo")} gestionados` },
      { label:"Reembolsos", value:fmtMXN(total("reembolso")), sub:`${count("reembolso")} gestionados` },
      { label:"Saldo pendiente", value:fmtMXN(
          solicitudes.filter(s=>s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0&&["liberado","parcial"].includes(s.status))
                     .reduce((a:number,s:any)=>a+parseFloat(s.saldo_pendiente),0)
        ), sub:"anticipos abiertos", color:"var(--warn)" },
      { label:"Rechazadas", value:rechazadas, sub:"solicitudes", color:rechazadas>0?"var(--danger)":undefined },
      { label:"Comprobadas", value:fmtMXN(del_anio.filter(s=>s.status==="comprobado").reduce((a:number,s:any)=>a+parseFloat(s.monto||0),0)), sub:`${del_anio.filter(s=>s.status==="comprobado").length} solicitudes`, color:"var(--success)" },
    ]
  }, [del_anio, solicitudes])

  // ── Antigüedad de saldos ──────────────────────────────────
  const antiguedad = useMemo(() => {
    const abiertas = solicitudes.filter(s => s.tipo==="anticipo" && parseFloat(s.saldo_pendiente)>0 && ["liberado","parcial"].includes(s.status))
    const hoy = Date.now()
    const buckets = [
      { label:"0-30 días",  min:0,  max:30,  items:[] as any[] },
      { label:"31-60 días", min:31, max:60,  items:[] as any[] },
      { label:"61-90 días", min:61, max:90,  items:[] as any[] },
      { label:"+90 días",   min:91, max:9999,items:[] as any[] },
    ]
    abiertas.forEach(s => {
      const dias = Math.floor((hoy - new Date(s.fecha).getTime()) / 86400000)
      const u = usuarios.find(u => u.id === s.usuario_id)
      const item = { ...s, dias, usuario: u?.nombre||"—", saldo: parseFloat(s.saldo_pendiente)||0 }
      buckets.find(b => dias >= b.min && dias <= b.max)?.items.push(item)
    })
    return buckets.map(b => ({
      ...b,
      total: b.items.reduce((a:number,i:any) => a+i.saldo, 0),
      count: b.items.length,
    }))
  }, [solicitudes, usuarios])

  // ── Gastos por mes ────────────────────────────────────────
  const porMes = useMemo(() => {
    const meses = Array.from({length:12},(_,i) => ({
      mes: MESES[i], n: i,
      anticipos:0, reembolsos:0, comprobaciones:0, total:0,
    }))
    del_anio.filter(s => ["liberado","comprobado"].includes(s.status)).forEach(s => {
      const m = new Date(s.fecha).getMonth()
      const v = parseFloat(s.monto)||0
      if (s.tipo==="anticipo") meses[m].anticipos += v
      else if (s.tipo==="reembolso") meses[m].reembolsos += v
      else meses[m].comprobaciones += v
      meses[m].total += v
    })
    return meses
  }, [del_anio])

  // ── Por área ──────────────────────────────────────────────
  const porArea = useMemo(() => {
    const map: Record<string, {label:string,total:number,count:number}> = {}
    del_anio.filter(s => ["liberado","comprobado"].includes(s.status)).forEach(s => {
      const u = usuarios.find(u => u.id === s.usuario_id)
      const cid = u?.centro_id || s.centro_id || "SIN_CENTRO"
      const c = centros.find(c => c.id === cid)
      const label = c ? `${c.id} · ${c.nombre}` : "Sin centro"
      if (!map[cid]) map[cid] = { label, total:0, count:0 }
      map[cid].total += parseFloat(s.monto)||0
      map[cid].count++
    })
    return Object.values(map).sort((a,b) => b.total-a.total)
  }, [del_anio, usuarios, centros])

  // ── Top deudores ──────────────────────────────────────────
  const topDeudores = useMemo(() => {
    const map: Record<string, {nombre:string,iniciales:string,saldo:number,count:number}> = {}
    solicitudes.filter(s => s.tipo==="anticipo" && parseFloat(s.saldo_pendiente)>0 && ["liberado","parcial"].includes(s.status))
      .forEach(s => {
        const u = usuarios.find(u => u.id === s.usuario_id)
        if (!map[s.usuario_id]) map[s.usuario_id] = { nombre:u?.nombre||"—", iniciales:u?.iniciales||"??", saldo:0, count:0 }
        map[s.usuario_id].saldo += parseFloat(s.saldo_pendiente)||0
        map[s.usuario_id].count++
      })
    return Object.values(map).sort((a,b) => b.saldo-a.saldo).slice(0,10)
  }, [solicitudes, usuarios])

  const maxDeudor = topDeudores[0]?.saldo || 1

  const TABS: { id: Tab; label: string; icon: string }[] = [
    { id:"resumen",   label:"Resumen",       icon:"📊" },
    { id:"mensual",   label:"Por mes",       icon:"📅" },
    { id:"area",      label:"Por área",      icon:"🏢" },
    { id:"antiguedad",label:"Antigüedad",    icon:"⏱" },
    { id:"deudores",  label:"Deudores",      icon:"⚑" },
  ]

  if (loading) return <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando reportes…</div>

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Reportes</h1>
          <div className="page-sub">Análisis financiero y operativo</div>
        </div>
        <div style={{display:"flex",alignItems:"center",gap:8}}>
          <label style={{fontSize:12,color:"var(--text-3)"}}>Año</label>
          <select className="select" style={{width:100}} value={anio} onChange={e=>setAnio(+e.target.value)}>
            {[2024,2025,2026,2027].map(y=><option key={y}>{y}</option>)}
          </select>
        </div>
      </div>

      {/* Tabs */}
      <div style={{display:"flex",gap:4,marginBottom:20,flexWrap:"wrap"}}>
        {TABS.map(t=>(
          <button key={t.id} onClick={()=>setTab(t.id)}
            style={{padding:"7px 14px",borderRadius:20,fontSize:13,fontWeight:500,cursor:"pointer",
              border:"1px solid",
              borderColor:tab===t.id?"var(--accent)":"var(--border)",
              background:tab===t.id?"var(--accent-soft)":"var(--surface)",
              color:tab===t.id?"var(--accent)":"var(--text-2)"}}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* ── RESUMEN ── */}
      {tab==="resumen" && (
        <div>
          <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(180px,1fr))",gap:12,marginBottom:24}}>
            {kpis.map(k=>(
              <div key={k.label} className="card" style={{textAlign:"center"}}>
                <div style={{fontSize:22,fontWeight:700,color:k.color}}>{k.value}</div>
                <div style={{fontSize:12,fontWeight:600,marginTop:4}}>{k.label}</div>
                <div style={{fontSize:11,color:"var(--text-3)",marginTop:2}}>{k.sub}</div>
              </div>
            ))}
          </div>
          <div className="card">
            <div className="card-title" style={{marginBottom:16}}>Gastos por mes — {anio}</div>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={porMes} margin={{left:-10}}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)"/>
                <XAxis dataKey="mes" tick={{fontSize:11,fill:"var(--text-3)"}} />
                <YAxis tick={{fontSize:11,fill:"var(--text-3)"}} tickFormatter={v=>v>=1000?`${(v/1000).toFixed(0)}k`:`${v}`}/>
                <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                <Bar dataKey="anticipos" name="Anticipos" fill="#c5f24d" radius={[3,3,0,0]}/>
                <Bar dataKey="reembolsos" name="Reembolsos" fill="#60a5fa" radius={[3,3,0,0]}/>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* ── POR MES ── */}
      {tab==="mensual" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div className="card">
            <div className="card-title" style={{marginBottom:16}}>Tendencia mensual — {anio}</div>
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={porMes} margin={{left:-10}}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)"/>
                <XAxis dataKey="mes" tick={{fontSize:11,fill:"var(--text-3)"}}/>
                <YAxis tick={{fontSize:11,fill:"var(--text-3)"}} tickFormatter={v=>`$${(v/1000).toFixed(0)}k`}/>
                <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                <Legend/>
                <Line type="monotone" dataKey="anticipos" name="Anticipos" stroke="#c5f24d" strokeWidth={2} dot={false}/>
                <Line type="monotone" dataKey="reembolsos" name="Reembolsos" stroke="#60a5fa" strokeWidth={2} dot={false}/>
                <Line type="monotone" dataKey="total" name="Total" stroke="#f97316" strokeWidth={2} strokeDasharray="5 5" dot={false}/>
              </LineChart>
            </ResponsiveContainer>
          </div>
          <div className="card" style={{padding:0,overflow:"hidden"}}>
            <table className="t">
              <thead><tr><th>Mes</th><th className="num">Anticipos</th><th className="num">Reembolsos</th><th className="num">Comprobaciones</th><th className="num">Total</th></tr></thead>
              <tbody>
                {porMes.filter(m=>m.total>0).map(m=>(
                  <tr key={m.mes}>
                    <td style={{fontWeight:600}}>{m.mes}</td>
                    <td className="num">{fmtMXN(m.anticipos)}</td>
                    <td className="num">{fmtMXN(m.reembolsos)}</td>
                    <td className="num">{fmtMXN(m.comprobaciones)}</td>
                    <td className="num" style={{fontWeight:700}}>{fmtMXN(m.total)}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr style={{fontWeight:700,borderTop:"2px solid var(--border)"}}>
                  <td>Total {anio}</td>
                  <td className="num">{fmtMXN(porMes.reduce((a,m)=>a+m.anticipos,0))}</td>
                  <td className="num">{fmtMXN(porMes.reduce((a,m)=>a+m.reembolsos,0))}</td>
                  <td className="num">{fmtMXN(porMes.reduce((a,m)=>a+m.comprobaciones,0))}</td>
                  <td className="num" style={{color:"var(--accent)"}}>{fmtMXN(porMes.reduce((a,m)=>a+m.total,0))}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}

      {/* ── POR ÁREA ── */}
      {tab==="area" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:16}}>
            <div className="card">
              <div className="card-title" style={{marginBottom:16}}>Distribución por área</div>
              <ResponsiveContainer width="100%" height={260}>
                <PieChart>
                  <Pie data={porArea.slice(0,8)} dataKey="total" nameKey="label" cx="50%" cy="50%" outerRadius={100} label={({percent}:{percent?:number})=>`${((percent||0)*100).toFixed(0)}%`}>
                    {porArea.slice(0,8).map((_:any,i:number)=><Cell key={i} fill={COLORS[i%COLORS.length]}/>)}
                  </Pie>
                  <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="card">
              <div className="card-title" style={{marginBottom:16}}>Ranking por gasto</div>
              <ResponsiveContainer width="100%" height={260}>
                <BarChart data={porArea.slice(0,8)} layout="vertical" margin={{left:0}}>
                  <XAxis type="number" tick={{fontSize:10,fill:"var(--text-3)"}} tickFormatter={v=>`$${(v/1000).toFixed(0)}k`}/>
                  <YAxis type="category" dataKey="label" tick={{fontSize:10,fill:"var(--text-3)"}} width={80}
                    tickFormatter={(v:string)=>v.split("·")[0].trim()}/>
                  <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                  <Bar dataKey="total" fill="var(--accent)" radius={[0,4,4,0]}/>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
          <div className="card" style={{padding:0,overflow:"hidden"}}>
            <table className="t">
              <thead><tr><th>#</th><th>Área</th><th className="num">Solicitudes</th><th className="num">Monto</th><th className="num">% del total</th></tr></thead>
              <tbody>
                {porArea.map((a,i)=>{
                  const totalGlobal = porArea.reduce((s:number,x:any)=>s+x.total,0)
                  return (
                    <tr key={a.label}>
                      <td style={{fontWeight:700,color:"var(--text-3)",width:32}}>{i+1}</td>
                      <td style={{fontWeight:500}}>{a.label}</td>
                      <td className="num">{a.count}</td>
                      <td className="num" style={{fontWeight:600}}>{fmtMXN(a.total)}</td>
                      <td className="num">
                        <div style={{display:"flex",alignItems:"center",gap:8,justifyContent:"flex-end"}}>
                          <div style={{width:60,height:4,background:"var(--border)",borderRadius:2}}>
                            <div style={{height:"100%",width:`${(a.total/totalGlobal*100).toFixed(0)}%`,background:"var(--accent)",borderRadius:2}}/>
                          </div>
                          <span style={{fontSize:11,color:"var(--text-3)",width:32}}>{(a.total/totalGlobal*100).toFixed(1)}%</span>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── ANTIGÜEDAD ── */}
      {tab==="antiguedad" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:12}}>
            {antiguedad.map((b,i)=>(
              <div key={b.label} className="card" style={{textAlign:"center",
                borderColor:b.count>0?COLORS[i]:"var(--border)"}}>
                <div style={{fontSize:22,fontWeight:700,color:b.count>0?COLORS[i]:undefined}}>{fmtMXN(b.total)}</div>
                <div style={{fontSize:12,fontWeight:600,margin:"4px 0"}}>{b.label}</div>
                <div style={{fontSize:11,color:"var(--text-3)"}}>{b.count} anticipo{b.count!==1?"s":""}</div>
              </div>
            ))}
          </div>
          {antiguedad.map((b,bi)=>b.items.length>0&&(
            <div key={b.label} className="card" style={{padding:0,overflow:"hidden"}}>
              <div style={{padding:"12px 16px",borderBottom:"1px solid var(--border)",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
                <div style={{fontWeight:600,color:COLORS[bi]}}>{b.label}</div>
                <div style={{fontWeight:700}}>{fmtMXN(b.total)}</div>
              </div>
              <table className="t">
                <thead><tr><th>Folio</th><th>Usuario</th><th>Concepto</th><th className="num">Días</th><th className="num">Saldo</th></tr></thead>
                <tbody>
                  {b.items.sort((a:any,b:any)=>b.dias-a.dias).map((it:any)=>(
                    <tr key={it.id}>
                      <td className="mono" style={{fontSize:11}}>{it.id}</td>
                      <td style={{fontSize:12}}>{it.usuario}</td>
                      <td style={{fontSize:12,maxWidth:200,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{it.concepto}</td>
                      <td className="num">
                        <span style={{fontSize:11,padding:"2px 8px",borderRadius:10,fontWeight:600,
                          background:it.dias>90?"var(--danger-soft)":it.dias>60?"var(--warn-soft)":"var(--surface-2)",
                          color:it.dias>90?"var(--danger)":it.dias>60?"var(--warn)":"var(--text-3)"}}>
                          {it.dias}d
                        </span>
                      </td>
                      <td className="num" style={{fontWeight:600,color:"var(--warn)"}}>{fmtMXN(it.saldo)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ))}
          {antiguedad.every(b=>b.count===0)&&(
            <div className="card" style={{padding:48,textAlign:"center"}}>
              <div style={{fontSize:36,marginBottom:12}}>🎉</div>
              <div style={{fontWeight:600}}>Sin saldos pendientes</div>
            </div>
          )}
        </div>
      )}

      {/* ── TOP DEUDORES ── */}
      {tab==="deudores" && (
        <div style={{display:"flex",flexDirection:"column",gap:12}}>
          <div className="card" style={{marginBottom:4}}>
            <div className="card-title" style={{marginBottom:16}}>Top deudores — saldo por comprobar</div>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={topDeudores} layout="vertical" margin={{left:10}}>
                <XAxis type="number" tick={{fontSize:11,fill:"var(--text-3)"}} tickFormatter={v=>fmtMXN(v)}/>
                <YAxis type="category" dataKey="nombre" tick={{fontSize:11,fill:"var(--text-3)"}} width={120}/>
                <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                <Bar dataKey="saldo" name="Saldo pendiente" fill="var(--danger)" radius={[0,4,4,0]}/>
              </BarChart>
            </ResponsiveContainer>
          </div>
          {topDeudores.map((d,i)=>(
            <div key={d.nombre} className="card" style={{display:"flex",alignItems:"center",gap:14}}>
              <div style={{width:36,height:36,borderRadius:"50%",background:"var(--danger-soft)",
                color:"var(--danger)",display:"grid",placeItems:"center",fontSize:13,fontWeight:700,flexShrink:0}}>
                {d.iniciales}
              </div>
              <div style={{flex:1}}>
                <div style={{fontWeight:600,fontSize:14}}>{d.nombre}</div>
                <div style={{fontSize:11,color:"var(--text-3)",marginTop:2}}>
                  {d.count} anticipo{d.count>1?"s":""} abierto{d.count>1?"s":""}
                </div>
                <div style={{marginTop:6,height:5,background:"var(--border)",borderRadius:3}}>
                  <div style={{height:"100%",width:`${(d.saldo/maxDeudor*100)}%`,
                    background:i===0?"var(--danger)":"var(--warn)",borderRadius:3,transition:"width .5s"}}/>
                </div>
              </div>
              <div style={{textAlign:"right",flexShrink:0}}>
                <div style={{fontWeight:700,fontSize:16,color:"var(--danger)"}}>{fmtMXN(d.saldo)}</div>
                <div style={{fontSize:10,color:"var(--text-3)"}}>#{i+1}</div>
              </div>
            </div>
          ))}
          {topDeudores.length===0&&(
            <div className="card" style={{padding:48,textAlign:"center"}}>
              <div style={{fontSize:36,marginBottom:12}}>🎉</div>
              <div style={{fontWeight:600}}>Sin deudores</div>
            </div>
          )}
        </div>
      )}
    </>
  )
}


FILEEOF

git add .
git commit -m "fix: reportes KPIs only count liberado/comprobado, exclude rechazado from charts"
git push
echo "✓ Done"