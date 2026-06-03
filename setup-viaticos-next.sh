#!/bin/bash
set -e
echo "Setting up viaticos-next files..."

mkdir -p $(dirname 'src/middleware.ts')
cat > 'src/middleware.ts' << 'FILEEOF'
import { type NextRequest } from "next/server"
import { updateSession } from "@/lib/supabase/middleware"

export async function middleware(request: NextRequest) {
  return await updateSession(request)
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
}

FILEEOF

mkdir -p $(dirname 'src/types/index.ts')
cat > 'src/types/index.ts' << 'FILEEOF'
// ─── Core domain types ────────────────────────────────────────────────────────

export type Rol = "usuario" | "gerente" | "tesoreria" | "contador" | "admin"

export type SolicitudStatus = "solicitado" | "autorizado" | "liberado" | "comprobado" | "rechazado" | "parcial"

export type SolicitudTipo = "anticipo" | "reembolso" | "comprobacion"

export interface Usuario {
  id: string
  nombre: string
  correo: string
  rol: Rol
  iniciales: string
  centro: string | null
  gerente: string | null
  division: "4105" | "4106" | string
  clabe: string | null
  banco: string | null
  suplanteId: string | null
  suplantaDesde: string | null
  suplantaHasta: string | null
}

export interface Centro {
  id: string
  nombre: string
  depto: string
  division: string
}

export interface CuentaContable {
  cuenta: string
  nombre: string
  grupo: string
  activo: boolean
}

export interface CfdItem {
  id?: string
  uuid: string
  emisor: string
  concepto: string
  subtotal: number
  iva: number
  total: number
  cuenta: string
  confianza: number
  archivoUrl: string | null
  archivoPdfUrl?: string | null
  archivoXmlUrl?: string | null
  rfcEmisor?: string | null
  rfcReceptor?: string | null
  satEstado?: string | null
  duplicado?: boolean
  motivoDup?: string
  ocrLeido?: boolean
  ocrPendiente?: boolean
}

export interface Solicitud {
  id: string
  tipo: SolicitudTipo
  concepto: string
  usuario: string
  monto: number
  fecha: Date
  status: SolicitudStatus
  saldoPendiente: number
  division?: string
  anticipoRef?: string | null
  motivoRechazo?: string | null
  notas?: string | null
  esCierre?: boolean
  comprobantes?: number
  centroId?: string | null
  cfdi?: CfdItem[]
  items?: Array<{ cuenta: string; desc: string; monto: number }>
}

export interface BitacoraEntry {
  id: string
  solicitudId: string
  accion: string
  usuarioId: string
  detalle?: string
  ts: string
}

export interface PolizaLinea {
  poliza: string
  folio: string
  fecha: string
  centro: string
  area: string
  division: string
  cuenta: string
  nombreCuenta: string
  tipo: "C" | "A"  // Cargo / Abono
  debe: number
  haber: number
  concepto: string
  proveedor: string
  usuario: string
  ref: string
  _archivos?: Array<{ nombre: string; url: string | null; uuid: string | null; emisor?: string | null; total?: number }>
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/CompUploader.tsx')
cat > 'src/components/ui/CompUploader.tsx' << 'FILEEOF'
"use client"

import { useRef, useCallback, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { parseCFDIXml } from "@/lib/cfdi"
import { fmtMXN } from "@/lib/format"
import type { CfdItem } from "@/types"

interface Props {
  solicitudId?: string
  catalogoGastos: Array<{ cuenta: string; nombre: string }>
  onAdd: (items: CfdItem[]) => void
  onOcrUpdate?: (id: string, updated: Partial<CfdItem>) => void
}

export function CompUploader({ solicitudId, catalogoGastos, onAdd }: Props) {
  const [uploading, setUploading] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const checkDuplicado = async (uuid: string, existingItems: CfdItem[]): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id, solicitudes!inner(status)")
      .eq("uuid", uuid)
      .not("solicitudes.status", "eq", "rechazado")
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

      // Upload
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
        const motivoDup = await checkDuplicado(parsed.uuid, newItems)
        newItems.push({ ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined })
      } else {
        newItems.push({
          uuid: "", emisor: file.name, concepto: file.name,
          subtotal: 0, iva: 0, total: 0, cuenta: "6121200001",
          confianza: 0.5, archivoUrl, duplicado: false,
        })
      }
    }

    if (newItems.length > 0) onAdd(newItems)
    if (fileRef.current) fileRef.current.value = ""
    setUploading(false)
  }, [solicitudId, onAdd])

  return (
    <div>
      <div
        className="card"
        style={{ border: "2px dashed var(--border)", textAlign: "center", padding: "24px 20px", cursor: "pointer" }}
        onClick={() => fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor = "var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor = "var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor = "var(--border)"; processFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize: 24, marginBottom: 6 }}>📂</div>
        <div style={{ fontWeight: 600, marginBottom: 3, fontSize: 13 }}>
          {uploading ? "Procesando…" : "Arrastra o clic para subir"}
        </div>
        <div style={{ fontSize: 11.5, color: "var(--text-3)" }}>XML (CFDI), PDF o imagen de ticket</div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => processFiles(e.target.files)} />
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/ComingSoon.tsx')
cat > 'src/components/ui/ComingSoon.tsx' << 'FILEEOF'
import Link from "next/link"

const PHASE: Record<string, { fase: number; label: string }> = {
  "Bandeja de aprobaciones":    { fase: 3, label: "Flujos de aprobación" },
  "Liberar pagos":              { fase: 3, label: "Flujos de aprobación" },
  "Pagados":                    { fase: 3, label: "Flujos de aprobación" },
  "Deudores":                   { fase: 3, label: "Flujos de aprobación" },
  "Mi equipo":                  { fase: 3, label: "Flujos de aprobación" },
  "Bandeja admin":              { fase: 3, label: "Flujos de aprobación" },
  "Detalle de solicitud":       { fase: 3, label: "Flujos de aprobación" },
  "Cerrar anticipo":            { fase: 2, label: "Solicitudes" },
  "Pólizas contables":          { fase: 4, label: "Contador + Admin" },
  "Trazabilidad de póliza":     { fase: 4, label: "Contador + Admin" },
  "Validación SAT":             { fase: 4, label: "Contador + Admin" },
  "Conciliación SAT":           { fase: 4, label: "Contador + Admin" },
  "Usuarios":                   { fase: 4, label: "Contador + Admin" },
  "Centros de beneficio":       { fase: 4, label: "Contador + Admin" },
  "Catálogo":                   { fase: 4, label: "Contador + Admin" },
  "Catálogo de gastos":         { fase: 4, label: "Contador + Admin" },
  "Mi perfil":                  { fase: 4, label: "Contador + Admin" },
  "Reportes":                   { fase: 4, label: "Contador + Admin" },
}

export function ComingSoon({ title }: { title: string }) {
  const info = PHASE[title]
  return (
    <div style={{ display: "grid", placeItems: "center", minHeight: "60vh" }}>
      <div style={{ textAlign: "center", maxWidth: 400, padding: "0 20px" }}>
        <div style={{ fontSize: 48, marginBottom: 16 }}>🚧</div>
        <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 8 }}>{title}</h2>
        <p style={{ color: "var(--text-3)", fontSize: 13.5, lineHeight: 1.6, marginBottom: 20 }}>
          Esta sección está siendo migrada a Next.js.
          {info && (
            <><br />
              <span style={{ color: "var(--accent)", fontWeight: 600 }}>
                Fase {info.fase} — {info.label}
              </span>
            </>
          )}
        </p>
        <div style={{ display:"flex", gap:8, justifyContent:"center", flexWrap:"wrap" }}>
          <Link href="/dashboard" className="btn ghost" style={{ fontSize: 13 }}>
            ← Inicio
          </Link>
          <a href="https://rhernandez318.github.io/Viaticos/"
            target="_blank" rel="noopener"
            className="btn primary" style={{ fontSize: 13 }}>
            Versión actual ↗
          </a>
        </div>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/Stepper.tsx')
