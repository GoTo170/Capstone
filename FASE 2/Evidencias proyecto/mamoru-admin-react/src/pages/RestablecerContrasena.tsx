import { useEffect, useState, type FormEvent } from 'react'
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import CampoContrasena from '../components/CampoContrasena'
import { apiFetch } from '../lib/api'

const NOMBRE_CANAL = 'mamoru-recuperacion'

/** Mismos requisitos que el registro de la app (el servidor los vuelve a comprobar). */
function requisitosDe(p: string) {
  return [
    { texto: 'Mínimo 8 caracteres', ok: p.length >= 8 },
    { texto: '1 mayúscula', ok: /[A-ZÁÉÍÓÚÑÜ]/.test(p) },
    { texto: '1 minúscula', ok: /[a-záéíóúñü]/.test(p) },
    { texto: '1 número', ok: /[0-9]/.test(p) },
    { texto: '1 carácter especial', ok: /[^A-Za-z0-9ÁÉÍÓÚÑÜáéíóúñü\s]/.test(p) },
  ]
}

/** Si hay otra pestaña de Mamoru esperando este enlace, se lo entrega y devuelve true. */
function ofrecerALaVentanaAnterior(token: string): Promise<boolean> {
  return new Promise((resolver) => {
    if (typeof BroadcastChannel === 'undefined') return resolver(false)
    const canal = new BroadcastChannel(NOMBRE_CANAL)
    const terminar = (r: boolean) => {
      window.clearTimeout(espera)
      canal.close()
      resolver(r)
    }
    const espera = window.setTimeout(() => terminar(false), 900)
    canal.onmessage = (e) => {
      if (e.data && e.data.tipo === 'recibido') terminar(true)
    }
    canal.postMessage({ tipo: 'enlace', token })
  })
}

/** Paso 2: pantalla a la que lleva el botón del correo (/restablecer-contrasena?token=...). */
export default function RestablecerContrasena() {
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const location = useLocation()
  const sinDifundir = Boolean((location.state as { sinDifundir?: boolean } | null)?.sinDifundir)
  const token = params.get('token') || ''

  const [estado, setEstado] = useState<'validando' | 'invalido' | 'otraVentana' | 'formulario' | 'listo'>('validando')
  const [nueva, setNueva] = useState('')
  const [confirmacion, setConfirmacion] = useState('')
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)

  // Comprueba al abrir si el enlace sigue vigente.
  useEffect(() => {
    if (!token) {
      setEstado('invalido')
      return
    }
    let activo = true
    apiFetch<{ valido: boolean }>(`/recuperar-contrasena/validar?token=${encodeURIComponent(token)}`)
      .then(async (r) => {
        if (!activo) return
        if (!r.valido) return setEstado('invalido')
        // Abierto desde el correo: si la ventana donde se pidió el cambio sigue abierta, sigue allí.
        const laTomoOtra = sinDifundir ? false : await ofrecerALaVentanaAnterior(token)
        if (activo) setEstado(laTomoOtra ? 'otraVentana' : 'formulario')
      })
      .catch(() => activo && setEstado('invalido'))
    return () => {
      activo = false
    }
  }, [token, sinDifundir])

  // Tras guardar, vuelve solo al login.
  useEffect(() => {
    if (estado !== 'listo') return
    const t = window.setTimeout(() => navigate('/login'), 3000)
    return () => window.clearTimeout(t)
  }, [estado, navigate])

  async function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    setError('')

    if (requisitosDe(nueva).some((r) => !r.ok)) {
      setError('La contraseña no cumple todos los requisitos de la lista.')
      return
    }
    if (nueva !== confirmacion) {
      setError('Las contraseñas no coinciden.')
      return
    }

    setGuardando(true)
    try {
      await apiFetch('/restablecer-contrasena', {
        method: 'POST',
        body: JSON.stringify({ token, password: nueva }),
      })
      setEstado('listo')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo cambiar la contraseña.')
    } finally {
      setGuardando(false)
    }
  }

  if (estado === 'validando') {
    return (
      <AuthLayout>
        <h1>Verificando enlace…</h1>
        <p className="auth-sub">Un momento, estamos comprobando tu enlace.</p>
      </AuthLayout>
    )
  }

  if (estado === 'invalido') {
    return (
      <AuthLayout>
        <h1>Enlace no válido</h1>
        <p className="auth-sub">
          Este enlace venció o ya fue usado. Pide uno nuevo para cambiar tu contraseña.
        </p>
        <Link to="/recuperar-contrasena" className="auth-submit auth-submit-link">
          Pedir un enlace nuevo
        </Link>
        <div className="auth-footer">
          <Link to="/login">← Volver a iniciar sesión</Link>
        </div>
      </AuthLayout>
    )
  }

  if (estado === 'otraVentana') {
    return (
      <AuthLayout>
        <h1>Correo confirmado</h1>
        <p className="auth-sub">
          Listo. Continúa en la ventana donde pediste el cambio: ahí ya puedes crear tu nueva
          contraseña. Puedes cerrar esta pestaña.
        </p>
        <div className="auth-footer">
          <button type="button" className="auth-link" onClick={() => setEstado('formulario')}>
            Continuar en esta ventana
          </button>
        </div>
      </AuthLayout>
    )
  }

  if (estado === 'listo') {
    return (
      <AuthLayout>
        <h1>Contraseña actualizada</h1>
        <p className="auth-sub">
          Listo, ya puedes iniciar sesión con tu nueva contraseña. Te llevamos al inicio de sesión…
        </p>
        <Link to="/login" className="auth-submit auth-submit-link">
          Ir a iniciar sesión
        </Link>
      </AuthLayout>
    )
  }

  return (
    <AuthLayout>
      <h1>Crea una nueva contraseña</h1>
      <p className="auth-sub">Verificamos tu identidad por correo. Ahora elige tu nueva contraseña.</p>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      <form onSubmit={manejarEnvio}>
        <div className="field">
          <label htmlFor="nueva">Nueva contraseña</label>
          <CampoContrasena
            id="nueva"
            placeholder="Mínimo 8 caracteres"
            autoComplete="new-password"
            value={nueva}
            onChange={(e) => setNueva(e.target.value)}
            required
          />
          <ul style={{ listStyle: 'none', padding: 0, margin: '8px 0 0', fontSize: '0.85rem' }}>
            {requisitosDe(nueva).map((r) => (
              <li key={r.texto} style={r.ok ? { color: '#3fb68b' } : { opacity: 0.65 }}>
                {r.ok ? '✓' : '○'} {r.texto}
              </li>
            ))}
          </ul>
        </div>
        <div className="field">
          <label htmlFor="confirmacion">Confirmar contraseña</label>
          <CampoContrasena
            id="confirmacion"
            placeholder="Repite la contraseña"
            autoComplete="new-password"
            value={confirmacion}
            onChange={(e) => setConfirmacion(e.target.value)}
            required
          />
        </div>
        <button type="submit" className="auth-submit" disabled={guardando}>
          {guardando ? 'Guardando…' : 'Guardar contraseña'}
        </button>
      </form>

      <div className="auth-footer">
        <Link to="/login">← Volver a iniciar sesión</Link>
      </div>
    </AuthLayout>
  )
}