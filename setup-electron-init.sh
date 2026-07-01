#!/bin/bash
# ════════════════════════════════════════════════════════════════════
#  Setup Viáticos Desktop — Electron wrapper sobre Next.js
#
#  Uso:    bash setup-electron-init.sh
#  Crea:   ./viaticos-desktop/ con todos los archivos del wrapper
#
#  Prerrequisitos:
#    • Node.js 20+ instalado
#    • Git instalado
#    • Para generar .exe: Windows 10+ o Wine en Linux/Mac
# ════════════════════════════════════════════════════════════════════
set -e

DEST="${1:-viaticos-desktop}"

if [ -d "$DEST" ]; then
  echo "⚠  El directorio $DEST ya existe. Borralo o pasa otro nombre."
  exit 1
fi

echo "📁  Creando $DEST/"
mkdir -p "$DEST"/{electron,build,installer}
cd "$DEST"

mkdir -p "$(dirname "package.json")"
cat > 'package.json' << 'FILEEOF'
{
  "name": "viaticos-desktop",
  "version": "0.1.0",
  "description": "Viáticos — Aplicación de escritorio",
  "main": "electron/main.js",
  "author": {
    "name": "Grupo Zapata",
    "email": "soporte@viaticos.local"
  },
  "scripts": {
    "dev": "concurrently \"npm run dev:next\" \"wait-on http://localhost:3847/login && electron .\"",
    "dev:next": "cd nextjs-app && npm run dev -- -p 3847",
    "start": "electron .",
    "build:next": "cd nextjs-app && npm run build",
    "pack": "electron-builder --dir",
    "dist": "electron-builder",
    "dist:win": "electron-builder --win",
    "postinstall": "electron-builder install-app-deps"
  },
  "devDependencies": {
    "concurrently": "^8.2.2",
    "electron": "^32.0.0",
    "electron-builder": "^25.0.0",
    "wait-on": "^7.2.0"
  }
}

FILEEOF
echo "  ✓ package.json"

mkdir -p "$(dirname "electron-builder.json")"
cat > 'electron-builder.json' << 'FILEEOF'
{
  "appId": "com.gzapata.viaticos",
  "productName": "Viáticos",
  "copyright": "Copyright © 2026 Grupo Zapata",
  "directories": {
    "output": "dist",
    "buildResources": "build"
  },
  "files": [
    "electron/**/*",
    "build/**/*",
    "package.json"
  ],
  "extraResources": [
    {
      "from": "nextjs-app/.next/standalone",
      "to": "nextjs-app",
      "filter": ["**/*"]
    },
    {
      "from": "nextjs-app/.next/static",
      "to": "nextjs-app/.next/static",
      "filter": ["**/*"]
    },
    {
      "from": "nextjs-app/public",
      "to": "nextjs-app/public",
      "filter": ["**/*"]
    }
  ],
  "win": {
    "target": [
      { "target": "nsis", "arch": ["x64"] }
    ],
    "icon": "build/icon.ico",
    "requestedExecutionLevel": "asInvoker"
  },
  "nsis": {
    "oneClick": false,
    "perMachine": false,
    "allowToChangeInstallationDirectory": true,
    "createDesktopShortcut": true,
    "createStartMenuShortcut": true,
    "shortcutName": "Viáticos",
    "installerLanguages": ["es_ES"],
    "language": "3082",
    "installerSidebar": "build/installer-sidebar.bmp",
    "uninstallerSidebar": "build/installer-sidebar.bmp",
    "include": "installer/installer-script.nsh"
  },
  "mac": {
    "target": "dmg",
    "icon": "build/icon.icns",
    "category": "public.app-category.business"
  },
  "linux": {
    "target": ["AppImage", "deb"],
    "icon": "build/icon.png",
    "category": "Office"
  }
}

FILEEOF
echo "  ✓ electron-builder.json"

