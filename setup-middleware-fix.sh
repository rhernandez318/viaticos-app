#!/bin/bash
set -e

cat > 'src/middleware.ts' << 'FILEEOF'
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
    "/((?!_next/static|_next/image|favicon\\.ico|sw\\.js|manifest\\.json|icon.*\\.png|logo\\.png|\\.well-known|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
}

FILEEOF

git add .
git commit -m "fix: exclude sw.js and PWA files from auth middleware"
git push
echo "✓ Done! Verifica en 2 min:"
echo "  https://viaticos-app-bice.vercel.app/sw.js"
echo "  Debe mostrar codigo JS, no redirigir al login"