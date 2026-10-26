import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'

/**
 * Paso 1 de la recuperación de contraseña.
 * Por ahora es SOLO VISUAL: todavía no se envían correos.
 * Cuando exista el envío de correos, aquí se llamará al backend.
 */
export default function RecuperarContrasena() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [enviado, setEnviado] = useState(false)

  function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    // TODO (cuando haya correos): POST al backend con el email.
    setEnviado(true)
  }

  if (enviado) {
    return (
      <AuthLayout>
        <h1>Revisa tu correo</h1>
        <p className="auth-sub">
          Si <b>{email}</b> corresponde a una cuenta del equipo, te enviamos un enlace para
          cambiar tu contraseña. El enlace verifica que fuiste tú quien lo pidió y vence en
          30 minutos.
        </p>

        <div className="aviso-ok">
          Modo demostración: todavía no se envían correos reales.
        </div>

        <button
          type="button"
          className="auth-submit"
          onClick={() => navigate('/restablecer-contrasena')}
        >
          Abrir el enlace del correo (simulación)
        </button>

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
        <button type="submit" className="auth-submit">
          Enviar enlace
        </button>
      </form>

      <div className="auth-footer">
        <Link to="/login">← Volver a iniciar sesión</Link>
      </div>
    </AuthLayout>
  )
}