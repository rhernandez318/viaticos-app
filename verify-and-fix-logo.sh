#!/bin/bash
set -e

echo "🔍  Buscando referencias al logo en AppShell..."
grep -n "logo\." src/components/layout/AppShell.tsx || echo "  ⚠ Sin coincidencias"

echo ""
echo "🔍  Buscando en todos los archivos src/..."
grep -rn 'src="/logo\|src={"/logo\|logo\.png\|logo\.svg' src/ | head -10

echo ""
echo "🔧  Forzando actualización a /logo.svg en AppShell (patrones múltiples)..."
python3 << 'PYEOF'
with open('src/components/layout/AppShell.tsx') as f: src = f.read()
original = src

# Múltiples patrones posibles
import re
# Cualquier logo.* en Image src
src = re.sub(r'src=\{?"/logo\.\w+"\}?', 'src="/logo.svg"', src)
# También logo sin extension
src = re.sub(r'src=\{?"/logo"\}?', 'src="/logo.svg"', src)

if src != original:
    with open('src/components/layout/AppShell.tsx', 'w') as f: f.write(src)
    print("  ✓ AppShell actualizado a /logo.svg")
else:
    print("  ⊙ No hay referencias a logo en AppShell — verifica manualmente")
PYEOF
