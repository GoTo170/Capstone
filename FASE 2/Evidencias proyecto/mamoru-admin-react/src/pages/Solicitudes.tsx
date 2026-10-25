import { useEffect, useState } from 'react'
import BarraBusqueda from '../components/BarraBusqueda'
import PanelFiltros from '../components/PanelFiltros'
import { apiFetch, type Usuario } from '../lib/api'
import { contiene } from '../lib/busqueda'
import { formatearFechaHora, formatearFechaIso, formatearHora, nombreCompleto } from '../lib/formato'
import type { PerfilCuidador, SolicitudServicio } from '../lib/tipos'

interface Filtros {
  estado: string
  tipo: string
  desde: string
  hasta: string
}

const SIN_FILTROS: Filtros = { estado: '', tipo: '', desde: '', hasta: '' }

const CHIPS = [
  { valor: '', texto: 'Todas' },
  { valor: 'pendiente', texto: 'Pendientes' },
  { valor: 'aceptada', texto: 'Aceptadas' },
  { valor: 'rechazada', texto: 'Rechazadas' },
  { valor: 'finalizada', texto: 'Finalizadas' },
]

const ESTADOS: Record<string, { clase: string; texto: string }> = {
  pendiente: { clase: 'pending', texto: 'Pendiente' },
  aceptada: { clase: 'ok', texto: 'Aceptada' },
  rechazada: { clase: 'crit', texto: 'Rechazada' },
  finalizada: { clase: 'neutral', texto: 'Finalizada' },
}

const SERVICIOS: Record<string, string> = {
  acompanamiento_apoyo_emocional: 'Acompañamiento y apoyo emocional',
  cuidado_fisico_personal: 'Cuidado físico y personal',
  control_medicamentos: 'Control de medicamentos',
  alimentacion: 'Alimentación',
  cuidador_integral: 'Cuidador integral',
  cuidado_puertas_adentro: 'Cuidado puertas adentro',
}

const MOTIVOS: Record<string, string> = {
  no_tengo_disponibilidad: 'No tengo disponibilidad',
  horario_no_acomoda: 'El horario no me acomoda',
  ubicacion_fuera_zona: 'La ubicación está fuera de mi zona',
  tipo_cuidado_no_corresponde: 'El tipo de cuidado no corresponde a mis servicios',
  otros: 'Otros',
}

interface DatosSolicitudes {
  solicitudes: SolicitudServicio[]
  usuarios: Usuario[]
  cuidadores: PerfilCuidador[]
}

function periodo(s: SolicitudServicio): string {
  if (!s.fecha_inicio) return 'Sin período definido'
  const inicio = `${formatearFechaIso(s.fecha_inicio)} ${s.hora_inicio ? formatearHora(s.hora_inicio) : ''}`.trim()
  if (!s.fecha_termino) return inicio
  const fin = `${formatearFechaIso(s.fecha_termino)} ${s.hora_termino ? formatearHora(s.hora_termino) : ''}`.trim()
  return `${inicio} → ${fin}`
}

function textoMotivo(s: SolicitudServicio): string | null {
  if (!s.motivo_rechazo) return null
  const base = MOTIVOS[s.motivo_rechazo] ?? s.motivo_rechazo
  return s.motivo_rechazo === 'otros' && s.motivo_rechazo_detalle ? `${base}: ${s.motivo_rechazo_detalle}` : base
}

