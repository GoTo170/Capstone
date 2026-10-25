import { useEffect, useState } from 'react'
import BarraBusqueda from '../components/BarraBusqueda'
import MenuAcciones, { type OpcionMenu } from '../components/MenuAcciones'
import Modal from '../components/Modal'
import PanelFiltros from '../components/PanelFiltros'
import { apiFetch, obtenerUsuarioSesion, type Usuario } from '../lib/api'
import { contiene } from '../lib/busqueda'
import { formatearFecha, formatearFechaCompleta, nombreCompleto } from '../lib/formato'

interface Filtros {
  rol: string
  estado: string
  desde: string
  hasta: string
}

type Accion = { tipo: 'detalle' | 'deshabilitar' | 'habilitar'; usuario: Usuario }

const SIN_FILTROS: Filtros = { rol: '', estado: '', desde: '', hasta: '' }

const ETIQUETA_ROL: Record<string, string> = {
  adulto_mayor: 'Adulto mayor',
  familiar: 'Familiar',
  cuidador: 'Cuidador',
  administrador: 'Administrador',
}

const CHIPS = [
  { valor: '', texto: 'Todos' },
  { valor: 'adulto_mayor', texto: 'Adulto mayor' },
  { valor: 'familiar', texto: 'Familiar' },
  { valor: 'cuidador', texto: 'Cuidador' },
  { valor: 'administrador', texto: 'Administrador' },
]

function cumple(usuario: Usuario, busqueda: string, f: Filtros): boolean {
  if (f.rol && usuario.rol !== f.rol) return false
  if (f.estado === 'activo' && !usuario.activo) return false
  if (f.estado === 'suspendido' && usuario.activo) return false

  const dia = usuario.fecha_creacion.slice(0, 10)
  if (f.desde && dia < f.desde) return false
  if (f.hasta && dia > f.hasta) return false

  if (busqueda && !contiene(`${nombreCompleto(usuario)} ${usuario.email ?? ''}`, busqueda)) return false
  return true
}

