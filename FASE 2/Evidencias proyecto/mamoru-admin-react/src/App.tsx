import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import ProtectedRoute from './components/ProtectedRoute'
import Auditoria from './pages/Auditoria'
import AlertasSOS from './pages/AlertasSOS'
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
            <Route path="/" element={<Dashboard />} />
            <Route path="/usuarios" element={<Usuarios />} />
            <Route path="/cuidadores" element={<Cuidadores />} />
            <Route path="/marketplace" element={<Marketplace />} />
            <Route path="/solicitudes" element={<Solicitudes />} />
            <Route path="/alertas-sos" element={<AlertasSOS />} />
            <Route path="/reportes" element={<Reportes />} />
            <Route path="/auditoria" element={<Auditoria />} />
            <Route path="/config" element={<Config />} />
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}