import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import { apiFetch } from '../lib/api'

/** Paso 1: se pide el correo y el servidor envía el enlace para crear una nueva contraseña. */
export default function RecuperarContrasena() {
  const [email, setEmail] = useState('')
  const [enviado, setEnviado] = useState(false)
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')

  async function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    setError('')
    setEnviando(true)
    try {
      await apiFetch('/recuperar-contrasena', {
        method: 'POST',
        body: JSON.stringify({ email: email.trim() }),
      })
      setEnviado(true)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo enviar el correo. Intenta de nuevo.')
    } finally {
      setEnviando(false)
    }
  }

  if (enviado) {
    return (
      <AuthLayout>
        <h1>Revisa tu correo</h1>
        <p className="auth-sub">
          Si <b>{email.trim()}</b> corresponde a una cuenta, te enviamos un correo para confirmar
          que fuiste tú. Presiona el botón del mensaje para crear tu nueva contraseña. El enlace
          vence en 30 minutos. Si no lo ves, revisa también la carpeta de spam.
        </p>

        <div className="auth-footer">
          <button type="button" className="auth-link" onClick={() => setEnviado(false)}>
            Usar otro correo
          </button>
          {' · '}
          <Link to="/login">Volver a iniciar sesión</Link>
        </div>
      </AuthLayout>
    )
  }

  return (
    <AuthLayout>
      <h1>¿Olvidaste tu contraseña?</h1>
      <p className="auth-sub">
        Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva.
      </p>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      <form onSubmit={manejarEnvio}>
        <div className="field">
          <label htmlFor="email">Correo institucional</label>
          <input
            type="email"
            id="email"
            placeholder="nombre@mamoru.cl"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        <button type="submit" className="auth-submit" disabled={enviando}>
          {enviando ? 'Enviando…' : 'Enviar enlace'}
        </button>
      </form>

      <div className="auth-footer">
        <Link to="/login">← Volver a iniciar sesión</Link>
      </div>
    </AuthLayout>
  )
}