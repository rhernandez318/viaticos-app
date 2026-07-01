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

