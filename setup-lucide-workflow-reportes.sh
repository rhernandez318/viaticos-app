#!/bin/bash
set -e

echo "🎨  Migrando íconos de workflow y reportes a Lucide..."
echo ""

# ═══════════════════════════════════════════════════════════════
#  1. DASHBOARD - Workflow STATUS_CONFIG + botones de acción
# ═══════════════════════════════════════════════════════════════
python3 << 'PYEOF'
DASH = 'src/app/(app)/dashboard/page.tsx'
try:
  with open(DASH) as f: src = f.read()
except FileNotFoundError:
  print(f"  ⚠ {DASH} no encontrado — skipping")
  import sys; sys.exit(0)

# 1.1 Agregar imports de Lucide (si no están)
if 'lucide-react' not in src:
    # Insertar después del "use client"
    src = src.replace(
        '"use client"',
        '''"use client"
import type { LucideIcon } from "lucide-react"
import { Inbox, Clock, ShieldCheck, Banknote, FileText, Trophy, XCircle, RotateCcw, Paperclip } from "lucide-react"'''
    )
    print("  ✓ Imports Lucide agregados a dashboard")
elif 'Inbox' not in src:
    # Ya usa lucide para algo, solo agregar los que faltan
    src = src.replace(
        'from "lucide-react"',
        ', Inbox, Clock, ShieldCheck, Banknote, FileText, Trophy, XCircle, RotateCcw, Paperclip } from "lucide-react"',
        1
    ).replace(
        'import {  ,',
        'import {'
    )
    # Fix double braces
    if '{ ,' in src: src = src.replace('{ ,', '{')

# 1.2 Cambiar STATUS_CONFIG type de icon:string → icon:LucideIcon
src = src.replace(
    'const STATUS_CONFIG: Record<Status,{label:string,icon:string,color:string,bg:string}>',
    'const STATUS_CONFIG: Record<Status,{label:string,icon:LucideIcon,color:string,bg:string}>'
)

# 1.3 Reemplazar emojis por componentes en cada línea de STATUS_CONFIG
replacements = [
  ('icon:"📨"',  'icon: Inbox'),
  ('icon:"🔐"',  'icon: Clock'),        # autorizado = pendiente admin = reloj
  ('icon:"✅"',  'icon: ShieldCheck'),  # validado = admin aprobó
  ('icon:"💵"',  'icon: Banknote'),     # liberado
  ('icon:"📎"',  'icon: FileText'),     # parcial
  ('icon:"🏆"',  'icon: Trophy'),       # comprobado
  ('icon:"❌"',  'icon: XCircle'),      # rechazado
  ('icon:"↩️"',  'icon: RotateCcw'),    # devuelto (si existe)
  # Con espacios por si el estilo es diferente
  ('icon: "📨"',  'icon: Inbox'),
  ('icon: "🔐"',  'icon: Clock'),
  ('icon: "✅"',  'icon: ShieldCheck'),
  ('icon: "💵"',  'icon: Banknote'),
  ('icon: "📎"',  'icon: FileText'),
  ('icon: "🏆"',  'icon: Trophy'),
  ('icon: "❌"',  'icon: XCircle'),
  ('icon: "↩️"',  'icon: RotateCcw'),
]
for old, new in replacements:
    src = src.replace(old, new)

# 1.4 Actualizar el render en las cards: {cfg.icon} → <cfg.icon size={.} />
# Patrón usual: <div style={{fontSize:22}}>{cfg.icon}</div>
# Change to: {(() => { const I = cfg.icon; return <I size={22} strokeWidth={1.75}/> })()}
import re

# El patrón de render en el card del status
# style={{fontSize:22}}>{cfg.icon}</div>  o similar
def replace_cfg_icon(match):
    style_part = match.group(1)
    # Extraer size del fontSize si existe
    size_match = re.search(r'fontSize\s*:\s*(\d+)', style_part)
    size = int(size_match.group(1)) if size_match else 22
    return f'style={{{{{style_part}display:"flex",alignItems:"center",justifyContent:"center"}}}}>{{(() => {{ const I = cfg.icon; return <I size={{{size}}} strokeWidth={{1.75}}/> }})()}}</div'

# Buscar todos los usos de {cfg.icon}
def replace_icon_uses(src):
    # Patrón 1: <span/div ...>{cfg.icon}</span/div>
    # Reemplazar simple: {cfg.icon} → <cfg.icon size={20} strokeWidth={1.75}/>
    # Pero JSX no permite lowercase component directamente, hay que hacer const I = cfg.icon
    # Wrap con un IIFE
    return re.sub(
        r'\{cfg\.icon\}',
        '{(() => { const StatusIcon = cfg.icon; return <StatusIcon size={20} strokeWidth={1.75}/> })()}',
        src
    )

