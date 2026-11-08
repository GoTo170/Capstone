import { createContext, useContext } from 'react'

// Número que sube cada vez que el panel detecta algo nuevo (un aviso en la campana o un cambio en los
// contadores del menú). Las páginas lo usan como dependencia para volver a pedir sus datos solas.
export const VersionDatosContext = createContext(0)

export function useVersionDatos(): number {
  return useContext(VersionDatosContext)
}