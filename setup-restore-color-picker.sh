#!/bin/bash
set -e

echo "🎨  Restaurando color picker de texto en sidebar..."
echo ""

python3 << 'PYEOF'
with open('src/components/layout/AppShell.tsx') as f: src = f.read()

# 1. Agregar Palette al import de lucide-react
if 'Palette' not in src.split('lucide-react')[0]:
    src = src.replace(
        'Menu as MenuIcon,',
        'Menu as MenuIcon, Palette,',
        1
    )
    print("  ✓ Import Palette agregado")

# 2. Agregar estado de textColor y showColorPicker después del estado dark
new_state = '''  const [dark, setDark] = useState(true)
  const [textColor, setTextColor] = useState<string | null>(null)
  const [showColorPicker, setShowColorPicker] = useState(false)'''

if 'showColorPicker' not in src:
    src = src.replace(
        '  const [dark, setDark] = useState(true)',
        new_state,
        1
    )
    print("  ✓ Estado textColor + showColorPicker agregado")

# 3. Actualizar el useEffect para leer textColor de localStorage
old_effect = '''    const t = localStorage.getItem("theme")
    if (t === "light") { setDark(false); document.documentElement.classList.add("light") }'''

new_effect = '''    const t = localStorage.getItem("theme")
    if (t === "light") { setDark(false); document.documentElement.classList.add("light") }
    const c = localStorage.getItem("textColor")
    if (c) {
      setTextColor(c)
      document.documentElement.style.setProperty("--text", c)
    }'''

if 'localStorage.getItem("textColor")' not in src:
    src = src.replace(old_effect, new_effect)
    print("  ✓ useEffect actualizado para cargar color guardado")

# 4. Agregar función para cambiar color
change_color_fn = '''
  const cambiarColor = (color: string | null) => {
    setTextColor(color)
    if (color) {
      document.documentElement.style.setProperty("--text", color)
      localStorage.setItem("textColor", color)
    } else {
      document.documentElement.style.removeProperty("--text")
      localStorage.removeItem("textColor")
    }
    setShowColorPicker(false)
  }
'''

if 'cambiarColor' not in src:
    src = src.replace(
        '  const toggleTheme = () => {',
        change_color_fn + '\n  const toggleTheme = () => {',
        1
    )
    print("  ✓ Función cambiarColor agregada")

# 5. Agregar el botón del color picker + popover en el sidebar header
old_header = '''        <div style={{ display:"flex", gap:6, padding:"0 4px" }}>
          <button className="icon-btn" onClick={() => router.push("/notificaciones")} title="Notificaciones">
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme} title="Cambiar tema">
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>
        </div>'''

new_header = '''        <div style={{ display:"flex", gap:6, padding:"0 4px", position:"relative" }}>
          <button className="icon-btn" onClick={() => router.push("/notificaciones")} title="Notificaciones">
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={() => setShowColorPicker(!showColorPicker)} title="Color de texto">
            <Palette size={16} strokeWidth={1.75} color={textColor || undefined}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme} title="Cambiar tema">
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>

          {showColorPicker && (
            <div style={{
              position:"absolute", top:36, left:0, zIndex:1000,
              background:"var(--surface, #14171b)",
              border:"1px solid var(--border, #23262c)",
              borderRadius:10, padding:10,
              boxShadow:"0 8px 24px rgba(0,0,0,0.4)",
              minWidth:200,
            }}>
              <div style={{ fontSize:10, fontWeight:700, textTransform:"uppercase", letterSpacing:"0.08em", color:"var(--text-3, #888)", marginBottom:8, padding:"0 2px" }}>
                Color de texto
              </div>
              <div style={{ display:"grid", gridTemplateColumns:"repeat(6, 1fr)", gap:6, marginBottom:8 }}>
                {[
                  { color:null,        label:"Predet.", bg:"transparent", border:"var(--border, #23262c)" },
                  { color:"#ffffff",   label:"Blanco",  bg:"#ffffff" },
                  { color:"#f5e6d3",   label:"Crema",   bg:"#f5e6d3" },
                  { color:"#c5f24d",   label:"Lima",    bg:"#c5f24d" },
                  { color:"#a8d5f0",   label:"Cielo",   bg:"#a8d5f0" },
                  { color:"#f5c0c0",   label:"Rosa",    bg:"#f5c0c0" },
                  { color:"#c0f5d5",   label:"Menta",   bg:"#c0f5d5" },
                  { color:"#e8d5f5",   label:"Lila",    bg:"#e8d5f5" },
                  { color:"#fbbf24",   label:"Ámbar",   bg:"#fbbf24" },
                  { color:"#f97316",   label:"Naranja", bg:"#f97316" },
                  { color:"#ef4444",   label:"Rojo",    bg:"#ef4444" },
                  { color:"#94a3b8",   label:"Gris",    bg:"#94a3b8" },
                ].map((c, i) => {
                  const isActive = (textColor === c.color) || (!textColor && c.color === null)
                  return (
                    <button key={i} onClick={() => cambiarColor(c.color)}
                      title={c.label}
                      style={{
                        width:26, height:26,
                        border: isActive ? "2px solid var(--accent, #c5f24d)" : `1px solid ${c.border || "rgba(0,0,0,0.2)"}`,
                        borderRadius:6,
                        background: c.bg,
                        cursor:"pointer",
                        padding:0,
                        position:"relative",
                      }}>
                      {c.color === null && (
                        <span style={{
                          position:"absolute", inset:0,
                          display:"grid", placeItems:"center",
                          fontSize:10, color:"var(--text-3, #888)",
                        }}>×</span>
                      )}
                    </button>
                  )
                })}
              </div>
              <input type="color"
                value={textColor || "#ffffff"}
                onChange={(e) => cambiarColor(e.target.value)}
                style={{
                  width:"100%", height:28,
                  border:"1px solid var(--border, #23262c)",
                  borderRadius:6, cursor:"pointer",
                  background:"transparent",
                }}
                title="Color personalizado"
              />
            </div>
          )}
        </div>'''

if 'showColorPicker && (' not in src:
    src = src.replace(old_header, new_header)
    print("  ✓ Color picker con paleta insertado en sidebar")

# 6. Mismo botón en la topbar mobile
old_mobile_topbar = '''        <div style={{ display:"flex", gap:6 }}>
          <button className="icon-btn" onClick={() => router.push("/notificaciones")}>
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme}>
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>
        </div>'''

new_mobile_topbar = '''        <div style={{ display:"flex", gap:6 }}>
          <button className="icon-btn" onClick={() => router.push("/notificaciones")}>
            <Bell size={16} strokeWidth={1.75}/>
          </button>
          <button className="icon-btn" onClick={() => setShowColorPicker(!showColorPicker)} title="Color de texto">
            <Palette size={16} strokeWidth={1.75} color={textColor || undefined}/>
          </button>
          <button className="icon-btn" onClick={toggleTheme}>
            {dark ? <Sun size={16} strokeWidth={1.75}/> : <Moon size={16} strokeWidth={1.75}/>}
          </button>
        </div>'''

src = src.replace(old_mobile_topbar, new_mobile_topbar)

with open('src/components/layout/AppShell.tsx', 'w') as f: f.write(src)
print("")
print("✓ AppShell actualizado")
PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

echo ""
git add .
git commit -m "feat: restaurar color picker de texto en sidebar con paleta + custom"
git push
echo "✓ Done"
