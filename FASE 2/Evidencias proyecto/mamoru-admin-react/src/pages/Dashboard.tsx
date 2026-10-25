import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { apiFetch, obtenerUsuarioSesion, type Usuario } from '../lib/api'
import { formatearFechaHora } from '../lib/formato'
import type { AlertaSOS, PerfilCuidador, RegistroAuditoria, SolicitudServicio } from '../lib/tipos'

interface DatosDashboard {
  usuarios: Usuario[]
  cuidadores: PerfilCuidador[]
  solicitudes: SolicitudServicio[]
  alertas: AlertaSOS[]
  auditoria: RegistroAuditoria[]
}

const VACIO: DatosDashboard = {
  usuarios: [],
  cuidadores: [],
  solicitudes: [],
  alertas: [],
  auditoria: [],
}

function claseEstado(estado: string): string {
  const mapa: Record<string, string> = {
    pendiente: 'pending',
    aceptada: 'ok',
    rechazada: 'crit',
    finalizada: 'neutral',
  }
  return mapa[estado] ?? 'neutral'
}

export default function Dashboard() {
  const usuarioSesion = obtenerUsuarioSesion()
  const primerNombre = usuarioSesion?.nombre.split(' ')[0] ?? 'Administrador'

  const [datos, setDatos] = useState<DatosDashboard | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let activo = true

    Promise.all([
      apiFetch<Usuario[]>('/usuarios'),
      apiFetch<PerfilCuidador[]>('/cuidadores'),
      apiFetch<SolicitudServicio[]>('/solicitudes'),
      apiFetch<AlertaSOS[]>('/alertas-sos'),
      apiFetch<RegistroAuditoria[]>('/auditoria'),
    ])
      .then(([usuarios, cuidadores, solicitudes, alertas, auditoria]) => {
        if (activo) setDatos({ usuarios, cuidadores, solicitudes, alertas, auditoria })
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar el dashboard')
      })

    return () => {
      activo = false
    }
  }, [])

  const { usuarios, cuidadores, solicitudes, alertas, auditoria } = datos ?? VACIO
  const valor = (n: number) => (datos ? n : '—')

  const activos = usuarios.filter((u) => u.activo).length
  const verificados = cuidadores.filter((c) => c.estado_validacion === 'aprobado').length
  const pendientesCuidadores = cuidadores.filter((c) => c.estado_validacion === 'pendiente').length
  const pendientesSolicitudes = solicitudes.filter((s) => s.estado === 'pendiente').length
  const alertasActivas = alertas.filter((a) => a.estado === 'activa').length
  const contarRol = (rol: string) => usuarios.filter((u) => u.rol === rol).length

  const usuarioPorId = new Map(usuarios.map((u) => [u.id, u]))

  const solicitudesRecientes = [...solicitudes]
    .sort((a, b) => new Date(b.fecha_solicitud).getTime() - new Date(a.fecha_solicitud).getTime())
    .slice(0, 5)

  const auditoriaReciente = [...auditoria]
    .sort((a, b) => new Date(b.fecha).getTime() - new Date(a.fecha).getTime())
    .slice(0, 4)

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Dashboard</div>
        <h1 className="page-title">Hola, {primerNombre}</h1>
        <p className="page-desc">Resumen operativo de la red de cuidado.</p>
      </div>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      <div className="kpi-row">
        <div className="kpi-card verde">
          <div className="kpi-label">Usuarios activos</div>
          <div className="kpi-value">{valor(activos)}</div>
          <div className="kpi-delta">{datos ? `${usuarios.length} en total` : ''}</div>
        </div>
        <div className="kpi-card lila">
          <div className="kpi-label">Cuidadores verificados</div>
          <div className="kpi-value">{valor(verificados)}</div>
          <div className="kpi-delta warn">{datos ? `${pendientesCuidadores} pendientes de revisión` : ''}</div>
        </div>
        <div className="kpi-card amarillo">
          <div className="kpi-label">Solicitudes de servicio</div>
          <div className="kpi-value">{valor(solicitudes.length)}</div>
          <div className="kpi-delta warn">{datos ? `${pendientesSolicitudes} pendientes` : ''}</div>
        </div>
        <Link to="/alertas-sos" className="kpi-card sos" style={{ textDecoration: 'none', color: 'inherit', display: 'block', cursor: 'pointer' }}>
          <div className="kpi-label">Alertas SOS activas</div>
          <div className="kpi-value">{valor(alertasActivas)}</div>
          <div className="kpi-delta crit">
            {datos ? (alertasActivas > 0 ? 'Requieren revisión · Ver alertas' : 'Sin alertas activas') : ''}
          </div>
        </Link>
      </div>

      <div className="two-col">
        <div className="panel">
          <div className="panel-head verde">
            <h2>Solicitudes recientes</h2>
            <Link className="link-btn" to="/solicitudes">
              Ver todas
            </Link>
          </div>
          <table>
            <thead>
              <tr>
                <th>Solicitante</th>
                <th>Cuidador</th>
                <th>Estado</th>
                <th>Fecha</th>
              </tr>
            </thead>
            <tbody>
              {!datos ? (
                <tr>
                  <td colSpan={4}>Cargando…</td>
                </tr>
              ) : solicitudesRecientes.length === 0 ? (
                <tr>
                  <td colSpan={4}>Todavía no hay solicitudes registradas.</td>
                </tr>
              ) : (
                solicitudesRecientes.map((s) => {
                  const solicitante = usuarioPorId.get(s.solicitante_id)
                  const perfil = cuidadores.find((c) => c.id === s.cuidador_id)
                  const cuidador = perfil ? usuarioPorId.get(perfil.usuario_id) : undefined

                  return (
                    <tr key={s.id}>
                      <td>{solicitante?.nombre ?? '—'}</td>
                      <td>{cuidador?.nombre ?? '—'}</td>
                      <td>
                        <span className={`pill ${claseEstado(s.estado)}`}>{s.estado}</span>
                      </td>
                      <td>{formatearFechaHora(s.fecha_solicitud)}</td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="panel">
          <div className="panel-head lila">
            <h2>Auditoría reciente</h2>
            <Link className="link-btn" to="/auditoria">
              Ver todo
            </Link>
          </div>
          <div className="audit-list">
            {!datos ? (
              <div className="audit-item">
                <div className="audit-text">Cargando…</div>
              </div>
            ) : auditoriaReciente.length === 0 ? (
              <div className="audit-item">
                <div className="audit-text">Aún no hay acciones registradas.</div>
              </div>
            ) : (
              auditoriaReciente.map((r) => (
                <div className="audit-item" key={r.id}>
                  <div className="audit-dot"></div>
                  <div>
                    <div className="audit-text">
                      <b>{usuarioPorId.get(r.administrador_id)?.nombre ?? 'Alguien'}</b> {r.accion.toLowerCase()}
                    </div>
                    <div className="audit-time">{formatearFechaHora(r.fecha)}</div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-head verde">
          <h2>Usuarios por rol</h2>
        </div>
        <div style={{ padding: 20, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 24 }}>
          <div>
            <div className="kpi-label">Adultos mayores</div>
            <div className="kpi-value" style={{ fontSize: 22 }}>
              {valor(contarRol('adulto_mayor'))}
            </div>
          </div>
          <div>
            <div className="kpi-label">Familiares</div>
            <div className="kpi-value" style={{ fontSize: 22 }}>
              {valor(contarRol('familiar'))}
            </div>
          </div>
          <div>
            <div className="kpi-label">Cuidadores</div>
            <div className="kpi-value" style={{ fontSize: 22 }}>
              {valor(contarRol('cuidador'))}
            </div>
          </div>
        </div>
      </div>
    </>
  )
}