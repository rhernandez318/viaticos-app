import { NextResponse } from "next/server"

const SW_CONTENT = `
const CACHE = "viaticos-gz-v5"
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


