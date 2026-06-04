import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

export async function GET() {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const { data: sub } = await sb
    .from("push_subscriptions")
    .select("usuario_id, subscription, updated_at")
    .eq("usuario_id", user.id)
    .single()

  const { data: perfil } = await sb
    .from("usuarios")
    .select("nombre, rol, gerente_id")
    .eq("id", user.id)
    .single()

  // Test calling the Worker
  const WORKER = process.env.NEXT_PUBLIC_WORKER_URL || "https://viaticos-admin.rhernandez-e52.workers.dev"
  let workerStatus = "not tested"
  if (sub?.subscription) {
    try {
      const r = await fetch(`${WORKER}/notify`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer viaticos-zapata-push-2026" },
        body: JSON.stringify({
          userIds: [user.id],
          title: "🔔 Test de notificación",
          body: "Si recibes esto, las notificaciones funcionan correctamente",
          url: "https://viaticos-app-bice.vercel.app/dashboard",
        }),
      })
      const data = await r.json()
      workerStatus = r.ok ? `OK: ${JSON.stringify(data)}` : `Error ${r.status}: ${JSON.stringify(data)}`
    } catch(e: any) {
      workerStatus = `Fetch error: ${e.message}`
    }
  }

  return NextResponse.json({
    userId: user.id,
    nombre: perfil?.nombre,
    rol: perfil?.rol,
    gerenteId: perfil?.gerente_id,
    hasToken: !!sub?.subscription,
    tokenPreview: sub?.subscription ? sub.subscription.slice(0, 30) + "..." : null,
    tokenUpdated: sub?.updated_at,
    workerTest: workerStatus,
  })
}

