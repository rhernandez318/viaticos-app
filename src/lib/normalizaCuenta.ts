// Maps a guessed account code to the closest available one in the catalog

const TIPO_CATALOG_PATTERNS: Record<string, RegExp> = {
  alimentos:       /(alimento|comida|comidas|restaurante|consumo|viático|representaci)/i,
  hospedaje:       /(hotel|hospedaje|alojamiento|nacional|internacional)/i,
  peaje:           /(peaje|caseta|autopista|telepeaje)/i,
  estacionamiento: /(estacionamiento|parking)/i,
  gasolina:        /(gasolina|combustible|diésel|diesel|gas)/i,
  taxi:            /(taxi|transporte local|uber|didi|terrestre)/i,
  aereo:           /(aéreo|vuelo|boleto|avión|aéreo|pasaje.*aéreo|pasaje.*nac|pasaje.*int)/i,
}

// Known SAT/internal code → semantic type
const KNOWN_CODES: Record<string, string> = {
  "6122200001": "alimentos",
  "6122100001": "hospedaje",
  "6122700001": "peaje",
  "6122700002": "estacionamiento",
  "6122600001": "gasolina",
  "6122900002": "taxi",
  "6122400001": "aereo",
}

export function normalizaCuenta(
  guessedCode: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): string {
  if (!catalog?.length) return guessedCode

  // 1. Exact match → use it
  if (catalog.some(c => c.cuenta === guessedCode)) return guessedCode

  // 2. Find semantic type from guessed code
  const tipo = KNOWN_CODES[guessedCode]
  if (tipo) {
    const pattern = TIPO_CATALOG_PATTERNS[tipo]
    // Search catalog entries for name match
    const match = catalog.find(c => pattern.test(c.nombre))
    if (match) {
      console.log(`[normalizaCuenta] ${guessedCode} → ${match.cuenta} (${match.nombre})`)
      return match.cuenta
    }
  }

  // 3. No match found: return first in catalog (better than wrong default)
  // but only if it's not a "No Deducibles" catch-all
  const notNd = catalog.find(c => !/(no deducible|nd)/i.test(c.nombre))
  return (notNd ?? catalog[0])?.cuenta ?? guessedCode
}

// Async version: fetches catalog from Supabase if local catalog is empty
export async function normalizaCuentaAsync(
  guessedCode: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): Promise<string> {
  if (catalog?.length) return normalizaCuenta(guessedCode, catalog)

  // Catalog not loaded yet — fetch directly
  try {
    const { createClient } = await import("@/lib/supabase/client")
    const sb = createClient()
    const { data } = await sb
      .from("cuentas_contables")
      .select("cuenta,nombre")
      .eq("activo", true)
      .order("cuenta")
    if (data?.length) return normalizaCuenta(guessedCode, data)
  } catch {}
  return guessedCode
}

