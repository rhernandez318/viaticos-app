importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js")
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js")

firebase.initializeApp({
  apiKey:            "AIzaSyD5WCpMWnQkwLJplAtbOXrjU2_5gwSRI2w",
  projectId:         "viaticos-zapata",
  messagingSenderId: "318139943193",
  appId:             "1:318139943193:web:3fade17ff5c1e89a805d88",
})

const messaging = firebase.messaging()

messaging.onBackgroundMessage(payload => {
  const { t: title, b: body, url } = payload.data || {}
  self.registration.showNotification(title || "Viáticos GZ", {
    body: body || "",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    data: { url: url || "/dashboard" },
    vibrate: [200, 100, 200],
  })
})

self.addEventListener("notificationclick", e => {
  e.notification.close()
  const url = e.notification.data?.url || "/dashboard"
  e.waitUntil(clients.openWindow(url))
})

