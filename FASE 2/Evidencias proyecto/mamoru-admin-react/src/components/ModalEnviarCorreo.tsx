import { useState } from 'react'
import Modal from './Modal'
import SelectorAdjuntos from './SelectorAdjuntos'
import { apiFetch, obtenerUsuarioSesion, type Usuario } from '../lib/api'
import { archivosABase64 } from '../lib/adjuntos'
import { nombreCompleto } from '../lib/formato'

interface Props {
  usuario: Usuario
  onCerrar: () => void
  onEnviado: (texto: string) => void
}

const LIMITE_MENSAJE = 5000

export default function ModalEnviarCorreo({ usuario, onCerrar, onEnviado }: Props) {
  const sesion = obtenerUsuarioSesion() as (Usuario & { email?: string | null }) | null
  const [asunto, setAsunto] = useState('Mensaje del equipo de Mamoru')
  const [mensaje, setMensaje] = useState('')
  const [archivos, setArchivos] = useState<File[]>([])
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')

  const puedeEnviar = asunto.trim() !== '' && mensaje.trim() !== '' && !enviando

  async function enviar() {
    if (!puedeEnviar) return
    setEnviando(true)
    setError('')
    try {
      const adjuntos = await archivosABase64(archivos)
      await apiFetch('/admin/enviar-correo', {
        method: 'POST',
        body: JSON.stringify({ usuario_id: usuario.id, asunto: asunto.trim(), mensaje, adjuntos }),
      })
      onEnviado(`Correo enviado a ${usuario.email}`)
      onCerrar()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo enviar el correo')
      setEnviando(false)
    }
  }

  return (
    <Modal
      titulo="Enviar correo"
      onCerrar={enviando ? () => {} : onCerrar}
      pie={
        <>
          <button className="btn" onClick={onCerrar} disabled={enviando}>
            Cancelar
          </button>
          <button className="btn primary" onClick={enviar} disabled={!puedeEnviar}>
            {enviando ? 'Enviando…' : 'Enviar correo'}
          </button>
        </>
      }
    >
      {error && (
        <div className="auth-error" style={{ display: 'block', marginBottom: 12 }}>
          {error}
        </div>
      )}

      <div className="campo-correo">
        <label>De</label>
        <div className="campo-correo-valor">
          {sesion ? nombreCompleto(sesion) : 'Tú'}
          {sesion?.email ? ` <${sesion.email}>` : ''}
        </div>
        <div className="cell-sub">Las respuestas llegarán a este correo.</div>
      </div>

      <div className="campo-correo">
        <label>Para</label>
        <div className="campo-correo-valor">
          {nombreCompleto(usuario)} {`<${usuario.email}>`}
        </div>
      </div>

      <div className="campo-correo">
        <label htmlFor="correo-asunto">Asunto</label>
        <input
          id="correo-asunto"
          type="text"
          maxLength={150}
          value={asunto}
          onChange={(e) => setAsunto(e.target.value)}
          disabled={enviando}
        />
      </div>

      <div className="campo-correo">
        <label htmlFor="correo-mensaje">Mensaje</label>
        <textarea
          id="correo-mensaje"
          rows={8}
          maxLength={LIMITE_MENSAJE}
          placeholder="Escribe aquí tu mensaje…"
          value={mensaje}
          onChange={(e) => setMensaje(e.target.value)}
          disabled={enviando}
        />
        <div className="cell-sub" style={{ textAlign: 'right' }}>
          {mensaje.length}/{LIMITE_MENSAJE}
        </div>
      </div>

      <div className="campo-correo">
        <label>Archivos adjuntos</label>
        <SelectorAdjuntos archivos={archivos} onCambio={setArchivos} deshabilitado={enviando} />
      </div>
    </Modal>
  )
}