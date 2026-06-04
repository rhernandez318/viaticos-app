#!/bin/bash
set -e

cat > 'src/components/ui/CompUploader.tsx' << 'FILEEOF'
"use client"
import { useRef, useCallback, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { parseCFDIXml } from "@/lib/cfdi"
import type { CfdItem } from "@/types"

const CUENTA_PATTERNS: [RegExp, string][] = [
  [/(peaje|caseta|autopista|telepeaje|iave)/i,          "6122700001"],
  [/(estacionamiento|parking|parquímetro)/i,            "6122700002"],
  [/(gasolina|combustible|magna|premium|diésel|pemex)/i,"6122600001"],
  [/(taxi|uber|didi|cabify|transporte)/i,               "6122900002"],
  [/(hotel|hospedaje|alojamiento)/i,                    "6122100001"],
  [/(restaurante|alimentos|comida|cenar|comer)/i,       "6122200001"],
  [/(aéreo|vuelo|boleto|avión)/i,                       "6122400001"],
]

function guessCuentaFromText(text: string): string {
  for (const [re, cuenta] of CUENTA_PATTERNS) {
    if (re.test(text)) return cuenta
  }
  return "6121200001"
}

function parseTotalFromOCR(text: string): number {
  // Look for total patterns like "Total: $1,234.56" or "TOTAL 1234.56"
  const patterns = [
    /total\s*[:$]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /importe\s*[:$]?\s*\$?\s*([\d,]+\.?\d*)/i,
    /\$\s*([\d,]+\.\d{2})\s*$/m,
  ]
  for (const p of patterns) {
    const m = text.match(p)
    if (m) {
      const val = parseFloat(m[1].replace(/,/g, ""))
      if (val > 0 && val < 1000000) return val
    }
  }
  // Last number that looks like a price
  const nums = [...text.matchAll(/\$?\s*([\d,]+\.\d{2})/g)]
    .map(m => parseFloat(m[1].replace(/,/g,"")))
    .filter(v => v > 0 && v < 1000000)
  return nums.length ? Math.max(...nums) : 0
}

let tesseractLoaded = false

async function loadTesseract(): Promise<void> {
  if (tesseractLoaded || (window as any).Tesseract) { tesseractLoaded = true; return }
  await new Promise<void>((resolve, reject) => {
    const s = document.createElement("script")
    s.src = "https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js"
    s.onload = () => { tesseractLoaded = true; resolve() }
    s.onerror = reject
    document.head.appendChild(s)
  })
}

async function runOCR(file: File): Promise<{ text: string; total: number; cuenta: string }> {
  await loadTesseract()
  const Tesseract = (window as any).Tesseract
  if (!Tesseract) throw new Error("Tesseract not available")

  const url = URL.createObjectURL(file)
  const { data: { text } } = await Tesseract.recognize(url, "spa", { logger: () => {} })
  URL.revokeObjectURL(url)

  const total  = parseTotalFromOCR(text)
  const cuenta = guessCuentaFromText(text)
  return { text, total, cuenta }
}

interface Props {
  solicitudId?: string
  catalogoGastos: Array<{ cuenta: string; nombre: string }>
  onAdd: (items: CfdItem[]) => void
}

export function CompUploader({ solicitudId, onAdd }: Props) {
  const [uploading, setUploading] = useState(false)
  const [ocrProgress, setOcrProgress] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  const checkDuplicate = async (uuid: string): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id")
      .eq("uuid", uuid)
      .limit(1)
    return data && data.length > 0 ? "Ya comprobado" : null
  }

  const processFiles = useCallback(async (files: FileList | null) => {
    if (!files || !files.length) return
    setUploading(true)
    const sb = createClient()
    const { data: { user } } = await sb.auth.getUser()
    if (!user) { setUploading(false); return }

    const newItems: CfdItem[] = []

    for (const file of Array.from(files)) {
      const isXml = file.name.toLowerCase().endsWith(".xml")
      const isPdf = file.name.toLowerCase().endsWith(".pdf")
      const isImg = file.type.startsWith("image/")
      if (!isXml && !isPdf && !isImg) continue

      // Upload file to Storage
      let archivoUrl: string | null = null
      const ext = file.name.split(".").pop()
      const path = `${solicitudId || "tmp"}/${Date.now()}.${ext}`
      const { data: up } = await sb.storage.from("comprobantes").upload(path, file, { upsert: true })
      if (up) {
        const { data: { publicUrl } } = sb.storage.from("comprobantes").getPublicUrl(path)
        archivoUrl = publicUrl
      }

      if (isXml) {
        const text = await file.text()
        const parsed = parseCFDIXml(text)
        if (!parsed) continue
        parsed.archivoUrl = archivoUrl
        const motivoDup = await checkDuplicate(parsed.uuid)
        newItems.push({ ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined })

      } else if (isImg) {
        // Run OCR on images (tickets, receipts)
        setOcrProgress(`Leyendo ticket: ${file.name}…`)
        try {
          const { text, total, cuenta } = await runOCR(file)
          const iva = total > 0 ? Math.round(total * 16 / 116 * 100) / 100 : 0
          const subtotal = Math.round((total - iva) * 100) / 100
          newItems.push({
            uuid: `OCR-${Date.now()}`,
            emisor: file.name.replace(/\.[^.]+$/, ""),
            concepto: text.slice(0, 60).replace(/\n/g, " ").trim() || "Ticket sin factura",
            subtotal, iva, total,
            cuenta, confianza: total > 0 ? 0.7 : 0.3,
            archivoUrl, duplicado: false,
            ocrLeido: true,
          } as unknown as CfdItem)
          setOcrProgress(null)
        } catch (e) {
          setOcrProgress(null)
          // Fallback: add without OCR
          newItems.push({
            uuid: `IMG-${Date.now()}`,
            emisor: file.name, concepto: "Imagen sin factura",
            subtotal: 0, iva: 0, total: 0,
            cuenta: "6121200001", confianza: 0.3,
            archivoUrl, duplicado: false,
          } as unknown as CfdItem)
        }

      } else {
        // PDF without OCR
        newItems.push({
          uuid: `PDF-${Date.now()}`,
          emisor: file.name, concepto: "PDF adjunto",
          subtotal: 0, iva: 0, total: 0,
          cuenta: "6121200001", confianza: 0.3,
          archivoUrl, duplicado: false,
        } as unknown as CfdItem)
      }
    }

    if (newItems.length > 0) onAdd(newItems)
    if (fileRef.current) fileRef.current.value = ""
    setUploading(false)
    setOcrProgress(null)
  }, [solicitudId, onAdd])

  return (
    <div>
      <div className="card"
        style={{ border:"2px dashed var(--border)", textAlign:"center", padding:"24px 20px",
          cursor: uploading ? "default" : "pointer" }}
        onClick={() => !uploading && fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor="var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor="var(--border)"; processFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize:24, marginBottom:6 }}>{uploading ? "⏳" : "📂"}</div>
        <div style={{ fontWeight:600, marginBottom:3, fontSize:13 }}>
          {ocrProgress ? ocrProgress : uploading ? "Procesando…" : "Arrastra o clic para subir"}
        </div>
        <div style={{ fontSize:11.5, color:"var(--text-3)" }}>
          XML (CFDI), PDF o imagen — tickets con OCR automático
        </div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => processFiles(e.target.files)} />
      </div>
    </div>
  )
}

FILEEOF

git add .
git commit -m "fix: load Tesseract.js from CDN to avoid Turbopack bundle issue"
git push
echo "✓ Done"