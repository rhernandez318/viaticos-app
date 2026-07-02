#!/bin/bash
set -e

echo "🔧  Verificando .gitignore..."

if [ -f .gitignore ]; then
  if grep -q "^\.next" .gitignore || grep -q "^/\.next" .gitignore; then
    echo "  ⊙ .next ya está en .gitignore"
  else
    echo "" >> .gitignore
    echo "# Next.js build output" >> .gitignore
    echo ".next/" >> .gitignore
    echo "out/" >> .gitignore
    echo "  ✓ .next/ agregado a .gitignore"
  fi
else
  cat > .gitignore << 'GITEOF'
# Next.js
.next/
out/
next-env.d.ts

# Dependencies
node_modules/
/.pnp
.pnp.*
.yarn/*
!.yarn/patches
!.yarn/plugins
!.yarn/releases
!.yarn/versions

# Local env
.env
.env.local
.env.*.local

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Deployment
.vercel/
GITEOF
  echo "  ✓ .gitignore creado"
fi

echo ""
echo "🧹  Removiendo .next/ del tracking de Git (mantiene los archivos en disco)..."
if git ls-files | grep -q "^\.next/"; then
  git rm -r --cached .next/ 2>/dev/null || true
  echo "  ✓ .next/ removido del tracking"
else
  echo "  ⊙ .next/ no estaba tracked"
fi

echo ""
echo "📝  Estado ahora:"
git status --short | head -10

echo ""
echo "📦  Committeando cambios reales (public/logo.svg, favicon.svg, manifest.json)..."
git add public/logo.svg public/favicon.svg
[ -f public/manifest.json ] && git add public/manifest.json
git add .gitignore
git add setup-new-logo.sh 2>/dev/null || true

# Solo si hay AppShell modificado
if git diff --name-only | grep -q "AppShell.tsx"; then
  git add src/components/layout/AppShell.tsx
fi

git commit -m "chore: gitignore .next + logo SVG asset" || echo "  ⊙ Nada nuevo para committear"
git push

echo ""
echo "✓ Done"
echo ""
echo "ℹ️  Verifica el AppShell con:"
echo "     grep 'logo' src/components/layout/AppShell.tsx"
