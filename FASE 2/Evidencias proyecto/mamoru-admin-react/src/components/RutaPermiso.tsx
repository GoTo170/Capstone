import { Navigate, Outlet, useOutletContext } from 'react-router-dom'
import { obtenerUsuarioSesion, tienePermiso, type Permiso } from '../lib/api'

/** Protege un grupo de rutas: si el rol no tiene el permiso, vuelve al Dashboard.
 *  Reenvía el contexto del Layout (refrescarPendientes, refrescarSOS...) a las páginas hijas. */
export default function RutaPermiso({ permiso }: { permiso: Permiso }) {
  const contexto = useOutletContext()
  return tienePermiso(obtenerUsuarioSesion(), permiso)
    ? <Outlet context={contexto} />
    : <Navigate to="/" replace />
}