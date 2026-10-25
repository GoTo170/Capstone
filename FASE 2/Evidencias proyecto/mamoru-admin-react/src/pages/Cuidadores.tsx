import { useEffect, useState, type CSSProperties, type KeyboardEvent } from 'react'
import { useOutletContext } from 'react-router-dom'
import BarraBusqueda from '../components/BarraBusqueda'
import Modal from '../components/Modal'
import PanelFiltros from '../components/PanelFiltros'
import { apiFetch, type Usuario } from '../lib/api'
import { contiene } from '../lib/busqueda'
import { formatearFechaCompleta, nombreCompleto } from '../lib/formato'
import type { ContextoLayout, PerfilCuidador } from '../lib/tipos'

type Pestana = 'aprobado' | 'pendiente' | 'rechazado' | 'puertas'

interface Filtros {
  areaSalud: string
  desde: string
  hasta: string
}

interface AccionPuertas {
  perfil: PerfilCuidador
  nombre: string
  aprobar: boolean
}

// El servidor ya devuelve estos dos datos del rechazo; se declaran aquí por si tipos.ts aún no los tiene.
type PerfilConMotivo = PerfilCuidador & { motivo_rechazo?: string | null; fecha_validacion?: string | null }

interface AccionRechazo {
  perfil: PerfilCuidador
  nombre: string
}

interface DetalleRechazo {
  perfil: PerfilCuidador
  usuario: Usuario | undefined
  nombre: string
}

const SIN_FILTROS: Filtros = { areaSalud: '', desde: '', hasta: '' }

// La modalidad activa se guarda como una línea más en "servicios_ofrecidos".
const MARCA_PUERTAS_ADENTRO = 'Cuidado puertas adentro'

// Cuando la app ya permita subir la foto, cámbialo a true (y también
// EXIGIR_FOTO_PERFIL en el backend): sin foto, el perfil no se muestra a las familias.
const EXIGIR_FOTO_PERFIL = false

const CHIPS: { valor: Pestana; texto: string }[] = [
  { valor: 'aprobado', texto: 'Verificados' },
  { valor: 'pendiente', texto: 'Pendientes' },
  { valor: 'rechazado', texto: 'Rechazados' },
  { valor: 'puertas', texto: 'Puertas adentro' },
]

