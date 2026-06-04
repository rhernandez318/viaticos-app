import { type NextRequest } from "next/server"
import { updateSession } from "@/lib/supabase/middleware"

export async function middleware(request: NextRequest) {
  return await updateSession(request)
}

export const config = {
  matcher: [
    /*
     * Match all paths EXCEPT:
     * - _next/static, _next/image (Next.js internals)
     * - favicon.ico, images
     * - PWA files: sw.js, manifest.json, icons
     * - .well-known (assetlinks.json)
     */
    "/((?!_next/static|_next/image|favicon\\.ico|sw\\.js|firebase-messaging-sw\\.js|manifest\\.json|icon.*\\.png|logo\\.png|\\.well-known|reset-password|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
}

