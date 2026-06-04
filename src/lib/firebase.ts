import { initializeApp, getApps } from "firebase/app"
import { getMessaging, getToken, onMessage, isSupported } from "firebase/messaging"
import { createClient } from "@/lib/supabase/client"

const firebaseConfig = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY

export function getFirebaseApp() {
  return getApps().length ? getApps()[0] : initializeApp(firebaseConfig)
}

// Register FCM token and save to Supabase
export async function registerPushToken(userId: string): Promise<string | null> {
  try {
    const supported = await isSupported()
    if (!supported) { console.log("[FCM] Not supported"); return null }

    const permission = await Notification.requestPermission()
    if (permission !== "granted") { console.log("[FCM] Permission denied"); return null }

    const app = getFirebaseApp()
    const messaging = getMessaging(app)

    const token = await getToken(messaging, { vapidKey: VAPID_KEY })
    if (!token) { console.log("[FCM] No token"); return null }

    console.log("[FCM] ✓ Token obtained")

    // Save token to Supabase push_subscriptions
    const sb = createClient()
    await sb.from("push_subscriptions").upsert(
      { usuario_id: userId, subscription: token, updated_at: new Date().toISOString() },
      { onConflict: "usuario_id" }
    )

    return token
  } catch (err) {
    console.error("[FCM] Error:", err)
    return null
  }
}

// Listen for foreground messages
export async function listenMessages(callback: (payload: any) => void) {
  try {
    const supported = await isSupported()
    if (!supported) return
    const app = getFirebaseApp()
    const messaging = getMessaging(app)
    onMessage(messaging, callback)
  } catch {}
}

