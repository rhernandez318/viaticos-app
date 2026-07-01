#!/bin/bash
set -e

echo "🎨  Migrando badges + alertas + bell a Lucide..."
echo ""

python3 << 'PYEOF'
import os, re

# ───── 1. StatusBadge component ─────
paths_status = ['src/components/ui/StatusBadge.tsx', 'src/components/StatusBadge.tsx']
for path in paths_status:
    if not os.path.exists(path): continue
    with open(path) as f: src = f.read()
    original = src

    if 'lucide-react' not in src:
        src = re.sub(r'^("use client".*?\n)',
            r'\1import { Inbox, Clock, ShieldCheck, Banknote, FileText, Trophy, XCircle, RotateCcw } from "lucide-react"\n',
            src, count=1, flags=re.MULTILINE)

    # Reemplazar emojis en el mapping típico: solicitado: "📨", etc.
    replacements = [
      ('solicitado:  { icon:"📨"',  'solicitado:  { icon: Inbox'),
      ('solicitado:{icon:"📨"',    'solicitado:{icon: Inbox'),
      ('autorizado: { icon:"🔐"',  'autorizado: { icon: Clock'),
      ('autorizado:{icon:"🔐"',    'autorizado:{icon: Clock'),
      ('validado:   { icon:"✅"',  'validado:   { icon: ShieldCheck'),
      ('validado:{icon:"✅"',      'validado:{icon: ShieldCheck'),
      ('liberado:   { icon:"💵"',  'liberado:   { icon: Banknote'),
      ('liberado:{icon:"💵"',      'liberado:{icon: Banknote'),
      ('parcial:    { icon:"📎"',  'parcial:    { icon: FileText'),
      ('parcial:{icon:"📎"',       'parcial:{icon: FileText'),
      ('comprobado: { icon:"🏆"',  'comprobado: { icon: Trophy'),
      ('comprobado:{icon:"🏆"',    'comprobado:{icon: Trophy'),
      ('rechazado:  { icon:"❌"',  'rechazado:  { icon: XCircle'),
      ('rechazado:{icon:"❌"',     'rechazado:{icon: XCircle'),
      ('devuelto:   { icon:"↩️"',  'devuelto:   { icon: RotateCcw'),
      ('devuelto:{icon:"↩️"',      'devuelto:{icon: RotateCcw'),
    ]
    for old, new in replacements:
        src = src.replace(old, new)

    # Actualizar el type del mapping
    src = re.sub(r'icon\s*:\s*string', 'icon: any', src)

    # Renderizado: {cfg.icon} → <cfg.icon size=... />
    src = re.sub(
      r'\{cfg\.icon\}',
      '{(() => { const Ico = cfg.icon; return <Ico size={11} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/> })()}',
      src
    )
    src = re.sub(
      r'\{config\.icon\}',
      '{(() => { const Ico = config.icon; return <Ico size={11} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/> })()}',
      src
    )

    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}")

# ───── 2. TipoBadge component ─────
paths_tipo = ['src/components/ui/TipoBadge.tsx', 'src/components/TipoBadge.tsx']
for path in paths_tipo:
    if not os.path.exists(path): continue
    with open(path) as f: src = f.read()
    original = src

    if 'lucide-react' not in src:
        src = re.sub(r'^("use client".*?\n)',
            r'\1import { HandCoins, Receipt, Paperclip } from "lucide-react"\n',
            src, count=1, flags=re.MULTILINE)

    replacements = [
      ('anticipo:    { icon:"💵"',     'anticipo:    { icon: HandCoins'),
      ('anticipo:{icon:"💵"',          'anticipo:{icon: HandCoins'),
      ('reembolso:   { icon:"🧾"',     'reembolso:   { icon: Receipt'),
      ('reembolso:{icon:"🧾"',         'reembolso:{icon: Receipt'),
      ('comprobacion:{ icon:"📎"',     'comprobacion:{ icon: Paperclip'),
      ('comprobacion:{icon:"📎"',      'comprobacion:{icon: Paperclip'),
    ]
    for old, new in replacements:
        src = src.replace(old, new)

    src = re.sub(r'icon\s*:\s*string', 'icon: any', src)
    src = re.sub(
      r'\{cfg\.icon\}',
      '{(() => { const Ico = cfg.icon; return <Ico size={11} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/> })()}',
      src
    )
    src = re.sub(
      r'\{config\.icon\}',
      '{(() => { const Ico = config.icon; return <Ico size={11} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/> })()}',
      src
    )

    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}")

# ───── 3. Alertas inline en páginas de solicitudes ─────
alert_pages = [
  'src/app/(app)/solicitudes/comprobacion/page.tsx',
  'src/app/(app)/solicitudes/reembolso/page.tsx',
  'src/app/(app)/solicitudes/anticipo/page.tsx',
  'src/app/(app)/solicitudes/[id]/corregir/page.tsx',
  'src/components/ui/CompUploader.tsx',
]

for path in alert_pages:
    if not os.path.exists(path): continue
    with open(path) as f: src = f.read()
    original = src

    # Agregar imports Lucide si no están
    needed = []
    if '⚠' in src or '\\u26a0' in src: needed.append('AlertTriangle')
    if '⏰' in src or 'AlarmClock' in src: needed.append('AlarmClock')
    if '💰' in src: needed.append('PiggyBank')
    if '✅' in src: needed.append('CheckCircle2')

    if needed and 'lucide-react' in src:
        # Extender import existente
        existing_match = re.search(r'from "lucide-react"', src)
        if existing_match:
            for icon in needed:
                if icon not in src[:existing_match.start()]:
                    src = re.sub(
                        r'import \{ ([^}]+) \} from "lucide-react"',
                        lambda m: f'import {{ {m.group(1)}, {icon} }} from "lucide-react"' if icon not in m.group(1) else m.group(0),
                        src, count=1
                    )
    elif needed:
        # Sin imports Lucide - agregarlos
        src = re.sub(r'^("use client".*?\n)',
            f'\\1import {{ {", ".join(needed)} }} from "lucide-react"\n',
            src, count=1, flags=re.MULTILINE)

    # Reemplazos inline (todos texto dentro de JSX)
    # ⚠ Factura ya... → <AlertTriangle/> Factura ya...
    src = re.sub(
        r'>(\s*)⚠(\s*)([^<]{0,80})',
        r'><AlertTriangle size={12} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/>\3',
        src
    )
    # ⏰ Factura de hace...
    src = re.sub(
        r'>(\s*)⏰(\s*)([^<]{0,80})',
        r'><AlarmClock size={12} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/>\3',
        src
    )
    # 💰 Saldo a favor
    src = re.sub(
        r'>(\s*)💰(\s*)([^<]{0,60})',
        r'><PiggyBank size={12} strokeWidth={2} style={{verticalAlign:"middle",marginRight:3}}/>\3',
        src
    )

    # Emojis en strings directas dentro de propiedades (menos comunes)
    # "⚠ Requerido" en placeholder → dejar como está o cambiar? Dejar por ahora.

    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}")

# ───── 4. Bell del AppShell — ya usa Lucide, no hace falta ─────
print("  ⊙ Bell del AppShell — ya usa Lucide Bell")

PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -5

echo ""
git add .
git commit -m "feat: migrate StatusBadge + TipoBadge + alerts to lucide-react icons"
git push
echo "✓ Done"
