import { useEffect, useRef, useState, type ReactNode } from 'react'

interface Props {
  activos: number
  onLimpiar: () => void
  children: ReactNode
}

export default function PanelFiltros({ activos, onLimpiar, children }: Props) {
  const [abierto, setAbierto] = useState(false)
  const contenedor = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function clicFuera(evento: MouseEvent) {
      if (contenedor.current && !contenedor.current.contains(evento.target as Node)) {
        setAbierto(false)
      }
    }
    document.addEventListener('mousedown', clicFuera)
    return () => document.removeEventListener('mousedown', clicFuera)
  }, [])

  return (
    <div className="filtros-wrapper" ref={contenedor}>
      <button
        type="button"
        className={abierto || activos > 0 ? 'btn-filtros activo' : 'btn-filtros'}
        onClick={() => setAbierto(!abierto)}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
        </svg>
        Filtros
        {activos > 0 && <span className="contador">{activos}</span>}
      </button>

      {abierto && (
        <div className="filtros-panel">
          {children}
          <div className="filtros-pie">
            <button type="button" className="btn" onClick={onLimpiar} disabled={activos === 0}>
              Limpiar filtros
            </button>
          </div>
        </div>
      )}
    </div>
  )
}