"use client"
import { useState } from "react"
import { useTheme } from "@/contexts/ThemeContext"

export function ThemePanel() {
  const { mode, accent, setMode, setAccent, accents } = useTheme()
  const [open, setOpen] = useState(false)

  return (
    <div style={{ position:"relative" }}>
      <button onClick={() => setOpen(!open)}
        style={{ width:32, height:32, borderRadius:8, border:"1px solid var(--border)",
          background:"var(--surface-2)", display:"grid", placeItems:"center",
          cursor:"pointer", fontSize:16 }}>
        {mode === "dark" ? "🌙" : "☀️"}
      </button>

      {open && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:49 }} onClick={() => setOpen(false)}/>
          <div style={{ position:"fixed", top:56, right:8, zIndex:200, width:220,
            background:"var(--surface)", border:"1px solid var(--border)", borderRadius:12,
            padding:14, boxShadow:"0 8px 32px rgba(0,0,0,.3)" }}>
            <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
              letterSpacing:".06em", color:"var(--text-3)", marginBottom:10 }}>
              Tema
            </div>
            {/* Mode toggle */}
            <div style={{ display:"flex", gap:6, marginBottom:14 }}>
              {(["dark","light"] as const).map(m => (
                <button key={m} onClick={() => setMode(m)}
                  style={{ flex:1, padding:"7px 0", borderRadius:8, fontSize:12, fontWeight:600,
                    border:"1px solid",
                    borderColor: mode===m ? "var(--accent)" : "var(--border)",
                    background: mode===m ? "var(--accent-soft)" : "var(--surface-2)",
                    color: mode===m ? "var(--accent)" : "var(--text-3)",
                    cursor:"pointer" }}>
                  {m === "dark" ? "🌙 Oscuro" : "☀️ Claro"}
                </button>
              ))}
            </div>
            <div style={{ fontSize:11, fontWeight:600, textTransform:"uppercase",
              letterSpacing:".06em", color:"var(--text-3)", marginBottom:10 }}>
              Color de acento
            </div>
            <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:6 }}>
              {(Object.entries(accents) as [any, any][]).map(([key, val]) => (
                <button key={key} onClick={() => setAccent(key)}
                  style={{ padding:"8px 6px", borderRadius:8, fontSize:11, fontWeight:600,
                    border:`2px solid ${accent===key ? val.color : "var(--border)"}`,
                    background: accent===key ? val.soft : "var(--surface-2)",
                    color: accent===key ? val.color : "var(--text-2)",
                    cursor:"pointer", display:"flex", alignItems:"center", gap:6 }}>
                  <span style={{ width:12, height:12, borderRadius:"50%",
                    background:val.color, flexShrink:0 }}/>
                  {val.name}
                </button>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  )
}

