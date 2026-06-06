import { createClient } from "@/lib/supabase/client"

const CACHE = new Map<string, { value: string; ts: number }>()
const TTL_MS = 60_000  // 1 minute cache

export async function getAjuste(clave: string, defaultValue: string): Promise<string> {
  const cached = CACHE.get(clave)
  if (cached && Date.now() - cached.ts < TTL_MS) return cached.value

  try {
    const sb = createClient()
    const { data } = await sb.from("ajustes").select("valor").eq("clave", clave).single()
    const value = data?.valor ?? defaultValue
    CACHE.set(clave, { value, ts: Date.now() })
    return value
  } catch {
    return defaultValue
  }
}

export async function getDiasMaxFactura(): Promise<number> {
  const v = await getAjuste("dias_max_factura", "30")
  const n = parseInt(v, 10)
  return Number.isFinite(n) && n > 0 ? n : 30
}

export function clearAjustesCache() { CACHE.clear() }

