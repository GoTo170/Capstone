import { useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { apiFetch, guardarSesion, obtenerToken, type LoginResponse } from '../lib/api'

export default function Login() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  if (obtenerToken()) return <Navigate to="/" replace />

  async function manejarEnvio(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    setError('')
    setCargando(true)

    try {
      const data = await apiFetch<LoginResponse>('/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      })

      if (data.usuario.rol !== 'administrador') {
        setError('Esta cuenta no tiene permisos para acceder al panel administrativo.')
        return
      }

      guardarSesion(data.access_token, data.usuario)
      navigate('/')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Correo o contraseña incorrectos.')
    } finally {
      setCargando(false)
    }
  }

  return (
    <div className="auth-shell">
      <div className="auth-brand-side">
        <div className="auth-decor-shape circle-big"></div>
        <div className="auth-decor-shape capsule"></div>
        <div className="auth-decor-shape ring"></div>
        <div className="auth-decor-dots"></div>

        <div className="auth-brand-text">
          <div className="auth-eyebrow">Acceso centralizado</div>
          <h2 className="auth-headline">
            Panel
            <br />
            <span className="subrayado">Administrativo</span>
          </h2>
        </div>

        <div className="auth-connector">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M5 12h14M13 6l6 6-6 6" />
          </svg>
        </div>

        <div className="auth-brand-foot">© 2026 Mamoru — Acceso exclusivo para el equipo interno.</div>
      </div>

      <div className="auth-form-side">
        <img src="/logo.png" alt="Mamoru" className="auth-top-logo" />
        <div className="slogan auth-top-slogan">
          Amor · <span className="destacado">Protección</span> · Servicio
        </div>

        <div className="auth-card">
          <h1>Bienvenido de vuelta</h1>
          <p className="auth-sub">Inicia sesión con tu cuenta del equipo Mamoru.</p>

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
            <div className="field">
              <label htmlFor="password">Contraseña</label>
              <input
                type="password"
                id="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>
            <div className="auth-olvido">
              <Link to="/recuperar-contrasena">¿Olvidaste tu contraseña?</Link>
            </div>
            <button type="submit" className="auth-submit" disabled={cargando}>
              {cargando ? 'Ingresando…' : 'Iniciar sesión'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}