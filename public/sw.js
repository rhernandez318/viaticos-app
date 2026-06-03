const CACHE_NAME = "viaticos-gz-v2"
const PRECACHE = ["/", "/login", "/dashboard", "/icon-192.png", "/icon-512.png", "/manifest.json"]

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then(c => c.addAll(PRECACHE).catch(() => {}))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return
  const url = new URL(e.request.url)
  // Don't cache API or Supabase calls
  if (url.pathname.startsWith("/api/") || url.hostname.includes("supabase") || url.hostname.includes("googleapis")) return
  
  // Network first, fallback to cache
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok && res.type !== "opaque") {
          caches.open(CACHE_NAME).then(c => c.put(e.request, res.clone()))
        }
        return res
      })
      .catch(() => caches.match(e.request))
  )
})

