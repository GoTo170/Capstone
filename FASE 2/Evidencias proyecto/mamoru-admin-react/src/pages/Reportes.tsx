import { useCallback, useEffect, useState } from 'react'
import { apiFetch } from '../lib/api'

// ---------- Tipos de la respuesta de GET /admin/reportes ----------
type Rol = 'familiar' | 'cuidador' | 'adulto_mayor'

interface UsuariosMes {
  mes: string
  familiar: number
  cuidador: number
  adulto_mayor: number
}

interface ServiciosMes {
  mes: string
  solicitados: number
  contratados: number
  finalizados: number
  rechazados: number
}

interface ServicioTipo {
  tipo: string
  total: number
  contratados: number
  finalizados: number
  rechazados: number
}

interface Reporte {
  periodo: { desde: string | null; hasta: string | null }
  usuarios: {
    total: number
    por_rol: Record<Rol, number>
    activos: number
    inactivos: number
    por_mes: UsuariosMes[]
  }
  servicios: {
    total: number
    por_estado: Record<'pendiente' | 'aceptada' | 'rechazada' | 'finalizada', number>
    contratados: number
    finalizados: number
    rechazados: number
    tasa_finalizacion: number | null
    tasa_aceptacion: number | null
    por_tipo: ServicioTipo[]
    por_mes: ServiciosMes[]
  }
  cuidadores: { por_validacion: Record<'pendiente' | 'aprobado' | 'rechazado', number> }
}

// ---------- Textos ----------
const ROLES: { valor: Rol; texto: string; clase: string }[] = [
  { valor: 'familiar', texto: 'Familiares', clase: 'rep-familiar' },
  { valor: 'cuidador', texto: 'Cuidadores', clase: 'rep-cuidador' },
  { valor: 'adulto_mayor', texto: 'Adultos mayores', clase: 'rep-adulto' },
]

const TIPOS: Record<string, string> = {
  acompanamiento_apoyo_emocional: 'Acompañamiento y apoyo emocional',
  cuidado_fisico_personal: 'Cuidado físico y personal',
  control_medicamentos: 'Control de medicamentos',
  alimentacion: 'Alimentación',
  cuidador_integral: 'Cuidador integral',
  cuidado_puertas_adentro: 'Cuidado puertas adentro',
  sin_tipo: 'Sin tipo',
}

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

function etiquetaTipo(tipo: string): string {
  if (TIPOS[tipo]) return TIPOS[tipo]
  const limpio = tipo.replace(/_/g, ' ')
  return limpio.charAt(0).toUpperCase() + limpio.slice(1)
}

function etiquetaMes(mes: string): string {
  const [anio, numero] = mes.split('-')
  return `${MESES[Number(numero) - 1] ?? numero} ${anio}`
}

