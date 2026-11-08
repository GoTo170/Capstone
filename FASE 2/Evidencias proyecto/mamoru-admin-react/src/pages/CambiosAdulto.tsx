import { useEffect, useState, type CSSProperties } from 'react'
import { useOutletContext } from 'react-router-dom'
import BarraBusqueda from '../components/BarraBusqueda'
import Modal from '../components/Modal'
import Paginacion from '../components/Paginacion'
import { apiFetch } from '../lib/api'
import { useVersionDatos } from '../lib/datosVivos'
import { contiene } from '../lib/busqueda'
import { formatearFechaCompleta } from '../lib/formato'
import { usePaginacion } from '../lib/usePaginacion'
import type { CambioAdulto, ContextoLayout } from '../lib/tipos'

type Pestana = 'pendiente' | 'aprobada' | 'rechazada'

interface Accion {
  cambio: CambioAdulto
  aprobar: boolean
}

const CHIPS: { valor: Pestana; texto: string }[] = [
  { valor: 'pendiente', texto: 'Pendientes' },
  { valor: 'aprobada', texto: 'Aprobados' },
  { valor: 'rechazada', texto: 'Rechazados' },
]

const TIPOS: Record<string, string> = {
  salud: 'Información de salud',
  alergias: 'Alergias e intolerancias',
  contactos: 'Contactos de emergencia',
}

const ESTADOS: Record<string, { clase: string; texto: string }> = {
  pendiente: { clase: 'pending', texto: 'Pendiente' },
  aprobada: { clase: 'ok', texto: 'Aprobado' },
  rechazada: { clase: 'crit', texto: 'Rechazado' },
}

const CAMPOS_TEXTO: Record<string, { clave: string; etiqueta: string }[]> = {
  salud: [{ clave: 'enfermedades', etiqueta: 'Condiciones médicas' }],
  alergias: [
    { clave: 'alergia_medicamentos', etiqueta: 'Alergia a medicamentos' },
    { clave: 'alergia_alimentos', etiqueta: 'Alergia a alimentos' },
    { clave: 'intolerancia_alimentaria', etiqueta: 'Intolerancias' },
  ],
}

const estiloTextarea: CSSProperties = {
  width: '100%',
  minHeight: 80,
  padding: '8px 10px',
  border: '1px solid var(--border)',
  borderRadius: 8,
  background: 'var(--surface)',
  color: 'var(--ink)',
  fontFamily: 'inherit',
  fontSize: 13,
  resize: 'vertical',
  boxSizing: 'border-box',
}

const estiloColumna: CSSProperties = {
  flex: 1,
  minWidth: 0,
  padding: '8px 10px',
  border: '1px solid var(--border)',
  borderRadius: 8,
  background: 'var(--surface)',
}

interface ContactoCambio {
  nombre: string
  telefono: string
  parentesco: string | null
}

function partes(texto: unknown): string[] {
  if (typeof texto !== 'string') return []
  return texto
    .split('\n')
    .map((p) => p.trim())
    .filter(Boolean)
}

function contactosDe(datos: Record<string, unknown>): ContactoCambio[] {
  const lista = datos.contactos
  return Array.isArray(lista) ? (lista as ContactoCambio[]) : []
}

