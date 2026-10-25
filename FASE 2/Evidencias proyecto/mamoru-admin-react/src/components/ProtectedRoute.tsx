import { Navigate, Outlet } from 'react-router-dom'
import { obtenerToken } from '../lib/api'

export default function ProtectedRoute() {
  return obtenerToken() ? <Outlet /> : <Navigate to="/login" replace />
}