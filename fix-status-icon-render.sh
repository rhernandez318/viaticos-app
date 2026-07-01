#!/bin/bash
set -e

echo "🔧  Buscando otros usos de STATUS_CONFIG[...].icon..."

python3 << 'PYEOF'
import re

FILES = [
  'src/app/(app)/dashboard/page.tsx',
]

for path in FILES:
    try:
      with open(path) as f: src = f.read()
    except FileNotFoundError:
      print(f"  ⚠ {path} no encontrado — skipping")
      continue

    original = src

    # Patrón 1: {STATUS_CONFIG[key].icon} → renderizar como componente
    # Ejemplo: {STATUS_CONFIG[activeStatus].icon}
    src = re.sub(
        r'\{STATUS_CONFIG\[([^\]]+)\]\.icon\}',
        r'{(() => { const StIcon = STATUS_CONFIG[\1].icon; return <StIcon size={16} strokeWidth={1.75} style={{verticalAlign:"middle"}}/> })()}',
        src
    )

    # Patrón 2: STATUS_CONFIG[x].icon usado dentro de props/atributos (menos común)
    # Solo aplica al render inline

    if src != original:
        with open(path, 'w') as f: f.write(src)
        matches = len(re.findall(r'STATUS_CONFIG\[[^\]]+\]\.icon', original)) - len(re.findall(r'STATUS_CONFIG\[[^\]]+\]\.icon', src))
        print(f"  ✓ {path}: {matches if matches > 0 else 'algunos'} usos actualizados")
    else:
        print(f"  ⊙ {path}: sin cambios necesarios")
PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -5

echo ""
git add .
git commit -m "fix: render STATUS_CONFIG[key].icon como componente (no ReactNode string)"
git push
echo "✓ Done"
