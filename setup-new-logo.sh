#!/bin/bash
# ════════════════════════════════════════════════════════════════════
#  Setup del nuevo logo Outline en el proyecto Viáticos
#
#  Reemplaza el logo.png actual con la maletita SVG en verde lima
#  Actualiza el AppShell para usar el nuevo archivo
# ════════════════════════════════════════════════════════════════════
set -e

echo "🎨  Instalando logo Outline (maletita verde lima)..."
echo ""

# 1. Guardar el SVG en public/
cat > public/logo.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="#c5f24d" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M 15 6 L 15 14"/>
  <path d="M 33 6 L 33 14"/>
  <path d="M 15 6 L 33 6"/>
  <rect x="8" y="14" width="32" height="28" rx="3.5"/>
  <line x1="8" y1="24" x2="40" y2="24" stroke-width="1.5"/>
  <rect x="21" y="22.5" width="6" height="3" rx="0.5" fill="#c5f24d" stroke="none"/>
  <circle cx="14" cy="45" r="1.8" fill="#c5f24d" stroke="none"/>
  <circle cx="34" cy="45" r="1.8" fill="#c5f24d" stroke="none"/>
</svg>
SVGEOF
echo "  ✓ public/logo.svg guardado"

# 2. Guardar el favicon SVG
cat > public/favicon.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" fill="none" stroke="#c5f24d" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M 10 4 L 10 10"/>
  <path d="M 22 4 L 22 10"/>
  <path d="M 10 4 L 22 4"/>
  <rect x="5" y="10" width="22" height="18" rx="2.5"/>
  <line x1="5" y1="17" x2="27" y2="17" stroke-width="1.2"/>
  <rect x="14" y="16" width="4" height="2" rx="0.3" fill="#c5f24d" stroke="none"/>
  <circle cx="9" cy="30" r="1.3" fill="#c5f24d" stroke="none"/>
  <circle cx="23" cy="30" r="1.3" fill="#c5f24d" stroke="none"/>
</svg>
SVGEOF
echo "  ✓ public/favicon.svg guardado"

# 3. Actualizar AppShell para usar el nuevo archivo SVG
python3 << 'PYEOF'
with open('src/components/layout/AppShell.tsx') as f: src = f.read()

# Cambiar /logo.png → /logo.svg en ambos <Image>
count = src.count('/logo.png')
src = src.replace('/logo.png', '/logo.svg')
if count > 0:
    with open('src/components/layout/AppShell.tsx', 'w') as f: f.write(src)
    print(f"  ✓ AppShell: {count} referencias actualizadas a /logo.svg")
else:
    print("  ⊙ AppShell ya usaba otro path")
PYEOF

# 4. Actualizar el manifest.json para PWA
if [ -f public/manifest.json ]; then
  python3 << 'PYEOF'
import json
with open('public/manifest.json') as f: m = json.load(f)
if 'icons' in m:
    for icon in m['icons']:
        if icon.get('src', '').endswith('.png') and 'logo' in icon.get('src', ''):
            icon['src'] = '/logo.svg'
            icon['type'] = 'image/svg+xml'
with open('public/manifest.json', 'w') as f: json.dump(m, f, indent=2, ensure_ascii=False)
print("  ✓ manifest.json actualizado")
PYEOF
fi

# 5. Actualizar layout.tsx si tiene referencia a favicon
if grep -q 'favicon' src/app/layout.tsx 2>/dev/null; then
  python3 << 'PYEOF'
with open('src/app/layout.tsx') as f: src = f.read()
# Cambiar referencia de favicon.ico a favicon.svg si aplica
original = src
src = src.replace('favicon.ico', 'favicon.svg')
if src != original:
    with open('src/app/layout.tsx', 'w') as f: f.write(src)
    print("  ✓ layout.tsx: referencia a favicon actualizada")
PYEOF
fi

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

echo ""
git add public/logo.svg public/favicon.svg src/components/layout/AppShell.tsx
[ -f public/manifest.json ] && git add public/manifest.json
[ -f src/app/layout.tsx ] && git add src/app/layout.tsx
git commit -m "feat: nuevo logo outline maletita verde lima (SVG vectorial)"
git push
echo "✓ Done"
echo ""
echo "ℹ️  Nota: El logo.png viejo sigue en public/ por si acaso."
echo "   Puedes borrarlo cuando confirmes que el nuevo funciona:"
echo "     git rm public/logo.png && git commit -am 'chore: remove old logo.png'"
