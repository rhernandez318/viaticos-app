import type { NextConfig } from "next"

const nextConfig: NextConfig = {
  experimental: {
    serverActions: { allowedOrigins: ["zapata.mx", "*.zapata.mx"] },
  },
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "*.supabase.co" },
    ],
  },
}

export default nextConfig