cat > 'src/components/ui/Stepper.tsx' << 'FILEEOF'
"use client"
import { fmtFecha } from "@/lib/format"
import type { SolicitudStatus } from "@/types"

const STEPS = [
  { key: "solicitado", label: "Solicitado" },
  { key: "autorizado", label: "Autorizado" },
  { key: "liberado",   label: "Liberado"   },
  { key: "comprobado", label: "Comprobado" },
]

const ORDER: Record<string, number> = {
  solicitado: 0, autorizado: 1, liberado: 2, comprobado: 3, parcial: 2,
}

export function Stepper({ status, dates }: { status: SolicitudStatus; dates?: Record<string, Date | null> }) {
  if (status === "rechazado") {
    return (
      <div className="stepper">
        <div className="step done"><div className="dot">1</div><div className="label">Solicitado</div></div>
        <div className="step rejected"><div className="dot">✕</div><div className="label">Rechazado</div></div>
      </div>
    )
  }
  const cur = ORDER[status] ?? 0
  return (
    <div className="stepper">
      {STEPS.map((s, i) => {
        const cls = i < cur ? "done" : i === cur ? "active" : ""
        return (
          <div key={s.key} className={`step ${cls}`}>
            <div className="dot">{i < cur ? "✓" : i + 1}</div>
            <div className="label">{s.label}</div>
            {dates?.[s.key] && <div className="meta">{fmtFecha(dates[s.key])}</div>}
          </div>
        )
      })}
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/StatusBadge.tsx')
cat > 'src/components/ui/StatusBadge.tsx' << 'FILEEOF'
import type { SolicitudStatus } from "@/types"

const LABELS: Record<string, string> = {
  solicitado: "Solicitado", autorizado: "Autorizado", liberado: "Liberado",
  comprobado: "Comprobado", rechazado: "Rechazado", parcial: "Parcial",
}

export function StatusBadge({ status }: { status: SolicitudStatus }) {
  return <span className={`badge ${status}`}>{LABELS[status] ?? status}</span>
}

export function TipoBadge({ tipo }: { tipo: string }) {
  const map: Record<string, string> = { anticipo: "ANT", comprobacion: "CMP", reembolso: "REE" }
  return <span className="badge tipo">{map[tipo] ?? tipo}</span>
}

FILEEOF

mkdir -p $(dirname 'src/components/layout/AppShell.tsx')
cat > 'src/components/layout/AppShell.tsx' << 'FILEEOF'
"use client"

import { usePathname } from "next/navigation"
import Link from "next/link"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"

const ICONS: Record<string, string> = {
  home: "⊞", book: "📋", chart: "📊", users: "👥", settings: "⚙️",
  check: "✓", shield: "🛡", search: "🔍", cash: "💵", flag: "⚑",
}

interface NavItem { id: string; label: string; icon: string; href: string }

const NAV_BY_ROL: Record<string, NavItem[]> = {
  usuario: [
    { id: "dashboard", label: "Inicio", icon: "home", href: "/dashboard" },
    { id: "anticipo", label: "Solicitar anticipo", icon: "cash", href: "/solicitudes/anticipo" },
    { id: "reembolso", label: "Reembolso", icon: "check", href: "/solicitudes/reembolso" },
    { id: "historial", label: "Mis solicitudes", icon: "book", href: "/solicitudes" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  gerente: [
    { id: "bandeja", label: "Por aprobar", icon: "check", href: "/gerente" },
    { id: "equipo", label: "Mi equipo", icon: "users", href: "/gerente/equipo" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/gerente/reportes" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  tesoreria: [
    { id: "liberar", label: "Liberar pagos", icon: "cash", href: "/tesoreria" },
    { id: "pagados", label: "Pagados", icon: "check", href: "/tesoreria/pagados" },
    { id: "deudores", label: "Deudores", icon: "flag", href: "/tesoreria/deudores" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/tesoreria/reportes" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  contador: [
    { id: "polizas", label: "Pólizas contables", icon: "book", href: "/contador/polizas" },
    { id: "trazabilidad", label: "Trazabilidad", icon: "search", href: "/contador/trazabilidad" },
    { id: "validacion-sat", label: "Validación SAT", icon: "shield", href: "/contador/validacion-sat" },
    { id: "conciliacion-sat", label: "Conciliación SAT", icon: "check", href: "/contador/conciliacion-sat" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/contador/reportes" },
    { id: "catalogo", label: "Catálogo de gastos", icon: "book", href: "/contador/catalogo" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
  admin: [
    { id: "dashboard", label: "Inicio", icon: "home", href: "/dashboard" },
    { id: "bandeja", label: "Por aprobar", icon: "check", href: "/admin/bandeja" },
    { id: "liberar", label: "Liberar pagos", icon: "cash", href: "/admin/liberar" },
    { id: "usuarios", label: "Usuarios", icon: "users", href: "/admin/usuarios" },
    { id: "centros", label: "Centros", icon: "book", href: "/admin/centros" },
    { id: "catalogo", label: "Catálogo", icon: "book", href: "/admin/catalogo" },
    { id: "reportes", label: "Reportes", icon: "chart", href: "/admin/reportes" },
    { id: "polizas", label: "Pólizas", icon: "book", href: "/contador/polizas" },
    { id: "perfil", label: "Mi perfil", icon: "settings", href: "/perfil" },
  ],
}

export default function AppShell({ user, children }: { user: any; children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const navItems = NAV_BY_ROL[user.rol] || []

  const handleLogout = async () => {
    const sb = createClient()
    await sb.auth.signOut()
    router.push("/login")
  }

  return (
    <div className="app-layout">
      {/* Sidebar */}
      <aside className="sidebar">
        <div style={{ padding: "8px 12px 20px" }}>
          <div style={{ fontSize: 15, fontWeight: 700, letterSpacing: "-0.02em" }}>
            Casa Zapata
          </div>
          <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 2 }}>Viáticos</div>
        </div>

        <nav style={{ flex: 1 }}>
          {navItems.map((item) => (
            <Link
              key={item.id}
              href={item.href}
              className={`nav-item ${pathname.startsWith(item.href) && item.href !== "/" ? "active" : ""}`}
            >
              <span style={{ fontSize: 15 }}>{ICONS[item.icon] || "•"}</span>
              {item.label}
            </Link>
          ))}
        </nav>

        {/* User info */}
        <div style={{ borderTop: "1px solid var(--border)", paddingTop: 12, marginTop: 8 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "6px 12px" }}>
            <div style={{
              width: 30, height: 30, borderRadius: "50%",
              background: "var(--accent-soft)", color: "var(--accent)",
              display: "grid", placeItems: "center",
              fontSize: 12, fontWeight: 700
            }}>
              {user.iniciales}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 12, fontWeight: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {user.nombre}
              </div>
              <div style={{ fontSize: 10, color: "var(--text-3)", textTransform: "capitalize" }}>{user.rol}</div>
            </div>
          </div>
          <button className="btn ghost" onClick={handleLogout}
            style={{ width: "100%", justifyContent: "center", fontSize: 12, marginTop: 4 }}>
            Cerrar sesión
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="main-content">
        {children}
      </main>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/hooks/useCatalogos.ts')
cat > 'src/hooks/useCatalogos.ts' << 'FILEEOF'
"use client"

import { useEffect, useState, useCallback } from "react"
import { createClient } from "@/lib/supabase/client"
import { catalogos, findUser } from "@/store/catalogos"
import type { Usuario, Centro, CuentaContable, Solicitud } from "@/types"

export function useCatalogos() {
  const [loaded, setLoaded] = useState(catalogos.dbLoaded)

  const load = useCallback(async () => {
    const sb = createClient()
    const [centrosRes, cuentasRes, usuariosRes] = await Promise.all([
      sb.from("centros").select("*").eq("activo", true),
      sb.from("cuentas_contables").select("*").eq("activo", true),
      sb.from("usuarios").select("*").eq("activo", true),
    ])
    if (centrosRes.error || cuentasRes.error || usuariosRes.error) return

    catalogos.centros = (centrosRes.data || []).map((c) => ({
      id: c.id, nombre: c.nombre, depto: c.depto, division: c.division,
    }))
    catalogos.catalogoGastos = (cuentasRes.data || []).map((c) => ({
      cuenta: c.cuenta, nombre: c.nombre, grupo: c.grupo, activo: c.activo,
    }))
    catalogos.usuarios = (usuariosRes.data || []).map((u) => ({
      id: u.id, nombre: u.nombre, correo: u.correo, rol: u.rol,
      iniciales: u.iniciales, centro: u.centro_id, gerente: u.gerente_id,
      division: u.division || "4105", clabe: u.clabe, banco: u.banco,
      suplanteId: u.suplente_id, suplantaDesde: u.suplente_desde, suplantaHasta: u.suplente_hasta,
    }))
    catalogos.dbLoaded = true
    setLoaded(true)
  }, [])

  useEffect(() => {
    if (!catalogos.dbLoaded) load()
  }, [load])

  return { loaded, reload: load, ...catalogos }
}

export function useSolicitudes(userId?: string, rol?: string) {
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!userId) return
    const sb = createClient()
    let query = sb.from("solicitudes")
      .select("*, cfdi:comprobantes_cfdi(*)")
      .order("fecha", { ascending: false })

    if (rol === "usuario") query = query.eq("usuario_id", userId)
    // gerente/admin: load all (filter in component)

    query.then(({ data, error }) => {
      if (error || !data) { setLoading(false); return }
      const mapped: Solicitud[] = data.map((s) => ({
        id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
        monto: parseFloat(s.monto) || 0,
        fecha: new Date(s.fecha),
        status: s.status,
        saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
        anticipoRef: s.anticipo_ref,
        motivoRechazo: s.motivo_rechazo,
        notas: s.notas,
        esCierre: !!(s.notas && s.notas.includes("CIERRE_DEPOSITO")),
        comprobantes: s.comprobantes || 0,
        centroId: s.centro_id,
        cfdi: (s.cfdi || []).map((c: any) => ({
          id: c.id, uuid: c.uuid, emisor: c.emisor, concepto: c.concepto,
          subtotal: parseFloat(c.subtotal) || 0,
          iva: parseFloat(c.iva) || 0,
          total: parseFloat(c.total) || 0,
          cuenta: c.cuenta, confianza: parseFloat(c.confianza) || 0.9,
          archivoUrl: c.archivo_url, archivoPdfUrl: c.archivo_pdf_url,
          archivoXmlUrl: c.archivo_xml_url,
          rfcEmisor: c.rfc_emisor, rfcReceptor: c.rfc_receptor, satEstado: c.sat_estado,
        })),
      }))
      catalogos.solicitudes = mapped
      setSolicitudes(mapped)
      setLoading(false)
    })
  }, [userId, rol])

  return { solicitudes, loading }
}

// Re-export finders for convenience
export { findUser, findCentro, findCuenta } from "@/store/catalogos"

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

FILEEOF

mkdir -p $(dirname 'src/app/page.tsx')
cat > 'src/app/page.tsx' << 'FILEEOF'
import { redirect } from "next/navigation"
export default function Home() { redirect("/dashboard") }

FILEEOF

mkdir -p $(dirname 'src/app/not-found.tsx')
cat > 'src/app/not-found.tsx' << 'FILEEOF'
import Link from "next/link"

export default function NotFound() {
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "var(--bg)" }}>
      <div style={{ textAlign: "center", padding: "0 20px" }}>
        <div style={{ fontSize: 64, marginBottom: 16 }}>🚧</div>
        <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Página en construcción</h1>
        <p style={{ color: "var(--text-3)", fontSize: 14, marginBottom: 24 }}>
          Esta sección se está migrando a la nueva versión.
        </p>
        <Link href="/dashboard" className="btn primary">← Volver al inicio</Link>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/layout.tsx')
cat > 'src/app/layout.tsx' << 'FILEEOF'
import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "Viáticos Casa Zapata",
  description: "Sistema de gestión de viáticos y gastos",
  manifest: "/manifest.json",
  themeColor: "#0d0d0d",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/api/sat/validate/route.ts')
cat > 'src/app/api/sat/validate/route.ts' << 'FILEEOF'
import { NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

interface CfdiInput { uuid: string; rfcEmisor: string; rfcReceptor: string; total: number }

async function consultarSAT(cfdi: CfdiInput) {
  const rfcE = cfdi.rfcEmisor.toUpperCase().trim()
  const rfcR = cfdi.rfcReceptor.toUpperCase().trim()
  let tt = String(cfdi.total).replace(/,/g,"")
  if (!tt.includes(".")) tt += ".00"
  else if (tt.split(".")[1].length === 1) tt += "0"
  const soap = `<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://tempuri.org/"><soapenv:Header/><soapenv:Body><tem:Consulta><tem:expresionImpresa>?re=${rfcE}&amp;rr=${rfcR}&amp;tt=${tt}&amp;id=${cfdi.uuid.toUpperCase()}</tem:expresionImpresa></tem:Consulta></soapenv:Body></soapenv:Envelope>`
  try {
    const res = await fetch("https://consultaqr.facturaelectronica.sat.gob.mx/ConsultaCFDIService.svc", {
      method:"POST", headers:{"Content-Type":"text/xml;charset=utf-8","SOAPAction":"http://tempuri.org/IConsultaCFDIService/Consulta"}, body:soap
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const xml = await res.text()
    const pick = (...tags: string[]) => { for(const t of tags){const m=xml.match(new RegExp(`<(?:[^:>]+:)?${t}>([^<]+)<\\/(?:[^:>]+:)?${t}>`));if(m)return m[1].trim()} return null }
    let estado = pick("Estado")
    if (!estado) { if(xml.includes("Vigente")) estado="Vigente"; else if(xml.includes("Cancelado")) estado="Cancelado"; else estado="No Encontrado" }
    return { ok:true, metodo:"sat-soap", estado, vigente:estado==="Vigente", codigoEstatus:pick("CodigoEstatus") }
  } catch(e:any) { return { ok:false, metodo:"local", estado:"Error", vigente:false, satError:e.message } }
}

export async function POST(request: NextRequest) {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) return NextResponse.json({ error:"Unauthorized" }, { status:401 })
  const body = await request.json()
  const cfdis: CfdiInput[] = Array.isArray(body.cfdis) ? body.cfdis : [body]
  const results = await Promise.allSettled(cfdis.slice(0,60).map(c=>consultarSAT(c)))
  return NextResponse.json({
    resultados: results.map((r,i) => ({ uuid:cfdis[i].uuid, ...(r.status==="fulfilled"?r.value:{ok:false,estado:"Error"}) })),
    total: cfdis.length,
  })
}

FILEEOF

mkdir -p $(dirname 'src/app/(auth)/login/page.tsx')
cat > 'src/app/(auth)/login/page.tsx' << 'FILEEOF'
"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"

export default function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const sb = createClient()
    const { error } = await sb.auth.signInWithPassword({ email, password })
    if (error) { setError("Credenciales incorrectas"); setLoading(false); return }
    router.push("/dashboard")
  }

  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "var(--bg)" }}>
      <div style={{ width: "100%", maxWidth: 380, padding: "0 16px" }}>
        {/* Logo */}
        <div style={{ textAlign: "center", marginBottom: 32 }}>
          <div style={{ width: 48, height: 48, borderRadius: 12, background: "var(--accent)", margin: "0 auto 12px",
                        display: "grid", placeItems: "center", fontSize: 22, fontWeight: 700, color: "#111" }}>
            Z
          </div>
          <div style={{ fontFamily: "var(--f-display)", fontSize: 22, fontWeight: 700, letterSpacing: "-0.02em" }}>
            Casa Zapata
          </div>
          <div style={{ fontSize: 13, color: "var(--text-3)", marginTop: 4 }}>Sistema de viáticos</div>
        </div>

        <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div>
            <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
              Correo electrónico
            </label>
            <input className="input" type="email" value={email}
              onChange={(e) => setEmail(e.target.value)} required placeholder="usuario@zapata.com.mx" />
          </div>
          <div>
            <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 4, display: "block" }}>
              Contraseña
            </label>
            <input className="input" type="password" value={password}
              onChange={(e) => setPassword(e.target.value)} required placeholder="••••••••" />
          </div>

          {error && (
            <div style={{ padding: "8px 12px", background: "var(--danger-soft)", borderRadius: "var(--r-md)",
                          fontSize: 12, color: "var(--danger)" }}>
              {error}
            </div>
          )}

          <button className="btn primary" type="submit" disabled={loading}
            style={{ justifyContent: "center", marginTop: 4, padding: "10px" }}>
            {loading ? "Iniciando sesión…" : "Entrar"}
          </button>
        </form>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/layout.tsx')
cat > 'src/app/(app)/layout.tsx' << 'FILEEOF'
import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"
import AppShell from "@/components/layout/AppShell"

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  // Load user profile from DB
  const { data: perfil } = await sb
    .from("usuarios")
    .select("*, centro:centros(*)")
    .eq("id", user.id)
    .single()

  if (!perfil) redirect("/login")

  return <AppShell user={perfil}>{children}</AppShell>
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/centros/page.tsx')
cat > 'src/app/(app)/admin/centros/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Centros de beneficio" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/reportes/page.tsx')
cat > 'src/app/(app)/admin/reportes/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Reportes" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/usuarios/page.tsx')
cat > 'src/app/(app)/admin/usuarios/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Usuarios" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/liberar/page.tsx')
cat > 'src/app/(app)/admin/liberar/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Liberar pagos" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/bandeja/page.tsx')
cat > 'src/app/(app)/admin/bandeja/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Bandeja admin" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/admin/catalogo/page.tsx')
cat > 'src/app/(app)/admin/catalogo/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Catálogo" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/page.tsx')
cat > 'src/app/(app)/tesoreria/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Liberar pagos" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/deudores/page.tsx')
cat > 'src/app/(app)/tesoreria/deudores/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Deudores" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/reportes/page.tsx')
cat > 'src/app/(app)/tesoreria/reportes/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Reportes" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/tesoreria/pagados/page.tsx')
cat > 'src/app/(app)/tesoreria/pagados/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Pagados" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/perfil/page.tsx')
cat > 'src/app/(app)/perfil/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Mi perfil" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/polizas/page.tsx')
cat > 'src/app/(app)/contador/polizas/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Pólizas contables" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/conciliacion-sat/page.tsx')
cat > 'src/app/(app)/contador/conciliacion-sat/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Conciliación SAT" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/reportes/page.tsx')
cat > 'src/app/(app)/contador/reportes/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Reportes" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/catalogo/page.tsx')
cat > 'src/app/(app)/contador/catalogo/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Catálogo de gastos" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/trazabilidad/page.tsx')
cat > 'src/app/(app)/contador/trazabilidad/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Trazabilidad de póliza" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/contador/validacion-sat/page.tsx')
cat > 'src/app/(app)/contador/validacion-sat/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Validación SAT" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/dashboard/page.tsx')
cat > 'src/app/(app)/dashboard/page.tsx' << 'FILEEOF'
import { createClient } from "@/lib/supabase/server"
import { redirect } from "next/navigation"

