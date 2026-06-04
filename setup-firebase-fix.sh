#!/bin/bash
set -e

mkdir -p src/lib
cat > 'src/lib/firebase.ts' << 'FILEEOF'
// Firebase Messaging - client-side only, all imports are dynamic/lazy

const VAPID_KEY = process.env.NEXT_PUBLIC_FCM_VAPID_KEY

const firebaseConfig = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

async function getFirebaseMessaging() {
  const { initializeApp, getApps } = await import("firebase/app")
  const { getMessaging } = await import("firebase/messaging")
  const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig)
  return getMessaging(app)
}

export async function registerPushToken(userId: string): Promise<string | null> {
  if (typeof window === "undefined") return null
  try {
    const { isSupported, getToken } = await import("firebase/messaging")
    const supported = await isSupported()
    if (!supported) return null

    const permission = await Notification.requestPermission()
    if (permission !== "granted") { console.log("[FCM] Permission denied"); return null }

    const messaging = await getFirebaseMessaging()
    const token = await getToken(messaging, { vapidKey: VAPID_KEY })
    if (!token) return null

    console.log("[FCM] ✓ Token obtained")

    const { createClient } = await import("@/lib/supabase/client")
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

export async function listenMessages(callback: (payload: any) => void) {
  if (typeof window === "undefined") return
  try {
    const { isSupported, onMessage } = await import("firebase/messaging")
    const supported = await isSupported()
    if (!supported) return
    const messaging = await getFirebaseMessaging()
    onMessage(messaging, callback)
  } catch {}
}

FILEEOF

git add .
git commit -m "fix: firebase dynamic imports to fix Vercel SSR build"
git push
echo "✓ Done - Vercel should deploy successfully now"