export default function Usuarios() {
  const [usuarios, setUsuarios] = useState<Usuario[] | null>(null)
  const [error, setError] = useState('')
  const [aviso, setAviso] = useState('')
  const [busqueda, setBusqueda] = useState('')
  const [filtros, setFiltros] = useState<Filtros>(SIN_FILTROS)
  const [accion, setAccion] = useState<Accion | null>(null)
  const [procesando, setProcesando] = useState(false)

  const miId = obtenerUsuarioSesion()?.id

  useEffect(() => {
    let activo = true

    apiFetch<Usuario[]>('/usuarios')
      .then((lista) => {
        if (activo) setUsuarios(lista)
      })
      .catch((e: unknown) => {
        if (activo) setError(e instanceof Error ? e.message : 'Error al cargar usuarios')
      })

    return () => {
      activo = false
    }
  }, [])

  function mostrarAviso(texto: string) {
    setAviso(texto)
    setTimeout(() => setAviso(''), 2500)
  }

  async function copiarCorreo(correo: string) {
    try {
      await navigator.clipboard.writeText(correo)
      mostrarAviso('Correo copiado al portapapeles')
    } catch {
      mostrarAviso('No se pudo copiar el correo')
    }
  }

  async function confirmarEstado(usuario: Usuario, activo: boolean) {
    setProcesando(true)
    setError('')
    try {
      const actualizado = await apiFetch<Usuario>(`/usuarios/${usuario.id}/estado`, {
        method: 'PATCH',
        body: JSON.stringify({ activo }),
      })
      setUsuarios((prev) => (prev ? prev.map((u) => (u.id === actualizado.id ? actualizado : u)) : prev))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error al cambiar el estado de la cuenta')
    } finally {
      setProcesando(false)
      setAccion(null)
    }
  }

  function opcionesDe(usuario: Usuario): OpcionMenu[] {
    const opciones: OpcionMenu[] = [
      { texto: 'Ver detalles', onClick: () => setAccion({ tipo: 'detalle', usuario }) },
    ]

    if (usuario.email) {
      const correo = usuario.email
      opciones.push({ texto: 'Copiar correo', onClick: () => copiarCorreo(correo) })
    }

    if (usuario.activo) {
      const esMia = usuario.id === miId
      opciones.push({
        texto: esMia ? 'No puedes deshabilitar tu cuenta' : 'Deshabilitar cuenta',
        peligro: true,
        deshabilitada: esMia,
        onClick: () => setAccion({ tipo: 'deshabilitar', usuario }),
      })
    } else {
      opciones.push({ texto: 'Habilitar cuenta', onClick: () => setAccion({ tipo: 'habilitar', usuario }) })
    }

    return opciones
  }

  const cambiar = (parcial: Partial<Filtros>) => setFiltros((prev) => ({ ...prev, ...parcial }))
  const filtrosActivos = Object.values(filtros).filter(Boolean).length

  const lista = usuarios ?? []
  const visibles = lista
    .filter((u) => cumple(u, busqueda, filtros))
    .sort((a, b) => new Date(b.fecha_creacion).getTime() - new Date(a.fecha_creacion).getTime())

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Usuarios</div>
        <h1 className="page-title">Usuarios</h1>
        <p className="page-desc">Búsqueda y gestión de cuentas de adultos mayores, familiares y cuidadores.</p>
      </div>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}
      {aviso && <div className="aviso-ok">{aviso}</div>}

      <div className="toolbar">
        <div className="filters">
          {CHIPS.map((chip) => (
            <button
              key={chip.valor}
              className={filtros.rol === chip.valor ? 'filter-chip active' : 'filter-chip'}
              onClick={() => cambiar({ rol: chip.valor })}
            >
              {usuarios
                ? `${chip.texto} (${lista.filter((u) => cumple(u, busqueda, { ...filtros, rol: chip.valor })).length})`
                : chip.texto}
            </button>
          ))}
        </div>

        <div className="toolbar-tools">
          <BarraBusqueda valor={busqueda} onCambio={setBusqueda} placeholder="Buscar por nombre o correo…" />

          <PanelFiltros activos={filtrosActivos} onLimpiar={() => setFiltros(SIN_FILTROS)}>
            <div className="filtro-campo">
              <label>Rol</label>
              <select value={filtros.rol} onChange={(e) => cambiar({ rol: e.target.value })}>
                <option value="">Todos</option>
                {Object.entries(ETIQUETA_ROL).map(([valor, texto]) => (
                  <option key={valor} value={valor}>
                    {texto}
                  </option>
                ))}
              </select>
            </div>

            <div className="filtro-campo">
              <label>Estado</label>
              <select value={filtros.estado} onChange={(e) => cambiar({ estado: e.target.value })}>
                <option value="">Todos</option>
                <option value="activo">Activo</option>
                <option value="suspendido">Suspendido</option>
              </select>
            </div>

            <div className="filtro-campo">
              <label>Fecha de registro</label>
              <div className="filtro-rango">
                <div>
                  <label className="sub">Desde</label>
                  <input
                    type="date"
                    value={filtros.desde}
                    max={filtros.hasta || undefined}
                    onChange={(e) => cambiar({ desde: e.target.value })}
                  />
                </div>
                <div>
                  <label className="sub">Hasta</label>
                  <input
                    type="date"
                    value={filtros.hasta}
                    min={filtros.desde || undefined}
                    onChange={(e) => cambiar({ hasta: e.target.value })}
                  />
                </div>
              </div>
            </div>
          </PanelFiltros>
        </div>
      </div>

      <div className="panel">
        <table>
          <thead>
            <tr>
              <th>Usuario</th>
              <th>Rol</th>
              <th>Estado</th>
              <th>Registro</th>
              <th className="col-acciones"></th>
            </tr>
          </thead>
          <tbody>
            {!usuarios ? (
              <tr>
                <td colSpan={5}>{error ? 'No se pudo cargar.' : 'Cargando usuarios…'}</td>
              </tr>
            ) : visibles.length === 0 ? (
              <tr>
                <td colSpan={5}>
                  {lista.length === 0
                    ? 'Todavía no hay usuarios registrados.'
                    : 'Ningún usuario coincide con la búsqueda o los filtros.'}
                </td>
              </tr>
            ) : (
              visibles.map((u) => (
                <tr key={u.id}>
                  <td>
                    <div className="cell-primary">{nombreCompleto(u)}</div>
                    <div className="cell-sub">{u.email ?? 'Sin correo (acceso por código)'}</div>
                  </td>
                  <td>
                    <span className="pill neutral">{ETIQUETA_ROL[u.rol] ?? u.rol}</span>
                  </td>
                  <td>
                    <span className={u.activo ? 'pill ok' : 'pill crit'}>{u.activo ? 'Activo' : 'Suspendido'}</span>
                  </td>
                  <td>{formatearFecha(u.fecha_creacion)}</td>
                  <td className="col-acciones">
                    <MenuAcciones opciones={opcionesDe(u)} etiqueta={`Acciones para ${nombreCompleto(u)}`} />
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {accion?.tipo === 'detalle' && (
        <Modal
          titulo="Detalles del usuario"
          onCerrar={() => setAccion(null)}
          pie={
            <button className="btn" onClick={() => setAccion(null)}>
              Cerrar
            </button>
          }
        >
          <dl className="detalle-lista">
            <dt>Nombre</dt>
            <dd>{nombreCompleto(accion.usuario)}</dd>
            <dt>Correo</dt>
            <dd>{accion.usuario.email ?? 'Sin correo (acceso por código)'}</dd>
            <dt>Teléfono</dt>
            <dd>{accion.usuario.telefono ?? '—'}</dd>
            <dt>Rol</dt>
            <dd>{ETIQUETA_ROL[accion.usuario.rol] ?? accion.usuario.rol}</dd>
            <dt>Estado</dt>
            <dd>{accion.usuario.activo ? 'Activo' : 'Suspendido'}</dd>
            <dt>Registro</dt>
            <dd>{formatearFechaCompleta(accion.usuario.fecha_creacion)}</dd>
          </dl>
        </Modal>
      )}

      {accion && accion.tipo !== 'detalle' && (
        <Modal
          titulo={accion.tipo === 'deshabilitar' ? 'Deshabilitar cuenta' : 'Habilitar cuenta'}
          onCerrar={() => setAccion(null)}
          pie={
            <>
              <button className="btn" onClick={() => setAccion(null)} disabled={procesando}>
                Cancelar
              </button>
              <button
                className={accion.tipo === 'deshabilitar' ? 'btn danger' : 'btn primary'}
                disabled={procesando}
                onClick={() => confirmarEstado(accion.usuario, accion.tipo === 'habilitar')}
              >
                {accion.tipo === 'deshabilitar' ? 'Deshabilitar' : 'Habilitar'}
              </button>
            </>
          }
        >
          {accion.tipo === 'deshabilitar' ? (
            <p>
              ¿Deshabilitar la cuenta de <b>{nombreCompleto(accion.usuario)}</b>? No podrá iniciar sesión ni usar la
              aplicación hasta que la habilites de nuevo.
            </p>
          ) : (
            <p>
              ¿Habilitar nuevamente la cuenta de <b>{nombreCompleto(accion.usuario)}</b>?
            </p>
          )}
        </Modal>
      )}
    </>
  )
}