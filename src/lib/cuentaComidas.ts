// Returns true if the given account should require "comensales" comment
// Matches by account NAME (flexible) rather than hardcoded code
// This handles catalogs where the comidas account may have a different code

const COMIDAS_PATTERNS = [
  /alimento/i,
  /comida/i,
  /restaurante/i,
  /cenar/i,
  /comer/i,
  /consumo/i,
  /food/i,
  /viático.*comida/i,
  /gastos.*representaci/i,
]

export function isComidas(cuenta: string, cuentaCatalogo?: Array<{ cuenta: string; nombre: string }>): boolean {
  if (cuentaCatalogo) {
    const entry = cuentaCatalogo.find(c => c.cuenta === cuenta)
    if (entry) return COMIDAS_PATTERNS.some(p => p.test(entry.nombre))
  }
  // Fallback: known codes
  return ["6122200001","6122200002","612220"].some(c => cuenta.startsWith(c))
}