new_src = replace_icon_uses(src)
if new_src != src:
    src = new_src
    print("  ✓ Render de STATUS_CONFIG.icon actualizado")

# 1.5 Botones de acción con emojis en el drilldown
button_emoji_replacements = [
  # 🔐 Validar
  ('🔐 Validar →', '<ShieldCheck size={14} strokeWidth={2} style={{marginRight:4,verticalAlign:"middle"}}/>Validar →'),
  # 📎 Comprobar
  ('📎 Comprobar →', '<Paperclip size={14} strokeWidth={2} style={{marginRight:4,verticalAlign:"middle"}}/>Comprobar →'),
  ('📎 Comprobar saldo →', '<Paperclip size={14} strokeWidth={2} style={{marginRight:4,verticalAlign:"middle"}}/>Comprobar saldo →'),
]
for old, new in button_emoji_replacements:
    src = src.replace(old, new)

# Handle the fact that emojis inside string may be JSX text
# Convert "🔐 Validar →" strings inside buttons to a fragment with icon
src = re.sub(
    r'>\s*🔐 Validar →\s*<',
    r'><ShieldCheck size={14} strokeWidth={2} style={{marginRight:4,verticalAlign:"middle"}}/>Validar →<',
    src
)
src = re.sub(
    r'>\s*📎 Comprobar →\s*<',
    r'><Paperclip size={14} strokeWidth={2} style={{marginRight:4,verticalAlign:"middle"}}/>Comprobar →<',
    src
)
src = re.sub(
    r'>\s*📎 Comprobar saldo →\s*<',
    r'><Paperclip size={14} strokeWidth={2} style={{marginRight:4,verticalAlign:"middle"}}/>Comprobar saldo →<',
    src
)

with open(DASH, 'w') as f: f.write(src)
print("  ✓ dashboard/page.tsx actualizado")
PYEOF

# ═══════════════════════════════════════════════════════════════
#  2. REPORTES - TABS + filtros + empty states
# ═══════════════════════════════════════════════════════════════
python3 << 'PYEOF'
REP = 'src/components/ReportesPage.tsx'
try:
  with open(REP) as f: src = f.read()
except FileNotFoundError:
  print(f"  ⚠ {REP} no encontrado — skipping")
  import sys; sys.exit(0)

import re

# 2.1 Agregar imports Lucide
if 'lucide-react' not in src:
    src = src.replace(
        '"use client"',
        '''"use client"
import type { LucideIcon } from "lucide-react"
import { BarChart3, Building2, BookOpen, User, Clock, FileX, Calendar } from "lucide-react"'''
    )
    print("  ✓ Imports Lucide agregados a reportes")

# 2.2 Cambiar TABS type y valores
src = src.replace(
    'const TABS: { id: Tab; label: string; icon: string }[] = [',
    'const TABS: { id: Tab; label: string; icon: LucideIcon }[] = ['
)

tab_replacements = [
  ('icon:"📊" }',   'icon: BarChart3 }'),
  ('icon:"🏢" }',   'icon: Building2 }'),
  ('icon:"📒" }',   'icon: BookOpen }'),
  ('icon:"👤" }',   'icon: User }'),
  ('icon:"⏱" }',    'icon: Clock }'),
  ('icon:"⏱️" }',    'icon: Clock }'),
]
for old, new in tab_replacements:
    src = src.replace(old, new)

# 2.3 Actualizar render de las tabs
# Antes: {t.icon} {t.label}
# Después: <t.icon size={14}/> {t.label}
src = re.sub(
    r'\{t\.icon\}\s+\{t\.label\}',
    '{(() => { const TabIcon = t.icon; return <TabIcon size={14} strokeWidth={1.75} style={{marginRight:4,verticalAlign:"middle"}}/> })()}{t.label}',
    src
)

# 2.4 Reemplazar el 📅 del banner "Filtrando por..."
src = re.sub(
    r'📅 Filtrando por',
    '<Calendar size={14} strokeWidth={2} style={{marginRight:6,verticalAlign:"middle"}}/>Filtrando por',
    src
)

# 2.5 Reemplazar 📒 del empty state
# fontSize:32 usualmente en un div contenedor con solo emoji
src = re.sub(
    r'<div style=\{\{fontSize:32,marginBottom:12\}\}>📒</div>',
    '<div style={{display:"flex",justifyContent:"center",marginBottom:12}}><FileX size={40} strokeWidth={1.5} style={{color:"var(--text-3, #888)"}}/></div>',
    src
)

with open(REP, 'w') as f: f.write(src)
print("  ✓ ReportesPage.tsx actualizado")
PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -5

echo ""
echo "📦  Deploy..."
git add .
git commit -m "feat: replace emoji icons in workflow + reportes with lucide-react components"
git push
echo ""
echo "✓ Done"
