// Maps a guessed account code to the closest available one in the catalog

const TIPO_PATTERNS: [RegExp, string][] = [
  [/(alimento|comida|restaurante|consumo|viático|food)/i, "alimentos"],
  [/(hotel|hospedaje|alojamiento)/i,                      "hospedaje"],
  [/(peaje|caseta|autopista|telepeaje)/i,                 "peaje"],
  [/(estacionamiento|parking)/i,                          "estacionamiento"],
  [/(gasolina|combustible|diesel)/i,                      "gasolina"],
  [/(taxi|uber|didi|transporte local)/i,                  "taxi"],
  [/(aéreo|vuelo|boleto|avión|pasaje)/i,                  "aereo"],
]

const TIPO_CATALOG_PATTERNS: Record<string, RegExp> = {
  alimentos:     /(alimento|comida|restaurante|consumo|viático|representaci)/i,
  hospedaje:     /(hotel|hospedaje|alojamiento)/i,
  peaje:         /(peaje|caseta|autopista|telepeaje)/i,
  estacionamiento: /(estacionamiento|parking)/i,
  gasolina:      /(gasolina|combustible|diésel|diesel)/i,
  taxi:          /(taxi|transporte local|uber|didi)/i,
  aereo:         /(aéreo|vuelo|boleto|avión|pasaje.*aéreo|pasaje nacional|pasaje inter)/i,
}

// Known internal-code → semantic type
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
  if (!catalog.length) return guessedCode

  // If guessed code exists in catalog → use it directly
  if (catalog.some(c => c.cuenta === guessedCode)) return guessedCode

  // Determine semantic type from guessed code
  const tipo = KNOWN_CODES[guessedCode]
  if (tipo) {
    const pattern = TIPO_CATALOG_PATTERNS[tipo]
    if (pattern) {
      const match = catalog.find(c => pattern.test(c.nombre))
      if (match) return match.cuenta
    }
  }

  // Last resort: return first non-generic account or first in catalog
  return catalog[0]?.cuenta ?? guessedCode
}

