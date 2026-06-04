// Send push notification via Cloudflare Worker

const WORKER_URL = process.env.NEXT_PUBLIC_WORKER_URL || "https://viaticos-admin.rhernandez-e52.workers.dev"
const WORKER_SECRET = "viaticos-zapata-push-2026"
const APP_URL = "https://viaticos-app-bice.vercel.app"

export async function notifyUsers(
  userIds: string[],
  title: string,
  body: string,
  path = "/dashboard"
) {
  if (!userIds.length) return
  try {
    await fetch(`${WORKER_URL}/notify`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${WORKER_SECRET}`,
      },
      body: JSON.stringify({
        userIds,
        title,
        body,
        url: APP_URL + path,
      }),
    })
  } catch (err) {
    console.warn("[Notify] Failed to send push:", err)
  }
}