export default function Solicitudes() {
  const [datos, setDatos] = useState<DatosSolicitudes | null>(null)
  const [error, setError] = useState('')
  const [busqueda, setBusqueda] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(SIN_FILTROS)

  useEffect(() => {
    let activo = true

    Promise.all([
      apiFetch<SolicitudServicio[]>('/solicitudes'),
      apiFetch<Usuario[]>('/usuarios'),
      apiFetch<PerfilCuidador[]>('/cuidadores'),
    ])
      .then(([solicitudes, usuarios, cuidadores]) => {
        if (activo) setDatos({ solicitudes, usuarios, cuidadores })
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar solicitudes')
      })

    return () => {
      activo = false
    }
  }, [])

  const solicitudes = datos?.solicitudes ?? []
  const usuarioPorId = new Map((datos?.usuarios ?? []).map((u) => [u.id, u]))
  const perfilPorId = new Map((datos?.cuidadores ?? []).map((c) => [c.id, c]))

  function cumple(s: SolicitudServicio, f: Filtros): boolean {
    if (f.estado && s.estado !== f.estado) return false
    if (f.tipo && s.tipo_servicio !== f.tipo) return false

    const dia = s.fecha_solicitud.slice(0, 10)
    if (f.desde && dia < f.desde) return false
    if (f.hasta && dia > f.hasta) return false

    if (busqueda) {
      const solicitante = usuarioPorId.get(s.solicitante_id)
      const adulto = usuarioPorId.get(s.adulto_mayor_id)
      const perfil = perfilPorId.get(s.cuidador_id)
      const cuidador = perfil ? usuarioPorId.get(perfil.usuario_id) : undefined
      const texto = [solicitante, adulto, cuidador].map((u) => (u ? nombreCompleto(u) : '')).join(' ')
      if (!contiene(texto, busqueda)) return false
    }
    return true
  }

  const cambiar = (parcial: Partial<Filtros>) => setFiltros((prev) => ({ ...prev, ...parcial }))
  const filtrosActivos = Object.values(filtros).filter(Boolean).length
  const hayCriterios = busqueda !== '' || filtrosActivos > 0

  const visibles = solicitudes
    .filter((s) => cumple(s, filtros))
    .sort((a, b) => new Date(b.fecha_solicitud).getTime() - new Date(a.fecha_solicitud).getTime())

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Solicitudes</div>
        <h1 className="page-title">Solicitudes de contacto y servicio</h1>
        <p className="page-desc">Trazabilidad completa del flujo entre familias y cuidadores.</p>
      </div>

      <div className="toolbar">
        <div className="filters">
          {CHIPS.map((chip) => (
            <button
              key={chip.valor}
              className={filtros.estado === chip.valor ? 'filter-chip active' : 'filter-chip'}
              onClick={() => cambiar({ estado: chip.valor })}
            >
              {datos
                ? `${chip.texto} (${solicitudes.filter((s) => cumple(s, { ...filtros, estado: chip.valor })).length})`
                : chip.texto}
            </button>
          ))}
        </div>

        <div className="toolbar-tools">
          <BarraBusqueda
            valor={busqueda}
            onCambio={setBusqueda}
            placeholder="Buscar por solicitante, adulto mayor o cuidador…"
          />

          <PanelFiltros activos={filtrosActivos} onLimpiar={() => setFiltros(SIN_FILTROS)}>
            <div className="filtro-campo">
              <label>Estado</label>
              <select value={filtros.estado} onChange={(e) => cambiar({ estado: e.target.value })}>
                <option value="">Todos</option>
                {Object.entries(ESTADOS).map(([valor, e]) => (
                  <option key={valor} value={valor}>
                    {e.texto}
                  </option>
                ))}
              </select>
            </div>

            <div className="filtro-campo">
              <label>Tipo de servicio</label>
              <select value={filtros.tipo} onChange={(e) => cambiar({ tipo: e.target.value })}>
                <option value="">Todos</option>
                {Object.entries(SERVICIOS).map(([valor, texto]) => (
                  <option key={valor} value={valor}>
                    {texto}
                  </option>
                ))}
              </select>
            </div>

            <div className="filtro-campo">
              <label>Fecha solicitada</label>
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
        <table>
          <thead>
            <tr>
              <th>Solicitante</th>
              <th>Adulto mayor</th>
              <th>Cuidador</th>
              <th>Servicio</th>
              <th>Estado</th>
              <th>Solicitada</th>
            </tr>
          </thead>
          <tbody>
            {error ? (
              <tr>
                <td colSpan={6}>Error al cargar solicitudes: {error}</td>
              </tr>
            ) : !datos ? (
              <tr>
                <td colSpan={6}>Cargando solicitudes…</td>
              </tr>
            ) : visibles.length === 0 ? (
              <tr>
                <td colSpan={6}>
                  {solicitudes.length === 0
                    ? 'Todavía no hay solicitudes registradas.'
                    : hayCriterios
                      ? 'Ninguna solicitud coincide con la búsqueda o los filtros.'
                      : 'No hay solicitudes en esta categoría.'}
                </td>
              </tr>
            ) : (
              visibles.map((s) => {
                const solicitante = usuarioPorId.get(s.solicitante_id)
                const adulto = usuarioPorId.get(s.adulto_mayor_id)
                const perfil = perfilPorId.get(s.cuidador_id)
                const cuidador = perfil ? usuarioPorId.get(perfil.usuario_id) : undefined
                const estado = ESTADOS[s.estado] ?? { clase: 'neutral', texto: s.estado }
                const motivo = textoMotivo(s)

                return (
                  <tr key={s.id}>
                    <td>
                      <div className="cell-primary">{solicitante ? nombreCompleto(solicitante) : '—'}</div>
                    </td>
                    <td>{adulto ? nombreCompleto(adulto) : '—'}</td>
                    <td>{cuidador ? nombreCompleto(cuidador) : '—'}</td>
                    <td>
                      <div>{s.tipo_servicio ? (SERVICIOS[s.tipo_servicio] ?? s.tipo_servicio) : 'Sin especificar'}</div>
                      <div className="cell-sub">{periodo(s)}</div>
                    </td>
                    <td>
                      <span className={`pill ${estado.clase}`}>{estado.texto}</span>
                      {motivo && <div className="cell-sub">{motivo}</div>}
                    </td>
                    <td>{formatearFechaHora(s.fecha_solicitud)}</td>
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