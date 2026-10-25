import { useEffect, useRef, useState } from 'react'

export interface OpcionMenu {
  texto: string
  onClick: () => void
  peligro?: boolean
  deshabilitada?: boolean
}

interface Props {
  opciones: OpcionMenu[]
  etiqueta: string
}

interface Posicion {
  top?: number
  bottom?: number
  right: number
}

export default function MenuAcciones({ opciones, etiqueta }: Props) {
  const [posicion, setPosicion] = useState<Posicion | null>(null)
  const boton = useRef<HTMLButtonElement>(null)
  const menu = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!posicion) return

    function clicFuera(evento: MouseEvent) {
      const objetivo = evento.target as Node
      if (menu.current?.contains(objetivo) || boton.current?.contains(objetivo)) return
      setPosicion(null)
    }
    function cerrar() {
      setPosicion(null)
    }

    document.addEventListener('mousedown', clicFuera)
    window.addEventListener('scroll', cerrar, true)
    window.addEventListener('resize', cerrar)
    return () => {
      document.removeEventListener('mousedown', clicFuera)
      window.removeEventListener('scroll', cerrar, true)
      window.removeEventListener('resize', cerrar)
    }
  }, [posicion])

  function alternar() {
    if (posicion) {
      setPosicion(null)
      return
    }
    const rect = boton.current?.getBoundingClientRect()
    if (!rect) return

    const alturaEstimada = opciones.length * 38 + 14
    const derecha = window.innerWidth - rect.right

    if (rect.bottom + alturaEstimada + 8 > window.innerHeight) {
      setPosicion({ bottom: window.innerHeight - rect.top + 4, right: derecha })
    } else {
      setPosicion({ top: rect.bottom + 4, right: derecha })
    }
  }

  return (
    <>
      <button
        ref={boton}
        type="button"
        className={posicion ? 'btn-menu abierto' : 'btn-menu'}
        onClick={alternar}
        aria-label={etiqueta}
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
          <circle cx="12" cy="5" r="1.8" />
          <circle cx="12" cy="12" r="1.8" />
          <circle cx="12" cy="19" r="1.8" />
        </svg>
      </button>

      {posicion && (
        <div className="menu-acciones" ref={menu} style={posicion}>
          {opciones.map((opcion) => (
            <button
              key={opcion.texto}
              type="button"
              className={opcion.peligro ? 'menu-item peligro' : 'menu-item'}
              disabled={opcion.deshabilitada}
              onClick={() => {
                setPosicion(null)
                opcion.onClick()
              }}
            >
              {opcion.texto}
            </button>
          ))}
        </div>
      )}
    </>
  )
}