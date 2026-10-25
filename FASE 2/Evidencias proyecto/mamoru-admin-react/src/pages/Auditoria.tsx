import { useEffect, useState } from 'react'
import BarraBusqueda from '../components/BarraBusqueda'
import PanelFiltros from '../components/PanelFiltros'
import { apiFetch, type Usuario } from '../lib/api'
import { contiene } from '../lib/busqueda'
import { formatearFechaCompleta, nombreCompleto } from '../lib/formato'
import type { RegistroAuditoria } from '../lib/tipos'

interface Filtros {
  admin: string
  entidad: string
  desde: string
  hasta: string
}

const SIN_FILTROS: Filtros = { admin: '', entidad: '', desde: '', hasta: '' }

const ENTIDADES: Record<string, string> = {
  perfil_cuidador: 'Perfil de cuidador',
  valoracion: 'Reseña',
  usuario: 'Usuario',
  alerta_sos: 'Alerta SOS',
}

interface DatosAuditoria {
  registros: RegistroAuditoria[]
  usuarios: Usuario[]
}

export default function Auditoria() {
  const [datos, setDatos] = useState<DatosAuditoria | null>(null)
  const [error, setError] = useState('')
  const [busqueda, setBusqueda] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(SIN_FILTROS)

  useEffect(() => {
    let activo = true

    Promise.all([apiFetch<RegistroAuditoria[]>('/auditoria'), apiFetch<Usuario[]>('/usuarios')])
      .then(([registros, usuarios]) => {
        if (activo) setDatos({ registros, usuarios })
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar la auditoría')
      })

    return () => {
      activo = false
    }
  }, [])

  const usuarioPorId = new Map((datos?.usuarios ?? []).map((u) => [u.id, u]))
  const todos = datos?.registros ?? []

  const cambiar = (parcial: Partial<Filtros>) => setFiltros((prev) => ({ ...prev, ...parcial }))
  const filtrosActivos = Object.values(filtros).filter(Boolean).length
  const hayCriterios = busqueda !== '' || filtrosActivos > 0

  const administradores = Array.from(new Set(todos.map((r) => r.administrador_id))).map((id) => {
    const usuario = usuarioPorId.get(id)
    return { id, nombre: usuario ? nombreCompleto(usuario) : 'Desconocido' }
  })

  const registros = todos
    .filter((r) => {
      if (filtros.admin && r.administrador_id !== filtros.admin) return false
      if (filtros.entidad && r.entidad_tipo !== filtros.entidad) return false

      const dia = r.fecha.slice(0, 10)
      if (filtros.desde && dia < filtros.desde) return false
      if (filtros.hasta && dia > filtros.hasta) return false

      if (busqueda) {
        const admin = usuarioPorId.get(r.administrador_id)
        const texto = `${r.accion} ${r.detalle ?? ''} ${admin ? nombreCompleto(admin) : ''}`
        if (!contiene(texto, busqueda)) return false
      }
      return true
    })
    .sort((a, b) => new Date(b.fecha).getTime() - new Date(a.fecha).getTime())

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Auditoría</div>
        <h1 className="page-title">Bitácora de auditoría</h1>
        <p className="page-desc">Registro de todas las acciones administrativas realizadas en la plataforma.</p>
      </div>

      <div className="toolbar">
        <div className="toolbar-tools">
          <BarraBusqueda valor={busqueda} onCambio={setBusqueda} placeholder="Buscar por acción o administrador…" />

          <PanelFiltros activos={filtrosActivos} onLimpiar={() => setFiltros(SIN_FILTROS)}>
            <div className="filtro-campo">
              <label>Administrador</label>
              <select value={filtros.admin} onChange={(e) => cambiar({ admin: e.target.value })}>
                <option value="">Todos</option>
                {administradores.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.nombre}
                  </option>
                ))}
              </select>
            </div>

            <div className="filtro-campo">
              <label>Entidad afectada</label>
              <select value={filtros.entidad} onChange={(e) => cambiar({ entidad: e.target.value })}>
                <option value="">Todas</option>
                {Object.entries(ENTIDADES).map(([valor, texto]) => (
                  <option key={valor} value={valor}>
                    {texto}
                  </option>
                ))}
              </select>
            </div>

            <div className="filtro-campo">
              <label>Fecha</label>
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
              <th>Fecha</th>
              <th>Administrador</th>
              <th>Acción</th>
              <th>Entidad afectada</th>
            </tr>
          </thead>
          <tbody>
            {error ? (
              <tr>
                <td colSpan={4}>Error al cargar la auditoría: {error}</td>
              </tr>
            ) : !datos ? (
              <tr>
                <td colSpan={4}>Cargando…</td>
              </tr>
            ) : registros.length === 0 ? (
              <tr>
                <td colSpan={4}>
                  {hayCriterios
                    ? 'Ningún registro coincide con la búsqueda o los filtros.'
                    : 'Todavía no hay acciones registradas.'}
                </td>
              </tr>
            ) : (
              registros.map((r) => {
                const admin = usuarioPorId.get(r.administrador_id)

                return (
                  <tr key={r.id}>
                    <td>{formatearFechaCompleta(r.fecha)}</td>
                    <td>{admin ? nombreCompleto(admin) : '—'}</td>
                    <td>
                      <div>{r.accion}</div>
                      {r.detalle && <div className="cell-sub">{r.detalle}</div>}
                    </td>
                    <td>{ENTIDADES[r.entidad_tipo] ?? r.entidad_tipo}</td>
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