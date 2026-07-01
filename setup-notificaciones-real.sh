#!/bin/bash
set -e

echo "🔔  Construyendo sistema de notificaciones real..."
echo ""

# ═══════════════════════════════════════════════════════════════
#  1. Helper de notificaciones (client-side, sin FCM dependency)
# ═══════════════════════════════════════════════════════════════
mkdir -p src/lib
cat > 'src/lib/notificaciones.ts' << 'TSEOF'
import { createClient } from "@/lib/supabase/client"

export interface NuevaNotif {
  usuario_id: string
  tipo: string           // "solicitud_creada", "aprobada", "rechazada", "liberada", "comprobada", "devuelta"
  titulo: string
  mensaje?: string
  ref_id?: string        // id de la solicitud relacionada
}

// Inserta 1..n notificaciones a la vez. Falla silenciosamente para no romper el flujo.
export async function insertNotif(notifs: NuevaNotif | NuevaNotif[]): Promise<void> {
  try {
    const sb = createClient()
    const rows = Array.isArray(notifs) ? notifs : [notifs]
    if (!rows.length) return
    const { error } = await sb.from("notificaciones").insert(rows)
    if (error) console.warn("[notif] insert error:", error.message)
  } catch (e) {
    console.warn("[notif] excepción:", e)
  }
}

// Encuentra usuarios por rol (para notificar a "todos los admins", "gerentes", etc.)
export async function usuariosPorRol(rol: string | string[]): Promise<{ id: string; nombre: string }[]> {
  try {
    const sb = createClient()
    const roles = Array.isArray(rol) ? rol : [rol]
    const { data } = await sb
      .from("usuarios")
      .select("id, nombre")
      .in("rol", roles)
      .eq("activo", true)
    return data || []
  } catch {
    return []
  }
}

// Notifica al gerente asignado a un usuario
export async function notificarGerente(usuarioId: string, titulo: string, mensaje: string, refId?: string) {
  try {
    const sb = createClient()
    const { data: usr } = await sb.from("usuarios").select("gerente_id").eq("id", usuarioId).single()
    if (!usr?.gerente_id) return
    await insertNotif({ usuario_id: usr.gerente_id, tipo: "aprobar", titulo, mensaje, ref_id: refId })
  } catch {}
}
TSEOF
echo "  ✓ src/lib/notificaciones.ts"

# ═══════════════════════════════════════════════════════════════
#  2. Página /notificaciones real (lista + mark as read)
# ═══════════════════════════════════════════════════════════════
mkdir -p 'src/app/(app)/notificaciones'
cat > 'src/app/(app)/notificaciones/page.tsx' << 'TSXEOF'
"use client"
import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Bell, CheckCheck, Inbox } from "lucide-react"

interface Notif {
  id: string
  tipo: string
  titulo: string
  mensaje: string | null
  ref_id: string | null
  leida: boolean
  created_at: string
}

const fmtFechaRel = (iso: string) => {
  const d = new Date(iso)
  const diff = Date.now() - d.getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return "hace segundos"
  if (min < 60) return `hace ${min} min`
  const hrs = Math.floor(min / 60)
  if (hrs < 24) return `hace ${hrs} h`
  const dias = Math.floor(hrs / 24)
  if (dias < 30) return `hace ${dias} d`
  return d.toLocaleDateString("es-MX", { day: "numeric", month: "short" })
}

