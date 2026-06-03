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

