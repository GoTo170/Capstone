import { useEffect, useState } from 'react'
import CambiarContrasena from '../components/CambiarContrasena'
import FormularioMiembro from '../components/FormularioMiembro'
import { apiFetch, obtenerUsuarioSesion, type Usuario } from '../lib/api'
import { nombreCompleto } from '../lib/formato'

const CLAVE_AJUSTES = 'mamoru_ajustes'

const AJUSTES = [
  {
    clave: 'notif_solicitudes',
    titulo: 'Notificar nuevas solicitudes de servicio',
    descripcion: 'Enviar un correo al equipo de soporte cuando una familia solicite un cuidador.',
    porDefecto: true,
  },
  {
    clave: 'notif_sos',
    titulo: 'Notificar alertas SOS',
    descripcion: 'Aviso inmediato al equipo de soporte ante cualquier botón SOS activado.',
    porDefecto: true,
  },
  {
    clave: 'resumen_semanal',
    titulo: 'Resumen semanal de adopción',
    descripcion: 'Correo con métricas de usuarios, cuidadores y solicitudes cada lunes.',
    porDefecto: false,
  },
]

function cargarAjustes(): Record<string, boolean> {
  const base: Record<string, boolean> = Object.fromEntries(AJUSTES.map((a) => [a.clave, a.porDefecto]))
  try {
    const guardado = JSON.parse(localStorage.getItem(CLAVE_AJUSTES) ?? '{}') as Record<string, boolean>
    return { ...base, ...guardado }
  } catch {
    return base
  }
}

export default function Config() {
  const [usuarios, setUsuarios] = useState<Usuario[] | null>(null)
  const [error, setError] = useState('')
  const [activos, setActivos] = useState<Record<string, boolean>>(cargarAjustes)
  const [nuevoAbierto, setNuevoAbierto] = useState(false)

  useEffect(() => {
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
  }, [])

  function alternar(clave: string) {
    const siguiente = { ...activos, [clave]: !activos[clave] }
    setActivos(siguiente)
    localStorage.setItem(CLAVE_AJUSTES, JSON.stringify(siguiente))
  }

  const sesion = obtenerUsuarioSesion()
  const administradores = (usuarios ?? []).filter((u) => u.rol === 'administrador')

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Configuración</div>
        <h1 className="page-title">Configuración general</h1>
        <p className="page-desc">Parámetros de la plataforma y permisos del equipo interno.</p>
      </div>

      <div className="panel">
        <div className="panel-head verde">
          <h2>Notificaciones</h2>
        </div>
        <div className="settings-group">
          {AJUSTES.map((a) => (
            <div className="setting-row" key={a.clave}>
              <div>
                <div className="setting-label">{a.titulo}</div>
                <div className="setting-desc">{a.descripcion}</div>
              </div>
              <button
                className={activos[a.clave] ? 'toggle on' : 'toggle'}
                onClick={() => alternar(a.clave)}
                aria-label={a.titulo}
                aria-pressed={activos[a.clave]}
              ></button>
            </div>
          ))}
        </div>
      </div>

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
              administradores.map((u) => (
                <tr key={u.id}>
                  <td>
                    <div className="cell-primary">{nombreCompleto(u)}</div>
                    <div className="cell-sub">{u.email ?? '—'}</div>
                  </td>
                  <td>
                    <span className="pill neutral">Administrador</span>
                  </td>
                  <td>Acceso total</td>
                  <td>
                    {sesion && (sesion.id === u.id || (!!u.email && sesion.email?.toLowerCase() === u.email.toLowerCase())) && (
                      <CambiarContrasena />
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {nuevoAbierto && (
        <FormularioMiembro
          onCerrar={() => setNuevoAbierto(false)}
          onCreado={(nuevo) => setUsuarios((prev) => (prev ? [...prev, nuevo] : prev))}
        />
      )}
    </>
  )
}