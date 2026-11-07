import { useEffect, useState } from 'react'
import CambiarContrasena from '../components/CambiarContrasena'
import FormularioMiembro from '../components/FormularioMiembro'
import Modal from '../components/Modal'
import {
  DESCRIPCION_ROL_INTERNO,
  ETIQUETA_ROL_INTERNO,
  ROLES_INTERNOS,
  apiFetch,
  obtenerUsuarioSesion,
  rolInternoDe,
  tienePermiso,
  type Usuario,
} from '../lib/api'
import { nombreCompleto } from '../lib/formato'

interface AjusteNotificacion {
  clave: string
  titulo: string
  descripcion: string
  activa: boolean
}

export default function Config() {
  const [usuarios, setUsuarios] = useState<Usuario[] | null>(null)
  const [error, setError] = useState('')
  const [ajustes, setAjustes] = useState<AjusteNotificacion[] | null>(null)
  const [errorAjustes, setErrorAjustes] = useState('')
  const [nuevoAbierto, setNuevoAbierto] = useState(false)
  const [cambioRol, setCambioRol] = useState<{ usuario: Usuario; nuevo: string } | null>(null)
  const [guardandoRol, setGuardandoRol] = useState(false)
  const [errorRol, setErrorRol] = useState('')

  const sesion = obtenerUsuarioSesion()
  // Solo el superadmin gestiona el equipo; los demás roles solo ven su propia cuenta.
  const gestionaEquipo = tienePermiso(sesion, 'equipo')

  useEffect(() => {
    if (!gestionaEquipo) return
    let activo = true

    apiFetch<Usuario[]>('/usuarios')
      .then((lista) => {
        if (activo) setUsuarios(lista)
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar el equipo')
      })

    return () => {
      activo = false
    }
  }, [gestionaEquipo])

  // Los avisos que tu rol puede recibir; se guardan en el servidor, no en este navegador.
  useEffect(() => {
    let activo = true
    apiFetch<AjusteNotificacion[]>('/perfil/ajustes-notificacion')
      .then((lista) => {
        if (activo) setAjustes(lista)
      })
      .catch((e: unknown) => {
        if (activo) setErrorAjustes(e instanceof Error ? e.message : 'No se pudieron cargar los avisos')
      })
    return () => {
      activo = false
    }
  }, [])

  async function alternar(clave: string) {
    const actual = ajustes?.find((a) => a.clave === clave)
    if (!actual) return
    const nuevo = !actual.activa
    setErrorAjustes('')
    // Se muestra el cambio al instante; si el servidor falla, se devuelve.
    const marcar = (valor: boolean) =>
      setAjustes((prev) => (prev ? prev.map((a) => (a.clave === clave ? { ...a, activa: valor } : a)) : prev))
    marcar(nuevo)
    try {
      await apiFetch('/perfil/ajustes-notificacion', {
        method: 'PATCH',
        body: JSON.stringify({ clave, activa: nuevo }),
      })
    } catch (e) {
      marcar(!nuevo)
      setErrorAjustes(e instanceof Error ? e.message : 'No se pudo guardar el cambio')
    }
  }

  async function confirmarCambioRol() {
    if (!cambioRol) return
    setGuardandoRol(true)
    setErrorRol('')
    try {
      const actualizado = await apiFetch<Usuario>(`/usuarios/equipo/${cambioRol.usuario.id}/rol`, {
        method: 'PATCH',
        body: JSON.stringify({ rol_interno: cambioRol.nuevo }),
      })
      setUsuarios((prev) => (prev ? prev.map((u) => (u.id === actualizado.id ? actualizado : u)) : prev))
      setCambioRol(null)
    } catch (e) {
      setErrorRol(e instanceof Error ? e.message : 'No se pudo cambiar el rol')
      setCambioRol(null)
    } finally {
      setGuardandoRol(false)
    }
  }

  const administradores = (usuarios ?? []).filter((u) => u.rol === 'administrador')

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Configuración</div>
        <h1 className="page-title">Configuración general</h1>
        <p className="page-desc">Parámetros de la plataforma y permisos del equipo interno.</p>
      </div>

      {errorRol && (
        <div className="auth-error" style={{ display: 'block' }}>
          {errorRol}
        </div>
      )}

      <div className="panel">
        <div className="panel-head verde">
          <h2>Notificaciones</h2>
        </div>
        <div className="settings-group">
          {errorAjustes && (
            <div className="auth-error" style={{ display: 'block' }}>
              {errorAjustes}
            </div>
          )}
          {ajustes === null && !errorAjustes && <div className="setting-desc">Cargando avisos…</div>}
          {(ajustes ?? []).map((a) => (
            <div className="setting-row" key={a.clave}>
              <div>
                <div className="setting-label">{a.titulo}</div>
                <div className="setting-desc">{a.descripcion}</div>
              </div>
              <button
                className={a.activa ? 'toggle on' : 'toggle'}
                onClick={() => alternar(a.clave)}
                aria-label={a.titulo}
                aria-pressed={a.activa}
              ></button>
            </div>
          ))}
          <div className="setting-row proximamente">
            <div>
              <div className="setting-label">
                Avisos por correo <span className="etiqueta-pronto">Próximamente</span>
              </div>
              <div className="setting-desc">Recibir estos mismos avisos en tu correo y un resumen semanal.</div>
            </div>
            <button className="toggle" disabled aria-label="Avisos por correo (próximamente)"></button>
          </div>
        </div>
      </div>

      {gestionaEquipo ? (
      <div className="panel" style={{ marginTop: 20 }}>
        <div className="panel-head lila">
          <h2>Roles del equipo interno</h2>
          <button className="btn primary" onClick={() => setNuevoAbierto(true)}>
            + Nuevo miembro
          </button>
        </div>
        <table>
          <thead>
            <tr>
              <th>Persona</th>
              <th>Rol interno</th>
              <th>Permisos</th>
              <th>Seguridad</th>
            </tr>
          </thead>
          <tbody>
            {error ? (
              <tr>
                <td colSpan={4}>Error al cargar el equipo: {error}</td>
              </tr>
            ) : !usuarios ? (
              <tr>
                <td colSpan={4}>Cargando…</td>
              </tr>
            ) : administradores.length === 0 ? (
              <tr>
                <td colSpan={4}>No hay administradores registrados.</td>
              </tr>
            ) : (
              administradores.map((u) => {
                const esMia = !!sesion && (sesion.id === u.id || (!!u.email && sesion.email?.toLowerCase() === u.email.toLowerCase()))
                const rol = rolInternoDe(u)

                return (
                <tr key={u.id}>
                  <td>
                    <div className="cell-primary">{nombreCompleto(u)}</div>
                    <div className="cell-sub">{u.email ?? '—'}</div>
                  </td>
                  <td>
                    {esMia ? (
                      <span className="pill neutral">{ETIQUETA_ROL_INTERNO[rol] ?? rol} (tú)</span>
                    ) : (
                      <span className="select-rol-caja">
                        <select
                          className="select-rol"
                          value={rol}
                          onChange={(e) => setCambioRol({ usuario: u, nuevo: e.target.value })}
                          aria-label={`Rol interno de ${nombreCompleto(u)}`}
                        >
                          {ROLES_INTERNOS.map((r) => (
                            <option key={r} value={r}>
                              {ETIQUETA_ROL_INTERNO[r]}
                            </option>
                          ))}
                          {!(ROLES_INTERNOS as readonly string[]).includes(rol) && <option value={rol}>{rol}</option>}
                        </select>
                        <svg className="select-rol-flecha" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                          <path d="M6 9l6 6 6-6" />
                        </svg>
                      </span>
                    )}
                  </td>
                  <td>{DESCRIPCION_ROL_INTERNO[rol] ?? 'Sin permisos'}</td>
                  <td>{esMia && <CambiarContrasena />}</td>
                </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>
      ) : (
      <div className="panel" style={{ marginTop: 20 }}>
        <div className="panel-head lila">
          <h2>Mi cuenta</h2>
        </div>
        <div className="settings-group">
          <div className="setting-row">
            <div>
              <div className="setting-label">{sesion ? nombreCompleto(sesion) : ''}</div>
              <div className="setting-desc">
                {ETIQUETA_ROL_INTERNO[rolInternoDe(sesion)] ?? 'Administrador'} ·{' '}
                {DESCRIPCION_ROL_INTERNO[rolInternoDe(sesion)] ?? 'Sin permisos'}
              </div>
            </div>
            <CambiarContrasena />
          </div>
        </div>
      </div>
      )}

      {cambioRol && (
        <Modal
          titulo="Cambiar rol interno"
          onCerrar={() => setCambioRol(null)}
          pie={
            <>
              <button className="btn" onClick={() => setCambioRol(null)} disabled={guardandoRol}>
                Cancelar
              </button>
              <button className="btn primary" onClick={confirmarCambioRol} disabled={guardandoRol}>
                {guardandoRol ? 'Guardando…' : 'Cambiar rol'}
              </button>
            </>
          }
        >
          <p>
            ¿Cambiar el rol de <b>{nombreCompleto(cambioRol.usuario)}</b> a{' '}
            <b>{ETIQUETA_ROL_INTERNO[cambioRol.nuevo] ?? cambioRol.nuevo}</b>? El cambio se aplica de inmediato: perderá o ganará acceso a las
            secciones correspondientes la próxima vez que cargue una pantalla.
          </p>
        </Modal>
      )}

      {nuevoAbierto && (
        <FormularioMiembro
          onCerrar={() => setNuevoAbierto(false)}
          onCreado={(nuevo) => setUsuarios((prev) => (prev ? [...prev, nuevo] : prev))}
        />
      )}
    </>
  )
}