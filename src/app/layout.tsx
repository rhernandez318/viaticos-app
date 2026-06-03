import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "Viáticos Casa Zapata",
  description: "Sistema de gestión de viáticos y gastos",
  manifest: "/manifest.json",
  themeColor: "#0d0d0d",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  )
}
