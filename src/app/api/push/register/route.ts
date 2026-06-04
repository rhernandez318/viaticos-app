import { NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

export async function POST(request: NextRequest) {
  const sb = await createClient()
  const { data: { user } } = await sb.auth.getUser()
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 })

  const { userId, token } = await request.json()
  if (!token) return NextResponse.json({ error: "No token" }, { status: 400 })

  const { error } = await sb.from("push_subscriptions").upsert(
    { usuario_id: userId || user.id, subscription: token, updated_at: new Date().toISOString() },
    { onConflict: "usuario_id" }
  )

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}

