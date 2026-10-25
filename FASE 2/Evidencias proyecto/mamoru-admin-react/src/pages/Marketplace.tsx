import { useEffect, useState } from 'react'
import BarraBusqueda from '../components/BarraBusqueda'
import PanelFiltros from '../components/PanelFiltros'
import { apiFetch, type Usuario } from '../lib/api'
import { contiene } from '../lib/busqueda'
import { formatearFecha, nombreCompleto } from '../lib/formato'
import type { PerfilCuidador, SolicitudServicio, Valoracion } from '../lib/tipos'

type Pestana = 'pendientes' | 'resueltas' | 'deshabilitadas'

interface Filtros {
  motivo: string
  desde: string
  hasta: string
}

const SIN_FILTROS: Filtros = { motivo: '', desde: '', hasta: '' }

const PESTANAS: { valor: Pestana; texto: string }[] = [
  { valor: 'pendientes', texto: 'Pendientes de revisión' },
  { valor: 'resueltas', texto: 'Resueltas' },
  { valor: 'deshabilitadas', texto: 'Deshabilitadas' },
]

const TITULOS: Record<Pestana, string> = {
  pendientes: 'Cola de moderación',
  resueltas: 'Reseñas resueltas (se mantuvieron habilitadas)',
  deshabilitadas: 'Reseñas deshabilitadas',
}

const VACIOS: Record<Pestana, string> = {
  pendientes: 'No hay reseñas reportadas pendientes de revisión.',
  resueltas: 'Todavía no hay reseñas reportadas que se hayan mantenido habilitadas.',
  deshabilitadas: 'No hay reseñas deshabilitadas.',
}

interface DatosMarketplace {
  valoraciones: Valoracion[]
  solicitudes: SolicitudServicio[]
  cuidadores: PerfilCuidador[]
  usuarios: Usuario[]
}

function coincide(valoracion: Valoracion, pestana: Pestana): boolean {
  if (pestana === 'pendientes') return valoracion.reportada
  if (pestana === 'resueltas') {
    return valoracion.habilitada && !valoracion.reportada && Boolean(valoracion.motivo_reporte)
  }
  return !valoracion.habilitada && !valoracion.reportada
}