mkdir -p "$(dirname "electron/main.js")"
cat > 'electron/main.js' << 'FILEEOF'
const { app, BrowserWindow, Menu, shell, dialog } = require('electron')
const { spawn } = require('child_process')
const path = require('path')
const http = require('http')
const fs = require('fs')

let mainWindow = null
let serverProcess = null
const PORT = 3847  // Puerto privado para evitar conflictos

// Detectar si estamos en dev o producción
const isDev = !app.isPackaged
const NEXT_DIR = isDev
  ? path.join(__dirname, '..', 'nextjs-app')
  : path.join(process.resourcesPath, 'nextjs-app')

function log(...args) {
  console.log('[Viáticos]', ...args)
  // Opcional: escribir a archivo de log para troubleshooting
  const logFile = path.join(app.getPath('userData'), 'app.log')
  try {
    fs.appendFileSync(logFile, `[${new Date().toISOString()}] ${args.join(' ')}\n`)
  } catch {}
}

// Esperar a que el servidor Next.js responda antes de cargar la ventana
function waitForServer(url, timeoutMs = 60000) {
  return new Promise((resolve, reject) => {
    const start = Date.now()
    const check = () => {
      http.get(url, (res) => {
        if (res.statusCode === 200 || res.statusCode === 307) {
          resolve()
        } else {
          retry()
        }
      }).on('error', retry)
    }
    const retry = () => {
      if (Date.now() - start > timeoutMs) {
        reject(new Error(`Servidor no respondió en ${timeoutMs/1000}s`))
      } else {
        setTimeout(check, 500)
      }
    }
    check()
  })
}

// Lanzar el servidor Next.js como proceso hijo
function startNextServer() {
  return new Promise((resolve, reject) => {
    log('Iniciando servidor Next.js en puerto', PORT, '...')
    log('Directorio:', NEXT_DIR)

    const nodeBin = process.execPath
    const nextStart = path.join(NEXT_DIR, 'node_modules', 'next', 'dist', 'bin', 'next')

    serverProcess = spawn(nodeBin, [nextStart, 'start', '-p', PORT.toString()], {
      cwd: NEXT_DIR,
      env: { ...process.env, NODE_ENV: 'production', PORT: PORT.toString() },
      stdio: ['ignore', 'pipe', 'pipe'],
    })

    serverProcess.stdout.on('data', (data) => log('next:', data.toString().trim()))
    serverProcess.stderr.on('data', (data) => log('next-err:', data.toString().trim()))

    serverProcess.on('error', (err) => {
      log('Error spawning Next.js:', err.message)
      reject(err)
    })

    waitForServer(`http://localhost:${PORT}/login`)
      .then(() => { log('Servidor listo'); resolve() })
      .catch(reject)
  })
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 600,
    title: 'Viáticos',
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
    show: false,  // Mostrar solo cuando el contenido esté listo
  })

  mainWindow.loadURL(`http://localhost:${PORT}/login`)

  // Mostrar cuando termine de cargar
  mainWindow.once('ready-to-show', () => mainWindow.show())

  // Abrir links externos (mailto, http externos) en el navegador del sistema
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http://localhost')) return { action: 'allow' }
    shell.openExternal(url)
    return { action: 'deny' }
  })

  mainWindow.on('closed', () => { mainWindow = null })

  // Menú simplificado (no exponer DevTools en producción)
  if (isDev) {
    mainWindow.webContents.openDevTools()
  } else {
    Menu.setApplicationMenu(null)
  }
}

app.whenReady().then(async () => {
  try {
    await startNextServer()
    createWindow()
  } catch (err) {
    log('Fatal error:', err.message)
    dialog.showErrorBox(
      'Error al iniciar Viáticos',
      `No se pudo iniciar el servidor interno.\n\nDetalles: ${err.message}\n\nRevisa: ${path.join(app.getPath('userData'), 'app.log')}`
    )
    app.quit()
  }
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})

app.on('before-quit', () => {
  log('Cerrando servidor Next.js...')
  if (serverProcess) {
    serverProcess.kill('SIGTERM')
    serverProcess = null
  }
})

