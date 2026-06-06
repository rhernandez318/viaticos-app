#!/bin/bash
set -e

mkdir -p $(dirname 'src/components/ReportesPage.tsx')
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

type Tab = "resumen" | "antiguedad" | "mensual" | "area" | "cuenta" | "usuario" | "deudores"

export default function ReportesPage() {
  const [tab, setTab] = useState<Tab>("resumen")
  const [filtroMes,  setFiltroMes]  = useState<string>("todos")
  const [filtroArea, setFiltroArea] = useState<string>("todos")
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [centros, setCentros] = useState<any[]>([])
  const [usuarios, setUsuarios] = useState<any[]>([])
  const [comprobantes, setComprobantes] = useState<any[]>([])
  const [cuentasMap,   setCuentasMap]   = useState<Record<string,string>>({})
  const [loading, setLoading] = useState(true)
  const [anio, setAnio] = useState(new Date().getFullYear())

  useEffect(() => {
    const sb = createClient()
    Promise.all([
      sb.from("solicitudes").select("id,tipo,status,monto,fecha,usuario_id,saldo_pendiente,anticipo_ref,centro_id").order("fecha",{ascending:false}),
      sb.from("comprobantes_cfdi").select("solicitud_id,cuenta,nombre_cuenta,total"),
      sb.from("cuentas_contables").select("cuenta,nombre"),
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
  const kpis = useMemo(() => {
    const total = (tipo?: string, status?: string) =>
      del_anio.filter(s => (!tipo||s.tipo===tipo)&&(!status||s.status===status))
              .reduce((a:number,s:any) => a + parseFloat(s.monto||0), 0)
    const count = (tipo?: string, status?: string) =>
      del_anio.filter(s => (!tipo||s.tipo===tipo)&&(!status||s.status===status)).length
    return [
      { label:"Total gestionado", value:fmtMXN(total()), sub:`${del_anio.length} solicitudes`, color:"var(--accent)" },
      { label:"Anticipos", value:fmtMXN(total("anticipo")), sub:`${count("anticipo")} solicitudes` },
      { label:"Reembolsos", value:fmtMXN(total("reembolso")), sub:`${count("reembolso")} solicitudes` },
      { label:"Saldo pendiente", value:fmtMXN(solicitudes.filter(s=>s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0).reduce((a:number,s:any)=>a+parseFloat(s.saldo_pendiente),0)), sub:"anticipos abiertos", color:"var(--warn)" },
      { label:"Rechazadas", value:count(undefined,"rechazado"), sub:"solicitudes", color:count(undefined,"rechazado")>0?"var(--danger)":undefined },
      { label:"Comprobadas", value:fmtMXN(total(undefined,"comprobado")), sub:`${count(undefined,"comprobado")} solicitudes`, color:"var(--success)" },
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
    del_anio.filter(s => !["rechazado","solicitado"].includes(s.status)).forEach(s => {
      const m = new Date(s.fecha).getMonth()
      const v = parseFloat(s.monto)||0
      if (s.tipo==="anticipo") meses[m].anticipos += v
      else if (s.tipo==="reembolso") meses[m].reembolsos += v
      else meses[m].comprobaciones += v
      meses[m].total += v
    })
    return meses
  }, [del_anio])

  // ── Por área (con filtro de mes) ──────────────────────────
  const porArea = useMemo(() => {
    const _withComp = new Set(del_anio.filter((s:any)=>s.anticipo_ref).map((s:any)=>s.anticipo_ref))
    const map: Record<string, {label:string,total:number,count:number}> = {}
    del_anio.filter((s:any) => {
      if (s.status === "rechazado") return false
      if (s.tipo==="anticipo" && _withComp.has(s.id)) return false
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      return true
    }).forEach((s:any) => {
      const u = usuarios.find((x:any) => x.id === s.usuario_id)
      const cid = u?.centro_id || s.centro_id || null
      // Match by id OR codigo (centros may key on either)
      const c = cid ? centros.find((c:any) => c.id === cid || c.codigo === cid) : null
      const label = c
        ? `${c.codigo || c.id} · ${c.nombre}`
        : (cid ? `Centro ${cid}` : "Sin centro")
      const key = c?.id || c?.codigo || cid || "SIN_CENTRO"
      if (!map[key]) map[key] = { label, total:0, count:0 }
      map[key].total += parseFloat(s.monto)||0
      map[key].count++
    })
    return Object.values(map).sort((a,b) => b.total-a.total)
  }, [del_anio, usuarios, centros, filtroMes])

  // ── Por cuenta contable (desde comprobantes_cfdi) ─────────
  const porCuenta = useMemo(() => {
    const validIds = new Set(del_anio.filter((s:any) => {
      if (s.status === "rechazado") return false
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      return true
    }).map((s:any) => s.id))

    const map: Record<string, { cuenta:string; nombre:string; total:number; count:number }> = {}
    comprobantes.filter((c:any) => validIds.has(c.solicitud_id)).forEach((c:any) => {
      const key = c.cuenta || "—"
      if (!map[key]) map[key] = {
        cuenta: key,
        nombre: c.nombre_cuenta || cuentasMap[key] || "Sin clasificar",
        total: 0, count: 0,
      }
      map[key].total += parseFloat(c.total||0)
      map[key].count++
    })
    return Object.values(map).sort((a,b) => b.total - a.total)
  }, [del_anio, comprobantes, cuentasMap, filtroMes])

  // ── Por usuario (filtros mes + área) ──────────────────────
  const porUsuario = useMemo(() => {
    const _withComp = new Set(del_anio.filter((s:any)=>s.anticipo_ref).map((s:any)=>s.anticipo_ref))
    const map: Record<string, { id:string; nombre:string; iniciales:string; centro:string; total:number; count:number }> = {}
    del_anio.filter((s:any) => {
      if (s.status === "rechazado") return false
      if (s.tipo==="anticipo" && _withComp.has(s.id)) return false
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      const u = usuarios.find((x:any) => x.id === s.usuario_id)
      if (filtroArea !== "todos") {
        const ucid = u?.centro_id || s.centro_id || ""
        const cFilter = centros.find((c:any) => c.id === filtroArea || c.codigo === filtroArea)
        const matches = String(ucid) === filtroArea
          || (cFilter && (String(ucid) === cFilter.id || String(ucid) === cFilter.codigo))
        if (!matches) return false
      }
      return true
    }).forEach((s:any) => {
      const u = usuarios.find((x:any) => x.id === s.usuario_id)
      if (!u) return
      const cid = u.centro_id || s.centro_id || null
      const c = cid ? centros.find((c:any) => c.id === cid || c.codigo === cid) : null
      if (!map[s.usuario_id]) map[s.usuario_id] = {
        id: s.usuario_id,
        nombre: u.nombre || "—",
        iniciales: u.iniciales || "??",
        centro: c ? String(c.codigo || c.id) : (cid ? String(cid) : "—"),
        total: 0, count: 0,
      }
      map[s.usuario_id].total += parseFloat(s.monto||0)
      map[s.usuario_id].count++
    })
    return Object.values(map).sort((a,b) => b.total - a.total)
  }, [del_anio, usuarios, centros, filtroMes, filtroArea])

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
    { id:"cuenta",    label:"Por cuenta",    icon:"📒" },
    { id:"usuario",   label:"Por usuario",   icon:"👤" },
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
          {/* Filtro mes */}
          <div className="card" style={{padding:12,display:"flex",alignItems:"center",gap:10,flexWrap:"wrap"}}>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600}}>Mes:</label>
            <select className="select" value={filtroMes} onChange={e=>setFiltroMes(e.target.value)} style={{maxWidth:160}}>
              <option value="todos">Todos los meses</option>
              {["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"].map((m,i)=>(
                <option key={i} value={String(i)}>{m}</option>
              ))}
            </select>
            {filtroMes!=="todos" && <button className="btn sm ghost" onClick={()=>setFiltroMes("todos")}>Limpiar</button>}
            <span style={{marginLeft:"auto",fontSize:12,color:"var(--text-3)"}}>
              Total: <strong style={{color:"var(--accent)"}}>{fmtMXN(porArea.reduce((a:number,x:any)=>a+x.total,0))}</strong>
            </span>
          </div>

          <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:16}}>
            <div className="card">
              <div className="card-title" style={{marginBottom:16}}>Distribución por área</div>
              {porArea.length===0 ? (
                <div style={{padding:60,textAlign:"center",color:"var(--text-3)",fontSize:13}}>Sin datos para el filtro</div>
              ) : (
                <ResponsiveContainer width="100%" height={260}>
                  <PieChart>
                    <Pie data={porArea.slice(0,8)} dataKey="total" nameKey="label" cx="50%" cy="50%" outerRadius={100} label={({percent}:{percent?:number})=>`${((percent||0)*100).toFixed(0)}%`}>
                      {porArea.slice(0,8).map((_:any,i:number)=><Cell key={i} fill={COLORS[i%COLORS.length]}/>)}
                    </Pie>
                    <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                  </PieChart>
                </ResponsiveContainer>
              )}
            </div>
            <div className="card">
              <div className="card-title" style={{marginBottom:16}}>Ranking por área</div>
              {porArea.length===0 ? (
                <div style={{padding:60,textAlign:"center",color:"var(--text-3)",fontSize:13}}>Sin datos</div>
              ) : (
                <ResponsiveContainer width="100%" height={260}>
                  <BarChart data={porArea.slice(0,8)} layout="vertical" margin={{left:0}}>
                    <XAxis type="number" tick={{fontSize:10,fill:"var(--text-3)"}} tickFormatter={v=>`$${(v/1000).toFixed(0)}k`}/>
                    <YAxis type="category" dataKey="label" tick={{fontSize:10,fill:"var(--text-3)"}} width={80}
                      tickFormatter={(v:string)=>v.split("·")[0].trim()}/>
                    <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                    <Bar dataKey="total" fill="var(--accent)" radius={[0,4,4,0]}/>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>
          <div className="card" style={{padding:0,overflow:"auto"}}>
            <table className="t" style={{minWidth:600}}>
              <thead><tr><th>#</th><th>Área</th><th className="num">Solicitudes</th><th className="num">Monto</th><th className="num">% del total</th></tr></thead>
              <tbody>
                {porArea.map((a:any,i:number)=>{
                  const totalGlobal = porArea.reduce((s:number,x:any)=>s+x.total,0)||1
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

      {/* ── POR CUENTA CONTABLE ── */}
      {tab==="cuenta" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div className="card" style={{padding:12,display:"flex",alignItems:"center",gap:10,flexWrap:"wrap"}}>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600}}>Mes:</label>
            <select className="select" value={filtroMes} onChange={e=>setFiltroMes(e.target.value)} style={{maxWidth:160}}>
              <option value="todos">Todos los meses</option>
              {["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"].map((m,i)=>(
                <option key={i} value={String(i)}>{m}</option>
              ))}
            </select>
            {filtroMes!=="todos" && <button className="btn sm ghost" onClick={()=>setFiltroMes("todos")}>Limpiar</button>}
            <span style={{marginLeft:"auto",fontSize:12,color:"var(--text-3)"}}>
              Total: <strong style={{color:"var(--accent)"}}>{fmtMXN(porCuenta.reduce((a:number,x:any)=>a+x.total,0))}</strong>
            </span>
          </div>

          <div className="card">
            <div className="card-title" style={{marginBottom:16}}>Ranking por cuenta contable</div>
            {porCuenta.length===0 ? (
              <div style={{padding:60,textAlign:"center",color:"var(--text-3)",fontSize:13}}>
                Sin gastos con cuenta contable. Las facturas comprobadas alimentan este gráfico.
              </div>
            ) : (
              <ResponsiveContainer width="100%" height={Math.max(280, porCuenta.length*32)}>
                <BarChart data={porCuenta.slice(0,15)} layout="vertical" margin={{left:0,right:20}}>
                  <XAxis type="number" tick={{fontSize:10,fill:"var(--text-3)"}} tickFormatter={v=>`$${(v/1000).toFixed(0)}k`}/>
                  <YAxis type="category" dataKey="nombre" tick={{fontSize:10,fill:"var(--text-3)"}} width={140}/>
                  <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                  <Bar dataKey="total" fill="var(--accent)" radius={[0,4,4,0]}/>
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
          <div className="card" style={{padding:0,overflow:"auto"}}>
            <table className="t" style={{minWidth:600}}>
              <thead><tr><th>#</th><th>Cuenta</th><th>Nombre</th><th className="num">Movs</th><th className="num">Monto</th><th className="num">% del total</th></tr></thead>
              <tbody>
                {porCuenta.map((c:any,i:number)=>{
                  const totalGlobal = porCuenta.reduce((s:number,x:any)=>s+x.total,0)||1
                  return (
                    <tr key={c.cuenta}>
                      <td style={{fontWeight:700,color:"var(--text-3)",width:32}}>{i+1}</td>
                      <td className="mono" style={{fontSize:11}}>{c.cuenta}</td>
                      <td style={{fontWeight:500}}>{c.nombre}</td>
                      <td className="num">{c.count}</td>
                      <td className="num" style={{fontWeight:600}}>{fmtMXN(c.total)}</td>
                      <td className="num">
                        <div style={{display:"flex",alignItems:"center",gap:8,justifyContent:"flex-end"}}>
                          <div style={{width:60,height:4,background:"var(--border)",borderRadius:2}}>
                            <div style={{height:"100%",width:`${(c.total/totalGlobal*100).toFixed(0)}%`,background:"var(--accent)",borderRadius:2}}/>
                          </div>
                          <span style={{fontSize:11,color:"var(--text-3)",width:32}}>{(c.total/totalGlobal*100).toFixed(1)}%</span>
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

      {/* ── POR USUARIO ── */}
      {tab==="usuario" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div className="card" style={{padding:12,display:"flex",alignItems:"center",gap:10,flexWrap:"wrap"}}>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600}}>Mes:</label>
            <select className="select" value={filtroMes} onChange={e=>setFiltroMes(e.target.value)} style={{maxWidth:160}}>
              <option value="todos">Todos los meses</option>
              {["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"].map((m,i)=>(
                <option key={i} value={String(i)}>{m}</option>
              ))}
            </select>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600,marginLeft:8}}>Área:</label>
            <select className="select" value={filtroArea} onChange={e=>setFiltroArea(e.target.value)} style={{maxWidth:240}}>
              <option value="todos">Todas las áreas</option>
              {centros.map((c:any)=>(
                <option key={c.id} value={c.id}>{c.codigo || c.id} · {c.nombre}</option>
              ))}
            </select>
            {(filtroMes!=="todos"||filtroArea!=="todos") && (
              <button className="btn sm ghost" onClick={()=>{setFiltroMes("todos");setFiltroArea("todos")}}>Limpiar</button>
            )}
            <span style={{marginLeft:"auto",fontSize:12,color:"var(--text-3)"}}>
              Total: <strong style={{color:"var(--accent)"}}>{fmtMXN(porUsuario.reduce((a:number,x:any)=>a+x.total,0))}</strong>
            </span>
          </div>

          <div className="card">
            <div className="card-title" style={{marginBottom:16}}>Gastos por usuario</div>
            {porUsuario.length===0 ? (
              <div style={{padding:60,textAlign:"center",color:"var(--text-3)",fontSize:13}}>Sin gastos para este filtro</div>
            ) : (
              <ResponsiveContainer width="100%" height={Math.max(280, porUsuario.length*32)}>
                <BarChart data={porUsuario.slice(0,20)} layout="vertical" margin={{left:0,right:20}}>
                  <XAxis type="number" tick={{fontSize:10,fill:"var(--text-3)"}} tickFormatter={v=>`$${(v/1000).toFixed(0)}k`}/>
                  <YAxis type="category" dataKey="nombre" tick={{fontSize:10,fill:"var(--text-3)"}} width={140}/>
                  <Tooltip formatter={(v:any)=>fmtMXN(v)} contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}/>
                  <Bar dataKey="total" fill="var(--accent)" radius={[0,4,4,0]}/>
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
          <div className="card" style={{padding:0,overflow:"auto"}}>
            <table className="t" style={{minWidth:600}}>
              <thead><tr><th>#</th><th>Usuario</th><th>Área</th><th className="num">Solicitudes</th><th className="num">Monto</th><th className="num">% del total</th></tr></thead>
              <tbody>
                {porUsuario.map((u:any,i:number)=>{
                  const totalGlobal = porUsuario.reduce((s:number,x:any)=>s+x.total,0)||1
                  return (
                    <tr key={u.id}>
                      <td style={{fontWeight:700,color:"var(--text-3)",width:32}}>{i+1}</td>
                      <td>
                        <div style={{display:"flex",alignItems:"center",gap:8}}>
                          <div style={{width:24,height:24,borderRadius:"50%",background:"var(--surface-2)",border:"1px solid var(--border)",display:"grid",placeItems:"center",fontSize:9,fontWeight:700}}>
                            {u.iniciales}
                          </div>
                          <span style={{fontWeight:500}}>{u.nombre}</span>
                        </div>
                      </td>
                      <td className="mono" style={{fontSize:11,color:"var(--text-3)"}}>{u.centro}</td>
                      <td className="num">{u.count}</td>
                      <td className="num" style={{fontWeight:600}}>{fmtMXN(u.total)}</td>
                      <td className="num">
                        <div style={{display:"flex",alignItems:"center",gap:8,justifyContent:"flex-end"}}>
                          <div style={{width:60,height:4,background:"var(--border)",borderRadius:2}}>
                            <div style={{height:"100%",width:`${(u.total/totalGlobal*100).toFixed(0)}%`,background:"var(--accent)",borderRadius:2}}/>
                          </div>
                          <span style={{fontSize:11,color:"var(--text-3)",width:32}}>{(u.total/totalGlobal*100).toFixed(1)}%</span>
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
    if (!editando.centro_id) { alert("⚠ Debe asignar un Centro de beneficio al usuario"); return }
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
    if (!centro_id) { alert("⚠ Debe asignar un Centro de beneficio al usuario"); return }
    if (!nombre.trim() || !correo.trim() || !password) { alert("⚠ Nombre, correo y contraseña son obligatorios"); return }
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
          <FormField label="Centro de beneficio *">
            <select className="select" required value={nuevoForm.centro_id} onChange={e=>setNuevoForm({...nuevoForm,centro_id:e.target.value})} style={{borderColor:!nuevoForm.centro_id?"var(--danger)":"var(--border)"}}>
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
            <select className="select" required value={editando.centro_id||""} onChange={e=>setEditando({...editando,centro_id:e.target.value||null})} style={{borderColor:!editando.centro_id?"var(--danger)":"var(--border)"}}>
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

git add .
git commit -m "feat: user form requires centro, reportes por cuenta/usuario with filters, centro lookup fix"
git push
echo "✓ Done"