export default async function DashboardPage() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) redirect("/login")

  // Load dashboard data server-side
  const [solicitudesRes, usuarioRes] = await Promise.all([
    sb.from("solicitudes")
      .select("id, tipo, status, monto, fecha, concepto")
      .eq("usuario_id", user.id)
      .order("fecha", { ascending: false })
      .limit(10),
    sb.from("usuarios").select("nombre, rol, iniciales").eq("id", user.id).single(),
  ])

  const solicitudes = solicitudesRes.data || []
  const perfil = usuarioRes.data

  return (
    <div>
      <div className="page-head">
        <div>
          <h1 className="page-title">Buenos días, {perfil?.nombre?.split(" ")[0]} 👋</h1>
          <p className="page-sub">Aquí está el resumen de tu actividad</p>
        </div>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 12, marginBottom: 24 }}>
        {[
          { label: "Activas", value: solicitudes.filter(s => ["solicitado","autorizado","liberado","parcial"].includes(s.status)).length, color: "var(--accent)" },
          { label: "Comprobadas", value: solicitudes.filter(s => s.status === "comprobado").length, color: "var(--success)" },
          { label: "Rechazadas", value: solicitudes.filter(s => s.status === "rechazado").length, color: "var(--danger)" },
        ].map(({ label, value, color }) => (
          <div key={label} className="card" style={{ textAlign: "center" }}>
            <div style={{ fontSize: 32, fontWeight: 700, color }}>{value}</div>
            <div style={{ fontSize: 12, color: "var(--text-3)", marginTop: 4 }}>{label}</div>
          </div>
        ))}
      </div>

      {/* Recent solicitudes */}
      <div className="card">
        <div className="card-title" style={{ marginBottom: 12 }}>Solicitudes recientes</div>
        {solicitudes.length === 0 ? (
          <div style={{ padding: "32px 0", textAlign: "center", color: "var(--text-3)" }}>
            Sin solicitudes registradas
          </div>
        ) : (
          <table className="t">
            <thead>
              <tr>
                <th>Folio</th>
                <th>Concepto</th>
                <th>Tipo</th>
                <th>Estado</th>
                <th className="num">Monto</th>
              </tr>
            </thead>
            <tbody>
              {solicitudes.map((s) => (
                <tr key={s.id}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td>{s.concepto}</td>
                  <td><span className="badge">{s.tipo}</span></td>
                  <td><span className={`badge ${s.status}`}>{s.status}</span></td>
                  <td className="num">
                    {new Intl.NumberFormat("es-MX", { style: "currency", currency: "MXN" }).format(s.monto)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/page.tsx')
cat > 'src/app/(app)/solicitudes/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect, useReducer } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { StatusBadge, TipoBadge } from "@/components/ui/StatusBadge"
import { fmtMXN, fmtFecha } from "@/lib/format"
import type { Solicitud, SolicitudStatus } from "@/types"

export default function MisSolicitudesPage() {
  const router = useRouter()
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([])
  const [loading, setLoading] = useState(true)
  const [filtroTipo, setFiltroTipo] = useState("todos")
  const [filtroStatus, setFiltroStatus] = useState("todos")
  const [busqueda, setBusqueda] = useState("")

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      sb.from("solicitudes")
        .select("*, cfdi:comprobantes_cfdi(id, uuid, emisor, total, cuenta, archivo_url, rfc_emisor, rfc_receptor)")
        .eq("usuario_id", user.id)
        .order("fecha", { ascending: false })
        .then(({ data }) => {
          if (!data) { setLoading(false); return }
          setSolicitudes(data.map(s => ({
            id: s.id, tipo: s.tipo, concepto: s.concepto, usuario: s.usuario_id,
            monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha), status: s.status,
            saldoPendiente: parseFloat(s.saldo_pendiente) || 0,
            anticipoRef: s.anticipo_ref, motivoRechazo: s.motivo_rechazo,
            cfdi: s.cfdi || [],
          })))
          setLoading(false)
        })
    })
  }, [])

  const filtradas = solicitudes
    .filter(s => {
      if (filtroTipo !== "todos" && s.tipo !== filtroTipo) return false
      if (filtroStatus !== "todos" && s.status !== filtroStatus) return false
      if (busqueda.trim()) {
        const q = busqueda.toLowerCase()
        if (!s.id.toLowerCase().includes(q) && !s.concepto.toLowerCase().includes(q)) return false
      }
      return true
    })
    .sort((a, b) => b.fecha.getTime() - a.fecha.getTime())

  const totalAbierto = solicitudes
    .filter(s => ["liberado","parcial"].includes(s.status) && (s.saldoPendiente || 0) > 0)
    .reduce((a, s) => a + (s.saldoPendiente || 0), 0)
  const enProceso = solicitudes.filter(s => ["solicitado","autorizado"].includes(s.status)).length
  const rechazadas = solicitudes.filter(s => s.status === "rechazado").length

  return (
    <>
      <div className="page-head">
        <div>
          <h1 className="page-title">Mis solicitudes</h1>
          <div className="page-sub">Historial completo · {solicitudes.length} registros</div>
        </div>
        <button className="btn primary" onClick={() => router.push("/solicitudes/anticipo")}>
          + Nuevo anticipo
        </button>
      </div>

      {/* KPIs */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 12, marginBottom: 16 }}>
        {[
          { label: "Saldo por comprobar", value: fmtMXN(totalAbierto), color: totalAbierto > 0 ? "var(--warn)" : "var(--success)" },
          { label: "En proceso", value: String(enProceso), color: undefined },
          { label: "Rechazadas", value: String(rechazadas), color: rechazadas > 0 ? "var(--danger)" : undefined },
        ].map(k => (
          <div key={k.label} className="card" style={{ textAlign: "center", padding: "14px 12px" }}>
            <div style={{ fontSize: 22, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: k.color }}>{k.value}</div>
            <div style={{ fontSize: 11, color: "var(--text-3)", marginTop: 3 }}>{k.label}</div>
          </div>
        ))}
      </div>

      {/* Filtros */}
      <div className="row" style={{ marginBottom: 14, gap: 8, flexWrap: "wrap" }}>
        <input className="input" style={{ flex: "1 1 160px" }} placeholder="Buscar por folio o concepto…"
          value={busqueda} onChange={e => setBusqueda(e.target.value)} />
        <select className="select" style={{ width: 160 }} value={filtroTipo} onChange={e => setFiltroTipo(e.target.value)}>
          <option value="todos">Todos los tipos</option>
          <option value="anticipo">Anticipos</option>
          <option value="comprobacion">Comprobaciones</option>
          <option value="reembolso">Reembolsos</option>
        </select>
        <select className="select" style={{ width: 160 }} value={filtroStatus} onChange={e => setFiltroStatus(e.target.value)}>
          <option value="todos">Todos los status</option>
          {["solicitado","autorizado","liberado","parcial","comprobado","rechazado"].map(s => (
            <option key={s} value={s} style={{ textTransform: "capitalize" }}>{s.charAt(0).toUpperCase()+s.slice(1)}</option>
          ))}
        </select>
      </div>

      {/* Tabla */}
      <div className="card" style={{ padding: 0, overflow: "hidden" }}>
        {loading ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Cargando solicitudes…</div>
        ) : filtradas.length === 0 ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-3)" }}>Sin solicitudes con ese filtro</div>
        ) : (
          <table className="t">
            <thead>
              <tr>
                <th>Folio</th><th>Tipo</th><th>Concepto</th>
                <th>Fecha</th><th className="num">Monto</th>
                <th className="num">Saldo</th><th>Status</th><th></th>
              </tr>
            </thead>
            <tbody>
              {filtradas.map(s => (
                <tr key={s.id} style={{ cursor: "pointer" }}
                  onClick={() => router.push(`/solicitudes/${s.id}`)}>
                  <td className="mono" style={{ fontSize: 11 }}>{s.id}</td>
                  <td><TipoBadge tipo={s.tipo} /></td>
                  <td style={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {s.concepto}
                  </td>
                  <td className="muted mono" style={{ fontSize: 12 }}>{fmtFecha(s.fecha)}</td>
                  <td className="num">{fmtMXN(s.monto)}</td>
                  <td className="num">
                    {s.tipo === "anticipo" && (s.saldoPendiente || 0) > 0
                      ? <span style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(s.saldoPendiente!)}</span>
                      : <span className="muted">—</span>}
                  </td>
                  <td><StatusBadge status={s.status} /></td>
                  <td className="num" onClick={e => e.stopPropagation()}>
                    {s.motivoRechazo && (
                      <span title={s.motivoRechazo} style={{ color: "var(--danger)", fontSize: 12, cursor: "help" }}>⚠</span>
                    )}
                    {["liberado","parcial"].includes(s.status) && s.tipo === "anticipo" && (
                      <>
                        {s.status === "parcial" && (
                          <button className="btn sm ghost" style={{ marginLeft: 4 }}
                            onClick={() => router.push(`/solicitudes/cierre?anticipo=${s.id}`)}>
                            Cerrar
                          </button>
                        )}
                        <button className="btn sm primary" style={{ marginLeft: 4 }}
                          onClick={() => router.push(`/solicitudes/comprobacion?anticipo=${s.id}`)}>
                          Comprobar
                        </button>
                      </>
                    )}
                    {s.tipo === "reembolso" && s.status === "solicitado" && (
                      <button className="btn sm ghost" style={{ marginLeft: 4 }}
                        onClick={() => router.push(`/solicitudes/reembolso?edit=${s.id}`)}>
                        Ver
                      </button>
                    )}
                  </td>
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

mkdir -p $(dirname 'src/app/(app)/solicitudes/anticipo/page.tsx')
cat > 'src/app/(app)/solicitudes/anticipo/page.tsx' << 'FILEEOF'
"use client"

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

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/[id]/page.tsx')
cat > 'src/app/(app)/solicitudes/[id]/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Detalle de solicitud" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/reembolso/page.tsx')
cat > 'src/app/(app)/solicitudes/reembolso/page.tsx' << 'FILEEOF'
"use client"

import { useState, useRef, useCallback } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN } from "@/lib/format"
import { parseCFDIXml } from "@/lib/cfdi"
import { useCatalogos } from "@/hooks/useCatalogos"
import type { CfdItem } from "@/types"

export default function NuevoReembolsoPage() {
  const router = useRouter()
  const { catalogoGastos } = useCatalogos()
  const fileRef = useRef<HTMLInputElement>(null)

  const [concepto,  setConcepto]  = useState("")
  const [items,     setItems]     = useState<CfdItem[]>([])
  const [enviando,  setEnviando]  = useState(false)
  const [toast,     setToast]     = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 3500) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)
  const totalDups = items.filter(i => i.duplicado).reduce((a, i) => a + (i.total || 0), 0)

  const checkDuplicado = useCallback(async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    // Check in current list
    if (items.some(i => (i.uuid) === uuid)) return "Ya en la lista"
    // Check in DB
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id, solicitudes!inner(status)")
      .eq("uuid", uuid)
      .not("solicitudes.status", "eq", "rechazado")
      .limit(1)
    return data && data.length > 0 ? "Ya comprobado en otra solicitud" : null
  }, [items])

  const handleFiles = useCallback(async (files: FileList | null) => {
    if (!files) return
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return

    for (const file of Array.from(files)) {
      const isXml = file.name.toLowerCase().endsWith(".xml")
      const isPdf = file.name.toLowerCase().endsWith(".pdf")
      const isImg = file.type.startsWith("image/")

      if (!isXml && !isPdf && !isImg) continue

      // Upload to storage
      let archivoUrl: string | null = null
      const ext = file.name.split(".").pop()
      const path = `${user.id}/${Date.now()}.${ext}`
      const { data: uploadData } = await sb.storage.from("comprobantes").upload(path, file, { upsert: true })
      if (uploadData) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }

      if (isXml) {
        const text = await file.text()
        const parsed = parseCFDIXml(text)
        if (!parsed) { showToast(`XML inválido: ${file.name}`, false); continue }
        parsed.archivoUrl = archivoUrl
        const motivoDup = await checkDuplicado(parsed.uuid)
        setItems(prev => [...prev, { ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined }])
      } else {
        // PDF / image
        const id = `file-${Date.now()}-${Math.random().toString(36).slice(2)}`
        setItems(prev => [...prev, {
          id, uuid: "", emisor: file.name, concepto: file.name,
          subtotal: 0, iva: 0, total: 0, cuenta: "6121200001",
          confianza: 0.5, archivoUrl, duplicado: false,
        } as unknown as CfdItem])
      }
    }
    if (fileRef.current) fileRef.current.value = ""
  }, [checkDuplicado])

  const handleEnviar = async () => {
    if (!concepto.trim())      { showToast("⚠ Agrega un concepto", false); return }
    if (items.length === 0)    { showToast("⚠ Agrega al menos un comprobante", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Todos son duplicados", false); return }
    if (total <= 0)            { showToast("⚠ Total cero — no se puede enviar", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const { data: perfil } = await sb.from("usuarios").select("centro_id").eq("id", user.id).single()
    const id = "REM-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "reembolso", concepto, usuario_id: user.id, monto: total,
      status: "solicitado", saldo_pendiente: 0, comprobantes: itemsValidos.length,
      centro_id: perfil?.centro_id ?? null, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    // Save CFDIs
    if (itemsValidos.length > 0) {
      await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
        solicitud_id: id,
        uuid: it.uuid || `SIN-UUID-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        emisor: it.emisor, concepto: it.concepto,
        subtotal: it.subtotal, iva: it.iva, total: it.total,
        cuenta: it.cuenta, confianza: it.confianza,
        archivo_url: it.archivoUrl,
        rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
      })))
    }

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Reembolso ${fmtMXN(total)} · ${itemsValidos.length} comprobante(s)`,
      ts: new Date().toISOString(),
    })

    showToast("✓ Reembolso enviado a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  const cuentaGastos = catalogoGastos

  return (
    <div style={{ maxWidth: 860 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nuevo reembolso</h1>
          <div className="page-sub">Gastos pagados de tu bolsa sin anticipo previo</div>
        </div>
      </div>

      {/* Concepto */}
      <div className="card" style={{ marginBottom: 16 }}>
        <label style={{ fontSize: 12, color: "var(--text-3)", marginBottom: 6, display: "block" }}>
          Concepto / descripción general *
        </label>
        <input className="input" value={concepto} onChange={e => setConcepto(e.target.value)}
          placeholder="Ej: Gastos de viaje a Guadalajara — 28 mayo 2026" />
      </div>

      {/* Drop zone */}
      <div className="card" style={{ marginBottom: 16, border: "2px dashed var(--border)", textAlign: "center",
           padding: "28px 20px", cursor: "pointer" }}
        onClick={() => fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; handleFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize: 28, marginBottom: 8 }}>📂</div>
        <div style={{ fontWeight: 600, marginBottom: 4 }}>Arrastra o haz clic para subir</div>
        <div style={{ fontSize: 12, color: "var(--text-3)" }}>XML (CFDI), PDF o imágenes de ticket</div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => handleFiles(e.target.files)} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom: 16, padding: 0, overflow: "hidden" }}>
          <table className="t">
            <thead>
              <tr>
                <th>Emisor</th><th>Concepto</th><th style={{ minWidth: 220 }}>Cuenta contable</th>
                <th className="num">Total</th><th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => {
                const meta = cuentaGastos.find(g => g.cuenta === it.cuenta)
                return (
                  <tr key={i} style={{ ...(it.duplicado ? { textDecoration: "line-through", opacity: 0.5 } : {}) }}>
                    <td style={{ fontSize: 12 }}>
                      {it.emisor}
                      {it.duplicado && <span style={{ fontSize: 10, color: "var(--danger)", marginLeft: 6 }}>⚠ {it.motivoDup}</span>}
                    </td>
                    <td style={{ fontSize: 12, maxWidth: 180, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {it.concepto}
                    </td>
                    <td>
                      {it.duplicado
                        ? <span style={{ fontSize: 11 }}>{meta?.nombre}</span>
                        : <select className="select" value={it.cuenta}
                            onChange={e => setItems(prev => prev.map((x, j) => j === i ? { ...x, cuenta: e.target.value } : x))}
                            style={{ fontSize: 11, padding: "5px 6px",
                              borderColor: it.cuenta === "6121200001" ? "var(--warn)" : "var(--border)",
                              background: it.cuenta === "6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                            {cuentaGastos.map(g => <option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                          </select>}
                    </td>
                    <td className="num">{fmtMXN(it.total)}</td>
                    <td>
                      <button onClick={() => setItems(prev => prev.filter((_, j) => j !== i))}
                        style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 16 }}>×</button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={3} style={{ textAlign: "right", fontWeight: 600, padding: "10px 12px" }}>
                  Total a reembolsar{totalDups > 0 && <span style={{ fontSize: 10, color: "var(--text-3)", fontWeight: 400, marginLeft: 6 }}>(excl. dup: {fmtMXN(totalDups)})</span>}
                </td>
                <td className="num" style={{ fontWeight: 700, fontSize: 16 }}>{fmtMXN(total)}</td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div style={{ padding: "10px 14px", borderRadius: 8, marginBottom: 12, fontSize: 13,
          background: toast.ok ? "var(--success-soft)" : "var(--danger-soft)",
          color: toast.ok ? "var(--success)" : "var(--danger)",
          border: `1px solid ${toast.ok ? "var(--success)" : "var(--danger)"}` }}>
          {toast.msg}
        </div>
      )}

      {/* Actions */}
      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <button className="btn ghost" onClick={() => router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || total <= 0 || itemsValidos.length === 0}
          style={{ opacity: enviando || total <= 0 || itemsValidos.length === 0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : `Enviar reembolso · ${fmtMXN(total)} →`}
        </button>
      </div>
    </div>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/cierre/page.tsx')
cat > 'src/app/(app)/solicitudes/cierre/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Cerrar anticipo" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/solicitudes/comprobacion/page.tsx')
cat > 'src/app/(app)/solicitudes/comprobacion/page.tsx' << 'FILEEOF'
"use client"

import { useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { fmtMXN, fmtFecha } from "@/lib/format"
import { CompUploader } from "@/components/ui/CompUploader"
import { useCatalogos } from "@/hooks/useCatalogos"
import type { CfdItem, Solicitud } from "@/types"
import { Suspense } from "react"

function NuevaComprobacionInner() {
  const router = useRouter()
  const params = useSearchParams()
  const anticipoId = params.get("anticipo")
  const { catalogoGastos } = useCatalogos()

  const [anticipo, setAnticipo] = useState<Solicitud | null>(null)
  const [anticipos, setAnticipos] = useState<Solicitud[]>([])
  const [anticipoSel, setAnticipoSel] = useState<Solicitud | null>(null)
  const [items, setItems] = useState<CfdItem[]>([])
  const [enviando, setEnviando] = useState(false)
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null)

  const showToast = (msg: string, ok = true) => { setToast({ msg, ok }); setTimeout(() => setToast(null), 3500) }

  const itemsValidos = items.filter(i => !i.duplicado)
  const total = itemsValidos.reduce((a, i) => a + (i.total || 0), 0)

  useEffect(() => {
    const sb = createClient()
    sb.auth.getUser().then(({ data: { user } }) => {
      if (!user) return
      sb.from("solicitudes")
        .select("id, concepto, monto, status, saldo_pendiente, fecha, tipo")
        .eq("usuario_id", user.id)
        .eq("tipo", "anticipo")
        .in("status", ["liberado", "parcial"])
        .gt("saldo_pendiente", 0)
        .order("fecha", { ascending: false })
        .then(({ data }) => {
          const mapped = (data || []).map(s => ({
            id: s.id, tipo: s.tipo as any, concepto: s.concepto, usuario: user.id,
            monto: parseFloat(s.monto) || 0, fecha: new Date(s.fecha), status: s.status as any,
            saldoPendiente: parseFloat(s.saldo_pendiente) || 0, cfdi: [],
          }))
          setAnticipos(mapped)
          if (anticipoId) {
            const found = mapped.find(a => a.id === anticipoId)
            if (found) setAnticipoSel(found)
          }
        })
    })
  }, [anticipoId])

  const handleAdd = (newItems: CfdItem[]) => {
    setItems(prev => [...prev, ...newItems])
  }

  const handleEnviar = async () => {
    if (!anticipoSel)              { showToast("⚠ Selecciona el anticipo a comprobar", false); return }
    if (itemsValidos.length === 0) { showToast("⚠ Agrega al menos un comprobante XML válido", false); return }
    if (total <= 0)                { showToast("⚠ El total es cero", false); return }

    setEnviando(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { router.push("/login"); return }

    const nuevoSaldo = Math.max(0, anticipoSel.saldoPendiente - total)
    const nuevoStatus = nuevoSaldo <= 0 ? "comprobado" : "parcial"
    const id = "CMP-" + new Date().getFullYear() + "-" + String(Date.now()).slice(-4)

    const { error } = await sb.from("solicitudes").insert({
      id, tipo: "comprobacion", concepto: `Comprobación de ${anticipoSel.id}`,
      usuario_id: user.id, monto: total, status: "solicitado",
      anticipo_ref: anticipoSel.id, saldo_pendiente: 0,
      comprobantes: itemsValidos.length, fecha: new Date().toISOString(),
    })
    if (error) { showToast("⚠ Error: " + error.message, false); setEnviando(false); return }

    // Save CFDIs
    await sb.from("comprobantes_cfdi").insert(itemsValidos.map(it => ({
      solicitud_id: id, uuid: it.uuid || `SIN-UUID-${Date.now()}`,
      emisor: it.emisor, concepto: it.concepto,
      subtotal: it.subtotal, iva: it.iva, total: it.total,
      cuenta: it.cuenta, confianza: it.confianza, archivo_url: it.archivoUrl,
      rfc_emisor: it.rfcEmisor, rfc_receptor: it.rfcReceptor,
    })))

    // Update anticipo saldo
    await sb.from("solicitudes")
      .update({ saldo_pendiente: nuevoSaldo, status: nuevoStatus, comprobantes: (anticipoSel as any).comprobantes + 1 })
      .eq("id", anticipoSel.id)

    await sb.from("bitacora").insert({
      solicitud_id: id, accion: "solicitado", usuario_id: user.id,
      detalle: `Comprobación ${fmtMXN(total)} del anticipo ${anticipoSel.id}`,
      ts: new Date().toISOString(),
    })

    showToast("✓ Comprobación enviada a autorización")
    setTimeout(() => router.push("/solicitudes"), 1500)
  }

  return (
    <div style={{ maxWidth: 900 }}>
      <div className="page-head">
        <div>
          <h1 className="page-title">Nueva comprobación</h1>
          <div className="page-sub">Sube los CFDIs para comprobar tu anticipo</div>
        </div>
      </div>

      {/* Anticipo selector */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-title" style={{ marginBottom: 12 }}>Anticipo a comprobar</div>
        {anticipos.length === 0 ? (
          <div style={{ color: "var(--text-3)", fontSize: 13 }}>
            No tienes anticipos liberados pendientes de comprobar.
          </div>
        ) : anticipoSel ? (
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <div>
              <div style={{ fontWeight: 600 }}>{anticipoSel.id}</div>
              <div style={{ fontSize: 13, color: "var(--text-2)" }}>{anticipoSel.concepto}</div>
              <div style={{ fontSize: 12, color: "var(--warn)", marginTop: 2 }}>
                Saldo pendiente: {fmtMXN(anticipoSel.saldoPendiente)}
              </div>
            </div>
            <button className="btn ghost" onClick={() => setAnticipoSel(null)}>Cambiar</button>
          </div>
        ) : (
          <div style={{ display: "grid", gap: 8 }}>
            {anticipos.map(a => (
              <div key={a.id} className="card" style={{ cursor: "pointer", margin: 0 }}
                onClick={() => setAnticipoSel(a)}>
                <div className="spread">
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 13 }}>{a.id}</div>
                    <div style={{ fontSize: 12, color: "var(--text-2)" }}>{a.concepto}</div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ color: "var(--warn)", fontWeight: 600 }}>{fmtMXN(a.saldoPendiente)}</div>
                    <div style={{ fontSize: 11, color: "var(--text-3)" }}>{fmtFecha(a.fecha)}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Uploader */}
      <div style={{ marginBottom: 16 }}>
        <CompUploader solicitudId={anticipoSel?.id} catalogoGastos={catalogoGastos} onAdd={handleAdd} />
      </div>

      {/* Items list */}
      {items.length > 0 && (
        <div className="card" style={{ marginBottom: 16, padding: 0, overflow: "hidden" }}>
          <table className="t">
            <thead>
              <tr>
                <th>UUID</th><th>Emisor</th><th>Concepto</th>
                <th style={{ minWidth: 220 }}>Cuenta</th><th className="num">Total</th><th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, i) => (
                <tr key={i} style={{ ...(it.duplicado ? { textDecoration: "line-through", opacity: 0.5 } : {}) }}>
                  <td className="mono" style={{ fontSize: 10, maxWidth: 120 }}>
                    <span title={it.uuid} onClick={() => navigator.clipboard.writeText(it.uuid)}
                      style={{ cursor: "pointer" }}>
                      {it.uuid ? it.uuid.slice(0, 18) + "…" : "—"}
                    </span>
                  </td>
                  <td style={{ fontSize: 12 }}>{it.emisor}</td>
                  <td style={{ fontSize: 11, maxWidth: 160, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {it.concepto}
                    {it.duplicado && <span style={{ color: "var(--danger)", fontSize: 10, marginLeft: 6 }}>⚠ {it.motivoDup}</span>}
                  </td>
                  <td>
                    {it.duplicado ? (
                      <span style={{ fontSize: 11 }}>{catalogoGastos.find(g => g.cuenta === it.cuenta)?.nombre}</span>
                    ) : (
                      <select className="select" value={it.cuenta}
                        onChange={e => setItems(prev => prev.map((x, j) => j === i ? { ...x, cuenta: e.target.value } : x))}
                        style={{ fontSize: 11, padding: "5px 6px",
                          borderColor: it.cuenta === "6121200001" ? "var(--warn)" : "var(--border)",
                          background: it.cuenta === "6121200001" ? "rgba(245,158,11,.06)" : "var(--surface)" }}>
                        {catalogoGastos.map(g => <option key={g.cuenta} value={g.cuenta}>{g.cuenta} · {g.nombre}</option>)}
                      </select>
                    )}
                  </td>
                  <td className="num">{fmtMXN(it.total)}</td>
                  <td>
                    <button onClick={() => setItems(prev => prev.filter((_, j) => j !== i))}
                      style={{ background: "none", border: "none", color: "var(--text-3)", cursor: "pointer", fontSize: 16 }}>×</button>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ textAlign: "right", fontWeight: 600, padding: "10px 12px" }}>Total a comprobar</td>
                <td className="num" style={{ fontWeight: 700, fontSize: 16 }}>{fmtMXN(total)}</td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Toast */}
      {toast && (
        <div style={{ padding: "10px 14px", borderRadius: 8, marginBottom: 12, fontSize: 13,
          background: toast.ok ? "var(--success-soft)" : "var(--danger-soft)",
          color: toast.ok ? "var(--success)" : "var(--danger)" }}>
          {toast.msg}
        </div>
      )}

      <div style={{ display: "flex", justifyContent: "flex-end", gap: 10 }}>
        <button className="btn ghost" onClick={() => router.push("/solicitudes")}>Cancelar</button>
        <button className="btn primary" onClick={handleEnviar}
          disabled={enviando || !anticipoSel || total <= 0}
          style={{ opacity: enviando || !anticipoSel || total <= 0 ? 0.5 : 1 }}>
          {enviando ? "Enviando…" : "Enviar comprobación →"}
        </button>
      </div>
    </div>
  )
}

export default function NuevaComprobacionPage() {
  return (
    <Suspense fallback={<div style={{ padding: 40, color: "var(--text-3)" }}>Cargando…</div>}>
      <NuevaComprobacionInner />
    </Suspense>
  )
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/gerente/page.tsx')
cat > 'src/app/(app)/gerente/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Bandeja de aprobaciones" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/gerente/reportes/page.tsx')
cat > 'src/app/(app)/gerente/reportes/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Reportes" />
}

FILEEOF

mkdir -p $(dirname 'src/app/(app)/gerente/equipo/page.tsx')
cat > 'src/app/(app)/gerente/equipo/page.tsx' << 'FILEEOF'
import { ComingSoon } from "@/components/ui/ComingSoon"
export default function Page() {
  return <ComingSoon title="Mi equipo" />
}

FILEEOF

mkdir -p $(dirname 'src/store/catalogos.ts')
cat > 'src/store/catalogos.ts' << 'FILEEOF'
// Global app data store - replaces window.USUARIOS, window.SOLICITUDES, etc.
// Uses React Context + zustand-style approach with simple module-level state

import type { Usuario, Centro, CuentaContable, Solicitud } from "@/types"

interface CatalogosState {
  usuarios: Usuario[]
  centros: Centro[]
  catalogoGastos: CuentaContable[]
  solicitudes: Solicitud[]
  dbLoaded: boolean
}

// Module-level state (mirrors the current window.USUARIOS pattern)
export const catalogos: CatalogosState = {
  usuarios: [],
  centros: [],
  catalogoGastos: [],
  solicitudes: [],
  dbLoaded: false,
}

// Helper finders
export const findUser = (id?: string | null): Usuario | undefined =>
  catalogos.usuarios.find((u) => u.id === id)

export const findCentro = (id?: string | null): Centro | undefined =>
  catalogos.centros.find((c) => c.id === id)

export const findCuenta = (cuenta?: string | null): CuentaContable | undefined =>
  catalogos.catalogoGastos.find((c) => c.cuenta === cuenta)

export const findUserByEmail = (email: string): Usuario | undefined =>
  catalogos.usuarios.find((u) => u.correo?.toLowerCase() === email.toLowerCase())

FILEEOF

mkdir -p $(dirname 'src/lib/format.ts')
cat > 'src/lib/format.ts' << 'FILEEOF'
// Formatting utilities - extracted from index.html

export const fmtMXN = (n: number): string => {
  return new Intl.NumberFormat("es-MX", {
    style: "currency",
    currency: "MXN",
    minimumFractionDigits: 2,
  }).format(n ?? 0)
}

export const fmtFecha = (d: Date | string | null): string => {
  if (!d) return "—"
  const date = d instanceof Date ? d : new Date(d)
  return date.toLocaleDateString("es-MX", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  })
}

export const fmtFechaCorta = (d: Date | string | null): string => {
  if (!d) return "—"
  const date = d instanceof Date ? d : new Date(d)
  return date.toLocaleDateString("es-MX", { day: "2-digit", month: "short" })
}

export const diasAtras = (n: number): Date => {
  const d = new Date()
  d.setDate(d.getDate() - n)
  return d
}

export const getBancosAccount = (division: string): string => {
  if (division === "4105") return "1110100001"
  if (division === "4106") return "1110100002"
  return "1110100001"
}

FILEEOF

mkdir -p $(dirname 'src/lib/cfdi.ts')
cat > 'src/lib/cfdi.ts' << 'FILEEOF'
// CFDI XML parsing utilities - extracted from index.html

import type { CfdItem } from "@/types"

function attr(el: Element | null, ...names: string[]): string {
  if (!el) return ""
  for (const n of names) {
    const v = el.getAttribute(n) || el.getAttribute(n.toLowerCase())
    if (v) return v
  }
  return ""
}

function qn(parent: Document | Element, localName: string): Element | null {
  const el = parent.querySelector(localName)
  if (el) return el
  const all = parent.getElementsByTagName("*")
  for (let i = 0; i < all.length; i++) {
    if (all[i].localName === localName) return all[i]
  }
  return null
}

const CUENTA_PATTERNS: [RegExp, string, number][] = [
  [/(peaje|caseta|autopista|telepeaje|iave|pase)/i, "6122700001", 0.9],
  [/(estacionamiento|parking|parquímetro|pensión)/i, "6122700002", 0.9],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i, "6122600001", 0.9],
  [/(taxi|uber|didi|cabify|transporte)/i, "6122900002", 0.85],
  [/(hotel|hospedaje|alojamiento)/i, "6122100001", 0.85],
  [/(restaurante|alimentos|comida|viáticos)/i, "6122200001", 0.8],
  [/(aéreo|vuelo|boleto|avión)/i, "6122400001", 0.85],
]

function guessCuenta(text: string): [string, number] {
  for (const [regex, cuenta, conf] of CUENTA_PATTERNS) {
    if (regex.test(text)) return [cuenta, conf]
  }
  return ["6121200001", 0.5] // No Deducibles as fallback
}

export function parseCFDIXml(xmlText: string): CfdItem | null {
  try {
    const doc = new DOMParser().parseFromString(xmlText, "application/xml")
    if (doc.querySelector("parsererror")) return null

    const comp = qn(doc, "Comprobante") || doc.documentElement
    const total = parseFloat(attr(comp, "Total", "total") || "0")
    const subtotal = parseFloat(attr(comp, "SubTotal", "Subtotal", "subtotal") || "0")

    const emisorEl = qn(doc, "Emisor")
    const emisor = attr(emisorEl, "Nombre", "nombre") || attr(emisorEl, "nombre") || ""
    const rfcEmisor = attr(emisorEl, "Rfc", "rfc") || ""

    const receptorEl = qn(doc, "Receptor")
    const rfcReceptor = attr(receptorEl, "Rfc", "rfc") || ""

    let iva = 0
    const traslados = doc.querySelectorAll("Traslado,traslado")
    traslados.forEach((t) => {
      const imp = attr(t, "Impuesto", "impuesto")
      if (imp === "002" || imp.toUpperCase() === "IVA") {
        iva += parseFloat(attr(t, "Importe", "importe") || "0") || 0
      }
    })
    if (!iva && total && subtotal) iva = Math.round((total - subtotal) * 100) / 100

    const tfd = qn(doc, "TimbreFiscalDigital")
    const uuid = (attr(tfd, "UUID", "uuid") || "").toUpperCase().trim()

    const conceptoEl = qn(doc, "Concepto")
    const conceptoStr = attr(conceptoEl, "Descripcion", "descripcion") || ""
    const claveProdServ = attr(conceptoEl, "ClaveProdServ", "claveProdServ") || ""

    const matchText = (emisor + " " + conceptoStr + " " + claveProdServ + " " + rfcEmisor).toLowerCase()
    const [cuenta, confianza] = guessCuenta(matchText)

    return {
      uuid,
      uuidFull: uuid,
      emisor,
      concepto: conceptoStr || emisor,
      subtotal,
      iva,
      total,
      cuenta,
      confianza,
      archivoUrl: null,
      rfcEmisor,
      rfcReceptor,
    } as CfdItem & { uuidFull: string }
  } catch {
    return null
  }
}

FILEEOF

mkdir -p $(dirname 'src/lib/supabase/middleware.ts')
cat > 'src/lib/supabase/middleware.ts' << 'FILEEOF'
import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options))
        },
      },
    }
  )
  const { data: { user } } = await supabase.auth.getUser()
  if (!user && !request.nextUrl.pathname.startsWith("/login")) {
    const url = request.nextUrl.clone()
    url.pathname = "/login"
    return NextResponse.redirect(url)
  }
  return supabaseResponse
}

FILEEOF

mkdir -p $(dirname 'src/lib/supabase/server.ts')
cat > 'src/lib/supabase/server.ts' << 'FILEEOF'
import { createServerClient } from "@supabase/ssr"
import { cookies } from "next/headers"

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options))
          } catch {}
        },
      },
    }
  )
}

FILEEOF

mkdir -p $(dirname 'src/lib/supabase/client.ts')
cat > 'src/lib/supabase/client.ts' << 'FILEEOF'
import { createBrowserClient } from "@supabase/ssr"
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}

FILEEOF

echo "✓ All files created"
echo "Now run: npm install && git add . && git commit -m feat: phase-2-solicitudes && git push"