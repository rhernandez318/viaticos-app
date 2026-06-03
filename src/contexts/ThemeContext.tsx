"use client"
import { createContext, useContext, useState, useEffect } from "react"

type Mode = "dark" | "light"
type Accent = "lime" | "blue" | "orange" | "purple"

const ACCENTS: Record<Accent, { name:string; color:string; soft:string }> = {
  lime:   { name:"Verde lima", color:"#c5f24d", soft:"rgba(197,242,77,.12)" },
  blue:   { name:"Azul",       color:"#60a5fa", soft:"rgba(96,165,250,.12)" },
  orange: { name:"Naranja",    color:"#f97316", soft:"rgba(249,115,22,.12)" },
  purple: { name:"Morado",     color:"#c084fc", soft:"rgba(192,132,252,.12)" },
}

interface ThemeCtx {
  mode: Mode; accent: Accent
  setMode: (m: Mode) => void
  setAccent: (a: Accent) => void
  accents: typeof ACCENTS
}

const ThemeContext = createContext<ThemeCtx|null>(null)

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [mode, setModeState] = useState<Mode>("dark")
  const [accent, setAccentState] = useState<Accent>("lime")

  // Load from localStorage
  useEffect(() => {
    const m = localStorage.getItem("vz-mode") as Mode
    const a = localStorage.getItem("vz-accent") as Accent
    if (m === "light" || m === "dark") setModeState(m)
    if (a && ACCENTS[a]) setAccentState(a)
  }, [])

  // Apply CSS variables
  useEffect(() => {
    const root = document.documentElement
    const ac = ACCENTS[accent]
    root.style.setProperty("--accent", ac.color)
    root.style.setProperty("--accent-soft", ac.soft)
    if (mode === "light") {
      root.classList.add("light")
    } else {
      root.classList.remove("light")
    }
  }, [mode, accent])

  const setMode = (m: Mode) => { setModeState(m); localStorage.setItem("vz-mode", m) }
  const setAccent = (a: Accent) => { setAccentState(a); localStorage.setItem("vz-accent", a) }

  return (
    <ThemeContext.Provider value={{ mode, accent, setMode, setAccent, accents:ACCENTS }}>
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => useContext(ThemeContext)!

