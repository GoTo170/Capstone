import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import ProtectedRoute from './components/ProtectedRoute'
import RutaPermiso from './components/RutaPermiso'
import Auditoria from './pages/Auditoria'
import AlertasSOS from './pages/AlertasSOS'
import CambiosAdulto from './pages/CambiosAdulto'
import Config from './pages/Config'
import Cuidadores from './pages/Cuidadores'
import Dashboard from './pages/Dashboard'
import Login from './pages/Login'
import RecuperarContrasena from './pages/RecuperarContrasena'
import RestablecerContrasena from './pages/RestablecerContrasena'
import Marketplace from './pages/Marketplace'
import Reportes from './pages/Reportes'
import Solicitudes from './pages/Solicitudes'
import Usuarios from './pages/Usuarios'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/recuperar-contrasena" element={<RecuperarContrasena />} />
        <Route path="/restablecer-contrasena" element={<RestablecerContrasena />} />

        <Route element={<ProtectedRoute />}>
          <Route element={<Layout />}>
            {/* Todos los roles internos */}
            <Route path="/" element={<Dashboard />} />
            <Route path="/reportes" element={<Reportes />} />
            <Route path="/config" element={<Config />} />

            {/* Superadmin */}
            <Route element={<RutaPermiso permiso="usuarios" />}>
              <Route path="/usuarios" element={<Usuarios />} />
            </Route>
            <Route element={<RutaPermiso permiso="auditoria" />}>
              <Route path="/auditoria" element={<Auditoria />} />
            </Route>

            {/* Moderador de cuidadores (y superadmin) */}
            <Route element={<RutaPermiso permiso="cuidadores" />}>
              <Route path="/cuidadores" element={<Cuidadores />} />
              <Route path="/marketplace" element={<Marketplace />} />
            </Route>

            {/* Soporte / SOS (y superadmin) */}
            <Route element={<RutaPermiso permiso="soporte" />}>
              <Route path="/solicitudes" element={<Solicitudes />} />
              <Route path="/cambios-adulto-mayor" element={<CambiosAdulto />} />
              <Route path="/alertas-sos" element={<AlertasSOS />} />
            </Route>
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}