process.on('uncaughtException', (err) => {
  log('Uncaught:', err.stack || err.message)
})

FILEEOF
echo "  ✓ electron/main.js"

mkdir -p "$(dirname "electron/preload.js")"
cat > 'electron/preload.js' << 'FILEEOF'
// Preload: aquí podemos exponer APIs nativas a la página web de manera segura
// Por ahora vacío — solo se usará si en el futuro queremos acceso a filesystem,
// notificaciones nativas, impresión, etc.
const { contextBridge } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true,
  version: process.versions.electron,
  platform: process.platform,
})

FILEEOF
echo "  ✓ electron/preload.js"

mkdir -p "$(dirname "installer/installer-script.nsh")"
cat > 'installer/installer-script.nsh' << 'FILEEOF'
; ════════════════════════════════════════════════════════════════════
;   Custom NSIS script para wizard de configuración inicial
;   Pide al usuario URL del servidor Supabase y guarda en config
; ════════════════════════════════════════════════════════════════════

!include "MUI2.nsh"
!include "nsDialogs.nsh"

Var SupabaseUrl
Var SupabaseUrlInput
Var SupabaseKey
Var SupabaseKeyInput
Var ConfigDialog

!macro customWelcomePage
  !insertmacro MUI_PAGE_WELCOME
!macroend

; Página personalizada: configuración de conexión a Supabase
Function PageConfigSupabase
  !insertmacro MUI_HEADER_TEXT "Configuración del servidor" "Indica dónde está el servidor de Viáticos"

  nsDialogs::Create 1018
  Pop $ConfigDialog

  ${If} $ConfigDialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 24u "URL del servidor Supabase:"
  Pop $0

  ${NSD_CreateText} 0 26u 100% 14u "https://tu-proyecto.supabase.co"
  Pop $SupabaseUrlInput

  ${NSD_CreateLabel} 0 50u 100% 24u "Clave anónima (anon key):"
  Pop $0

  ${NSD_CreateText} 0 76u 100% 14u "eyJ..."
  Pop $SupabaseKeyInput

  ${NSD_CreateLabel} 0 100u 100% 36u "Puedes obtener estos valores desde tu panel de Supabase → Settings → API. Tu administrador de IT debe proporcionártelos."
  Pop $0

  nsDialogs::Show
FunctionEnd

Function PageConfigSupabaseLeave
  ${NSD_GetText} $SupabaseUrlInput $SupabaseUrl
  ${NSD_GetText} $SupabaseKeyInput $SupabaseKey

  ; Validar que se haya ingresado algo
  ${If} $SupabaseUrl == ""
    MessageBox MB_ICONEXCLAMATION "Debes ingresar la URL del servidor"
    Abort
  ${EndIf}

  ; Guardar en archivo .env del usuario
  FileOpen $0 "$APPDATA\Viaticos\.env" w
  FileWrite $0 "NEXT_PUBLIC_SUPABASE_URL=$SupabaseUrl$\r$\n"
  FileWrite $0 "NEXT_PUBLIC_SUPABASE_ANON_KEY=$SupabaseKey$\r$\n"
  FileClose $0
FunctionEnd

; Crear carpeta de configuración al instalar
!macro customInstall
  CreateDirectory "$APPDATA\Viaticos"
!macroend

FILEEOF
echo "  ✓ installer/installer-script.nsh"

mkdir -p "$(dirname "README.md")"
cat > 'README.md' << 'FILEEOF'
# Viáticos Desktop

Wrapper Electron sobre la aplicación Next.js de Viáticos.

## Estructura

```
viaticos-desktop/
├── electron/
│   ├── main.js              # Proceso principal Electron
│   └── preload.js           # Bridge web ↔ nativo
├── nextjs-app/              # Tu Next.js actual (clonado o symlink)
├── build/                   # Iconos y assets del instalador
├── installer/               # Scripts NSIS personalizados
├── electron-builder.json    # Configuración de empaquetado
└── package.json
```