export default function NotificacionesPage() {
  const router = useRouter()
  const [notifs, setNotifs] = useState<Notif[]>([])
  const [loading, setLoading] = useState(true)

  const cargar = async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { setLoading(false); return }
    const { data } = await sb
      .from("notificaciones")
      .select("*")
      .eq("usuario_id", user.id)
      .order("created_at", { ascending: false })
      .limit(50)
    setNotifs(data || [])
    setLoading(false)
  }

  useEffect(() => { cargar() }, [])

  const marcarLeida = async (id: string) => {
    const sb = createClient()
    await sb.from("notificaciones").update({ leida: true }).eq("id", id)
    setNotifs(prev => prev.map(n => n.id === id ? { ...n, leida: true } : n))
  }

  const marcarTodasLeidas = async () => {
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) return
    await sb.from("notificaciones").update({ leida: true }).eq("usuario_id", user.id).eq("leida", false)
    setNotifs(prev => prev.map(n => ({ ...n, leida: true })))
  }

  const abrirRef = async (n: Notif) => {
    if (!n.leida) await marcarLeida(n.id)
    if (n.ref_id) router.push(`/solicitudes/${n.ref_id}`)
  }

  const noLeidas = notifs.filter(n => !n.leida).length

  if (loading) return <div style={{padding:40,textAlign:"center",color:"var(--text-3)"}}>Cargando…</div>

  return (
    <>
      <div className="page-head" style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",flexWrap:"wrap",gap:10}}>
        <div>
          <h1 className="page-title" style={{display:"flex",alignItems:"center",gap:10}}>
            <Bell size={22} strokeWidth={1.75}/> Notificaciones
          </h1>
          <div className="page-sub">
            {noLeidas > 0 ? `${noLeidas} sin leer` : "Todas leídas"}
          </div>
        </div>
        {noLeidas > 0 && (
          <button className="btn sm" onClick={marcarTodasLeidas}
            style={{display:"flex",alignItems:"center",gap:6}}>
            <CheckCheck size={14}/> Marcar todas
          </button>
        )}
      </div>

      {notifs.length === 0 ? (
        <div className="card" style={{padding:60,textAlign:"center"}}>
          <Inbox size={48} strokeWidth={1.5} style={{color:"var(--text-3)",marginBottom:14}}/>
          <div style={{fontSize:14,color:"var(--text-3)"}}>
            No tienes notificaciones aún
          </div>
          <div style={{fontSize:11,color:"var(--text-3)",marginTop:6}}>
            Cuando alguien te envíe una solicitud o cambie el estatus de una tuya, aparecerá aquí.
          </div>
        </div>
      ) : (
        <div className="card" style={{padding:0,overflow:"hidden"}}>
          {notifs.map((n, i) => (
            <div key={n.id}
              onClick={() => abrirRef(n)}
              style={{
                padding: "14px 16px",
                borderBottom: i < notifs.length-1 ? "1px solid var(--border)" : "none",
                cursor: n.ref_id ? "pointer" : "default",
                background: !n.leida ? "var(--accent-soft, rgba(197,242,77,0.05))" : "transparent",
                position: "relative",
                display: "flex",
                gap: 12,
                alignItems: "flex-start",
              }}>
              {!n.leida && (
                <div style={{
                  width: 8, height: 8, borderRadius: "50%",
                  background: "var(--accent, #c5f24d)",
                  marginTop: 8, flexShrink: 0,
                }}/>
              )}
              {n.leida && <div style={{width:8,flexShrink:0}}/>}
              <div style={{flex:1,minWidth:0}}>
                <div style={{display:"flex",justifyContent:"space-between",gap:10,marginBottom:4}}>
                  <div style={{fontWeight: n.leida ? 500 : 600, fontSize:14}}>{n.titulo}</div>
                  <div style={{fontSize:11,color:"var(--text-3)",whiteSpace:"nowrap",flexShrink:0}}>
                    {fmtFechaRel(n.created_at)}
                  </div>
                </div>
                {n.mensaje && (
                  <div style={{fontSize:12,color:"var(--text-2)",lineHeight:1.5}}>{n.mensaje}</div>
                )}
                {n.ref_id && (
                  <div className="mono" style={{fontSize:10,color:"var(--text-3)",marginTop:6}}>
                    {n.ref_id}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
TSXEOF
echo "  ✓ src/app/(app)/notificaciones/page.tsx"

# ═══════════════════════════════════════════════════════════════
#  3. Agregar inserción de notif en creación de solicitudes
#     Buscamos en anticipo/reembolso/comprobacion y agregamos el
#     helper después del insert exitoso
# ═══════════════════════════════════════════════════════════════
python3 << 'PYEOF'
import os, re

PAGES = [
  'src/app/(app)/solicitudes/anticipo/page.tsx',
  'src/app/(app)/solicitudes/reembolso/page.tsx',
  'src/app/(app)/solicitudes/comprobacion/page.tsx',
]

for path in PAGES:
    if not os.path.exists(path):
        print(f"  ⚠ {path} no encontrado")
        continue
    with open(path) as f: src = f.read()
    original = src

    # 1. Agregar imports si no están
    if 'notificarGerente' not in src:
        # Insertar después de imports de supabase
        src = re.sub(
            r'(import \{ createClient \} from "@/lib/supabase/client")',
            r'\1\nimport { notificarGerente, insertNotif, usuariosPorRol } from "@/lib/notificaciones"',
            src, count=1
        )

    # 2. Detectar el tipo de solicitud por la ruta
    tipo = 'anticipo' if 'anticipo' in path else ('reembolso' if 'reembolso' in path else 'comprobacion')

    # 3. Buscar el patrón de router.push("/solicitudes") o similar después del insert exitoso
    # y meter la notificación ANTES
    # Patrón común: setTimeout... router.push o router.push directo tras insert
    if 'notificarGerente(' not in src:
        # Buscar dónde termina el guardar exitoso — usualmente antes de router.push("/solicitudes")
        # o antes de setToast("✓ ...")
        notif_snippet = f'''
      // Notificar al gerente asignado
      try {{
        const {{ data: {{ user }} }} = await sb.auth.getUser()
        if (user) {{
          await notificarGerente(
            user.id,
            "Nueva solicitud de {tipo}",
            `Se registró una nueva solicitud de ${{fmtMXN ? fmtMXN(parseFloat(monto)) : monto}} por revisar`,
            solId || nuevoId,
          )
        }}
      }} catch {{}}
'''
        # Este snippet no lo insertamos automáticamente porque las variables cambian por archivo;
        # el usuario tendrá que llamar a notificarGerente() manualmente en el flujo de submit.
        # Dejamos el import listo para uso.
        pass

    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}: imports agregados (helper listo para usar)")
    else:
        print(f"  ⊙ {path}: sin cambios")
PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

echo ""
git add .
git commit -m "feat: notificaciones page real + helper de inserción sin dependencia FCM"
git push
echo ""
echo "✓ Done"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  TESTING (después del deploy):"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "1. Inserta una notificación manual desde el SQL Editor de Supabase"
echo "   para probar la página:"
echo ""
echo "   INSERT INTO notificaciones (usuario_id, tipo, titulo, mensaje, ref_id)"
echo "   VALUES ("
echo "     (SELECT id FROM usuarios WHERE correo = 'admin.demo@viaticos.local'),"
echo "     'aprobar',"
echo "     'Nueva solicitud pendiente',"
echo "     'Ana López registró un anticipo de \$8,500 para viaje Monterrey',"
echo "     'ANT-DEMO-001'"
echo "   );"
echo ""
echo "2. Inicia sesión como admin y entra a /notificaciones — debe aparecer."
echo ""
echo "3. Para que se creen automáticamente al enviar solicitudes:"
echo "   dime cuál archivo (anticipo/reembolso/comprobacion) quieres priorizar"
echo "   y agrego la llamada a notificarGerente() en el punto exacto del submit."
