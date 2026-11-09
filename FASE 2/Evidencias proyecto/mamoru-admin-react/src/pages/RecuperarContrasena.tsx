import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'
import { apiFetch } from '../lib/api'

// Canal entre pestañas del mismo navegador: cuando se abre el enlace del correo en otra pestaña,
// esta ventana (la que pidió el cambio) pasa sola a la pantalla de nueva contraseña.
const NOMBRE_CANAL = 'mamoru-recuperacion'

/** Paso 1: se pide el correo y el servidor envía el enlace para crear una nueva contraseña. */
export default function RecuperarContrasena() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [enviado, setEnviado] = useState(false)
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')

  // Mientras se espera el correo, escucha a la pestaña que abre el enlace.
  useEffect(() => {
    if (!enviado || typeof BroadcastChannel === 'undefined') return
    const canal = new BroadcastChannel(NOMBRE_CANAL)
    let usado = false
    canal.onmessage = (evento) => {
      const datos = evento.data as { tipo?: string; token?: unknown } | null
      if (usado || !datos || datos.tipo !== 'enlace' || typeof datos.token !== 'string') return
      usado = true
      canal.postMessage({ tipo: 'recibido' })
      navigate(`/restablecer-contrasena?token=${encodeURIComponent(datos.token)}`, {
        replace: true,
        state: { sinDifundir: true },
      })
    }
    return () => canal.close()
  }, [enviado, navigate])

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
          vence en 30 minutos. Si no lo ves, revisa también la carpeta de spam. Cuando presiones el botón, esta ventana pasará sola a crear tu nueva contraseña.
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