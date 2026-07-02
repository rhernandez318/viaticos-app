#!/bin/bash
# ════════════════════════════════════════════════════════════════════
#  Convierte public/logo.svg a todos los formatos raster necesarios:
#  - PWA: icon-192.png, icon-512.png, apple-touch-icon.png
#  - Desktop Electron: build/icon.ico (Win), build/icon.png (Linux)
#  - Favicon: favicon-16, favicon-32
#
#  Corre desde: raíz de viaticos-app (para PWA)
#              raíz de viaticos-desktop (para .exe)
# ════════════════════════════════════════════════════════════════════
set -e

echo "🔍  Detectando proyecto..."

# Detectar si estamos en el proyecto web o desktop
if [ -f "public/logo.svg" ]; then
  PROJECT_TYPE="web"
  SOURCE_SVG="public/logo.svg"
  echo "  ✓ Proyecto web (Next.js) detectado"
elif [ -f "nextjs-app/public/logo.svg" ]; then
  PROJECT_TYPE="desktop"
  SOURCE_SVG="nextjs-app/public/logo.svg"
  echo "  ✓ Proyecto desktop (Electron) detectado"
else
  echo "  ⚠ No encontré logo.svg. Ejecuta desde la raíz del proyecto."
  exit 1
fi

# Verificar que sharp está disponible o instalarlo temporalmente
echo ""
echo "📦  Verificando sharp (convertidor SVG→PNG)..."
if ! npm list sharp 2>/dev/null | grep -q "sharp@"; then
  echo "  Instalando sharp como devDependency..."
  npm install --save-dev sharp png-to-ico 2>&1 | tail -3
else
  echo "  ✓ sharp ya instalado"
fi

# Script de conversión
echo ""
echo "🎨  Generando PNGs en múltiples resoluciones..."

node << 'NODEEOF'
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

// Detectar tipo de proyecto
const isDesktop = fs.existsSync('nextjs-app/public/logo.svg');
const publicDir = isDesktop ? 'nextjs-app/public' : 'public';
const buildDir = isDesktop ? 'build' : 'public';

const sourceSvg = path.join(publicDir, 'logo.svg');
const svgBuffer = fs.readFileSync(sourceSvg);

// Fondo transparente para las conversiones
const transparent = { r: 0, g: 0, b: 0, alpha: 0 };

async function convert(size, output) {
  await sharp(svgBuffer, { density: 300 })
    .resize(size, size, { fit: 'contain', background: transparent })
    .png()
    .toFile(output);
  console.log(`  ✓ ${output} (${size}×${size})`);
}

async function main() {
  // Directorio public/ para PWA
  await convert(16,   path.join(publicDir, 'favicon-16.png'));
  await convert(32,   path.join(publicDir, 'favicon-32.png'));
  await convert(192,  path.join(publicDir, 'icon-192.png'));
  await convert(512,  path.join(publicDir, 'icon-512.png'));
  await convert(180,  path.join(publicDir, 'apple-touch-icon.png'));

  // Directorio build/ para Electron (solo si es desktop)
  if (isDesktop) {
    if (!fs.existsSync('build')) fs.mkdirSync('build');
    await convert(256,  'build/icon.png');
    await convert(512,  'build/icon-512.png');

    // Generar .ico multi-resolución para Windows
    const pngToIco = require('png-to-ico');
    const icoBuffers = await Promise.all([16, 24, 32, 48, 64, 128, 256].map(async (size) => {
      return await sharp(svgBuffer, { density: 300 })
        .resize(size, size, { fit: 'contain', background: transparent })
        .png()
        .toBuffer();
    }));
    const icoData = await pngToIco(icoBuffers);
    fs.writeFileSync('build/icon.ico', icoData);
    console.log(`  ✓ build/icon.ico (multi-res 16-256)`);
  }
}

main().catch(err => { console.error(err); process.exit(1); });
NODEEOF

# Actualizar manifest.json para PWA
if [ "$PROJECT_TYPE" = "web" ] && [ -f "public/manifest.json" ]; then
  echo ""
  echo "📝  Actualizando manifest.json..."
  python3 << 'PYEOF'
import json
with open('public/manifest.json') as f: m = json.load(f)

# Reemplazar icons con las nuevas PNGs
m['icons'] = [
  {
    "src": "/icon-192.png",
    "sizes": "192x192",
    "type": "image/png",
    "purpose": "any maskable"
  },
  {
    "src": "/icon-512.png",
    "sizes": "512x512",
    "type": "image/png",
    "purpose": "any maskable"
  },
  {
    "src": "/apple-touch-icon.png",
    "sizes": "180x180",
    "type": "image/png"
  }
]

with open('public/manifest.json', 'w') as f:
  json.dump(m, f, indent=2, ensure_ascii=False)
print("  ✓ manifest.json actualizado con PNGs de 192 y 512 px")
PYEOF
fi

# Actualizar layout.tsx para agregar apple-touch-icon meta tag
if [ "$PROJECT_TYPE" = "web" ] && [ -f "src/app/layout.tsx" ]; then
  echo ""
  echo "📝  Verificando favicon en layout.tsx..."
  python3 << 'PYEOF'
import re
with open('src/app/layout.tsx') as f: src = f.read()
original = src

# Si tiene metadata icons, actualizar
# Si no, no hacemos nada — el favicon.svg + manifest ya cubren
if 'icons:' in src or 'icon:' in src:
    src = re.sub(r'favicon\.ico', 'favicon-32.png', src)
    src = re.sub(r'favicon\.svg', 'favicon-32.png', src)
    if src != original:
        with open('src/app/layout.tsx', 'w') as f: f.write(src)
        print("  ✓ layout.tsx actualizado a favicon-32.png")
PYEOF
fi

echo ""
echo "════════════════════════════════════════════════════════════"
if [ "$PROJECT_TYPE" = "web" ]; then
  ls -la public/*.png 2>/dev/null | tail -6
  echo ""
  echo "📦  Committeando..."
  git add public/*.png public/manifest.json src/app/layout.tsx 2>/dev/null || true
  git commit -m "feat: PNG icons multi-size para PWA install" || echo "  ⊙ Sin cambios"
  git push
else
  ls -la build/*.png build/*.ico 2>/dev/null
  echo ""
  echo "📦  Para desktop no hacemos commit — build/ suele estar en gitignore"
fi

echo ""
echo "✓ Done"
echo ""
echo "SIGUIENTE PASO:"
echo ""
if [ "$PROJECT_TYPE" = "web" ]; then
  echo "  1. Espera que Vercel redeploye (~1 min)"
  echo "  2. En el celular: DESINSTALA la PWA actual"
  echo "     (mantén el ícono, botón i, Desinstalar)"
  echo "  3. Abre demo-viaticos.vercel.app en el celular"
  echo "  4. En Chrome: menú ⋮ → 'Instalar app'"
  echo "  5. El nuevo ícono debe aparecer verde lima"
else
  echo "  Ya tienes build/icon.ico y build/icon.png actualizados."
  echo "  Re-genera el .exe con:"
  echo "    npm run build:next && npm run dist:win"
  echo ""
  echo "  El nuevo .exe usará la maletita verde lima como ícono."
fi
