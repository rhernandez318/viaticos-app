import type { Metadata, Viewport } from "next"
import { ThemeProvider } from "@/contexts/ThemeContext"
import { PWARegister } from "@/components/ui/PWARegister"
import "./globals.css"

export const metadata: Metadata = {
  title: "Sistema de Viáticos — Grupo Zapata",
  description: "Sistema de gestión de viáticos y gastos",
  manifest: "/manifest.json",
  appleWebApp: { capable: true, statusBarStyle: "black-translucent", title: "Viáticos GZ" },
}

export const viewport: Viewport = {
  themeColor: "#0d0d0d",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" suppressHydrationWarning>
      <head>
        <link rel="apple-touch-icon" href="/logo.png"/>
      </head>
      <body>
        <ThemeProvider><PWARegister/>{children}</ThemeProvider>
      </body>
    </html>
  )
}

