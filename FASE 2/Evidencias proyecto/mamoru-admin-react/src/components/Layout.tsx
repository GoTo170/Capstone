import { useCallback, useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { apiFetch, cerrarSesion, obtenerUsuarioSesion } from '../lib/api'
import type { AlertaSOS, ContextoLayout, PerfilCuidador } from '../lib/tipos'
import { useTheme } from '../lib/useTheme'
import Notificaciones from './Notificaciones'

interface Enlace {
  to: string
  texto: string
  end?: boolean
}

const enlaces: Enlace[] = [
  { to: '/', texto: 'Dashboard', end: true },
  { to: '/usuarios', texto: 'Usuarios' },
  { to: '/cuidadores', texto: 'Cuidadores' },
  { to: '/marketplace', texto: 'Marketplace' },
  { to: '/solicitudes', texto: 'Solicitudes' },
  { to: '/alertas-sos', texto: 'Alertas SOS' },
  { to: '/reportes', texto: 'Reportes' },
  { to: '/auditoria', texto: 'Auditoría' },
  { to: '/config', texto: 'Configuración' },
]

// Cada cuánto se revisan los contadores del menú (cuidadores pendientes y alertas SOS).
const SEGUNDOS_ACTUALIZACION = 30

export default function Layout() {
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const { tema, alternar } = useTheme()
  const usuario = obtenerUsuarioSesion()
  const [pendientes, setPendientes] = useState(0)
  const [sosActivas, setSosActivas] = useState(0)

  const refrescarPendientes = useCallback(() => {
    apiFetch<PerfilCuidador[]>('/cuidadores')
      .then((lista) =>
        // Cuenta perfiles por aprobar y solicitudes de puertas adentro por resolver.
        setPendientes(lista.filter((c) => c.estado_validacion === 'pendiente' || c.puertas_adentro_pendiente).length),
      )
      .catch(() => {})
  }, [])

  const refrescarSOS = useCallback(() => {
    apiFetch<AlertaSOS[]>('/alertas-sos')
      .then((lista) => setSosActivas(lista.filter((a) => a.estado === 'activa').length))
      .catch(() => {})
  }, [])

  useEffect(() => {
    refrescarPendientes()
    refrescarSOS()
    const temporizador = setInterval(() => {
      refrescarPendientes()
      refrescarSOS()
    }, SEGUNDOS_ACTUALIZACION * 1000)
    return () => clearInterval(temporizador)
  }, [refrescarPendientes, refrescarSOS])

  // El título de la pestaña del navegador sigue a la página actual.
  useEffect(() => {
    const actual = enlaces.find((e) => e.to === pathname)
    document.title = `${actual?.texto ?? 'Panel'} · Mamoru`
  }, [pathname])

  const contexto: ContextoLayout = { refrescarPendientes, refrescarSOS }

  async function salir() {
     try {
       await apiFetch('/logout', { method: 'POST' })
     } catch {
       // se ignora a propósito
     }
     cerrarSesion()
     navigate('/login')
   }

  function insignia(to: string): number {
    if (to === '/cuidadores') return pendientes
    if (to === '/alertas-sos') return sosActivas
    return 0
  }

  return (
    <>
      <header className="app-header">
        <div className="header-top">
          <img src="/logo-icon.jpeg" alt="Mamoru" className="header-logo" />

          <div className="titulo-panel">Panel Administrativo Mamoru</div>

          <div className="header-right">
            <Notificaciones />

            <button className="icon-btn" onClick={alternar} title="Cambiar tema">
              {tema === 'dark' ? (
                <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                </svg>
              ) : (
                <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <circle cx="12" cy="12" r="4" />
                  <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
                </svg>
              )}
            </button>

            <div className="user-chip">
              <div className="who">{usuario?.nombre}</div>
              <div className="role">Administrador</div>
            </div>

            <button className="btn-logout" onClick={salir}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
                <path d="M16 17l5-5-5-5" />
                <path d="M21 12H9" />
              </svg>
              Cerrar sesión
            </button>
          </div>
        </div>

        <nav className="top-nav">
          {enlaces.map((enlace) => (
            <NavLink
              key={enlace.to}
              to={enlace.to}
              end={enlace.end}
              className={({ isActive }) => (isActive ? 'nav-pill active' : 'nav-pill')}
            >
              {enlace.texto}
              {insignia(enlace.to) > 0 && <span className="badge">{insignia(enlace.to)}</span>}
            </NavLink>
          ))}
        </nav>
      </header>

      <main className="content">
        <Outlet context={contexto} />
      </main>
    </>
  )
}