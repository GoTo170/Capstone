import { useCallback, useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import BarraBusqueda from '../components/BarraBusqueda'
import Modal from '../components/Modal'
import PanelFiltros from '../components/PanelFiltros'
import { apiFetch } from '../lib/api'
import { contiene } from '../lib/busqueda'
import { diaLocal, formatearFechaCompleta } from '../lib/formato'
import type { AlertaSOSPanel, ContextoLayout } from '../lib/tipos'

type Estado = 'activa' | 'atendida' | 'cancelada'

interface Filtros {
  desde: string
  hasta: string
}

interface Accion {
  alerta: AlertaSOSPanel
  estado: 'atendida' | 'cancelada'
}

const SIN_FILTROS: Filtros = { desde: '', hasta: '' }

const CHIPS: { valor: Estado; texto: string }[] = [
  { valor: 'activa', texto: 'Activas' },
  { valor: 'atendida', texto: 'Atendidas' },
  { valor: 'cancelada', texto: 'Canceladas' },
]

const ESTADOS: Record<string, { clase: string; texto: string }> = {
  activa: { clase: 'crit', texto: 'Activa' },
  atendida: { clase: 'ok', texto: 'Atendida' },
  cancelada: { clase: 'neutral', texto: 'Falsa alarma' },
}

// Una alerta SOS es urgente: la lista se actualiza sola cada 15 segundos.
const SEGUNDOS_ACTUALIZACION = 15

function cumple(alerta: AlertaSOSPanel, estado: Estado, busqueda: string, f: Filtros): boolean {
  if (alerta.estado !== estado) return false

  const dia = diaLocal(alerta.fecha_alerta)
  if (f.desde && dia < f.desde) return false
  if (f.hasta && dia > f.hasta) return false

  if (busqueda) {
    const texto = `${alerta.persona_nombre} ${alerta.contactos.map((c) => c.nombre).join(' ')} ${alerta.familiares.join(' ')}`
    if (!contiene(texto, busqueda)) return false
  }
  return true
}

export default function AlertasSOS() {
  const { refrescarSOS } = useOutletContext<ContextoLayout>()
  const [alertas, setAlertas] = useState<AlertaSOSPanel[] | null>(null)
  const [error, setError] = useState('')
  const [estado, setEstado] = useState<Estado>('activa')
  const [busqueda, setBusqueda] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(SIN_FILTROS)
  const [accion, setAccion] = useState<Accion | null>(null)
  const [procesando, setProcesando] = useState(false)

  const cargar = useCallback(async () => {
    try {
      const lista = await apiFetch<AlertaSOSPanel[]>('/admin/alertas-sos')
      setAlertas(lista)
      setError('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error al cargar las alertas')
    }
  }, [])

  useEffect(() => {
    cargar()
    const temporizador = setInterval(cargar, SEGUNDOS_ACTUALIZACION * 1000)
    return () => clearInterval(temporizador)
  }, [cargar])

  async function confirmar() {
    if (!accion) return
    setProcesando(true)
    try {
      await apiFetch(`/alertas-sos/${accion.alerta.id}/estado`, {
        method: 'PATCH',
        body: JSON.stringify({ estado: accion.estado }),
      })
      setAccion(null)
      await cargar()
      refrescarSOS()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo actualizar la alerta')
      setAccion(null)
    } finally {
      setProcesando(false)
    }
  }

  const cambiar = (parcial: Partial<Filtros>) => setFiltros((prev) => ({ ...prev, ...parcial }))
  const filtrosActivos = Object.values(filtros).filter(Boolean).length
  const hayCriterios = busqueda !== '' || filtrosActivos > 0

  const lista = alertas ?? []
  const activas = lista.filter((a) => a.estado === 'activa').length

  const visibles = lista
    .filter((a) => cumple(a, estado, busqueda, filtros))
    .sort((a, b) => new Date(b.fecha_alerta).getTime() - new Date(a.fecha_alerta).getTime())

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Alertas SOS</div>
        <h1 className="page-title">Alertas SOS</h1>
        <p className="page-desc">Emergencias activadas por los adultos mayores desde el botón SOS de la app.</p>
      </div>

      {activas > 0 && (
        <div className="auth-error" style={{ display: 'block' }}>
          {activas === 1 ? 'Hay 1 alerta SOS activa esperando atención.' : `Hay ${activas} alertas SOS activas esperando atención.`}
        </div>
      )}
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
              className={estado === chip.valor ? 'filter-chip active' : 'filter-chip'}
              onClick={() => setEstado(chip.valor)}
            >
              {alertas ? `${chip.texto} (${lista.filter((a) => cumple(a, chip.valor, busqueda, filtros)).length})` : chip.texto}
            </button>
          ))}
        </div>

        <div className="toolbar-tools">
          <BarraBusqueda valor={busqueda} onCambio={setBusqueda} placeholder="Buscar por persona, contacto o familiar…" />

          <PanelFiltros activos={filtrosActivos} onLimpiar={() => setFiltros(SIN_FILTROS)}>
            <div className="filtro-campo">
              <label>Fecha de la alerta</label>
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
              <th>Persona</th>
              <th>Contactos de emergencia</th>
              <th>Familiares avisados</th>
              <th>Fecha y hora</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {!alertas ? (
              <tr>
                <td colSpan={6}>{error ? 'No se pudo cargar.' : 'Cargando alertas…'}</td>
              </tr>
            ) : visibles.length === 0 ? (
              <tr>
                <td colSpan={6}>
                  {hayCriterios
                    ? 'Ninguna alerta coincide con la búsqueda o los filtros.'
                    : estado === 'activa'
                      ? 'No hay alertas SOS activas.'
                      : 'No hay alertas en esta categoría.'}
                </td>
              </tr>
            ) : (
              visibles.map((a) => {
                const etiqueta = ESTADOS[a.estado] ?? { clase: 'neutral', texto: a.estado }

                return (
                  <tr key={a.id}>
                    <td>
                      <div className="cell-primary">{a.persona_nombre}</div>
                      {a.persona_telefono && <div className="cell-sub">{a.persona_telefono}</div>}
                    </td>
                    <td>
                      {a.contactos.length === 0 ? (
                        <span className="cell-sub">Sin contactos registrados</span>
                      ) : (
                        a.contactos.map((c) => (
                          <div key={`${c.nombre}-${c.telefono}`} style={{ marginBottom: 6 }}>
                            <div>
                              {c.nombre}
                              {c.parentesco ? ` (${c.parentesco})` : ''}
                            </div>
                            <div className="cell-sub">{c.telefono}</div>
                          </div>
                        ))
                      )}
                    </td>
                    <td>{a.familiares.length === 0 ? '—' : a.familiares.join(', ')}</td>
                    <td>{formatearFechaCompleta(a.fecha_alerta)}</td>
                    <td>
                      <span className={`pill ${etiqueta.clase}`}>{etiqueta.texto}</span>
                      {a.fecha_atencion && <div className="cell-sub">Cerrada: {formatearFechaCompleta(a.fecha_atencion)}</div>}
                    </td>
                    <td>
                      {a.estado === 'activa' ? (
                        <div className="row-actions">
                          <button className="btn primary" onClick={() => setAccion({ alerta: a, estado: 'atendida' })}>
                            Marcar como atendida
                          </button>
                          <button className="btn" onClick={() => setAccion({ alerta: a, estado: 'cancelada' })}>
                            Falsa alarma
                          </button>
                        </div>
                      ) : (
                        '—'
                      )}
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>

      {accion && (
        <Modal
          titulo={accion.estado === 'atendida' ? 'Marcar alerta como atendida' : 'Marcar como falsa alarma'}
          onCerrar={() => setAccion(null)}
          pie={
            <>
              <button className="btn" onClick={() => setAccion(null)} disabled={procesando}>
                Cancelar
              </button>
              <button
                className={accion.estado === 'atendida' ? 'btn primary' : 'btn danger'}
                onClick={confirmar}
                disabled={procesando}
              >
                {procesando ? 'Guardando…' : 'Confirmar'}
              </button>
            </>
          }
        >
          <p>
            {accion.estado === 'atendida' ? (
              <>
                ¿Confirmas que ya atendiste la alerta SOS de <b>{accion.alerta.persona_nombre}</b>? Se avisará a sus familiares.
              </>
            ) : (
              <>
                ¿Marcar la alerta de <b>{accion.alerta.persona_nombre}</b> como falsa alarma? No se avisará a sus familiares.
              </>
            )}
          </p>
        </Modal>
      )}
    </>
  )
}