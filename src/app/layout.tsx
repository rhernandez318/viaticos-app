import type { Metadata, Viewport } from "next"
import Script from "next/script"
import { ThemeProvider } from "@/contexts/ThemeContext"
import { InstallBanner } from "@/components/ui/InstallBanner"
import "./globals.css"

export const metadata: Metadata = {
  title: "Viáticos Grupo Zapata",
  description: "Sistema de gestión de viáticos y gastos corporativos",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Viáticos GZ",
  },
  icons: { icon: "/icon-192.png", apple: "/icon-512.png" },
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
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Viáticos GZ" />
        <link rel="apple-touch-icon" href="/icon-512.png" />
      </head>
      <body>
        <ThemeProvider>
          <InstallBanner />
          {children}
        </ThemeProvider>
        {/* Service Worker registration — must use next/script, NOT dangerouslySetInnerHTML */}
        <Script id="sw-register" strategy="afterInteractive">
          {`
            if ('serviceWorker' in navigator) {
              window.addEventListener('load', function() {
                navigator.serviceWorker.register('/sw.js', { scope: '/' })
                  .then(function(reg) {
                    console.log('[PWA] Service Worker registered, scope:', reg.scope);
                  })
                  .catch(function(err) {
                    console.warn('[PWA] Service Worker failed:', err);
                  });
              });
            }
          `}
        </Script>
      </body>
    </html>
  )
}

