import { useState } from 'react'
import type { CSSProperties } from 'react'
import { useNavigate } from 'react-router-dom'
import Modal from './Modal'
import { apiFetch, cerrarSesion } from '../lib/api'

const LARGO_MINIMO = 8

const estiloCampo: CSSProperties = {
  width: '100%',
  padding: '9px 10px',
  border: '1px solid var(--border)',
  borderRadius: 8,
  background: 'var(--surface)',
  color: 'var(--ink)',
  fontFamily: 'inherit',
  fontSize: 13,
  boxSizing: 'border-box',
  marginBottom: 10,
}

const estiloEtiqueta: CSSProperties = { display: 'block', fontSize: 12, marginBottom: 4 }

type Paso = 'cerrado' | 'actual' | 'nueva'

/**
 * Botón "Cambiar contraseña" con sus dos ventanas flotantes:
 *  1) pide la contraseña actual y la comprueba en el servidor;
 *  2) pide la contraseña nueva y su confirmación.
 * Al terminar cierra la sesión y lleva al login.
 */
export default function CambiarContrasena() {
  const navigate = useNavigate()
  const [paso, setPaso] = useState<Paso>('cerrado')
  const [actual, setActual] = useState('')
  const [nueva, setNueva] = useState('')
  const [confirmacion, setConfirmacion] = useState('')
  const [error, setError] = useState('')
  const [procesando, setProcesando] = useState(false)

  function cerrar() {
    if (procesando) return
    setPaso('cerrado')
    setActual('')
    setNueva('')
    setConfirmacion('')
    setError('')
  }

  async function verificarActual() {
    if (!actual) {
      setError('Escribe tu contraseña actual')
      return
    }
    setProcesando(true)
    setError('')
    try {
      await apiFetch('/perfil/verificar-contrasena', {
        method: 'POST',
        body: JSON.stringify({ password_actual: actual }),
      })
      setPaso('nueva')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo comprobar la contraseña')
    } finally {
      setProcesando(false)
    }
  }

  async function guardarNueva() {
    if (nueva.length < LARGO_MINIMO) {
      setError(`La contraseña nueva debe tener al menos ${LARGO_MINIMO} caracteres`)
      return
    }
    if (nueva === actual) {
      setError('La contraseña nueva debe ser distinta de la actual')
      return
    }
    if (nueva !== confirmacion) {
      setError('La confirmación no coincide con la contraseña nueva')
      return
    }
    setProcesando(true)
    setError('')
    try {
      await apiFetch('/perfil/contrasena', {
        method: 'PATCH',
        body: JSON.stringify({ password_actual: actual, password_nueva: nueva }),
      })
      cerrarSesion()
      navigate('/login')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo cambiar la contraseña')
      setProcesando(false)
    }
  }

  return (
    <>
      <button className="btn primary" onClick={() => setPaso('actual')}>
        Cambiar contraseña
      </button>

      {paso === 'actual' && (
        <Modal
          titulo="Confirma tu contraseña actual"
          onCerrar={cerrar}
          pie={
            <>
              <button className="btn" onClick={cerrar} disabled={procesando}>
                Cancelar
              </button>
              <button className="btn primary" onClick={verificarActual} disabled={procesando}>
                {procesando ? 'Comprobando…' : 'Continuar'}
              </button>
            </>
          }
        >
          <form
            onSubmit={(e) => {
              e.preventDefault()
              verificarActual()
            }}
          >
            <label style={estiloEtiqueta} htmlFor="pw-actual">
              Contraseña actual
            </label>
            <input
              id="pw-actual"
              type="password"
              style={estiloCampo}
              autoFocus
              autoComplete="current-password"
              value={actual}
              onChange={(e) => setActual(e.target.value)}
            />
            {error && <div className="auth-error" style={{ display: 'block' }}>{error}</div>}
          </form>
        </Modal>
      )}

      {paso === 'nueva' && (
        <Modal
          titulo="Elige tu contraseña nueva"
          onCerrar={cerrar}
          pie={
            <>
              <button className="btn" onClick={cerrar} disabled={procesando}>
                Cancelar
              </button>
              <button className="btn primary" onClick={guardarNueva} disabled={procesando}>
                {procesando ? 'Guardando…' : 'Cambiar contraseña'}
              </button>
            </>
          }
        >
          <form
            onSubmit={(e) => {
              e.preventDefault()
              guardarNueva()
            }}
          >
            <label style={estiloEtiqueta} htmlFor="pw-nueva">
              Contraseña nueva (mínimo {LARGO_MINIMO} caracteres)
            </label>
            <input
              id="pw-nueva"
              type="password"
              style={estiloCampo}
              autoFocus
              autoComplete="new-password"
              value={nueva}
              onChange={(e) => setNueva(e.target.value)}
            />
            <label style={estiloEtiqueta} htmlFor="pw-confirmacion">
              Repite la contraseña nueva
            </label>
            <input
              id="pw-confirmacion"
              type="password"
              style={estiloCampo}
              autoComplete="new-password"
              value={confirmacion}
              onChange={(e) => setConfirmacion(e.target.value)}
            />
            <p style={{ fontSize: 12, opacity: 0.8 }}>Al guardar, tu sesión se cerrará y tendrás que entrar con la contraseña nueva.</p>
            {error && <div className="auth-error" style={{ display: 'block' }}>{error}</div>}
          </form>
        </Modal>
      )}
    </>
  )
}