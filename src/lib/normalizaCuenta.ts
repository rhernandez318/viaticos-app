// Resolves a semantic tipo marker (like __alimentos__) to the actual account
// code that exists in the client's catalog.

// Catalog name patterns per semantic type
const TIPO_CATALOG_PATTERNS: Record<string, RegExp> = {
  alimentos:       /(alimento|comida|comidas|restaurante|consumo|viático|representaci)/i,
  hospedaje:       /(hotel|hospedaje|alojamiento)/i,
  peaje:           /(peaje|caseta|autopista|telepeaje)/i,
  estacionamiento: /(estacionamiento|parking)/i,
  gasolina:        /(gasolina|combustible|diésel|diesel|gas)/i,
  taxi:            /(taxi|transporte.*local|uber|didi|terrestre)/i,
  aereo:           /(aéreo|vuelo|boleto|avión|pasaje)/i,
  nd:              /(no deducible|nd\b)/i,
}

function findInCatalog(tipo: string, catalog: Array<{ cuenta: string; nombre: string }>): string | null {
  const pattern = TIPO_CATALOG_PATTERNS[tipo]
  if (!pattern) return null
  return catalog.find(c => pattern.test(c.nombre))?.cuenta ?? null
}

function getNdAccount(catalog: Array<{ cuenta: string; nombre: string }>): string {
  return catalog.find(c => TIPO_CATALOG_PATTERNS.nd.test(c.nombre))?.cuenta
      ?? catalog[catalog.length - 1]?.cuenta
      ?? "6121200001"
}

export function normalizaCuenta(
  cuentaOrTipo: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): string {
  if (!catalog?.length) return cuentaOrTipo

  // Already a real code that exists in catalog
  if (catalog.some(c => c.cuenta === cuentaOrTipo)) return cuentaOrTipo

  // Resolve __tipo__ marker
  const tipoMatch = cuentaOrTipo.match(/^__(\w+)__$/)
  if (tipoMatch) {
    const tipo = tipoMatch[1]
    const found = findInCatalog(tipo, catalog)
    if (found) {
      console.log(`[normalizaCuenta] ${cuentaOrTipo} → ${found}`)
      return found
    }
    return getNdAccount(catalog)
  }

  // Unknown code not in catalog → No Deducibles
  return getNdAccount(catalog)
}

// Async version: fetches catalog from Supabase if local catalog is empty
// Debug: log when catalog is used for normalization
export async function normalizaCuentaAsync(
  cuentaOrTipo: string,
  catalog: Array<{ cuenta: string; nombre: string }>
): Promise<string> {
  // Always fetch fresh from Supabase to avoid stale catalog state
  try {
    const { createClient } = await import("@/lib/supabase/client")
    const sb = createClient()
    const { data } = await sb
      .from("cuentas_contables")
      .select("cuenta,nombre")
      .eq("activo", true)
      .order("cuenta")
    if (data?.length) {
      console.log("[normalizaCuenta] catalog loaded:", data.length, "accounts")
      return normalizaCuenta(cuentaOrTipo, data)
    }
  } catch (e) {
    console.warn("[normalizaCuenta] catalog fetch failed:", e)
  }
  // Fallback to passed catalog
  if (catalog?.length) return normalizaCuenta(cuentaOrTipo, catalog)
  return cuentaOrTipo
}

// For isComidas: check if a catalog account code corresponds to a food account
export function isCuentaComidas(cuenta: string, catalog: Array<{ cuenta: string; nombre: string }>): boolean {
  const entry = catalog.find(c => c.cuenta === cuenta)
  if (entry) return TIPO_CATALOG_PATTERNS.alimentos.test(entry.nombre)
  // Fallback for __alimentos__ markers
  return cuenta === "__alimentos__"
}