function aIso(fecha: Date): string {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${fecha.getFullYear()}-${p(fecha.getMonth() + 1)}-${p(fecha.getDate())}`
}

function fechaLarga(iso: string | null): string {
  if (!iso) return '—'
  const [a, m, d] = iso.split('-')
  return `${d}-${m}-${a}`
}

function porcentaje(valor: number | null): string {
  return valor === null ? '—' : `${String(valor).replace('.', ',')} %`
}

// Atajos de período
function hace(dias: number): string {
  const f = new Date()
  f.setDate(f.getDate() - dias)
  return aIso(f)
}

const ATAJOS: { texto: string; desde: () => string; hasta: () => string }[] = [
  { texto: 'Últimos 30 días', desde: () => hace(30), hasta: () => aIso(new Date()) },
  { texto: 'Últimos 6 meses', desde: () => hace(182), hasta: () => aIso(new Date()) },
  { texto: 'Este año', desde: () => `${new Date().getFullYear()}-01-01`, hasta: () => aIso(new Date()) },
  { texto: 'Todo', desde: () => '', hasta: () => '' },
]

export default function Reportes() {
  const [rol, setRol] = useState<'' | Rol>('')
  const [desde, setDesde] = useState(ATAJOS[1].desde())
  const [hasta, setHasta] = useState(ATAJOS[1].hasta())
  const [reporte, setReporte] = useState<Reporte | null>(null)
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)

  const cargar = useCallback(() => {
    const params = new URLSearchParams()
    if (rol) params.set('rol', rol)
    if (desde) params.set('desde', desde)
    if (hasta) params.set('hasta', hasta)
    const consulta = params.toString()

    setCargando(true)
    setError('')
    apiFetch<Reporte>(`/admin/reportes${consulta ? `?${consulta}` : ''}`)
      .then(setReporte)
      .catch((e: unknown) => setError(e instanceof Error ? e.message : 'No se pudo cargar el reporte'))
      .finally(() => setCargando(false))
  }, [rol, desde, hasta])

  useEffect(() => {
    cargar()
  }, [cargar])

  const rolesVisibles = ROLES.filter((r) => !rol || r.valor === rol)
  const maxUsuariosMes = Math.max(1, ...(reporte?.usuarios.por_mes ?? []).map((m) => m.familiar + m.cuidador + m.adulto_mayor))
  const maxServiciosMes = Math.max(1, ...(reporte?.servicios.por_mes ?? []).map((m) => m.solicitados))
  const totalServicios = reporte?.servicios.total ?? 0

  const textoPeriodo =
    !desde && !hasta
      ? 'Todo el período'
      : `${fechaLarga(desde || null)} al ${fechaLarga(hasta || null)}`
  const textoRol = rol ? ROLES.find((r) => r.valor === rol)?.texto : 'Todos los usuarios'

  return (
    <>
      <div className="page-head">
        <div className="breadcrumb">Panel · Reportes</div>
        <h1 className="page-title">Reportes y estadísticas</h1>
        <p className="page-desc">
          Análisis por período del crecimiento y del uso de los servicios. Para el total actual de usuarios por
          rol, revisa el Dashboard.
        </p>
      </div>

      {/* ---------- Filtros ---------- */}
      <div className="panel rep-filtros no-imprimir">
        <div className="rep-filtros-grid">
          <div className="filtro-campo">
            <label>Tipo de usuario</label>
            <select value={rol} onChange={(e) => setRol(e.target.value as '' | Rol)}>
              <option value="">Todos</option>
              {ROLES.map((r) => (
                <option key={r.valor} value={r.valor}>
                  {r.texto}
                </option>
              ))}
            </select>
          </div>

          <div className="filtro-campo">
            <label>Desde</label>
            <input type="date" value={desde} max={hasta || undefined} onChange={(e) => setDesde(e.target.value)} />
          </div>

          <div className="filtro-campo">
            <label>Hasta</label>
            <input type="date" value={hasta} min={desde || undefined} onChange={(e) => setHasta(e.target.value)} />
          </div>

          <div className="filtro-campo">
            <label>Plan de suscripción</label>
            <select disabled title="Disponible cuando Mamoru registre suscripciones">
              <option>Próximamente</option>
            </select>
          </div>
        </div>

        <div className="rep-filtros-pie">
          <div className="rep-atajos">
            {ATAJOS.map((a) => (
              <button
                key={a.texto}
                type="button"
                className="filter-chip"
                onClick={() => {
                  setDesde(a.desde())
                  setHasta(a.hasta())
                }}
              >
                {a.texto}
              </button>
            ))}
          </div>
          <button type="button" className="btn primary" onClick={() => window.print()}>
            Imprimir / guardar PDF
          </button>
        </div>
      </div>

      {/* Solo se ve al imprimir */}
      <div className="solo-imprimir rep-cabecera-impresion">
        <strong>Reporte Mamoru</strong> · {textoPeriodo} · {textoRol}
      </div>

      {error && (
        <div className="auth-error" style={{ display: 'block' }}>
          {error}
        </div>
      )}

      {!reporte && cargando && <div className="panel rep-vacio">Cargando reporte…</div>}

      {reporte && (
        <>
          {/* ---------- Indicadores ---------- */}
          <div className="kpi-row">
            <div className="kpi-card verde">
              <div className="kpi-label">Usuarios nuevos</div>
              <div className="kpi-value">{reporte.usuarios.total}</div>
              <div className="kpi-delta">
                {reporte.usuarios.activos} activos · {reporte.usuarios.inactivos} inactivos
              </div>
            </div>
            <div className="kpi-card lila">
              <div className="kpi-label">Servicios solicitados</div>
              <div className="kpi-value">{reporte.servicios.total}</div>
              <div className="kpi-delta">{reporte.servicios.por_estado.pendiente} pendientes de respuesta</div>
            </div>
            <div className="kpi-card amarillo">
              <div className="kpi-label">Servicios contratados</div>
              <div className="kpi-value">{reporte.servicios.contratados}</div>
              <div className="kpi-delta">Aceptación: {porcentaje(reporte.servicios.tasa_aceptacion)}</div>
            </div>
            <div className="kpi-card">
              <div className="kpi-label">Servicios finalizados</div>
              <div className="kpi-value">{reporte.servicios.finalizados}</div>
              <div className="kpi-delta">Finalización: {porcentaje(reporte.servicios.tasa_finalizacion)}</div>
            </div>
          </div>

          {/* ---------- Usuarios ---------- */}
          <div className="two-col">
            <div className="panel">
              <div className="panel-head verde">
                <h2>Nuevos usuarios por mes</h2>
              </div>
              <div className="rep-cuerpo">
                {reporte.usuarios.por_mes.length === 0 ? (
                  <div className="rep-vacio">No hay registros en este período.</div>
                ) : (
                  <>
                    <div className="rep-grafico">
                      {reporte.usuarios.por_mes.map((m) => {
                        const total = m.familiar + m.cuidador + m.adulto_mayor
                        return (
                          <div className="rep-col" key={m.mes} title={`${etiquetaMes(m.mes)}: ${total}`}>
                            <div className="rep-valor">{total}</div>
                            <div className="rep-pila" style={{ height: `${(total / maxUsuariosMes) * 100}%` }}>
                              {rolesVisibles.map((r) => (
                                <div
                                  key={r.valor}
                                  className={`rep-seg ${r.clase}`}
                                  style={{ flex: m[r.valor] }}
                                />
                              ))}
                            </div>
                            <div className="rep-mes">{etiquetaMes(m.mes)}</div>
                          </div>
                        )
                      })}
                    </div>
                    <div className="rep-leyenda">
                      {rolesVisibles.map((r) => (
                        <span key={r.valor}>
                          <i className={`rep-punto ${r.clase}`} />
                          {r.texto}
                        </span>
                      ))}
                    </div>
                  </>
                )}
              </div>
            </div>

            <div className="panel">
              <div className="panel-head lila">
                <h2>Usuarios nuevos por tipo</h2>
              </div>
              <table>
                <thead>
                  <tr>
                    <th>Tipo</th>
                    <th className="num">Cantidad</th>
                    <th className="num">%</th>
                  </tr>
                </thead>
                <tbody>
                  {rolesVisibles.map((r) => {
                    const n = reporte.usuarios.por_rol[r.valor]
                    return (
                      <tr key={r.valor}>
                        <td>
                          <i className={`rep-punto ${r.clase}`} />
                          {r.texto}
                        </td>
                        <td className="num">{n}</td>
                        <td className="num">
                          {reporte.usuarios.total ? porcentaje(Math.round((n * 1000) / reporte.usuarios.total) / 10) : '—'}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>

          {/* ---------- Servicios ---------- */}
          <div className="two-col">
            <div className="panel">
              <div className="panel-head verde">
                <h2>Servicios por estado</h2>
              </div>
              <div className="rep-cuerpo">
                {totalServicios === 0 ? (
                  <div className="rep-vacio">No hay solicitudes de servicio en este período.</div>
                ) : (
                  (
                    [
                      ['finalizada', 'Finalizados', 'rep-ok'],
                      ['aceptada', 'En curso (aceptados)', 'rep-curso'],
                      ['pendiente', 'Pendientes', 'rep-pend'],
                      ['rechazada', 'Rechazados', 'rep-crit'],
                    ] as const
                  ).map(([clave, texto, clase]) => {
                    const n = reporte.servicios.por_estado[clave]
                    return (
                      <div className="rep-barra-fila" key={clave}>
                        <div className="rep-barra-texto">
                          <span>{texto}</span>
                          <b>
                            {n} · {porcentaje(Math.round((n * 1000) / totalServicios) / 10)}
                          </b>
                        </div>
                        <div className="rep-barra-pista">
                          <div className={`rep-barra ${clase}`} style={{ width: `${(n / totalServicios) * 100}%` }} />
                        </div>
                      </div>
                    )
                  })
                )}
                <p className="ayuda">
                  Mamoru no tiene un estado "cancelado" en los servicios: aquí se muestran los rechazados por el
                  cuidador.
                </p>
              </div>
            </div>

            <div className="panel">
              <div className="panel-head lila">
                <h2>Servicios por mes</h2>
              </div>
              <div className="rep-cuerpo">
                {reporte.servicios.por_mes.length === 0 ? (
                  <div className="rep-vacio">Sin solicitudes en este período.</div>
                ) : (
                  reporte.servicios.por_mes.map((m) => (
                    <div className="rep-barra-fila" key={m.mes}>
                      <div className="rep-barra-texto">
                        <span>{etiquetaMes(m.mes)}</span>
                        <b>
                          {m.solicitados} solic. · {m.contratados} contrat. · {m.finalizados} final.
                        </b>
                      </div>
                      <div className="rep-barra-pista">
                        <div
                          className="rep-barra rep-curso"
                          style={{ width: `${(m.solicitados / maxServiciosMes) * 100}%` }}
                        >
                          <div
                            className="rep-barra rep-ok"
                            style={{ width: m.solicitados ? `${(m.finalizados / m.solicitados) * 100}%` : 0 }}
                          />
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>

          <div className="panel rep-bloque">
            <div className="panel-head verde">
              <h2>Servicios por tipo</h2>
            </div>
            <table>
              <thead>
                <tr>
                  <th>Tipo de servicio</th>
                  <th className="num">Solicitados</th>
                  <th className="num">Contratados</th>
                  <th className="num">Finalizados</th>
                  <th className="num">Rechazados</th>
                </tr>
              </thead>
              <tbody>
                {reporte.servicios.por_tipo.length === 0 ? (
                  <tr>
                    <td colSpan={5}>No hay solicitudes de servicio en este período.</td>
                  </tr>
                ) : (
                  reporte.servicios.por_tipo.map((t) => (
                    <tr key={t.tipo}>
                      <td className="cell-primary">{etiquetaTipo(t.tipo)}</td>
                      <td className="num">{t.total}</td>
                      <td className="num">{t.contratados}</td>
                      <td className="num">{t.finalizados}</td>
                      <td className="num">{t.rechazados}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <div className="two-col">
            <div className="panel">
              <div className="panel-head lila">
                <h2>Cuidadores nuevos según validación</h2>
              </div>
              <table>
                <tbody>
                  <tr>
                    <td>Aprobados</td>
                    <td className="num">
                      <span className="pill ok">{reporte.cuidadores.por_validacion.aprobado}</span>
                    </td>
                  </tr>
                  <tr>
                    <td>Pendientes de revisión</td>
                    <td className="num">
                      <span className="pill pending">{reporte.cuidadores.por_validacion.pendiente}</span>
                    </td>
                  </tr>
                  <tr>
                    <td>Rechazados</td>
                    <td className="num">
                      <span className="pill crit">{reporte.cuidadores.por_validacion.rechazado}</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div className="panel">
              <div className="panel-head verde">
                <h2>Suscripciones por plan</h2>
              </div>
              <div className="rep-cuerpo">
                <p className="rep-nota">
                  Este reporte (Gratuito, Dorado, Platino y Proveedor, con sus estados) estará disponible cuando
                  Mamoru registre las suscripciones en la base de datos. Por ahora no existen esos datos.
                </p>
              </div>
            </div>
          </div>
        </>
      )}
    </>
  )
}