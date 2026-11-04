import { Navigate, Outlet } from 'react-router-dom'
import { obtenerUsuarioSesion, tienePermiso, type Permiso } from '../lib/api'

/** Protege un grupo de rutas: si el rol no tiene el permiso, vuelve al Dashboard. */
export default function RutaPermiso({ permiso }: { permiso: Permiso }) {
  return tienePermiso(obtenerUsuarioSesion(), permiso) ? <Outlet /> : <Navigate to="/" replace />
}