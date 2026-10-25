import { useEffect, useRef, useState } from 'react'
import { apiFetch } from '../lib/api'
import { formatearFechaHora } from '../lib/formato'
import type { Notificacion } from '../lib/tipos'

export default function Notificaciones() {
  const [notificaciones, setNotificaciones] = useState<Notificacion[]>([])
  const [cargadas, setCargadas] = useState(false)
  const [abierto, setAbierto] = useState(false)
  const [punto, setPunto] = useState(false)
  const contenedor = useRef<HTMLDivElement>(null)

  useEffect(() => {
    let activo = true

    apiFetch<Notificacion[]>('/notificaciones')
      .then((todas) => {
        if (!activo) return
        const recientes = [...todas]
          .sort((a, b) => new Date(b.fecha_envio).getTime() - new Date(a.fecha_envio).getTime())
          .slice(0, 8)
        setNotificaciones(recientes)
        setPunto(recientes.some((n) => !n.leida))
        setCargadas(true)
      })
      .catch(() => {
        if (activo) setCargadas(true)
      })

    return () => {
      activo = false
    }
  }, [])

  useEffect(() => {
    function clicFuera(evento: MouseEvent) {
      if (contenedor.current && !contenedor.current.contains(evento.target as Node)) {
        setAbierto(false)
      }
    }
    document.addEventListener('mousedown', clicFuera)
    return () => document.removeEventListener('mousedown', clicFuera)
  }, [])

  async function alternar() {
    const abriendo = !abierto
    setAbierto(abriendo)

    if (abriendo && punto) {
      setPunto(false)
      try {
        await apiFetch('/notificaciones/marcar-leidas', { method: 'PATCH' })
      } catch (e) {
        console.error('No se pudieron marcar como leídas:', e)
      }
    }
  }

  return (
    <div className="notif-wrapper" ref={contenedor}>
      <button className="icon-btn" onClick={alternar} title="Notificaciones">
        <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
          <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" />
          <path d="M13.7 21a2 2 0 0 1-3.4 0" />
        </svg>
        {punto && <span className="dot"></span>}
      </button>

      <div className={abierto ? 'notif-dropdown open' : 'notif-dropdown'}>
        {!cargadas ? (
          <div className="notif-empty">Cargando…</div>
        ) : notificaciones.length === 0 ? (
          <div className="notif-empty">No tienes notificaciones.</div>
        ) : (
          notificaciones.map((n) => (
            <div key={n.id} className={n.leida ? 'notif-item' : 'notif-item unread'}>
              {n.mensaje}
              <div style={{ color: 'var(--ink-faint)', fontSize: 11, marginTop: 4 }}>
                {formatearFechaHora(n.fecha_envio)}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}