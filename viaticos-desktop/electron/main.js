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

