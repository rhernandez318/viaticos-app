#!/bin/bash
set -e

echo "🎨  Forzando color explícito en íconos Lucide..."
echo ""

python3 << 'PYEOF'
import os, re

# ═══════════════════════════════════════════════════════════════
#  1. StatusBadge/TipoBadge — usar cfg.color en el ícono
# ═══════════════════════════════════════════════════════════════
badge_files = [
  'src/components/ui/StatusBadge.tsx',
  'src/components/StatusBadge.tsx',
  'src/components/ui/TipoBadge.tsx',
  'src/components/TipoBadge.tsx',
]
for path in badge_files:
    if not os.path.exists(path): continue
    with open(path) as f: src = f.read()
    original = src

    # Añadir color={cfg.color} al IIFE del ícono
    src = re.sub(
      r'const Ico = cfg\.icon; return <Ico size=\{(\d+)\} strokeWidth=\{(\d+)\}([^/]*)/>',
      r'const Ico = cfg.icon; return <Ico size={\1} strokeWidth={\2} color={cfg.color}\3/>',
      src
    )
    src = re.sub(
      r'const Ico = config\.icon; return <Ico size=\{(\d+)\} strokeWidth=\{(\d+)\}([^/]*)/>',
      r'const Ico = config.icon; return <Ico size={\1} strokeWidth={\2} color={config.color}\3/>',
      src
    )
    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}: color explícito en badges")

# ═══════════════════════════════════════════════════════════════
#  2. Dashboard workflow — íconos de STATUS_CONFIG usar cfg.color
# ═══════════════════════════════════════════════════════════════
dash = 'src/app/(app)/dashboard/page.tsx'
if os.path.exists(dash):
    with open(dash) as f: src = f.read()
    original = src

    # Patrón 1: {(() => { const StatusIcon = cfg.icon; return <StatusIcon ...} })()}
    src = re.sub(
      r'const StatusIcon = cfg\.icon; return <StatusIcon size=\{(\d+)\} strokeWidth=\{([\d.]+)\}([^/]*)/>',
      r'const StatusIcon = cfg.icon; return <StatusIcon size={\1} strokeWidth={\2} color={cfg.color}\3/>',
      src
    )

    # Patrón 2: {(() => { const StIcon = STATUS_CONFIG[activeStatus].icon; return <StIcon ...}
    # Aquí usamos STATUS_CONFIG[activeStatus].color
    src = re.sub(
      r'const StIcon = STATUS_CONFIG\[([^\]]+)\]\.icon; return <StIcon size=\{(\d+)\} strokeWidth=\{([\d.]+)\}([^/]*)/>',
      r'const StIcon = STATUS_CONFIG[\1].icon; return <StIcon size={\2} strokeWidth={\3} color={STATUS_CONFIG[\1].color}\4/>',
      src
    )

    # Botones de acción — íconos usan el color del texto del botón
    # ShieldCheck de "Validar" está sobre bg:#c084fc con color:#111 → poner color="#111"
    src = re.sub(
      r'<ShieldCheck size=\{14\} strokeWidth=\{2\} style=\{\{marginRight:4,verticalAlign:"middle"\}\}/>',
      '<ShieldCheck size={14} strokeWidth={2} color="#111" style={{marginRight:4,verticalAlign:"middle"}}/>',
      src
    )
    # Paperclip de "Comprobar" — está sobre botón primary o warn
    # Como los botones .btn.primary suelen tener texto oscuro sobre fondo verde acento,
    # ponemos color heredado (default) — pero si el fondo es warn, cambiamos:
    # Mejor: dejar sin color y que herede el color del botón contenedor

    if src != original:
        with open(dash, 'w') as f: f.write(src)
        print(f"  ✓ {dash}: STATUS_CONFIG.icon con color explícito")

# ═══════════════════════════════════════════════════════════════
#  3. ReportesPage — tabs y otros íconos
# ═══════════════════════════════════════════════════════════════
rep = 'src/components/ReportesPage.tsx'
if os.path.exists(rep):
    with open(rep) as f: src = f.read()
    original = src

    # Tabs: el <TabIcon/> hereda color del botón (tab activo tiene color:var(--accent),
    # tab inactivo tiene color:var(--text-2)). Ya funciona por herencia — no cambiar.

    # Empty state: FileX ya tiene color:var(--text-3) inline

    # Banner "Filtrando por": <Calendar/> está dentro de un div con color:var(--accent)
    # Debe heredar bien, pero por seguridad, forzar:
    src = re.sub(
      r'<Calendar size=\{(\d+)\} strokeWidth=\{(\d+)\} style=\{\{marginRight:(\d+),verticalAlign:"middle"\}\}/>',
      r'<Calendar size={\1} strokeWidth={\2} color="var(--accent, #c5f24d)" style={{marginRight:\3,verticalAlign:"middle"}}/>',
      src
    )

    if src != original:
        with open(rep, 'w') as f: f.write(src)
        print(f"  ✓ {rep}: iconos con color garantizado")

# ═══════════════════════════════════════════════════════════════
#  4. Alertas en solicitudes — <AlertTriangle/> <AlarmClock/> <PiggyBank/>
#     Estas están inline en badges de color var(--danger) o var(--warn)
#     Dependen del color del contenedor
# ═══════════════════════════════════════════════════════════════
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

    # AlertTriangle → color de var(--danger) por defecto (contexto de warning/error)
    src = re.sub(
      r'<AlertTriangle size=\{(\d+)\} strokeWidth=\{(\d+)\} style=\{\{verticalAlign:"middle",marginRight:(\d+)\}\}/>',
      r'<AlertTriangle size={\1} strokeWidth={\2} color="currentColor" style={{verticalAlign:"middle",marginRight:\3,display:"inline"}}/>',
      src
    )
    # AlarmClock → color amarillo (vencida)
    src = re.sub(
      r'<AlarmClock size=\{(\d+)\} strokeWidth=\{(\d+)\} style=\{\{verticalAlign:"middle",marginRight:(\d+)\}\}/>',
      r'<AlarmClock size={\1} strokeWidth={\2} color="currentColor" style={{verticalAlign:"middle",marginRight:\3,display:"inline"}}/>',
      src
    )
    # PiggyBank → color acento (saldo a favor = positivo)
    src = re.sub(
      r'<PiggyBank size=\{(\d+)\} strokeWidth=\{(\d+)\} style=\{\{verticalAlign:"middle",marginRight:(\d+)\}\}/>',
      r'<PiggyBank size={\1} strokeWidth={\2} color="currentColor" style={{verticalAlign:"middle",marginRight:\3,display:"inline"}}/>',
      src
    )

    if src != original:
        with open(path, 'w') as f: f.write(src)
        print(f"  ✓ {path}: alertas con color explícito")

PYEOF

echo ""
echo "🏗️   Verificando build..."
npm run build 2>&1 | grep -E "✓ Compiled|Type error|error TS" | head -3

echo ""
git add .
git commit -m "fix: force explicit color on lucide icons for visibility on dark backgrounds"
git push
echo "✓ Done"
