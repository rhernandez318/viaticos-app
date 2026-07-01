"use client"
import type { LucideIcon } from "lucide-react"
import { BarChart3, Building2, BookOpen, User, Clock, FileX, Calendar } from "lucide-react"
import { useState, useEffect, useMemo } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  LineChart, Line, CartesianGrid, PieChart, Pie, Cell, Legend,
} from "recharts"

const COLORS = ["#c5f24d","#60a5fa","#f97316","#c084fc","#4ade80","#fb923c","#38bdf8","#a78bfa"]
const MESES = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
const MESES_LARGOS = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]

type Tab = "resumen" | "antiguedad" | "area" | "cuenta" | "usuario"

export default function ReportesPage() {
  const [tab, setTab] = useState<Tab>("resumen")
  const [filtroMes,  setFiltroMes]  = useState<string>("todos")
  const [filtroArea, setFiltroArea] = useState<string>("todos")
  const [bucketSel,  setBucketSel]  = useState<string | null>(null)  // bucket name for antiguedad filter
  const [solicitudes, setSolicitudes] = useState<any[]>([])
  const [comprobantes,setComprobantes]= useState<any[]>([])
  const [cuentasMap,  setCuentasMap]  = useState<Record<string,string>>({})
  const [centros,     setCentros]     = useState<any[]>([])
  const [usuarios,    setUsuarios]    = useState<any[]>([])
  const [loading,     setLoading]     = useState(true)
  const [anio,        setAnio]        = useState(new Date().getFullYear())

  useEffect(() => {
    const sb = createClient()
    Promise.all([
      sb.from("solicitudes").select("id,tipo,status,monto,fecha,usuario_id,saldo_pendiente,anticipo_ref,centro_id").order("fecha",{ascending:false}),
      sb.from("comprobantes_cfdi").select("solicitud_id,cuenta,nombre_cuenta,total"),
      sb.from("cuentas_contables").select("cuenta,nombre"),
      sb.from("centros").select("*"),
      sb.from("usuarios").select("id,nombre,iniciales,centro_id"),
    ]).then(([s,comps,ctas,c,u]) => {
      setSolicitudes(s.data||[])
      setComprobantes(comps.data||[])
      const cmap: Record<string,string> = {}
      ;(ctas.data || []).forEach((c:any) => { cmap[c.cuenta] = c.nombre })
      setCuentasMap(cmap)
      setCentros(c.data||[])
      setUsuarios(u.data||[])
      setLoading(false)
    })
  }, [])

  const del_anio = useMemo(() =>
    solicitudes.filter(s => new Date(s.fecha).getFullYear() === anio), [solicitudes, anio])

  // ── Resumen KPIs (excluye rechazados + dedup + filtroMes opcional) ──
  const kpis = useMemo(() => {
    const PAGADOS = ["liberado","comprobado"]
    const anticiposConComp = new Set(
      del_anio.filter((s:any) => s.anticipo_ref).map((s:any) => s.anticipo_ref)
    )
    const pagados = del_anio.filter((s:any) => {
      if (!PAGADOS.includes(s.status)) return false
      if (s.tipo === "anticipo" && anticiposConComp.has(s.id)) return false
      // Aplicar filtro de mes si está activo
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      return true
    })
    const total = (tipo?: string) =>
      pagados.filter((s:any) => !tipo || s.tipo === tipo)
             .reduce((a:number,s:any) => a + parseFloat(s.monto||0), 0)
    const count = (tipo?: string) =>
      pagados.filter((s:any) => !tipo || s.tipo === tipo).length

    const rechazadas = del_anio.filter((s:any) => {
      if (s.status !== "rechazado") return false
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      return true
    }).length
    const comps      = pagados.filter((s:any) => s.tipo === "comprobacion")

    return [
      { label:"Total gestionado", value:fmtMXN(total()),             sub:`${count()} gestionadas`,        color:"var(--accent)" },
      { label:"Anticipos",         value:fmtMXN(total("anticipo")),    sub:`${count("anticipo")} sin comp.` },
      { label:"Reembolsos",        value:fmtMXN(total("reembolso")),   sub:`${count("reembolso")} gestionados` },
      { label:"Saldo pendiente",   value:fmtMXN(
          solicitudes.filter((s:any)=>s.tipo==="anticipo"&&parseFloat(s.saldo_pendiente)>0&&["liberado","parcial"].includes(s.status))
                     .reduce((a:number,s:any)=>a+parseFloat(s.saldo_pendiente),0)
        ), sub:"anticipos abiertos", color:"var(--warn)" },
      { label:"Rechazadas",        value:rechazadas,                    sub:"solicitudes", color:rechazadas>0?"var(--danger)":undefined },
      { label:"Comprobadas",       value:fmtMXN(comps.reduce((a:number,s:any)=>a+parseFloat(s.monto||0),0)),
        sub:`${comps.length} comprobaciones`, color:"var(--success)" },
    ]
  }, [del_anio, solicitudes, filtroMes])

  // ── Gastos por mes (excluye anticipos con comp y rechazados) ──────────
  const porMes = useMemo(() => {
    const _withComp = new Set(del_anio.filter((s:any)=>s.anticipo_ref).map((s:any)=>s.anticipo_ref))
    const arr = MESES.map(m => ({ mes:m, anticipos:0, reembolsos:0, comprobaciones:0, total:0 }))
    del_anio.filter((s:any) =>
      ["liberado","comprobado"].includes(s.status) &&
      !(s.tipo==="anticipo" && _withComp.has(s.id))
    ).forEach((s:any) => {
      const m = new Date(s.fecha).getMonth()
      const monto = parseFloat(s.monto)||0
      if (s.tipo==="anticipo")    arr[m].anticipos += monto
      if (s.tipo==="reembolso")   arr[m].reembolsos += monto
      if (s.tipo==="comprobacion") arr[m].comprobaciones += monto
      arr[m].total += monto
    })
    return arr
  }, [del_anio])

  // ── Por área (con filtro mes, label=nombre del centro) ────────────────
  const porArea = useMemo(() => {
    const _withComp = new Set(del_anio.filter((s:any)=>s.anticipo_ref).map((s:any)=>s.anticipo_ref))
    const map: Record<string, {label:string;codigo:string;total:number;count:number}> = {}
    del_anio.filter((s:any) => {
      // Solo comprobados (anticipos comprobados + reembolsos comprobados)
      if (s.status !== "comprobado") return false
      // Excluir anticipos comprobados que tienen CMP vinculada (evitar doble conteo $30K+$32K)
      if (s.tipo === "anticipo" && _withComp.has(s.id)) return false
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      return true
    }).forEach((s:any) => {
      const u = usuarios.find((x:any) => x.id === s.usuario_id)
      const cid = u?.centro_id || s.centro_id || null
      const c = cid ? centros.find((c:any) => c.id === cid || c.codigo === cid) : null
      const label  = c?.nombre || (cid ? `Centro ${cid}` : "Sin centro")
      const codigo = String(c?.id || c?.codigo || cid || "")
      const key = codigo || "SIN_CENTRO"
      if (!map[key]) map[key] = { label, codigo, total:0, count:0 }
      map[key].total += parseFloat(s.monto)||0
      map[key].count++
    })
    return Object.values(map).sort((a,b) => b.total-a.total)
  }, [del_anio, usuarios, centros, filtroMes])

  // ── Por cuenta contable (desde comprobantes_cfdi) ─────────────────────
  const porCuenta = useMemo(() => {
    const validIds = new Set(del_anio.filter((s:any) => {
      if (s.status !== "comprobado") return false
      if (filtroMes !== "todos") {
        const m = new Date(s.fecha).getMonth()
        if (String(m) !== filtroMes) return false
      }
      return true
    }).map((s:any) => s.id))
    const map: Record<string, {cuenta:string;nombre:string;total:number;count:number}> = {}
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

  // ── Por usuario (solo comprobados, dedup ANT con CMP, filtros mes+área) ─
  const porUsuario = useMemo(() => {
    const anticiposConComp = new Set(
      del_anio.filter((s:any) => s.anticipo_ref).map((s:any) => s.anticipo_ref)
    )
    const map: Record<string, {id:string;nombre:string;iniciales:string;centro:string;centroCodigo:string;total:number;count:number}> = {}
    del_anio.filter((s:any) => {
      if (s.status !== "comprobado") return false
      if (s.tipo === "anticipo" && anticiposConComp.has(s.id)) return false
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
        centro: c?.nombre || (cid ? `Centro ${cid}` : "—"),
        centroCodigo: String(c?.id || c?.codigo || cid || ""),
        total: 0, count: 0,
      }
      map[s.usuario_id].total += parseFloat(s.monto||0)
      map[s.usuario_id].count++
    })
    return Object.values(map).sort((a,b) => b.total - a.total)
  }, [del_anio, usuarios, centros, filtroMes, filtroArea])

  // ── Top deudores (con filtro por bucket de antigüedad opcional) ───────
  const topDeudores = useMemo(() => {
    const buckets: Record<string, [number,number]> = {
      "0-15 días":  [0,15],
      "16-30 días": [16,30],
      "31-60 días": [31,60],
      "60+ días":   [61,9999],
    }
    const rango = bucketSel ? buckets[bucketSel] : null
    const map: Record<string, {nombre:string,iniciales:string,saldo:number,count:number,maxDias:number}> = {}
    solicitudes.filter(s =>
      s.tipo==="anticipo" &&
      parseFloat(s.saldo_pendiente)>0 &&
      ["liberado","parcial"].includes(s.status)
    ).forEach(s => {
      const dias = Math.floor((Date.now() - new Date(s.fecha).getTime())/86400000)
      // Si hay bucket seleccionado, solo incluir anticipos en ese rango
      if (rango && (dias < rango[0] || dias > rango[1])) return
      const u = usuarios.find(u => u.id === s.usuario_id)
      if (!map[s.usuario_id]) map[s.usuario_id] = {
        nombre:u?.nombre||"—", iniciales:u?.iniciales||"??",
        saldo:0, count:0, maxDias:0,
      }
      map[s.usuario_id].saldo += parseFloat(s.saldo_pendiente)||0
      map[s.usuario_id].count++
      if (dias > map[s.usuario_id].maxDias) map[s.usuario_id].maxDias = dias
    })
    return Object.values(map).sort((a,b) => b.saldo-a.saldo)
  }, [solicitudes, usuarios, bucketSel])

  const maxDeudor = topDeudores[0]?.saldo || 1

  // ── Antigüedad ────────────────────────────────────────────────────────
  const antiguedad = useMemo(() => {
    const buckets = [
      { label:"0-15 días",  rango:[0,15],    count:0, monto:0, color:"var(--success)" },
      { label:"16-30 días", rango:[16,30],   count:0, monto:0, color:"#fbbf24" },
      { label:"31-60 días", rango:[31,60],   count:0, monto:0, color:"var(--warn)" },
      { label:"60+ días",   rango:[61,9999], count:0, monto:0, color:"var(--danger)" },
    ]
    solicitudes.filter(s => s.tipo==="anticipo" && parseFloat(s.saldo_pendiente)>0 && ["liberado","parcial"].includes(s.status))
      .forEach(s => {
        const dias = Math.floor((Date.now() - new Date(s.fecha).getTime())/86400000)
        const bucket = buckets.find(b => dias>=b.rango[0] && dias<=b.rango[1])
        if (bucket) { bucket.count++; bucket.monto += parseFloat(s.saldo_pendiente)||0 }
      })
    return buckets
  }, [solicitudes])

  const TABS: { id: Tab; label: string; icon: LucideIcon }[] = [
    { id:"resumen",   label:"Resumen",       icon: BarChart3 },
    { id:"area",      label:"Por área",      icon: Building2 },
    { id:"cuenta",    label:"Por cuenta",    icon: BookOpen },
    { id:"usuario",   label:"Por usuario",   icon: User },
    { id:"antiguedad",label:"Antigüedad",    icon: Clock },
  ]

  if (loading) return <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando reportes…</div>

  return (
    <>
      <div className="page-head" style={{display:"flex",alignItems:"flex-start",justifyContent:"space-between",gap:16,flexWrap:"wrap"}}>
        <div>
          <h1 className="page-title">Reportes</h1>
          <div className="page-sub">Análisis financiero y operativo</div>
        </div>
        <div style={{display:"flex",alignItems:"center",gap:8}}>
          <label style={{fontSize:12,color:"var(--text-3)"}}>Año</label>
          <select className="select" value={anio} onChange={e=>setAnio(parseInt(e.target.value))} style={{maxWidth:100}}>
            {Array.from({length:5}).map((_,i)=>{
              const y = new Date().getFullYear()-i
              return <option key={y} value={y}>{y}</option>
            })}
          </select>
        </div>
      </div>

      {/* TABS */}
      <div style={{display:"flex",gap:6,marginBottom:14,flexWrap:"wrap",overflowX:"auto"}}>
        {TABS.map(t => (
          <button key={t.id} onClick={()=>setTab(t.id)}
            className="btn sm"
            style={{
              borderColor:tab===t.id?"var(--accent)":"var(--border)",
              background:tab===t.id?"var(--accent-soft)":"var(--surface)",
              color:tab===t.id?"var(--accent)":"var(--text-2)",
              fontWeight:tab===t.id?700:500, whiteSpace:"nowrap",
            }}>
            {(() => { const TabIcon = t.icon; return <TabIcon size={14} strokeWidth={1.75} style={{marginRight:4,verticalAlign:"middle"}}/> })()}{t.label}
          </button>
        ))}
      </div>

      {/* RESUMEN (KPIs + LineChart interactivo) */}
      {tab==="resumen" && (
        <>
          {/* Indicador de filtro activo */}
          {filtroMes !== "todos" && (
            <div className="card" style={{padding:"10px 14px",marginBottom:12,display:"flex",alignItems:"center",justifyContent:"space-between",gap:10,flexWrap:"wrap",background:"var(--accent-soft)",borderColor:"var(--accent)"}}>
              <div style={{fontSize:13,color:"var(--accent)",fontWeight:600}}>
                <Calendar size={14} strokeWidth={2} color="var(--accent, #c5f24d)" style={{marginRight:6,verticalAlign:"middle"}}/>Filtrando por {MESES_LARGOS[parseInt(filtroMes)]} {anio}
              </div>
              <button className="btn sm ghost" onClick={()=>setFiltroMes("todos")}>
                Ver todo el año
              </button>
            </div>
          )}

          {/* KPIs */}
          <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit, minmax(180px, 1fr))",gap:12,marginBottom:16}}>
            {kpis.map((k,i)=>(
              <div key={i} className="card">
                <div style={{fontSize:22,fontWeight:700,color:k.color||"var(--text)"}}>{k.value}</div>
                <div style={{fontSize:11,color:"var(--text-3)",marginTop:6}}>{k.label}</div>
                <div style={{fontSize:10,color:"var(--text-3)",marginTop:2}}>{k.sub}</div>
              </div>
            ))}
          </div>

          {/* Línea interactiva: clic en mes filtra KPIs */}
          <div className="card">
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:16,flexWrap:"wrap",gap:8}}>
              <div className="card-title" style={{margin:0,textTransform:"uppercase",fontSize:11,letterSpacing:".05em"}}>
                Gastos por mes — {anio}
              </div>
              <div style={{fontSize:11,color:"var(--text-3)"}}>
                Haz clic en un mes para filtrar los KPIs
              </div>
            </div>
            <ResponsiveContainer width="100%" height={320}>
              <LineChart data={porMes} margin={{left:-10,right:10}}
                onClick={(e:any) => {
                  if (e?.activeLabel) {
                    const idx = MESES.indexOf(e.activeLabel)
                    if (idx >= 0) setFiltroMes(filtroMes === String(idx) ? "todos" : String(idx))
                  }
                }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)"/>
                <XAxis dataKey="mes" tick={(props:any) => {
                  const m = MESES.indexOf(props.payload.value)
                  const isSelected = String(m) === filtroMes
                  return (
                    <text {...props}
                      style={{
                        fontSize: 11,
                        fill: isSelected ? "var(--accent)" : "var(--text-3)",
                        fontWeight: isSelected ? 700 : 400,
                        cursor: "pointer",
                      }}>{props.payload.value}</text>
                  )
                }}/>
                <YAxis tick={{fontSize:11,fill:"var(--text-3)"}} tickFormatter={v=>`$${(v/1000).toFixed(0)}k`}/>
                <Tooltip
                  formatter={(v:any)=>fmtMXN(v)}
                  contentStyle={{background:"var(--surface)",border:"1px solid var(--border)",borderRadius:8}}
                  cursor={{stroke:"var(--accent)",strokeWidth:1,strokeDasharray:"3 3"}}/>
                <Legend wrapperStyle={{fontSize:12,cursor:"pointer"}}/>
                <Line type="monotone" dataKey="anticipos"      stroke="var(--accent)" strokeWidth={2}
                  activeDot={{r:7, onClick:(_:any,e:any) => {
                    const payload = e?.payload || e
                    const idx = MESES.indexOf(payload?.mes || payload?.activeLabel)
                    if (idx >= 0) setFiltroMes(filtroMes === String(idx) ? "todos" : String(idx))
                  }}}/>
                <Line type="monotone" dataKey="reembolsos"     stroke="#60a5fa"       strokeWidth={2}
                  activeDot={{r:7}}/>
                <Line type="monotone" dataKey="comprobaciones" stroke="#c084fc"       strokeWidth={2}
                  activeDot={{r:7}}/>
              </LineChart>
            </ResponsiveContainer>
            <div style={{display:"flex",gap:6,flexWrap:"wrap",marginTop:12,paddingTop:12,borderTop:"1px solid var(--border)"}}>
              {MESES.map((m,i)=>{
                const isActive = String(i) === filtroMes
                return (
                  <button key={m}
                    className="btn sm"
                    onClick={()=>setFiltroMes(isActive ? "todos" : String(i))}
                    style={{
                      fontSize: 11,
                      padding: "4px 10px",
                      borderColor: isActive ? "var(--accent)" : "var(--border)",
                      background: isActive ? "var(--accent-soft)" : "var(--surface)",
                      color: isActive ? "var(--accent)" : "var(--text-2)",
                      fontWeight: isActive ? 700 : 500,
                    }}>
                    {m}
                  </button>
                )
              })}
            </div>
          </div>
        </>
      )}

      {/* POR ÁREA (con filtro mes) */}
      {tab==="area" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div className="card" style={{padding:12,display:"flex",alignItems:"center",gap:10,flexWrap:"wrap"}}>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600}}>Mes:</label>
            <select className="select" value={filtroMes} onChange={e=>setFiltroMes(e.target.value)} style={{maxWidth:160}}>
              <option value="todos">Todos los meses</option>
              {MESES_LARGOS.map((m,i)=><option key={i} value={String(i)}>{m}</option>)}
            </select>
            {filtroMes!=="todos" && <button className="btn sm ghost" onClick={()=>setFiltroMes("todos")}>Limpiar</button>}
            <span style={{marginLeft:"auto",fontSize:12,color:"var(--text-3)"}}>
              Total: <strong style={{color:"var(--accent)"}}>{fmtMXN(porArea.reduce((a,x)=>a+x.total,0))}</strong>
            </span>
          </div>
          <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:16}}>
            <div className="card">
              <div className="card-title" style={{marginBottom:16}}>Distribución por área</div>
              {porArea.length===0 ? (
                <div style={{padding:60,textAlign:"center",color:"var(--text-3)",fontSize:13}}>Sin datos</div>
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
                    <YAxis type="category" dataKey="label" tick={{fontSize:10,fill:"var(--text-3)"}} width={120}/>
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
                {porArea.map((a,i)=>{
                  const totalGlobal = porArea.reduce((s,x)=>s+x.total,0)||1
                  return (
                    <tr key={a.codigo||a.label}>
                      <td style={{fontWeight:700,color:"var(--text-3)",width:32}}>{i+1}</td>
                      <td>
                        <div style={{fontWeight:500}}>{a.label}</div>
                        {a.codigo && a.codigo!==a.label && (
                          <div className="mono" style={{fontSize:10,color:"var(--text-3)",marginTop:2}}>{a.codigo}</div>
                        )}
                      </td>
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

      {/* POR CUENTA CONTABLE */}
      {tab==="cuenta" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div className="card" style={{padding:12,display:"flex",alignItems:"center",gap:10,flexWrap:"wrap"}}>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600}}>Mes:</label>
            <select className="select" value={filtroMes} onChange={e=>setFiltroMes(e.target.value)} style={{maxWidth:160}}>
              <option value="todos">Todos los meses</option>
              {MESES_LARGOS.map((m,i)=><option key={i} value={String(i)}>{m}</option>)}
            </select>
            {filtroMes!=="todos" && <button className="btn sm ghost" onClick={()=>setFiltroMes("todos")}>Limpiar</button>}
            <span style={{marginLeft:"auto",fontSize:12,color:"var(--text-3)"}}>
              Total: <strong style={{color:"var(--accent)"}}>{fmtMXN(porCuenta.reduce((a,x)=>a+x.total,0))}</strong>
            </span>
          </div>
          <div className="card">
            <div className="card-title" style={{marginBottom:16}}>Ranking por cuenta contable</div>
            {porCuenta.length===0 ? (
              <div style={{padding:60,textAlign:"center",color:"var(--text-3)",fontSize:13}}>
                <div style={{display:"flex",justifyContent:"center",marginBottom:12}}><FileX size={40} strokeWidth={1.5} style={{color:"var(--text-3, #888)"}}/></div>
                Sin datos para este filtro.
                <div style={{fontSize:11,marginTop:10}}>
                  {comprobantes.length === 0
                    ? "Aún no hay comprobantes XML registrados."
                    : `Hay ${comprobantes.length} comprobantes en BD, pero ninguno entra en el filtro.`}
                </div>
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
                {porCuenta.map((c,i)=>{
                  const totalGlobal = porCuenta.reduce((s,x)=>s+x.total,0)||1
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

      {/* POR USUARIO */}
      {tab==="usuario" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          <div className="card" style={{padding:12,display:"flex",alignItems:"center",gap:10,flexWrap:"wrap"}}>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600}}>Mes:</label>
            <select className="select" value={filtroMes} onChange={e=>setFiltroMes(e.target.value)} style={{maxWidth:160}}>
              <option value="todos">Todos los meses</option>
              {MESES_LARGOS.map((m,i)=><option key={i} value={String(i)}>{m}</option>)}
            </select>
            <label style={{fontSize:12,color:"var(--text-3)",fontWeight:600,marginLeft:8}}>Área:</label>
            <select className="select" value={filtroArea} onChange={e=>setFiltroArea(e.target.value)} style={{maxWidth:280}}>
              <option value="todos">Todas las áreas</option>
              {centros.map((c:any)=>(
                <option key={c.id} value={c.id}>{c.nombre}</option>
              ))}
            </select>
            {(filtroMes!=="todos"||filtroArea!=="todos") && (
              <button className="btn sm ghost" onClick={()=>{setFiltroMes("todos");setFiltroArea("todos")}}>Limpiar</button>
            )}
            <span style={{marginLeft:"auto",fontSize:12,color:"var(--text-3)"}}>
              Total: <strong style={{color:"var(--accent)"}}>{fmtMXN(porUsuario.reduce((a,x)=>a+x.total,0))}</strong>
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
                {porUsuario.map((u,i)=>{
                  const totalGlobal = porUsuario.reduce((s,x)=>s+x.total,0)||1
                  return (
                    <tr key={u.id}>
                      <td style={{fontWeight:700,color:"var(--text-3)",width:32}}>{i+1}</td>
                      <td>
                        <div style={{display:"flex",alignItems:"center",gap:8}}>
                          <div style={{width:24,height:24,borderRadius:"50%",background:"var(--surface-2)",border:"1px solid var(--border)",display:"grid",placeItems:"center",fontSize:9,fontWeight:700}}>{u.iniciales}</div>
                          <span style={{fontWeight:500}}>{u.nombre}</span>
                        </div>
                      </td>
                      <td>
                        <div style={{fontWeight:500,fontSize:12}}>{u.centro}</div>
                        {u.centroCodigo && (
                          <div className="mono" style={{fontSize:10,color:"var(--text-3)",marginTop:2}}>{u.centroCodigo}</div>
                        )}
                      </td>
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

      {/* ANTIGÜEDAD + DEUDORES UNIFICADOS */}
      {tab==="antiguedad" && (
        <div style={{display:"flex",flexDirection:"column",gap:16}}>
          {/* Buckets clickeables */}
          <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit, minmax(200px, 1fr))",gap:12}}>
            {antiguedad.map(b => {
              const active = bucketSel === b.label
              return (
                <button key={b.label}
                  onClick={() => setBucketSel(active ? null : b.label)}
                  className="card"
                  style={{
                    border: `2px solid ${active ? b.color : "var(--border)"}`,
                    background: active ? "var(--surface-2)" : "var(--surface)",
                    cursor: "pointer", textAlign: "left",
                    transition: "all 150ms ease",
                    transform: active ? "translateY(-2px)" : "none",
                    boxShadow: active ? `0 4px 12px ${b.color}33` : "none",
                  }}>
                  <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:6}}>
                    <span style={{fontSize:11,color:"var(--text-3)",fontWeight:600}}>{b.label}</span>
                    {active && <span style={{fontSize:10,color:b.color,fontWeight:700}}>● Filtrando</span>}
                  </div>
                  <div style={{fontSize:22,fontWeight:700,color:b.color}}>{fmtMXN(b.monto)}</div>
                  <div style={{fontSize:11,color:"var(--text-3)",marginTop:4}}>{b.count} anticipos</div>
                </button>
              )
            })}
          </div>

          {/* Tabla de deudores filtrada */}
          <div className="card" style={{padding:0,overflow:"auto"}}>
            <div style={{padding:"14px 16px 6px",display:"flex",alignItems:"center",justifyContent:"space-between",gap:10,flexWrap:"wrap"}}>
              <div className="card-title" style={{margin:0}}>
                {bucketSel
                  ? `Deudores con anticipos de ${bucketSel.toLowerCase()}`
                  : "Todos los deudores"}
              </div>
              <div style={{display:"flex",alignItems:"center",gap:10}}>
                {bucketSel && (
                  <button className="btn sm ghost" onClick={()=>setBucketSel(null)}>
                    Ver todos
                  </button>
                )}
                <span style={{fontSize:12,color:"var(--text-3)"}}>
                  Total: <strong style={{color:"var(--warn)"}}>
                    {fmtMXN(topDeudores.reduce((a,d)=>a+d.saldo,0))}
                  </strong>
                </span>
              </div>
            </div>
            {topDeudores.length === 0 ? (
              <div style={{padding:40,textAlign:"center",color:"var(--text-3)",fontSize:13}}>
                {bucketSel
                  ? "Sin deudores en este rango de antigüedad"
                  : "Sin anticipos pendientes — ningún deudor"}
              </div>
            ) : (
              <table className="t" style={{minWidth:700}}>
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Usuario</th>
                    <th className="num">Anticipos</th>
                    <th className="num">Días máx.</th>
                    <th className="num">Saldo</th>
                    <th style={{minWidth:120}}>Proporción</th>
                  </tr>
                </thead>
                <tbody>
                  {topDeudores.map((d:any,i:number)=>(
                    <tr key={d.nombre+i}>
                      <td style={{fontWeight:700,color:"var(--text-3)",width:32}}>{i+1}</td>
                      <td>
                        <div style={{display:"flex",alignItems:"center",gap:8}}>
                          <div style={{width:24,height:24,borderRadius:"50%",background:"var(--surface-2)",border:"1px solid var(--border)",display:"grid",placeItems:"center",fontSize:9,fontWeight:700}}>
                            {d.iniciales}
                          </div>
                          <span style={{fontWeight:500}}>{d.nombre}</span>
                        </div>
                      </td>
                      <td className="num">{d.count}</td>
                      <td className="num">
                        <span style={{
                          fontWeight:600,
                          color: d.maxDias > 60 ? "var(--danger)"
                              : d.maxDias > 30 ? "var(--warn)"
                              : d.maxDias > 15 ? "#fbbf24"
                              : "var(--success)",
                        }}>
                          {d.maxDias}d
                        </span>
                      </td>
                      <td className="num" style={{fontWeight:600,color:"var(--warn)"}}>{fmtMXN(d.saldo)}</td>
                      <td>
                        <div style={{width:100,height:4,background:"var(--border)",borderRadius:2}}>
                          <div style={{height:"100%",width:`${(d.saldo/maxDeudor*100).toFixed(0)}%`,background:"var(--warn)",borderRadius:2}}/>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </>
  )
}

