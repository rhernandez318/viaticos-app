// Preload: aquí podemos exponer APIs nativas a la página web de manera segura
// Por ahora vacío — solo se usará si en el futuro queremos acceso a filesystem,
// notificaciones nativas, impresión, etc.
const { contextBridge } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true,
  version: process.versions.electron,
  platform: process.platform,
})