## Setup inicial

1. Clonar el repo de Viáticos como subcarpeta:
   ```bash
   git clone https://github.com/rhernandez318/viaticos-app.git nextjs-app
   ```

2. Instalar dependencias:
   ```bash
   npm install
   cd nextjs-app && npm install && cd ..
   ```

3. Configurar `.env.local` en `nextjs-app/`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://tu-demo.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
   ```

4. Configurar Next.js para modo standalone (en `nextjs-app/next.config.ts`):
   ```ts
   output: "standalone"
   ```

## Comandos

| Comando | Qué hace |
|---|---|
| `npm run dev` | Modo desarrollo (live reload + DevTools abiertas) |
| `npm run build:next` | Compilar Next.js para producción |
| `npm run pack` | Empaquetar app sin instalador (carpeta `dist/`) |
| `npm run dist:win` | Generar instalador .exe para Windows |

## Iconos requeridos

Coloca en `build/`:
- `icon.ico` — 256×256 mínimo, multi-resolución (Windows)
- `icon.icns` — Mac
- `icon.png` — 512×512 (Linux)
- `installer-sidebar.bmp` — 164×314 (panel lateral del instalador NSIS, opcional)

Si no tienes íconos personalizados, electron-builder usa unos por defecto.

## Probar el .exe generado

1. `npm run dist:win` produce `dist/Viáticos Setup 0.1.0.exe`
2. Cópialo a una VM/PC limpia y ejecuta
3. El wizard pedirá URL + anon key del Supabase
4. Después del install, abre del menú inicio o escritorio

## Troubleshooting

Logs del runtime: `%APPDATA%\Viaticos\app.log` (Windows) o `~/Library/Application Support/Viaticos/app.log` (Mac).

FILEEOF
echo "  ✓ README.md"


# .gitignore para el proyecto desktop
cat > .gitignore << 'GITEOF'
node_modules/
dist/
out/
nextjs-app/
.env
.env.local
app.log
GITEOF

echo ""
echo "📥  Clonando viaticos-app como subcarpeta..."
if [ ! -d "nextjs-app" ]; then
  git clone https://github.com/rhernandez318/viaticos-app.git nextjs-app
fi

echo ""
echo "⚙️   Habilitando output:standalone en Next.js..."
cd nextjs-app
if ! grep -q 'output:' next.config.ts 2>/dev/null && ! grep -q 'output:' next.config.js 2>/dev/null; then
  # Insertar output:standalone en next.config
  if [ -f next.config.ts ]; then
    sed -i.bak 's/const nextConfig[^=]*= *{/const nextConfig: NextConfig = {\n  output: "standalone",/' next.config.ts
    echo "  ✓ next.config.ts modificado"
  elif [ -f next.config.js ]; then
    sed -i.bak 's/const nextConfig *= *{/const nextConfig = {\n  output: "standalone",/' next.config.js
    echo "  ✓ next.config.js modificado"
  fi
else
  echo "  ⊙ output ya estaba configurado"
fi
cd ..

echo ""
echo "📦  Instalando dependencias (Electron + Next.js)..."
npm install
cd nextjs-app && npm install && cd ..

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✓ Setup completado en ./$DEST/"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Siguientes pasos:"
echo ""
echo "  1. Copia tu .env de Vercel a:"
echo "       $DEST/nextjs-app/.env.local"
echo ""
echo "     Mínimo necesitas:"
echo "       NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co"
echo "       NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ..."
echo ""
echo "  2. Probar en modo dev (abre Electron + DevTools):"
echo "       cd $DEST && npm run dev"
echo ""
echo "  3. Generar el .exe (en Windows):"
echo "       cd $DEST && npm run build:next && npm run dist:win"
echo "       → produce dist/Viáticos Setup 0.1.0.exe (~250MB)"
echo ""
echo "Logs en runtime: %APPDATA%\\Viáticos\\app.log"
echo ""