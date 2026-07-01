#!/bin/bash
set -e

echo "🔧  Corrigiendo detección de ruta activa..."

python3 << 'PYEOF'
with open('src/components/layout/AppShell.tsx') as f: src = f.read()
original = src

# La versión buggy: pathname.startsWith(href) hace que "/solicitudes/anticipo"
# también active "/solicitudes"
# La versión correcta: match exacto para rutas padre, prefix con "/" para hijas

old = '''  const isActive = (href: string) =>
    href === "/dashboard" ? pathname === "/dashboard" : pathname.startsWith(href)'''

new = '''  const isActive = (href: string) => {
    // Rutas que requieren match exacto (rutas "índice" con hijos)
    const exactMatch = ["/dashboard", "/solicitudes", "/solicitudes/todas", "/gerente", "/perfil", "/notificaciones"]
    if (exactMatch.includes(href)) return pathname === href
    // El resto: match exacto o si es un prefix seguido de "/"
    return pathname === href || pathname.startsWith(href + "/")
  }'''

if old in src:
    src = src.replace(old, new)
    print("  ✓ isActive corregido")
else:
    print("  ⚠ No encontré el patrón exacto de isActive — revisar manualmente")

if src != original:
    with open('src/components/layout/AppShell.tsx', 'w') as f: f.write(src)
    print("  ✓ AppShell.tsx guardado")
PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

git add .
git commit -m "fix: rutas padre requieren match exacto (mis solicitudes ya no se activa con hijas)"
git push
echo "✓ Done"
