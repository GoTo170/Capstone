interface Props {
  valor: string
  onCambio: (valor: string) => void
  placeholder: string
}

export default function BarraBusqueda({ valor, onCambio, placeholder }: Props) {
  return (
    <div className="buscador">
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="11" cy="11" r="7" />
        <path d="M20 20l-3.5-3.5" />
      </svg>
      <input type="text" value={valor} onChange={(e) => onCambio(e.target.value)} placeholder={placeholder} />
      {valor && (
        <button type="button" onClick={() => onCambio('')} aria-label="Limpiar búsqueda">
          ×
        </button>
      )}
    </div>
  )
}