// Una columna (antes o después) de un cambio de texto: lo que cambió se resalta.
function ColumnaTexto({ titulo, datos, otros, tipo }: { titulo: string; datos: Record<string, unknown>; otros: Record<string, unknown>; tipo: string }) {
  return (
    <div style={estiloColumna}>
      <div className="cell-sub" style={{ fontWeight: 600, marginBottom: 6 }}>
        {titulo}
      </div>
      {CAMPOS_TEXTO[tipo].map(({ clave, etiqueta }) => {
        const mias = partes(datos[clave])
        const ajenas = new Set(partes(otros[clave]))
        return (
          <div key={clave} style={{ marginBottom: 8 }}>
            <div className="cell-sub">{etiqueta}</div>
            {mias.length === 0 ? (
              <div className="cell-sub" style={{ fontStyle: 'italic' }}>
                Sin registros
              </div>
            ) : (
              <div className="cg-tags">
                {mias.map((p) => (
                  <span key={p} className="tag" style={ajenas.has(p) ? undefined : { fontWeight: 700, outline: '1px solid var(--accent, #7c5cd6)' }}>
                    {p}
                  </span>
                ))}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}

function ColumnaContactos({ titulo, datos }: { titulo: string; datos: Record<string, unknown> }) {
  const contactos = contactosDe(datos)
  return (
    <div style={estiloColumna}>
      <div className="cell-sub" style={{ fontWeight: 600, marginBottom: 6 }}>
        {titulo}
      </div>
      {contactos.length === 0 ? (
        <div className="cell-sub" style={{ fontStyle: 'italic' }}>
          Sin contactos
        </div>
      ) : (
        contactos.map((c, i) => (
          <div key={i} style={{ marginBottom: 6 }}>
            <div>
              <b>{c.nombre}</b>
            </div>
            <div className="cell-sub">
              {c.parentesco ? `${c.parentesco} · ` : ''}
              {c.telefono}
            </div>
          </div>
        ))
      )}
    </div>
  )
}

export default function CambiosAdulto() {
  const { refrescarPendientes } = useOutletContext<ContextoLayout>()
  const version = useVersionDatos()
  const [cambios, setCambios] = useState<CambioAdulto[] | null>(null)
  const [error, setError] = useState('')
  const [pestana, setPestana] = useState<Pestana>('pendiente')
  const [busqueda, setBusqueda] = useState('')
  const [accion, setAccion] = useState<Accion | null>(null)
  const [motivo, setMotivo] = useState('')
  const [procesando, setProcesando] = useState(false)

  useEffect(() => {
    let activo = true
    apiFetch<CambioAdulto[]>('/admin/cambios-adulto-mayor')
      .then((lista) => {
        if (activo) setCambios(lista)
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar las solicitudes')
      })
    return () => {
      activo = false
    }
  }, [version])

  function abrir(cambio: CambioAdulto, aprobar: boolean) {
    setMotivo('')
    setAccion({ cambio, aprobar })
  }

  async function resolver() {
    if (!accion) return
    setProcesando(true)
    setError('')
    try {
      const actualizado = await apiFetch<CambioAdulto>(`/admin/cambios-adulto-mayor/${accion.cambio.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ aprobar: accion.aprobar, motivo: motivo.trim() || null }),
      })
      setCambios((prev) => (prev ? prev.map((c) => (c.id === actualizado.id ? actualizado : c)) : prev))
      refrescarPendientes()
      setAccion(null)
      setMotivo('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo resolver la solicitud')
    } finally {
      setProcesando(false)
    }
  }

  const lista = cambios ?? []
  const coincide = (c: CambioAdulto, estado: Pestana) =>
    c.estado === estado && (!busqueda || contiene(`${c.adulto_mayor_nombre} ${c.solicitante_nombre} ${TIPOS[c.tipo] ?? ''}`, busqueda))
  const visibles = lista
    .filter((c) => coincide(c, pestana))
    .sort((a, b) => {
      const fa = new Date(a.fecha_solicitud ?? 0).getTime()
      const fb = new Date(b.fecha_solicitud ?? 0).getTime()
      // Las pendientes más antiguas primero; el resto, las más recientes primero.
      return pestana === 'pendiente' ? fa - fb : fb - fa
    })

  const pag = usePaginacion(visibles, 8, `${pestana}|${busqueda}`)

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Cambios de datos</div>
        <h1 className="page-title">Cambios de datos del adulto mayor</h1>
        <p className="page-desc">
          Cambios que proponen las familias en salud, alergias y contactos de emergencia. El perfil conserva los datos
          anteriores hasta que apruebes el cambio.
        </p>
      </div>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      <div className="toolbar">
        <div className="filters">
          {CHIPS.map((chip) => (
            <button
              key={chip.valor}
              className={pestana === chip.valor ? 'filter-chip active' : 'filter-chip'}
              onClick={() => setPestana(chip.valor)}
            >
              {cambios ? `${chip.texto} (${lista.filter((c) => coincide(c, chip.valor)).length})` : chip.texto}
            </button>
          ))}
        </div>
        <div className="toolbar-tools">
          <BarraBusqueda valor={busqueda} onCambio={setBusqueda} placeholder="Buscar por adulto mayor, familiar o tipo…" />
        </div>
      </div>

      {!cambios ? (
        <p>{error ? '' : 'Cargando solicitudes…'}</p>
      ) : visibles.length === 0 ? (
        <p>{busqueda ? 'Ninguna solicitud coincide con la búsqueda.' : 'No hay solicitudes en esta categoría.'}</p>
      ) : (
        <div className="card-grid">
          {pag.visibles.map((c) => {
            const estado = ESTADOS[c.estado] ?? { clase: 'neutral', texto: c.estado }
            return (
              <div className="cg-card" key={c.id} style={{ gridColumn: '1 / -1' }}>
                <div className="cg-top">
                  <div>
                    <div className="cg-name">{TIPOS[c.tipo] ?? c.tipo}</div>
                    <div className="cg-loc">
                      Adulto mayor: <b>{c.adulto_mayor_nombre}</b> · Propuesto por {c.solicitante_nombre}
                    </div>
                    <div className="cell-sub">Solicitado: {formatearFechaCompleta(c.fecha_solicitud ?? '')}</div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', margin: '10px 0' }}>
                  {c.tipo === 'contactos' ? (
                    <>
                      <ColumnaContactos titulo="Actual" datos={c.anteriores} />
                      <ColumnaContactos titulo="Propuesto" datos={c.nuevos} />
                    </>
                  ) : (
                    <>
                      <ColumnaTexto titulo="Actual" datos={c.anteriores} otros={c.nuevos} tipo={c.tipo} />
                      <ColumnaTexto titulo="Propuesto" datos={c.nuevos} otros={c.anteriores} tipo={c.tipo} />
                    </>
                  )}
                </div>

                <span className={`pill ${estado.clase}`} style={{ alignSelf: 'flex-start' }}>
                  {estado.texto}
                </span>
                {c.fecha_resolucion && (
                  <div className="cell-sub">Resuelto: {formatearFechaCompleta(c.fecha_resolucion)}</div>
                )}
                {c.estado === 'rechazada' && c.motivo_rechazo && (
                  <div className="cell-sub">Motivo: {c.motivo_rechazo}</div>
                )}

                {c.estado === 'pendiente' && (
                  <div className="cg-actions">
                    <button className="btn primary" onClick={() => abrir(c, true)}>
                      Aprobar cambio
                    </button>
                    <button className="btn danger" onClick={() => abrir(c, false)}>
                      Rechazar
                    </button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {cambios && visibles.length > 0 && <Paginacion pag={pag} />}

      {accion && (
        <Modal
          titulo={accion.aprobar ? 'Aprobar cambio' : 'Rechazar cambio'}
          onCerrar={() => setAccion(null)}
          pie={
            <>
              <button className="btn" onClick={() => setAccion(null)} disabled={procesando}>
                Cancelar
              </button>
              <button className={accion.aprobar ? 'btn primary' : 'btn danger'} onClick={resolver} disabled={procesando}>
                {procesando ? 'Guardando…' : accion.aprobar ? 'Aprobar' : 'Rechazar'}
              </button>
            </>
          }
        >
          {accion.aprobar ? (
            <p>
              ¿Aprobar el cambio de <b>{(TIPOS[accion.cambio.tipo] ?? '').toLowerCase()}</b> de{' '}
              <b>{accion.cambio.adulto_mayor_nombre}</b>? El perfil se actualizará de inmediato y la familia recibirá un aviso.
            </p>
          ) : (
            <>
              <p style={{ marginBottom: 12 }}>
                ¿Rechazar el cambio de <b>{(TIPOS[accion.cambio.tipo] ?? '').toLowerCase()}</b> de{' '}
                <b>{accion.cambio.adulto_mayor_nombre}</b>? El perfil no se modifica. La familia recibirá un aviso con el motivo, si lo escribes.
              </p>
              <textarea
                style={estiloTextarea}
                maxLength={300}
                placeholder="Motivo (opcional)"
                value={motivo}
                onChange={(e) => setMotivo(e.target.value)}
              />
            </>
          )}
        </Modal>
      )}
    </>
  )
}