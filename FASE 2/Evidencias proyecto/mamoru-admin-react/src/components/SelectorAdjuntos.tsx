import { useRef, useState } from 'react'
import {
  EXTENSIONES_ADJUNTO,
  MAX_ADJUNTOS,
  MAX_BYTES_ADJUNTOS,
  agregarAdjuntos,
  formatearPeso,
} from '../lib/adjuntos'

interface Props {
  archivos: File[]
  onCambio: (archivos: File[]) => void
  deshabilitado?: boolean
}

export default function SelectorAdjuntos({ archivos, onCambio, deshabilitado }: Props) {
  const entrada = useRef<HTMLInputElement>(null)
  const [error, setError] = useState('')
  const total = archivos.reduce((suma, a) => suma + a.size, 0)

  function alElegir(lista: FileList | null) {
    if (!lista) return
    const resultado = agregarAdjuntos(archivos, Array.from(lista))
    setError(resultado.error)
    onCambio(resultado.archivos)
    // Se limpia para poder volver a elegir el mismo archivo si se quitó.
    if (entrada.current) entrada.current.value = ''
  }

  function quitar(indice: number) {
    setError('')
    onCambio(archivos.filter((_, i) => i !== indice))
  }

  return (
    <div className="adjuntos">
      <div className="adjuntos-cabecera">
        <button
          type="button"
          className="btn"
          disabled={deshabilitado || archivos.length >= MAX_ADJUNTOS}
          onClick={() => entrada.current?.click()}
        >
          Adjuntar archivos
        </button>
        <span className="cell-sub">
          {archivos.length > 0
            ? `${archivos.length} de ${MAX_ADJUNTOS} · ${formatearPeso(total)} de ${formatearPeso(MAX_BYTES_ADJUNTOS)}`
            : `PDF, imágenes, Word, Excel… hasta ${MAX_ADJUNTOS} archivos y ${formatearPeso(MAX_BYTES_ADJUNTOS)} en total`}
        </span>
      </div>

      <input
        ref={entrada}
        type="file"
        multiple
        hidden
        accept={EXTENSIONES_ADJUNTO.map((e) => `.${e}`).join(',')}
        onChange={(e) => alElegir(e.target.files)}
      />

      {error && <div className="adjuntos-error">{error}</div>}

      {archivos.length > 0 && (
        <ul className="adjuntos-lista">
          {archivos.map((a, i) => (
            <li key={`${a.name}-${a.size}`}>
              <span className="adjunto-nombre" title={a.name}>
                {a.name}
              </span>
              <span className="cell-sub">{formatearPeso(a.size)}</span>
              <button
                type="button"
                className="adjunto-quitar"
                onClick={() => quitar(i)}
                disabled={deshabilitado}
                aria-label={`Quitar ${a.name}`}
                title="Quitar"
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}