const ESTADOS: Record<string, { clase: string; texto: string }> = {
  aprobado: { clase: 'ok', texto: 'Verificado' },
  pendiente: { clase: 'pending', texto: 'Pendiente de verificación' },
  rechazado: { clase: 'crit', texto: 'Rechazado' },
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

function lineas(texto: string | null): string[] {
  return (texto ?? '')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
}

function ofrecePuertasAdentro(perfil: PerfilCuidador): boolean {
  return lineas(perfil.servicios_ofrecidos).includes(MARCA_PUERTAS_ADENTRO)
}

// Mismo criterio que el servidor: descripción, al menos una especialidad
// (la modalidad puertas adentro no cuenta como especialidad) y teléfono.
function perfilCompleto(perfil: PerfilCuidador, usuario: Usuario | undefined): boolean {
  const especialidades = lineas(perfil.servicios_ofrecidos).filter((l) => l !== MARCA_PUERTAS_ADENTRO)
  return Boolean(
    perfil.descripcion?.trim() &&
      especialidades.length > 0 &&
      usuario?.telefono?.trim() &&
      (!EXIGIR_FOTO_PERFIL || perfil.foto_url),
  )
}

function iniciales(nombre: string): string {
  return nombre
    .split(' ')
    .filter(Boolean)
    .map((p) => p[0])
    .join('')
    .substring(0, 2)
    .toUpperCase()
}

// Foto del cuidador; si no tiene (o no se puede cargar) se muestran sus iniciales.
function AvatarCuidador({ url, nombre }: { url: string | null; nombre: string }) {
  const [falla, setFalla] = useState(false)

  if (!url || falla) return <div className="cg-avatar">{iniciales(nombre)}</div>

  return (
    <img
      className="cg-avatar"
      src={url}
      alt={`Foto de ${nombre}`}
      style={{ objectFit: 'cover' }}
      onError={() => setFalla(true)}
    />
  )
}

function cumple(
  perfil: PerfilCuidador,
  usuario: Usuario | undefined,
  busqueda: string,
  pestana: Pestana,
  f: Filtros,
): boolean {
  if (pestana === 'puertas') {
    if (!perfil.puertas_adentro_pendiente) return false
  } else if (perfil.estado_validacion !== pestana) {
    return false
  }

  if (f.areaSalud === 'si' && !perfil.es_area_salud) return false
  if (f.areaSalud === 'no' && perfil.es_area_salud) return false

  const dia = perfil.fecha_creacion.slice(0, 10)
  if (f.desde && dia < f.desde) return false
  if (f.hasta && dia > f.hasta) return false

  if (busqueda) {
    const texto = `${usuario ? nombreCompleto(usuario) : ''} ${perfil.profesion ?? ''} ${perfil.ubicacion ?? ''}`
    if (!contiene(texto, busqueda)) return false
  }
  return true
}

export default function Cuidadores() {
  const { refrescarPendientes } = useOutletContext<ContextoLayout>()
  const [cuidadores, setCuidadores] = useState<PerfilCuidador[] | null>(null)
  const [usuarios, setUsuarios] = useState<Usuario[]>([])
  const [error, setError] = useState('')
  const [pestana, setPestana] = useState<Pestana>('aprobado')
  const [busqueda, setBusqueda] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(SIN_FILTROS)
  const [procesando, setProcesando] = useState<string | null>(null)
  const [accionPuertas, setAccionPuertas] = useState<AccionPuertas | null>(null)
  const [motivo, setMotivo] = useState('')
  const [rechazo, setRechazo] = useState<AccionRechazo | null>(null)
  const [detalle, setDetalle] = useState<DetalleRechazo | null>(null)

  useEffect(() => {
    let activo = true

    Promise.all([apiFetch<PerfilCuidador[]>('/cuidadores'), apiFetch<Usuario[]>('/usuarios')])
      .then(([perfiles, lista]) => {
        if (!activo) return
        setCuidadores(perfiles)
        setUsuarios(lista)
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar cuidadores')
      })

    return () => {
      activo = false
    }
  }, [])

  function reemplazar(actualizado: PerfilCuidador) {
    setCuidadores((prev) => (prev ? prev.map((c) => (c.id === actualizado.id ? actualizado : c)) : prev))
    refrescarPendientes()
  }

  async function cambiarEstado(id: string, nuevoEstado: 'aprobado' | 'rechazado', motivoRechazo?: string) {
    setProcesando(id)
    setError('')
    try {
      const actualizado = await apiFetch<PerfilCuidador>(`/cuidadores/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ estado_validacion: nuevoEstado, motivo_rechazo: motivoRechazo ?? null }),
      })
      reemplazar(actualizado)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error al actualizar el cuidador')
    } finally {
      setProcesando(null)
    }
  }

  function abrirRechazo(perfil: PerfilCuidador, nombre: string) {
    setMotivo('')
    setRechazo({ perfil, nombre })
  }

  async function confirmarRechazo() {
    if (!rechazo) return
    const texto = motivo.trim()
    if (!texto) return
    await cambiarEstado(rechazo.perfil.id, 'rechazado', texto)
    setRechazo(null)
    setMotivo('')
  }

  function abrirDetalle(perfil: PerfilCuidador, usuario: Usuario | undefined, nombre: string) {
    setDetalle({ perfil, usuario, nombre })
  }

  function abrirPuertas(perfil: PerfilCuidador, nombre: string, aprobar: boolean) {
    setMotivo('')
    setAccionPuertas({ perfil, nombre, aprobar })
  }

  async function resolverPuertas() {
    if (!accionPuertas) return
    const { perfil, aprobar } = accionPuertas

    setProcesando(perfil.id)
    setError('')
    try {
      const actualizado = await apiFetch<PerfilCuidador>(`/cuidadores/${perfil.id}/puertas-adentro`, {
        method: 'PATCH',
        body: JSON.stringify({ aprobar, motivo: motivo.trim() || null }),
      })
      reemplazar(actualizado)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo resolver la solicitud')
    } finally {
      setProcesando(null)
      setAccionPuertas(null)
      setMotivo('')
    }
  }

  const cambiar = (parcial: Partial<Filtros>) => setFiltros((prev) => ({ ...prev, ...parcial }))
  const filtrosActivos = Object.values(filtros).filter(Boolean).length
  const hayCriterios = busqueda !== '' || filtrosActivos > 0

  const lista = cuidadores ?? []
  const usuarioPorId = new Map(usuarios.map((u) => [u.id, u]))

  const visibles = lista
    .filter((c) => cumple(c, usuarioPorId.get(c.usuario_id), busqueda, pestana, filtros))
    .sort((a, b) => {
      if (pestana === 'puertas') {
        // Las solicitudes más antiguas primero.
        const fa = new Date(a.puertas_adentro_fecha_solicitud ?? a.fecha_creacion).getTime()
        const fb = new Date(b.puertas_adentro_fecha_solicitud ?? b.fecha_creacion).getTime()
        return fa - fb
      }
      return new Date(b.fecha_creacion).getTime() - new Date(a.fecha_creacion).getTime()
    })

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Cuidadores</div>
        <h1 className="page-title">Cuidadores</h1>
        <p className="page-desc">Verificación de perfiles y moderación de la red de cuidadores del marketplace.</p>
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
              title={chip.valor === 'puertas' ? 'Solicitudes para ofrecer la modalidad puertas adentro' : undefined}
            >
              {cuidadores
                ? `${chip.texto} (${
                    lista.filter((c) => cumple(c, usuarioPorId.get(c.usuario_id), busqueda, chip.valor, filtros)).length
                  })`
                : chip.texto}
            </button>
          ))}
        </div>

        <div className="toolbar-tools">
          <BarraBusqueda valor={busqueda} onCambio={setBusqueda} placeholder="Buscar por nombre, profesión o ubicación…" />

          <PanelFiltros activos={filtrosActivos} onLimpiar={() => setFiltros(SIN_FILTROS)}>
            <div className="filtro-campo">
              <label>Área de salud</label>
              <select value={filtros.areaSalud} onChange={(e) => cambiar({ areaSalud: e.target.value })}>
                <option value="">Todos</option>
                <option value="si">Sí</option>
                <option value="no">No</option>
              </select>
            </div>

            <div className="filtro-campo">
              <label>Fecha de registro</label>
              <div className="filtro-rango">
                <div>
                  <label className="sub">Desde</label>
                  <input
                    type="date"
                    value={filtros.desde}
                    max={filtros.hasta || undefined}
                    onChange={(e) => cambiar({ desde: e.target.value })}
                  />
                </div>
                <div>
                  <label className="sub">Hasta</label>
                  <input
                    type="date"
                    value={filtros.hasta}
                    min={filtros.desde || undefined}
                    onChange={(e) => cambiar({ hasta: e.target.value })}
                  />
                </div>
              </div>
            </div>
          </PanelFiltros>
        </div>
      </div>

      {!cuidadores ? (
        <p>{error ? '' : 'Cargando cuidadores…'}</p>
      ) : visibles.length === 0 ? (
        <p>
          {hayCriterios
            ? 'Ningún cuidador coincide con la búsqueda o los filtros.'
            : pestana === 'puertas'
              ? 'No hay solicitudes de modalidad puertas adentro pendientes.'
              : 'No hay cuidadores en esta categoría.'}
        </p>
      ) : (
        <div className="card-grid">
          {visibles.map((c) => {
            const usuario = usuarioPorId.get(c.usuario_id)
            const nombre = usuario ? nombreCompleto(usuario) : 'Usuario desconocido'
            const estadoVisual = ESTADOS[c.estado_validacion] ?? { clase: 'neutral', texto: c.estado_validacion }

            return (
              <div
                className="cg-card"
                key={c.id}
                {...(c.estado_validacion === 'rechazado'
                  ? {
                      role: 'button',
                      tabIndex: 0,
                      title: 'Ver el motivo del rechazo',
                      style: { cursor: 'pointer' },
                      onClick: () => abrirDetalle(c, usuario, nombre),
                      onKeyDown: (e: KeyboardEvent) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault()
                          abrirDetalle(c, usuario, nombre)
                        }
                      },
                    }
                  : {})}
              >
                <div className="cg-top">
                  <AvatarCuidador key={c.foto_url ?? 'sin-foto'} url={c.foto_url} nombre={nombre} />
                  <div>
                    <div className="cg-name">{nombre}</div>
                    <div className="cg-loc">{c.ubicacion || 'Sin ubicación registrada'}</div>
                  </div>
                </div>

                <div className="cg-tags">
                  {c.profesion && <span className="tag">{c.profesion}</span>}
                  {c.es_area_salud && <span className="tag">Área de salud</span>}
                  {ofrecePuertasAdentro(c) && <span className="tag">Puertas adentro</span>}
                  {c.tarifa_hora != null && <span className="tag">${Number(c.tarifa_hora).toLocaleString('es-CL')}/hora</span>}
                </div>

                {c.descripcion && (
                  <div className="cell-sub" style={{ margin: '6px 0' }}>
                    {c.descripcion}
                  </div>
                )}

                <div className="cg-rating">
                  {c.valoracion_promedio > 0 ? `★ ${c.valoracion_promedio}` : 'Sin calificaciones aún'}
                </div>

                <span className={`pill ${estadoVisual.clase}`} style={{ alignSelf: 'flex-start' }}>
                  {estadoVisual.texto}
                </span>

                {c.estado_validacion === 'rechazado' && <div className="cell-sub">Haz clic para ver el motivo</div>}

                {c.estado_validacion === 'aprobado' && !perfilCompleto(c, usuario) && (
                  <span className="pill pending" style={{ alignSelf: 'flex-start' }}>
                    Perfil incompleto · no visible para las familias
                  </span>
                )}

                {c.puertas_adentro_pendiente && (
                  <>
                    <span className="pill pending" style={{ alignSelf: 'flex-start' }}>
                      Solicita ofrecer puertas adentro
                    </span>
                    {c.puertas_adentro_fecha_solicitud && (
                      <div className="cell-sub">Solicitada: {formatearFechaCompleta(c.puertas_adentro_fecha_solicitud)}</div>
                    )}
                    <div className="cg-actions">
                      <button
                        className="btn primary"
                        disabled={procesando === c.id}
                        onClick={() => abrirPuertas(c, nombre, true)}
                      >
                        Aprobar puertas adentro
                      </button>
                      <button
                        className="btn danger"
                        disabled={procesando === c.id}
                        onClick={() => abrirPuertas(c, nombre, false)}
                      >
                        Rechazar
                      </button>
                    </div>
                  </>
                )}

                {c.estado_validacion === 'pendiente' && (
                  <div className="cg-actions">
                    <button
                      className="btn primary"
                      disabled={procesando === c.id}
                      onClick={() => cambiarEstado(c.id, 'aprobado')}
                    >
                      Aprobar
                    </button>
                    <button
                      className="btn danger"
                      disabled={procesando === c.id}
                      onClick={() => abrirRechazo(c, nombre)}
                    >
                      Rechazar
                    </button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {accionPuertas && (
        <Modal
          titulo={accionPuertas.aprobar ? 'Aprobar modalidad puertas adentro' : 'Rechazar modalidad puertas adentro'}
          onCerrar={() => setAccionPuertas(null)}
          pie={
            <>
              <button className="btn" onClick={() => setAccionPuertas(null)} disabled={procesando !== null}>
                Cancelar
              </button>
              <button
                className={accionPuertas.aprobar ? 'btn primary' : 'btn danger'}
                onClick={resolverPuertas}
                disabled={procesando !== null}
              >
                {procesando !== null ? 'Guardando…' : accionPuertas.aprobar ? 'Aprobar' : 'Rechazar'}
              </button>
            </>
          }
        >
          {accionPuertas.aprobar ? (
            <p>
              ¿Aprobar que <b>{accionPuertas.nombre}</b> ofrezca la modalidad puertas adentro? Las familias verán su tarifa por día y
              recibirá un aviso.
            </p>
          ) : (
            <>
              <p style={{ marginBottom: 12 }}>
                ¿Rechazar la solicitud de <b>{accionPuertas.nombre}</b>? Recibirá un aviso con el motivo, si lo escribes.
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

      {rechazo && (
        <Modal
          titulo="Rechazar cuidador"
          onCerrar={() => setRechazo(null)}
          pie={
            <>
              <button className="btn" onClick={() => setRechazo(null)} disabled={procesando !== null}>
                Cancelar
              </button>
              <button
                className="btn danger"
                onClick={confirmarRechazo}
                disabled={procesando !== null || motivo.trim() === ''}
              >
                {procesando !== null ? 'Guardando…' : 'Rechazar cuidador'}
              </button>
            </>
          }
        >
          <p style={{ marginBottom: 12 }}>
            ¿Rechazar el perfil de <b>{rechazo.nombre}</b>? Escribe el motivo: quedará registrado y podrás consultarlo en el apartado "Rechazados".
          </p>
          <textarea
            style={estiloTextarea}
            maxLength={300}
            placeholder="Motivo del rechazo (obligatorio)"
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
          />
          <div className="cell-sub" style={{ textAlign: 'right' }}>
            {motivo.length}/300
          </div>
        </Modal>
      )}

      {detalle && (
        <Modal
          titulo="Cuidador rechazado"
          onCerrar={() => setDetalle(null)}
          pie={
            <button className="btn" onClick={() => setDetalle(null)}>
              Cerrar
            </button>
          }
        >
          {(() => {
            const perfil = detalle.perfil as PerfilConMotivo
            const correo = (detalle.usuario as { email?: string | null } | undefined)?.email
            const motivoGuardado = perfil.motivo_rechazo?.trim()

            return (
              <>
                <p>
                  <b>{detalle.nombre}</b>
                  {perfil.profesion ? ` · ${perfil.profesion}` : ''}
                </p>
                {correo && <div className="cell-sub">{correo}</div>}
                {perfil.fecha_validacion && (
                  <div className="cell-sub">Rechazado el {formatearFechaCompleta(perfil.fecha_validacion)}</div>
                )}

                <p style={{ marginTop: 14, marginBottom: 4 }}>
                  <b>Motivo del rechazo</b>
                </p>
                {motivoGuardado ? (
                  <p style={{ whiteSpace: 'pre-wrap' }}>{motivoGuardado}</p>
                ) : (
                  <p className="cell-sub">
                    Sin motivo registrado: este cuidador se rechazó antes de que el panel pidiera un motivo.
                  </p>
                )}
              </>
            )
          })()}
        </Modal>
      )}
    </>
  )
}