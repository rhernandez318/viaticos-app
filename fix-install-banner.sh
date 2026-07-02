#!/bin/bash
set -e

echo "🔍  Buscando el banner de instalación..."
grep -rn "Instalar aplicación\|InstallBanner\|InstallPrompt" src/ | grep -v "\.next\|node_modules" | head -10

echo ""
echo "🔧  Aplicando fix a InstallBanner y componentes similares..."

python3 << 'PYEOF'
import os, glob, re

# Buscar todos los archivos que puedan tener el banner
candidates = glob.glob('src/**/InstallBanner*.tsx', recursive=True)
candidates += glob.glob('src/**/InstallPrompt*.tsx', recursive=True)
# También buscar por contenido
for path in glob.glob('src/**/*.tsx', recursive=True):
    if path in candidates: continue
    try:
        with open(path) as f: c = f.read()
        if 'Instalar aplicación' in c or 'beforeinstallprompt' in c:
            candidates.append(path)
    except: pass

for path in candidates:
    with open(path) as f: src = f.read()
    original = src
    
    # 1. Cambiar imágenes viejas por logo.svg
    src = re.sub(r'src=\{?"/logo\.(png|jpg|jpeg|webp|ico)"\}?', 'src="/logo.svg"', src)
    src = re.sub(r'src=\{?"/icon-\d+\.png"\}?', 'src="/logo.svg"', src)
    
    # 2. Cambiar el emoji ⬇️ del botón por un ícono Lucide (Download)
    # Si no tiene lucide-react import, agregarlo
    if '⬇️' in src or '⬇' in src:
        if 'lucide-react' not in src:
            src = re.sub(r'^("use client".*?\n)',
                r'\1import { Download } from "lucide-react"\n',
                src, count=1, flags=re.MULTILINE)
        elif 'Download' not in src.split('lucide-react')[0]:
            src = re.sub(
                r'from "lucide-react"',
                lambda m: m.group(0),
                src
            )
            # Extender el import existente
            src = re.sub(
                r'import \{ ([^}]+) \} from "lucide-react"',
                lambda m: f'import {{ {m.group(1)}, Download }} from "lucide-react"' if 'Download' not in m.group(1) else m.group(0),
                src, count=1
            )
        
        # Reemplazar el emoji en el texto del botón
        src = re.sub(
            r'>\s*⬇️?\s*Instalar aplicación\s*<',
            r'><Download size={16} strokeWidth={2} style={{marginRight:6,verticalAlign:"middle"}}/>Instalar aplicación<',
            src
        )
        # Fallback si el patrón es distinto
        src = src.replace('⬇️ Instalar aplicación', 'Instalar aplicación')
        src = src.replace('⬇ Instalar aplicación', 'Instalar aplicación')
    
    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}")

if not candidates:
    print("  ⚠ No se encontró el componente del banner")
PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

git add .
git commit -m "fix: banner de instalación usa logo.svg y ícono Lucide"
git push
echo "✓ Done"
