#!/bin/bash
set -e

mkdir -p $(dirname 'public/.well-known/assetlinks.json')
cat > 'public/.well-known/assetlinks.json' << 'FILEEOF'
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "mx.zapata.viaticos",
    "sha256_cert_fingerprints": [
      "60:2C:6F:41:CD:00:2D:84:08:E6:C8:CC:32:37:51:1A:79:D5:40:7F:38:E4:5B:8E:FC:8A:D9:26:3D:C9:6F:EE"
    ]
  }
}]

FILEEOF

mkdir -p $(dirname 'next.config.ts')
cat > 'next.config.ts' << 'FILEEOF'
import type { NextConfig } from "next"

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/.well-known/assetlinks.json",
        headers: [
          { key: "Content-Type", value: "application/json" },
          { key: "Cache-Control", value: "public, max-age=3600" },
        ],
      },
    ]
  },
}

export default nextConfig

FILEEOF

git add .
git commit -m "feat: assetlinks.json for TWA verification"
git push
echo "✓ Done! Vercel will deploy in ~2 min"
echo "Verify at: https://viaticos-app-bice.vercel.app/.well-known/assetlinks.json"