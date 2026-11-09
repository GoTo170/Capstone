import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import CampoContrasena from '../components/CampoContrasena'
import { apiFetch } from '../lib/api'

const MINIMO = 8

/** Paso 2: pantalla a la que lleva el botón del correo (/restablecer-contrasena?token=...). */
export default function RestablecerContrasena() {
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const token = params.get('token') || ''

  const [estado, setEstado] = useState<'validando' | 'invalido' | 'formulario' | 'listo'>('validando')
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
      .then((r) => activo && setEstado(r.valido ? 'formulario' : 'invalido'))
      .catch(() => activo && setEstado('invalido'))
    return () => {
      activo = false
    }
  }, [token])

  // Tras guardar, vuelve solo al login.
  useEffect(() => {
    if (estado !== 'listo') return
    const t = window.setTimeout(() => navigate('/login'), 3000)
    return () => window.clearTimeout(t)
  }, [estado, navigate])

  async function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    setError('')

    if (nueva.length < MINIMO) {
      setError(`La contraseña debe tener al menos ${MINIMO} caracteres.`)
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