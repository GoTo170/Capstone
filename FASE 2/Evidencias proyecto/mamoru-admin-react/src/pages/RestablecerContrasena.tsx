import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import AuthLayout from '../components/AuthLayout'

const MINIMO = 8

/**
 * Paso 2: pantalla a la que lleva el enlace del correo.
 * Por ahora es SOLO VISUAL: valida los campos pero no cambia nada en el servidor.
 */
export default function RestablecerContrasena() {
  const [nueva, setNueva] = useState('')
  const [confirmacion, setConfirmacion] = useState('')
  const [error, setError] = useState('')
  const [listo, setListo] = useState(false)

  function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
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

    // TODO (cuando haya correos): enviar el token del enlace + la nueva contraseña al backend.
    setListo(true)
  }

  if (listo) {
    return (
      <AuthLayout>
        <h1>Contraseña actualizada</h1>
        <p className="auth-sub">Ya puedes iniciar sesión con tu nueva contraseña.</p>

        <div className="aviso-ok">
          Modo demostración: la contraseña real todavía no se modificó.
        </div>

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
          <input
            type="password"
            id="nueva"
            placeholder="Mínimo 8 caracteres"
            value={nueva}
            onChange={(e) => setNueva(e.target.value)}
            required
          />
        </div>
        <div className="field">
          <label htmlFor="confirmacion">Confirmar contraseña</label>
          <input
            type="password"
            id="confirmacion"
            placeholder="Repite la contraseña"
            value={confirmacion}
            onChange={(e) => setConfirmacion(e.target.value)}
            required
          />
        </div>
        <button type="submit" className="auth-submit">
          Guardar contraseña
        </button>
      </form>

      <div className="auth-footer">
        <Link to="/login">← Volver a iniciar sesión</Link>
      </div>
    </AuthLayout>
  )
}