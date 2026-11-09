import { useState, type FormEvent } from 'react'
import { DESCRIPCION_ROL_INTERNO, ETIQUETA_ROL_INTERNO, ROLES_INTERNOS, apiFetch, rolInternoDe, type Usuario } from '../lib/api'
import { normalizar } from '../lib/busqueda'
import { nombreCompleto } from '../lib/formato'
import Modal from './Modal'
import CampoContrasena from './CampoContrasena'
import RequisitosContrasena from './RequisitosContrasena'
import { cumpleRequisitos, MENSAJE_REQUISITOS } from '../lib/contrasena'

interface Props {
  onCerrar: () => void
  onCreado: (usuario: Usuario) => void
}

interface Creado {
  usuario: Usuario
  password: string
}

function generarPassword(nombre: string): string {
  const limpio = nombre.trim()
  return limpio ? `${limpio[0].toUpperCase()}mamoru_170` : ''
}

function descargarCredenciales({ usuario, password }: Creado) {
  const lineas = [
    'MAMORU — Credenciales de acceso al Panel Administrativo',
    '',
    `Nombre: ${nombreCompleto(usuario)}`,
    `Rol: ${ETIQUETA_ROL_INTERNO[rolInternoDe(usuario)] ?? 'Administrador'}`,
    `Correo: ${usuario.email ?? ''}`,
    `Contraseña: ${password}`,
    '',
    `Ingreso: ${window.location.origin}/login`,
    `Generado el: ${new Date().toLocaleString('es-CL')}`,
    '',
    'Guarda este archivo en un lugar seguro y no lo compartas por canales públicos.',
  ]

  const blob = new Blob([lineas.join('\r\n')], { type: 'text/plain;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const enlace = document.createElement('a')
  enlace.href = url
  enlace.download = `credenciales-${normalizar(nombreCompleto(usuario)).replace(/[^a-z0-9]+/g, '-')}.txt`
  document.body.appendChild(enlace)
  enlace.click()
  enlace.remove()
  URL.revokeObjectURL(url)
}

export default function FormularioMiembro({ onCerrar, onCreado }: Props) {
  const [nombre, setNombre] = useState('')
  const [apellido, setApellido] = useState('')
  const [email, setEmail] = useState('')
  // Por defecto el de menos alcance: el superadmin se elige a propósito.
  const [rolInterno, setRolInterno] = useState<string>('soporte')
  const [automatica, setAutomatica] = useState(true)
  const [password, setPassword] = useState('')
  const [confirmar, setConfirmar] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [creado, setCreado] = useState<Creado | null>(null)

  const generada = generarPassword(nombre)

  async function enviar(evento: FormEvent<HTMLFormElement>) {
    evento.preventDefault()
    setError('')

    const claveFinal = automatica ? generada : password

    if (!cumpleRequisitos(claveFinal)) {
      setError(MENSAJE_REQUISITOS)
      return
    }
    if (!automatica) {
      if (password !== confirmar) {
        setError('Las contraseñas no coinciden.')
        return
      }
    }

    setEnviando(true)
    try {
      const usuario = await apiFetch<Usuario>('/usuarios/equipo', {
        method: 'POST',
        body: JSON.stringify({
          nombre: nombre.trim(),
          apellido: apellido.trim(),
          email: email.trim(),
          password: claveFinal,
          rol: 'administrador',
          rol_interno: rolInterno,
        }),
      })
      setCreado({ usuario, password: claveFinal })
      onCreado(usuario)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo crear el miembro.')
    } finally {
      setEnviando(false)
    }
  }

  if (creado) {
    return (
      <Modal
        titulo="Miembro creado"
        ancho={520}
        onCerrar={onCerrar}
        pie={
          <>
            <button className="btn" onClick={onCerrar}>
              Cerrar
            </button>
            <button className="btn primary" onClick={() => descargarCredenciales(creado)}>
              Descargar credenciales
            </button>
          </>
        }
      >
        <div className="aviso-ok">
          La cuenta de <b>{nombreCompleto(creado.usuario)}</b> se creó correctamente.
        </div>
        <dl className="detalle-lista">
          <dt>Correo</dt>
          <dd>{creado.usuario.email}</dd>
          <dt>Contraseña</dt>
          <dd>{creado.password}</dd>
          <dt>Rol</dt>
          <dd>{ETIQUETA_ROL_INTERNO[rolInternoDe(creado.usuario)] ?? creado.usuario.rol}</dd>
        </dl>
        <p className="ayuda">
          La contraseña solo se muestra ahora: el sistema la guarda cifrada y no podrá volver a consultarse. Descarga
          las credenciales para entregárselas.
        </p>
      </Modal>
    )
  }

  return (
    <Modal
      titulo="Nuevo miembro del equipo"
      ancho={520}
      onCerrar={onCerrar}
      pie={
        <>
          <button type="button" className="btn" onClick={onCerrar} disabled={enviando}>
            Cancelar
          </button>
          <button type="submit" form="form-miembro" className="btn primary" disabled={enviando}>
            {enviando ? 'Creando…' : 'Crear miembro'}
          </button>
        </>
      }
    >
      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      <form id="form-miembro" onSubmit={enviar}>
        <div className="field-row">
          <div className="field">
            <label htmlFor="mm-nombre">Nombre</label>
            <input id="mm-nombre" value={nombre} onChange={(e) => setNombre(e.target.value)} required />
          </div>
          <div className="field">
            <label htmlFor="mm-apellido">Apellido</label>
            <input id="mm-apellido" value={apellido} onChange={(e) => setApellido(e.target.value)} required />
          </div>
        </div>

        <div className="field">
          <label htmlFor="mm-email">Correo</label>
          <input
            id="mm-email"
            type="email"
            placeholder="nombre@mamoru.cl"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>

        <div className="field">
          <label htmlFor="mm-rol">Rol</label>
          <select id="mm-rol" value={rolInterno} onChange={(e) => setRolInterno(e.target.value)}>
            {ROLES_INTERNOS.map((r) => (
              <option key={r} value={r}>
                {ETIQUETA_ROL_INTERNO[r]}
              </option>
            ))}
          </select>
          <div className="ayuda">{DESCRIPCION_ROL_INTERNO[rolInterno]}</div>
        </div>

        <label className="opcion-check">
          <input type="checkbox" checked={automatica} onChange={(e) => setAutomatica(e.target.checked)} />
          Generar contraseña automáticamente
        </label>

        {automatica ? (
          <div className="field">
            <label htmlFor="mm-pass-auto">Contraseña</label>
            <input id="mm-pass-auto" type="text" value={generada || '—'} readOnly />
            <div className="ayuda">Inicial del nombre en mayúscula + mamoru_170.</div>
          </div>
        ) : (
          <div className="field-row">
            <div className="field">
              <label htmlFor="mm-pass">Contraseña</label>
              <CampoContrasena
                id="mm-pass"
                minLength={8}
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <RequisitosContrasena valor={password} />
            </div>
            <div className="field">
              <label htmlFor="mm-pass2">Confirmar contraseña</label>
              <CampoContrasena
                id="mm-pass2"
                autoComplete="new-password"
                value={confirmar}
                onChange={(e) => setConfirmar(e.target.value)}
                required
              />
            </div>
          </div>
        )}
      </form>
    </Modal>
  )
}