export default function Marketplace() {
  const [datos, setDatos] = useState<DatosMarketplace | null>(null)
  const [error, setError] = useState('')
  const [pestana, setPestana] = useState<Pestana>('pendientes')
  const [busqueda, setBusqueda] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(SIN_FILTROS)
  const [procesando, setProcesando] = useState<string | null>(null)

  useEffect(() => {
    let activo = true

    Promise.all([
      apiFetch<Valoracion[]>('/valoraciones'),
      apiFetch<SolicitudServicio[]>('/solicitudes'),
      apiFetch<PerfilCuidador[]>('/cuidadores'),
      apiFetch<Usuario[]>('/usuarios'),
    ])
      .then(([valoraciones, solicitudes, cuidadores, usuarios]) => {
        if (activo) setDatos({ valoraciones, solicitudes, cuidadores, usuarios })
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar la moderación')
      })

    return () => {
      activo = false
    }
  }, [])

  async function moderar(id: string, habilitada: boolean) {
    setProcesando(id)
    setError('')
    try {
      const actualizada = await apiFetch<Valoracion>(`/valoraciones/${id}/moderar`, {
        method: 'PATCH',
        body: JSON.stringify({ habilitada }),
      })
      setDatos((prev) =>
        prev
          ? { ...prev, valoraciones: prev.valoraciones.map((v) => (v.id === actualizada.id ? actualizada : v)) }
          : prev,
      )
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error al moderar la reseña')
    } finally {
      setProcesando(null)
    }
  }

  const valoraciones = datos?.valoraciones ?? []
  const usuarioPorId = new Map((datos?.usuarios ?? []).map((u) => [u.id, u]))
  const perfilPorId = new Map((datos?.cuidadores ?? []).map((c) => [c.id, c]))
  const solicitudPorId = new Map((datos?.solicitudes ?? []).map((s) => [s.id, s]))

  function personasDe(v: Valoracion) {
    const solicitud = solicitudPorId.get(v.solicitud_id)
    const autor = solicitud ? usuarioPorId.get(solicitud.solicitante_id) : undefined
    const perfil = solicitud ? perfilPorId.get(solicitud.cuidador_id) : undefined
    const cuidador = perfil ? usuarioPorId.get(perfil.usuario_id) : undefined
    return { autor, cuidador }
  }

  function cumple(v: Valoracion, pest: Pestana): boolean {
    if (!coincide(v, pest)) return false
    if (filtros.motivo && v.motivo_reporte !== filtros.motivo) return false

    const dia = v.fecha.slice(0, 10)
    if (filtros.desde && dia < filtros.desde) return false
    if (filtros.hasta && dia > filtros.hasta) return false

    if (busqueda) {
      const { autor, cuidador } = personasDe(v)
      const texto = `${cuidador ? nombreCompleto(cuidador) : ''} ${autor ? nombreCompleto(autor) : ''} ${v.comentario ?? ''}`
      if (!contiene(texto, busqueda)) return false
    }
    return true
  }

  const cambiar = (parcial: Partial<Filtros>) => setFiltros((prev) => ({ ...prev, ...parcial }))
  const filtrosActivos = Object.values(filtros).filter(Boolean).length
  const hayCriterios = busqueda !== '' || filtrosActivos > 0

  const motivos = Array.from(
    new Set(valoraciones.map((v) => v.motivo_reporte).filter((m): m is string => Boolean(m))),
  )

  const visibles = valoraciones
    .filter((v) => cumple(v, pestana))
    .sort((a, b) => new Date(b.fecha).getTime() - new Date(a.fecha).getTime())

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Marketplace</div>
        <h1 className="page-title">Moderación del marketplace</h1>
        <p className="page-desc">Reseñas reportadas por los cuidadores, a la espera de revisión.</p>
      </div>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      <div className="toolbar">
        <div className="filters">
          {PESTANAS.map((p) => (
            <button
              key={p.valor}
              className={pestana === p.valor ? 'filter-chip active' : 'filter-chip'}
              onClick={() => setPestana(p.valor)}
            >
              {datos ? `${p.texto} (${valoraciones.filter((v) => cumple(v, p.valor)).length})` : p.texto}
            </button>
          ))}
        </div>

        <div className="toolbar-tools">
          <BarraBusqueda valor={busqueda} onCambio={setBusqueda} placeholder="Buscar por cuidador, autor o comentario…" />

          <PanelFiltros activos={filtrosActivos} onLimpiar={() => setFiltros(SIN_FILTROS)}>
            <div className="filtro-campo">
              <label>Motivo del reporte</label>
              <select value={filtros.motivo} onChange={(e) => cambiar({ motivo: e.target.value })}>
                <option value="">Todos</option>
                {motivos.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}
              </select>
            </div>

            <div className="filtro-campo">
              <label>Fecha de la reseña</label>
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

      <div className="panel">
        <div className="panel-head lila">
          <h2>{TITULOS[pestana]}</h2>
        </div>
        <table>
          <thead>
            <tr>
              <th>Reseña</th>
              <th>Escrita por</th>
              <th>Motivo del reporte</th>
              <th>Fecha</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {!datos ? (
              <tr>
                <td colSpan={5}>{error ? 'No se pudo cargar.' : 'Cargando…'}</td>
              </tr>
            ) : visibles.length === 0 ? (
              <tr>
                <td colSpan={5}>
                  {hayCriterios ? 'Ninguna reseña coincide con la búsqueda o los filtros.' : VACIOS[pestana]}
                </td>
              </tr>
            ) : (
              visibles.map((v) => {
                const { autor, cuidador } = personasDe(v)

                return (
                  <tr key={v.id}>
                    <td>
                      <div className="cell-primary">
                        Reseña sobre {cuidador ? nombreCompleto(cuidador) : 'cuidador desconocido'}
                      </div>
                      <div className="cell-sub">
                        ★ {v.puntuacion} — “{v.comentario || 'Sin comentario'}”
                      </div>
                    </td>
                    <td>{autor ? nombreCompleto(autor) : '—'}</td>
                    <td>{v.motivo_reporte ?? '—'}</td>
                    <td>{formatearFecha(v.fecha)}</td>
                    <td>
                      <div className="row-actions">
                        {pestana === 'pendientes' && (
                          <>
                            <button
                              className="btn primary"
                              disabled={procesando === v.id}
                              onClick={() => moderar(v.id, true)}
                            >
                              Mantener habilitada
                            </button>
                            <button
                              className="btn danger"
                              disabled={procesando === v.id}
                              onClick={() => moderar(v.id, false)}
                            >
                              Deshabilitar
                            </button>
                          </>
                        )}
                        {pestana === 'resueltas' && (
                          <button
                            className="btn danger"
                            disabled={procesando === v.id}
                            onClick={() => moderar(v.id, false)}
                          >
                            Deshabilitar
                          </button>
                        )}
                        {pestana === 'deshabilitadas' && (
                          <button
                            className="btn primary"
                            disabled={procesando === v.id}
                            onClick={() => moderar(v.id, true)}
                          >
                            Habilitar de nuevo
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>
    </>
  )
}