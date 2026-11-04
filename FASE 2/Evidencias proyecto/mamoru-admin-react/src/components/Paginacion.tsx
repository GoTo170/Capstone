import type { Paginado } from '../lib/usePaginacion'

/** Barra "Anterior · Página X de Y · Siguiente". No se muestra si todo cabe en una página. */
export default function Paginacion<T>({ pag }: { pag: Paginado<T> }) {
  if (pag.totalPaginas <= 1) return null

  return (
    <div
      className="paginacion"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
        flexWrap: 'wrap',
        margin: '16px 0',
      }}
    >
      <span className="cell-sub">
        Mostrando {pag.desde}–{pag.hasta} de {pag.total}
      </span>

      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <button className="btn" onClick={() => pag.irA(1)} disabled={pag.pagina === 1} aria-label="Primera página">
          «
        </button>
        <button className="btn" onClick={() => pag.irA(pag.pagina - 1)} disabled={pag.pagina === 1}>
          Anterior
        </button>
        <span style={{ fontSize: 13, minWidth: 96, textAlign: 'center' }}>
          Página {pag.pagina} de {pag.totalPaginas}
        </span>
        <button className="btn" onClick={() => pag.irA(pag.pagina + 1)} disabled={pag.pagina === pag.totalPaginas}>
          Siguiente
        </button>
        <button
          className="btn"
          onClick={() => pag.irA(pag.totalPaginas)}
          disabled={pag.pagina === pag.totalPaginas}
          aria-label="Última página"
        >
          »
        </button>
      </div>
    </div>
  )
}