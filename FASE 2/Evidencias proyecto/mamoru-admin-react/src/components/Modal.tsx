import { useEffect, type ReactNode } from 'react'

interface Props {
  titulo: string
  onCerrar: () => void
  children: ReactNode
  pie?: ReactNode
  ancho?: number
}

export default function Modal({ titulo, onCerrar, children, pie, ancho }: Props) {
  useEffect(() => {
    function tecla(evento: KeyboardEvent) {
      if (evento.key === 'Escape') onCerrar()
    }
    document.addEventListener('keydown', tecla)
    return () => document.removeEventListener('keydown', tecla)
  }, [onCerrar])

  return (
    <div className="modal-fondo" onMouseDown={onCerrar}>
      <div
        className="modal"
        style={ancho ? { maxWidth: ancho } : undefined}
        role="dialog"
        aria-modal="true"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div className="modal-cabecera">{titulo}</div>
        <div className="modal-cuerpo">{children}</div>
        {pie && <div className="modal-pie">{pie}</div>}
      </div>
    </div>
  )
}