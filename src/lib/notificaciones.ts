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
