#!/bin/bash
set -e

mkdir -p $(dirname 'src/components/ui/NotificationBell.tsx')
cat > 'src/components/ui/NotificationBell.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { fmtFecha } from "@/lib/format"

interface Notif {
  id: string
  titulo: string
  cuerpo: string
  tipo: string
  leida: boolean
  created_at: string
  solicitud_id?: string
}

const TIPO_ICON: Record<string, string> = {
  aprobacion: "✅", rechazo: "❌", liberacion: "💵",
  comprobacion: "📎", cierre: "🏦", sistema: "ℹ️", default: "🔔",
}

export function NotificationBell({ userId }: { userId: string }) {
  const [notifs, setNotifs] = useState<Notif[]>([])
  const [open, setOpen] = useState(false)
  const unread = notifs.filter(n => !n.leida).length

  const load = useCallback(async () => {
    const sb = createClient()
    // Try notificaciones table, fallback to bitacora
    const { data, error } = await sb
      .from("notificaciones")
      .select("*")
      .eq("usuario_id", userId)
      .order("created_at", { ascending: false })
      .limit(30)

    if (!error && data) {
      setNotifs(data)
    } else {
      // Fallback: use bitacora entries as notifications
      const { data: bData } = await sb
        .from("bitacora")
        .select("id, accion, detalle, ts, solicitud_id")
        .order("ts", { ascending: false })
        .limit(20)
      if (bData && bData.length > 0) {
        setNotifs(bData.map((b: any) => ({
          id: b.id, titulo: b.accion, cuerpo: b.detalle || "",
          tipo: b.accion, leida: true,
          created_at: b.ts, solicitud_id: b.solicitud_id,
        })))
      } else {
        setNotifs([])
      }
    }
  }, [userId])

  useEffect(() => { load() }, [load])

  // Real-time subscription (only if notificaciones table exists)
  useEffect(() => {
    const sb = createClient()
    try {
      const channel = sb.channel("notifs-" + userId)
        .on("postgres_changes", {
          event: "INSERT", schema: "public", table: "notificaciones",
          filter: `usuario_id=eq.${userId}`,
        }, payload => {
          setNotifs(prev => [payload.new as Notif, ...prev])
        })
        .subscribe()
      return () => { sb.removeChannel(channel) }
    } catch {}
  }, [userId])

  const markAllRead = async () => {
    const sb = createClient()
    const unreadIds = notifs.filter(n => !n.leida).map(n => n.id)
    if (!unreadIds.length) return
    await sb.from("notificaciones").update({ leida: true }).in("id", unreadIds)
    setNotifs(prev => prev.map(n => ({ ...n, leida: true })))
  }

  const markRead = async (id: string) => {
    const sb = createClient()
    await sb.from("notificaciones").update({ leida: true }).eq("id", id)
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, leida: true } : n))
  }

  return (
    <div style={{ position: "relative" }}>
      <button onClick={() => { setOpen(!open); if (!open && unread > 0) markAllRead() }}
        style={{
          width: 36, height: 36, borderRadius: 8, border: "1px solid var(--border)",
          background: "var(--surface-2)", display: "grid", placeItems: "center",
          cursor: "pointer", position: "relative", fontSize: 18,
        }}>
        🔔
        {unread > 0 && (
          <span style={{
            position: "absolute", top: -4, right: -4,
            width: 18, height: 18, borderRadius: "50%",
            background: "var(--danger)", color: "#fff",
            fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center",
            border: "2px solid var(--bg)",
          }}>
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>

      {open && (
        <>
          <div style={{ position: "fixed", inset: 0, zIndex: 49 }} onClick={() => setOpen(false)} />
          <div style={{
            position: "fixed", top: 56, left: 8, right: 8, zIndex: 200,
            width: "auto", maxWidth: 360, maxHeight: 480, overflowY: "auto",
            background: "var(--surface)", border: "1px solid var(--border)",
            borderRadius: 12, boxShadow: "0 8px 32px rgba(0,0,0,.4)",
          }}>
            <div style={{
              padding: "12px 16px", display: "flex", justifyContent: "space-between",
              alignItems: "center", borderBottom: "1px solid var(--border)", position: "sticky", top: 0,
              background: "var(--surface)",
            }}>
              <div style={{ fontWeight: 700, fontSize: 14 }}>Notificaciones</div>
              {unread > 0 && (
                <button onClick={markAllRead}
                  style={{ fontSize: 11, color: "var(--accent)", background: "none", border: "none", cursor: "pointer" }}>
                  Marcar todo leído
                </button>
              )}
            </div>

            {notifs.length === 0 ? (
              <div style={{ padding: 32, textAlign: "center", color: "var(--text-3)", fontSize: 13 }}>
                <div style={{ fontSize: 32, marginBottom: 8 }}>🔔</div>
                Sin notificaciones
              </div>
            ) : (
              notifs.map(n => (
                <div key={n.id}
                  onClick={() => markRead(n.id)}
                  style={{
                    padding: "12px 16px", borderBottom: "1px solid var(--border)",
                    cursor: "pointer", display: "flex", gap: 12, alignItems: "flex-start",
                    background: n.leida ? "transparent" : "var(--accent-soft)",
                    transition: "background .15s",
                  }}>
                  <span style={{ fontSize: 20, flexShrink: 0, marginTop: 1 }}>
                    {TIPO_ICON[n.tipo] || TIPO_ICON.default}
                  </span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: n.leida ? 400 : 600,
                      overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {n.titulo}
                    </div>
                    {n.cuerpo && (
                      <div style={{ fontSize: 11.5, color: "var(--text-3)", marginTop: 2,
                        overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        {n.cuerpo}
                      </div>
                    )}
                    <div style={{ fontSize: 10.5, color: "var(--text-3)", marginTop: 3 }}>
                      {fmtFecha(n.created_at)}
                    </div>
                  </div>
                  {!n.leida && (
                    <div style={{ width: 8, height: 8, borderRadius: "50%",
                      background: "var(--accent)", flexShrink: 0, marginTop: 5 }} />
                  )}
                </div>
              ))
            )}
          </div>
        </>
      )}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/ThemePanel.tsx')
cat > 'src/components/ui/ThemePanel.tsx' << 'FILEEOF'
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

FILEEOF

mkdir -p $(dirname 'src/components/ui/CompUploader.tsx')
cat > 'src/components/ui/CompUploader.tsx' << 'FILEEOF'
"use client"
import { useRef, useCallback, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { parseCFDIXml } from "@/lib/cfdi"
import type { CfdItem } from "@/types"

const CUENTA_PATTERNS: [RegExp, string][] = [
  [/(peaje|caseta|autopista|telepeaje|iave)/i,          "6122700001"],
  [/(estacionamiento|parking|parquímetro)/i,            "6122700002"],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i,"6122600001"],
  [/(taxi|uber|didi|cabify|transporte)/i,               "6122900002"],
  [/(hotel|hospedaje|alojamiento)/i,                    "6122100001"],
  [/(restaurante|alimentos|comida|cenar|comer)/i,       "6122200001"],
  [/(aéreo|vuelo|boleto|avión)/i,                       "6122400001"],
]

function guessCuentaFromText(text: string): string {
  for (const [re, cuenta] of CUENTA_PATTERNS) {
    if (re.test(text)) return cuenta
  }
  return "6121200001"
}

function parseTotalFromOCR(text: string): number {
  // Look for total patterns like "Total: $1,234.56" or "TOTAL 1234.56"
  const patterns = [
    /total\s*[:$]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /importe\s*[:$]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /\$\s*([\d,]+\.\d{2})\s*$/m,
  ]
  for (const p of patterns) {
    const m = text.match(p)
    if (m) {
      const val = parseFloat(m[1].replace(/,/g, ""))
      if (val > 0 && val < 1000000) return val
    }
  }
  // Last number that looks like a price
  const nums = [...text.matchAll(/\$?\s*([\d,]+\.\d{2})/g)]
    .map(m => parseFloat(m[1].replace(/,/g,"")))
    .filter(v => v > 0 && v < 1000000)
  return nums.length ? Math.max(...nums) : 0
}

async function runOCR(file: File): Promise<{ text: string; total: number; cuenta: string }> {
  const { createWorker } = await import("tesseract.js")
  const worker = await createWorker("spa", 1, {
    logger: () => {},
  })
  const url = URL.createObjectURL(file)
  const { data: { text } } = await worker.recognize(url)
  await worker.terminate()
  URL.revokeObjectURL(url)

  const total  = parseTotalFromOCR(text)
  const cuenta = guessCuentaFromText(text)
  return { text, total, cuenta }
}

interface Props {
  solicitudId?: string
  catalogoGastos: Array<{ cuenta: string; nombre: string }>
  onAdd: (items: CfdItem[]) => void
}

export function CompUploader({ solicitudId, onAdd }: Props) {
  const [uploading, setUploading] = useState(false)
  const [ocrProgress, setOcrProgress] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  const checkDuplicate = async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id")
      .eq("uuid", uuid)
      .limit(1)
    return data && data.length > 0 ? "Ya comprobado" : null
  }

  const processFiles = useCallback(async (files: FileList | null) => {
    if (!files || !files.length) return
    setUploading(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { setUploading(false); return }

    const newItems: CfdItem[] = []

    for (const file of Array.from(files)) {
      const isXml = file.name.toLowerCase().endsWith(".xml")
      const isPdf = file.name.toLowerCase().endsWith(".pdf")
      const isImg = file.type.startsWith("image/")
      if (!isXml && !isPdf && !isImg) continue

      // Upload file to Storage
      let archivoUrl: string | null = null
      const ext = file.name.split(".").pop()
      const path = `${solicitudId || "tmp"}/${Date.now()}.${ext}`
      const { data: up } = await sb.storage.from("comprobantes").upload(path, file, { upsert: true })
      if (up) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }

      if (isXml) {
        const text = await file.text()
        const parsed = parseCFDIXml(text)
        if (!parsed) continue
        parsed.archivoUrl = archivoUrl
        const motivoDup = await checkDuplicate(parsed.uuid)
        newItems.push({ ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined })

      } else if (isImg) {
        // Run OCR on images (tickets, receipts)
        setOcrProgress(`Leyendo ticket: ${file.name}…`)
        try {
          const { text, total, cuenta } = await runOCR(file)
          const iva = total > 0 ? Math.round(total * 16 / 116 * 100) / 100 : 0
          const subtotal = Math.round((total - iva) * 100) / 100
          newItems.push({
            uuid: `OCR-${Date.now()}`,
            emisor: file.name.replace(/\.[^.]+$/, ""),
            concepto: text.slice(0, 60).replace(/\n/g, " ").trim() || "Ticket sin factura",
            subtotal, iva, total,
            cuenta, confianza: total > 0 ? 0.7 : 0.3,
            archivoUrl, duplicado: false,
            ocrLeido: true,
          } as unknown as CfdItem)
          setOcrProgress(null)
        } catch (e) {
          setOcrProgress(null)
          // Fallback: add without OCR
          newItems.push({
            uuid: `IMG-${Date.now()}`,
            emisor: file.name, concepto: "Imagen sin factura",
            subtotal: 0, iva: 0, total: 0,
            cuenta: "6121200001", confianza: 0.3,
            archivoUrl, duplicado: false,
          } as unknown as CfdItem)
        }

      } else {
        // PDF without OCR
        newItems.push({
          uuid: `PDF-${Date.now()}`,
          emisor: file.name, concepto: "PDF adjunto",
          subtotal: 0, iva: 0, total: 0,
          cuenta: "6121200001", confianza: 0.3,
          archivoUrl, duplicado: false,
        } as unknown as CfdItem)
      }
    }

    if (newItems.length > 0) onAdd(newItems)
    if (fileRef.current) fileRef.current.value = ""
    setUploading(false)
    setOcrProgress(null)
  }, [solicitudId, onAdd])

  return (
    <div>
      <div className="card"
        style={{ border:"2px dashed var(--border)", textAlign:"center", padding:"24px 20px",
          cursor: uploading ? "default" : "pointer" }}
        onClick={() => !uploading && fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; processFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize:24, marginBottom:6 }}>{uploading ? "⏳" : "📂"}</div>
        <div style={{ fontWeight:600, marginBottom:3, fontSize:13 }}>
          {ocrProgress ? ocrProgress : uploading ? "Procesando…" : "Arrastra o clic para subir"}
        </div>
        <div style={{ fontSize:11.5, color:"var(--text-3)" }}>
          XML (CFDI), PDF o imagen — tickets con OCR automático
        </div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => processFiles(e.target.files)} />
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(auth)/login/page.tsx')
cat > 'src/app/(auth)/login/page.tsx' << 'FILEEOF'
"use client"
import { useState, useEffect, useRef } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import Image from "next/image"
import { triggerNotifSetup } from "@/components/ui/PushNotifications"

function InstallButton() {
  const [canInstall, setCanInstall] = useState(false)
  const promptRef = useRef<any>(null)
  useEffect(() => {
    const handler = (e: Event) => { e.preventDefault(); promptRef.current = e; setCanInstall(true) }
    window.addEventListener("beforeinstallprompt", handler)
    return () => window.removeEventListener("beforeinstallprompt", handler)
  }, [])
  if (!canInstall) return null
  return (
    <button onClick={async () => {
      if (!promptRef.current) return
      await promptRef.current.prompt()
      const { outcome } = await promptRef.current.userChoice
      if (outcome === "accepted") { promptRef.current = null; setCanInstall(false) }
    }} style={{
      marginTop:12, width:"100%", padding:"11px", borderRadius:10,
      border:"1px solid var(--border)", background:"var(--surface-2)",
      color:"var(--text-2)", fontSize:13, fontWeight:500, cursor:"pointer",
      display:"flex", alignItems:"center", justifyContent:"center", gap:8,
    }}>⬇️ Instalar aplicación</button>
  )
}

export default function LoginPage() {
  const [email,    setEmail]    = useState("")
  const [password, setPassword] = useState("")
  const [error,    setError]    = useState<string|null>(null)
  const [loading,  setLoading]  = useState(false)
  const [mode,     setMode]     = useState<"login"|"recover">("login")
  const [sent,     setSent]     = useState(false)
  const router = useRouter()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) { setError("Credenciales incorrectas"); setLoading(false); return }
    router.push("/dashboard")
  }

  const handleRecover = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.trim()) { setError("Ingresa tu correo"); return }
    setLoading(true); setError(null)
    const sb = createClient()
    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/dashboard`,
    })
    if (error) { setError("Error al enviar: " + error.message); setLoading(false); return }
    setSent(true); setLoading(false)
  }

  return (
    <div style={{ minHeight:"100vh", display:"grid", placeItems:"center", background:"var(--bg)" }}>
      <div style={{ width:"100%", maxWidth:380, padding:"0 20px" }}>
        {/* Logo */}
        <div style={{ textAlign:"center", marginBottom:28 }}>
          <div style={{ width:80, height:80, margin:"0 auto 14px", borderRadius:20,
            overflow:"hidden", background:"white", padding:4, boxShadow:"0 8px 32px rgba(0,0,0,.2)" }}>
            <Image src="/logo.png" alt="Grupo Zapata" width={72} height={72}
              style={{ width:"100%", height:"100%", objectFit:"contain" }}/>
          </div>
          <div style={{ fontSize:24, fontWeight:800, letterSpacing:"-0.03em", marginBottom:4 }}>
            Grupo Zapata
          </div>
          <div style={{ fontSize:13, color:"var(--text-3)" }}>Sistema de Viáticos</div>
        </div>

        {mode === "login" ? (
          <>
            <form onSubmit={handleLogin} style={{ display:"flex", flexDirection:"column", gap:12 }}>
              <div>
                <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                  Correo electrónico
                </label>
                <input className="input" type="email" value={email}
                  onChange={e=>setEmail(e.target.value)} required
                  placeholder="usuario@grupozapata.com.mx" autoComplete="email"/>
              </div>
              <div>
                <div style={{ display:"flex", justifyContent:"space-between", marginBottom:4 }}>
                  <label style={{ fontSize:12, color:"var(--text-3)" }}>Contraseña</label>
                  <button type="button" onClick={()=>{ setMode("recover"); setError(null); setSent(false) }}
                    style={{ fontSize:12, color:"var(--accent)", background:"none", border:"none",
                      cursor:"pointer", padding:0 }}>
                    ¿Olvidaste tu contraseña?
                  </button>
                </div>
                <input className="input" type="password" value={password}
                  onChange={e=>setPassword(e.target.value)} required
                  placeholder="••••••••" autoComplete="current-password"/>
              </div>
              {error && (
                <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                  borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>{error}</div>
              )}
              <button className="btn primary" type="submit" disabled={loading}
                style={{ justifyContent:"center", marginTop:4, padding:"12px" }}>
                {loading ? "Iniciando sesión…" : "Entrar →"}
              </button>
            </form>
            <InstallButton/>
          </>
        ) : sent ? (
          <div style={{ textAlign:"center", padding:"24px 0" }}>
            <div style={{ fontSize:40, marginBottom:16 }}>📧</div>
            <div style={{ fontWeight:700, fontSize:16, marginBottom:8 }}>Revisa tu correo</div>
            <div style={{ fontSize:13, color:"var(--text-3)", lineHeight:1.6, marginBottom:20 }}>
              Enviamos un enlace a <strong>{email}</strong> para restablecer tu contraseña.
              Puede tardar unos minutos.
            </div>
            <button className="btn ghost" onClick={()=>{ setMode("login"); setSent(false) }}
              style={{ width:"100%" }}>
              ← Volver al inicio de sesión
            </button>
          </div>
        ) : (
          <form onSubmit={handleRecover} style={{ display:"flex", flexDirection:"column", gap:12 }}>
            <div style={{ marginBottom:4 }}>
              <div style={{ fontWeight:700, fontSize:16, marginBottom:6 }}>Recuperar contraseña</div>
              <div style={{ fontSize:13, color:"var(--text-3)" }}>
                Ingresa tu correo y te enviaremos un enlace para restablecerla.
              </div>
            </div>
            <div>
              <label style={{ fontSize:12, color:"var(--text-3)", marginBottom:4, display:"block" }}>
                Correo electrónico
              </label>
              <input className="input" type="email" value={email}
                onChange={e=>setEmail(e.target.value)} required
                placeholder="usuario@grupozapata.com.mx" autoComplete="email"/>
            </div>
            {error && (
              <div style={{ padding:"8px 12px", background:"var(--danger-soft)",
                borderRadius:"var(--r-md)", fontSize:12, color:"var(--danger)" }}>{error}</div>
            )}
            <button className="btn primary" type="submit" disabled={loading}
              style={{ justifyContent:"center", padding:"12px" }}>
              {loading ? "Enviando…" : "Enviar enlace de recuperación"}
            </button>
            <button type="button" className="btn ghost" onClick={()=>{ setMode("login"); setError(null) }}
              style={{ justifyContent:"center" }}>
              ← Volver
            </button>
          </form>
        )}
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/globals.css')
cat > 'src/app/globals.css' << 'FILEEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* ── Design tokens (same as current app) ──────────────────────────────────── */
:root {
  --bg:          #0d0d0d;
  --surface:     #161616;
  --surface-2:   #1c1c1c;
  --border:      #2a2a2a;
  --text:        #f0f0f0;
  --text-2:      #b0b0b0;
  --text-3:      #606060;
  --accent:      #c5f24d;
  --accent-soft: rgba(197,242,77,.12);
  --success:     #4ade80;
  --success-soft:rgba(74,222,128,.12);
  --danger:      #e24b4a;
  --danger-soft: rgba(226,75,74,.12);
  --warn:        #f59e0b;
  --warn-soft:   rgba(245,158,11,.12);
  --r-sm:        6px;
  --r-md:        8px;
  --r-lg:        12px;
  --r-xl:        16px;
  --f-display:   "Geist", system-ui, sans-serif;
}

.light {
  --bg:       #f5f5f0;
  --surface:  #ffffff;
  --surface-2:#f0f0ec;
  --border:   #ddddd8;
  --text:     #1a1a1a;
  --text-2:   #444444;
  --text-3:   #999999;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--f-display);
  font-size: 14px;
  min-height: 100vh;
}

/* ── Shared component styles ─────────────────────────────────────────────── */
.btn {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 8px 14px; border-radius: var(--r-md);
  border: 1px solid var(--border); background: var(--surface);
  color: var(--text); font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all .15s;
}
.btn:hover { border-color: var(--text-3); }
.btn.primary { background: var(--accent); border-color: var(--accent); color: #111; }
.btn.primary:hover { opacity: .9; }
.btn.ghost { background: transparent; }
.btn.sm { padding: 5px 10px; font-size: 12px; }
.btn:disabled { opacity: .5; cursor: not-allowed; }

.card {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-lg); padding: 16px;
}
.card-title { font-weight: 600; font-size: 13px; color: var(--text-2); letter-spacing: .05em; text-transform: uppercase; }

.input, .select {
  width: 100%; padding: 8px 10px;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--r-md); color: var(--text); font-size: 13px;
  outline: none; transition: border-color .15s;
}
.input:focus, .select:focus { border-color: var(--accent); }

.badge {
  display: inline-flex; align-items: center;
  padding: 2px 10px; border-radius: 20px;
  font-size: 11px; font-weight: 600;
}
.badge.solicitado { background: rgba(245,158,11,.15); color: var(--warn); }
.badge.autorizado { background: var(--accent-soft); color: var(--accent); }
.badge.liberado   { background: rgba(96,165,250,.15); color: #60a5fa; }
.badge.comprobado { background: var(--success-soft); color: var(--success); }
.badge.rechazado  { background: var(--danger-soft); color: var(--danger); }
.badge.parcial    { background: rgba(245,158,11,.15); color: var(--warn); }

.t { width: 100%; border-collapse: collapse; font-size: 13px; }
.t th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600;
        color: var(--text-3); border-bottom: 1px solid var(--border); white-space: nowrap; }
.t td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
.t tbody tr:hover { background: var(--surface-2); }
.t .num { text-align: right; font-variant-numeric: tabular-nums; font-family: monospace; }
.mono { font-family: monospace; }
.muted { color: var(--text-3); }
.spread { display: flex; align-items: center; justify-content: space-between; }
.row { display: flex; align-items: center; gap: 8px; }
.divider { height: 1px; background: var(--border); }

/* ── Sidebar layout ──────────────────────────────────────────────────────── */
.app-layout {
  display: grid;
  grid-template-columns: 220px 1fr;
  min-height: 100vh;
}
.sidebar {
  background: var(--surface); border-right: 1px solid var(--border);
  padding: 20px 12px; display: flex; flex-direction: column; gap: 2px;
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.nav-item {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 12px; border-radius: var(--r-md);
  color: var(--text-2); font-size: 13px; font-weight: 500;
  cursor: pointer; transition: all .15s; text-decoration: none;
}
.nav-item:hover { background: var(--surface-2); color: var(--text); }
.nav-item.active { background: var(--accent-soft); color: var(--accent); }
.main-content { padding: 24px 32px; overflow-y: auto; }

/* ── Page header ─────────────────────────────────────────────────────────── */
.page-head { display: flex; align-items: flex-start; justify-content: space-between;
             margin-bottom: 20px; gap: 12px; flex-wrap: wrap; }
.page-title { font-size: 24px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }
.page-sub { font-size: 13px; color: var(--text-3); margin-top: 4px; }

/* ── Stepper ─────────────────────────────────────────────────────────────── */
.stepper { display: flex; gap: 0; width: 100%; }
.step { flex: 1; display: flex; flex-direction: column; align-items: center; position: relative; }
.step::before { content: ""; position: absolute; top: 12px; right: -50%;
               width: 100%; height: 2px; background: var(--border); z-index: 0; }
.step:last-child::before { display: none; }
.step.done::before { background: var(--success); }
.step.active::before { background: var(--border); }
.step .dot { width: 24px; height: 24px; border-radius: 50%; border: 2px solid var(--border);
             display: grid; placeItems: center; font-size: 11px; font-weight: 700;
             background: var(--bg); position: relative; z-index: 1; }
.step.done .dot { background: var(--success); border-color: var(--success); color: #000; }
.step.active .dot { background: var(--accent); border-color: var(--accent); color: #000; }
.step.rejected .dot { background: var(--danger); border-color: var(--danger); color: #fff; }
.step .label { font-size: 10px; color: var(--text-3); margin-top: 4px; }
.step.active .label, .step.done .label { color: var(--text); }
.step .meta { font-size: 9px; color: var(--text-3); margin-top: 2px; }
.table { width: 100%; border-collapse: collapse; font-size: 13px; }
.table th { padding: 8px 12px; text-align: left; font-size: 11px; font-weight: 600; color: var(--text-3); border-bottom: 1px solid var(--border); white-space: nowrap; }
.table td { padding: 10px 12px; border-bottom: 1px solid var(--border); }
.table tbody tr:hover { background: var(--surface-2); }
.table .num, .table .right { text-align: right; }
.kpi-grid { display: grid; gap: 12; }
.kpi { background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-lg); padding: 14px 16px; }
.kpi-label { font-size: 11px; color: var(--text-3); text-transform: uppercase; letter-spacing: .05em; }
.kpi-value { font-size: 22px; font-weight: 700; margin-top: 4px; font-variant-numeric: tabular-nums; }

/* ── Mobile responsive layout ────────────────────────────────────────────── */
@media (max-width: 768px) {
  .app-layout {
    grid-template-columns: 1fr;
    grid-template-rows: 1fr auto;
  }
  .sidebar {
    display: none;
  }
  .main-content {
    padding: 16px 16px 80px;
  }
  .page-title { font-size: 20px; }
  .page-head { margin-bottom: 14px; }

  /* Bottom navigation for mobile */
  .mobile-nav {
    display: flex;
    position: fixed; bottom: 0; left: 0; right: 0; z-index: 50;
    background: var(--surface); border-top: 1px solid var(--border);
    padding: 8px 4px 12px;
    gap: 0;
  }
  .mobile-nav-item {
    flex: 1; display: flex; flex-direction: column; align-items: center;
    gap: 3px; padding: 4px 2px; cursor: pointer; text-decoration: none;
    color: var(--text-3); border: none; background: none; font-family: inherit;
    transition: color .15s;
  }
  .mobile-nav-item.active { color: var(--accent); }
  .mobile-nav-item span.icon { font-size: 20px; }
  .mobile-nav-item span.label { font-size: 9px; font-weight: 600; text-align: center; }

  /* Adjust cards and tables for mobile */
  .card { padding: 12px; }
  .t { font-size: 12px; }
  .t th, .t td { padding: 8px 8px; }
  .t th:nth-child(n+5), .t td:nth-child(n+5) { display: none; }
}

@media (min-width: 769px) {
  .mobile-nav { display: none !important; }
}

/* ── Safe area for notched phones ──────────────────────────────────────── */
@supports (padding-bottom: env(safe-area-inset-bottom)) {
  .mobile-nav { padding-bottom: calc(12px + env(safe-area-inset-bottom)); }
  @media (max-width: 768px) { .main-content { padding-bottom: calc(80px + env(safe-area-inset-bottom)); } }
}

@keyframes slideUp {
  from { transform: translateY(100%); opacity: 0; }
  to   { transform: translateY(0);    opacity: 1; }
}

/* ── Mobile top bar ──────────────────────────────────────────────────────── */
.mobile-topbar {
  display: none;
}
@media (max-width: 768px) {
  .mobile-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: sticky;
    top: 0;
    z-index: 50;
    height: 48px;
    min-height: 48px;
    max-height: 48px;
    overflow: visible;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 0 16px;
    margin: -16px -16px 16px -16px;
    flex-shrink: 0;
  }
  .main-content {
    padding-top: 0 !important;
  }
}

FILEEOF

git add .
git commit -m "fix: dropdown dirs, mobile topbar height, password recovery, OCR tickets"
git push
echo "✓ Done"