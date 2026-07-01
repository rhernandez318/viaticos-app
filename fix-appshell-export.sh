#!/bin/bash
set -e

# Agregar default export al final de AppShell.tsx (idempotente)
if ! grep -q "^export default AppShell" src/components/layout/AppShell.tsx; then
  echo "" >> src/components/layout/AppShell.tsx
  echo "export default AppShell" >> src/components/layout/AppShell.tsx
  echo "✓ Default export agregado"
else
  echo "⊙ Default export ya existía"
fi

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

git add .
git commit -m "fix: AppShell añadir default export para compatibilidad con layout.tsx"
git push
echo ""
echo "✓ Done"
