const CACHE = "viaticos-gz-v5"
const PRECACHE = ["/", "/login", "/icon-192.png", "/manifest.json"]

self.addEventListener("install", e => {
  console.log("[SW] Installing v4")
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", e => {
  console.log("[SW] Activated v4")
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  const url = new URL(e.request.url)
  // Skip API calls, Supabase, Firebase, external CDN
  if (
    url.pathname.startsWith("/api/") ||
    url.pathname.includes("sw.js") ||
    url.pathname.includes("firebase") ||
    url.hostname.includes("supabase") ||
    url.hostname.includes("googleapis") ||
    url.hostname.includes("gstatic") ||
    url.hostname !== self.location.hostname
  ) return

  e.respondWith(
    fetch(e.request)
      .then(res => {
        // Only cache successful same-origin responses
        if (res.ok && res.status < 400 && res.type === "basic") {
          const clone = res.clone() // clone BEFORE returning
          caches.open(CACHE).then(c => c.put(e.request, clone)).catch(() => {})
        }
        return res
      })
      .catch(() => caches.match(e.request).then(r => r || Response.error()))
  )
})


