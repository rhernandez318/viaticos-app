// Global app data store - replaces window.USUARIOS, window.SOLICITUDES, etc.
// Uses React Context + zustand-style approach with simple module-level state

import type { Usuario, Centro, CuentaContable, Solicitud } from "@/types"

interface CatalogosState {
  usuarios: Usuario[]
  centros: Centro[]
  catalogoGastos: CuentaContable[]
  solicitudes: Solicitud[]
  dbLoaded: boolean
}

// Module-level state (mirrors the current window.USUARIOS pattern)
export const catalogos: CatalogosState = {
  usuarios: [],
  centros: [],
  catalogoGastos: [],
  solicitudes: [],
  dbLoaded: false,
}

// Helper finders
export const findUser = (id?: string | null): Usuario | undefined =>
  catalogos.usuarios.find((u) => u.id === id)

export const findCentro = (id?: string | null): Centro | undefined =>
  catalogos.centros.find((c) => c.id === id)

export const findCuenta = (cuenta?: string | null): CuentaContable | undefined =>
  catalogos.catalogoGastos.find((c) => c.cuenta === cuenta)

export const findUserByEmail = (email: string): Usuario | undefined =>
  catalogos.usuarios.find((u) => u.correo?.toLowerCase() === email.toLowerCase())

