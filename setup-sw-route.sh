#!/bin/bash
set -e

mkdir -p $(dirname 'src/app/sw.js/route.ts')
cat > 'src/app/sw.js/route.ts' << 'FILEEOF'
import { NextResponse } from "next/server"

const SW_CONTENT = `
const CACHE = "viaticos-gz-v3"
const PRECACHE = ["/", "/login", "/icon-192.png", "/manifest.json"]

self.addEventListener("install", e => {
  console.log("[SW] Installing v3")
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", e => {
  console.log("[SW] Activated v3")
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  const url = new URL(e.request.url)
  if (url.pathname.startsWith("/api/") || url.hostname.includes("supabase")) return
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()))
        return res
      })
      .catch(() => caches.match(e.request))
  )
})
`

export async function GET() {
  return new NextResponse(SW_CONTENT, {
    headers: {
      "Content-Type": "application/javascript; charset=utf-8",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Service-Worker-Allowed": "/",
    },
  })
}

FILEEOF

mkdir -p $(dirname 'src/components/ui/PWARegister.tsx')
cat > 'src/components/ui/PWARegister.tsx' << 'FILEEOF'
"use client"
import { useEffect } from "react"

export function PWARegister() {
  useEffect(() => {
    console.log("[PWA] PWARegister mounted, checking SW support...")

    if (!("serviceWorker" in navigator)) {
      console.log("[PWA] Service workers NOT supported in this browser")
      return
    }

    console.log("[PWA] Registering service worker at /sw.js")

    navigator.serviceWorker
      .register("/sw.js", { scope: "/", updateViaCache: "none" })
      .then(reg => {
        console.log("[PWA] ✓ Service Worker registered! Scope:", reg.scope)
        console.log("[PWA] SW state:", reg.active?.state ?? reg.installing?.state ?? "pending")
      })
      .catch(err => {
        console.error("[PWA] ✗ SW registration FAILED:", err.message, err)
      })
  }, [])

  return null
}

FILEEOF

mkdir -p $(dirname 'src/app/layout.tsx')
cat > 'src/app/layout.tsx' << 'FILEEOF'
import type { Metadata, Viewport } from "next"
import { ThemeProvider } from "@/contexts/ThemeContext"
import { InstallBanner } from "@/components/ui/InstallBanner"
import { PWARegister } from "@/components/ui/PWARegister"
import "./globals.css"

export const metadata: Metadata = {
  title: "Viáticos Grupo Zapata",
  description: "Sistema de gestión de viáticos y gastos corporativos",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Viáticos GZ",
  },
  icons: { icon: "/icon-192.png", apple: "/icon-512.png" },
}

export const viewport: Viewport = {
  themeColor: "#0d0d0d",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" suppressHydrationWarning>
      <head>
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Viáticos GZ" />
        <link rel="apple-touch-icon" href="/icon-512.png" />
      </head>
      <body>
        <ThemeProvider>
          <PWARegister />
          <InstallBanner />
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}

FILEEOF

git add .
git commit -m "fix: SW served via Next.js API route - guaranteed registration"
git push
echo ""
echo "✓ Deployed! After Vercel finishes (~2 min):"
echo "  1. Verifica: https://viaticos-app-bice.vercel.app/sw.js"
echo "     Debe mostrar codigo JavaScript del service worker"
echo "  2. Abre el sitio en Chrome Android"
echo "  3. En Logcat filtra por: chromium"
echo "     Debe aparecer: [PWA] Service Worker registered"