"use client"

import { useRef, useCallback, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { parseCFDIXml } from "@/lib/cfdi"
import { fmtMXN } from "@/lib/format"
import type { CfdItem } from "@/types"

interface Props {
  solicitudId?: string
  catalogoGastos: Array<{ cuenta: string; nombre: string }>
  onAdd: (items: CfdItem[]) => void
  onOcrUpdate?: (id: string, updated: Partial<CfdItem>) => void
}

export function CompUploader({ solicitudId, catalogoGastos, onAdd }: Props) {
  const [uploading, setUploading] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const checkDuplicado = async (uuid: string, existingItems: CfdItem[]): Promise<string | null> => {
    if (!uuid || uuid.startsWith("SIN-")) return null
    const sb = createClient()
    const { data } = await sb.from("comprobantes_cfdi")
      .select("solicitud_id, solicitudes!inner(status)")
      .eq("uuid", uuid)
      .not("solicitudes.status", "eq", "rechazado")
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

      // Upload
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
        const motivoDup = await checkDuplicado(parsed.uuid, newItems)
        newItems.push({ ...parsed, duplicado: !!motivoDup, motivoDup: motivoDup || undefined })
      } else {
        newItems.push({
          uuid: "", emisor: file.name, concepto: file.name,
          subtotal: 0, iva: 0, total: 0, cuenta: "6121200001",
          confianza: 0.5, archivoUrl, duplicado: false,
        })
      }
    }

    if (newItems.length > 0) onAdd(newItems)
    if (fileRef.current) fileRef.current.value = ""
    setUploading(false)
  }, [solicitudId, onAdd])

  return (
    <div>
      <div
        className="card"
        style={{ border: "2px dashed var(--border)", textAlign: "center", padding: "24px 20px", cursor: "pointer" }}
        onClick={() => fileRef.current?.click()}
        onDragOver={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor = "var(--accent)" }}
        onDragLeave={e => { (e.currentTarget as HTMLElement).style.borderColor = "var(--border)" }}
        onDrop={e => { e.preventDefault(); (e.currentTarget as HTMLElement).style.borderColor = "var(--border)"; processFiles(e.dataTransfer.files) }}>
        <div style={{ fontSize: 24, marginBottom: 6 }}>📂</div>
        <div style={{ fontWeight: 600, marginBottom: 3, fontSize: 13 }}>
          {uploading ? "Procesando…" : "Arrastra o clic para subir"}
        </div>
        <div style={{ fontSize: 11.5, color: "var(--text-3)" }}>XML (CFDI), PDF o imagen de ticket</div>
        <input ref={fileRef} type="file" accept=".xml,.pdf,image/*" multiple hidden
          onChange={e => processFiles(e.target.files)} />
      </div>
    </div>
  )
}

