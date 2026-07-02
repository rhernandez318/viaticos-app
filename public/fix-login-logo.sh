#!/bin/bash
set -e

echo "🔍  Buscando referencias a logo en la página de login y otros auth..."
grep -rn "logo\|Image src=" 'src/app/(auth)/' | head -10

echo ""
echo "🔧  Aplicando fix..."

python3 << 'PYEOF'
import os, glob, re

# Todos los archivos en la carpeta (auth) que puedan tener logo
files_to_check = glob.glob('src/app/(auth)/**/*.tsx', recursive=True)
files_to_check += glob.glob('src/app/**/layout.tsx', recursive=True)

count_files = 0
for path in files_to_check:
    with open(path) as f: src = f.read()
    original = src
    # Cambiar cualquier logo.png o logo.jpg → logo.svg
    src = re.sub(r'src=\{?"/logo\.(png|jpg|jpeg|webp)"\}?', 'src="/logo.svg"', src)
    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}")
        count_files += 1

if count_files == 0:
    print("  ⚠ Ningún archivo se modificó — puede que ya usen /logo.svg o el logo esté como emoji/svg inline")
PYEOF

echo ""
echo "🔍  Estado final:"
grep -rn "logo" src/app/ | grep -v "\.next\|node_modules" | head -10

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

echo ""
git add .
git commit -m "fix: página de login usa /logo.svg (no logo.png)"
git push
echo "✓ Done"
