import { useEffect, useState } from 'react'

export interface Paginado<T> {
  /** Elementos de la página actual. */
  visibles: T[]
  pagina: number
  totalPaginas: number
  total: number
  porPagina: number
  desde: number
  hasta: number
  irA: (pagina: number) => void
}

/**
 * Divide una lista en páginas en pantalla.
 * `clave` identifica la búsqueda/filtros/pestaña actuales: cuando cambia, vuelve a la página 1.
 */
export function usePaginacion<T>(items: T[], porPagina: number, clave: string): Paginado<T> {
  const [pagina, setPagina] = useState(1)

  useEffect(() => {
    setPagina(1)
  }, [clave])

  const total = items.length
  const totalPaginas = Math.max(1, Math.ceil(total / porPagina))
  // Si la lista se acorta (p. ej. al aprobar el último de la página), no queda una página vacía.
  const actual = Math.min(pagina, totalPaginas)
  const inicio = (actual - 1) * porPagina

  return {
    visibles: items.slice(inicio, inicio + porPagina),
    pagina: actual,
    totalPaginas,
    total,
    porPagina,
    desde: total === 0 ? 0 : inicio + 1,
    hasta: Math.min(inicio + porPagina, total),
    irA: (p: number) => setPagina(Math.min(Math.max(1, p), totalPaginas)),
  }
}