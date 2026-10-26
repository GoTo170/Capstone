import type { ReactNode } from 'react'

/** Marco de las pantallas de acceso (mismo diseño que el login). */
export default function AuthLayout({ children }: { children: ReactNode }) {
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

        <div className="auth-card">{children}</div>
      </div>
    </div>
  )
}