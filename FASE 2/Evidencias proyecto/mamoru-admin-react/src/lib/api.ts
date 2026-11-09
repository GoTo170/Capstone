export const API_BASE = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000'

const TOKEN_KEY = 'mamoru_token'
const USER_KEY = 'mamoru_usuario'

export interface Usuario {
  id: string
  nombre: string
  apellido: string | null
  email: string | null
  rol: string
  // Solo administradores: 'superadmin' | 'moderador' | 'soporte'. Vacío = superadmin.
  rol_interno?: string | null
  telefono: string | null
  activo: boolean
  fecha_creacion: string
  // Solo cuidadores: 'pendiente' | 'aprobado' | 'rechazado'
  estado_validacion?: string | null
}

export interface LoginResponse {
  access_token: string
  token_type: string
  usuario: Usuario
}

// ---------------------------------------------------------------------------
// Roles internos y permisos (el servidor es quien manda; esto solo decide qué
// menús y pantallas mostrar). Debe coincidir con PERMISOS_POR_ROL_INTERNO del backend.
// ---------------------------------------------------------------------------
export type Permiso = 'cuidadores' | 'soporte' | 'reportes' | 'usuarios' | 'auditoria' | 'equipo'

export const ROLES_INTERNOS = ['superadmin', 'moderador', 'soporte'] as const

export const ETIQUETA_ROL_INTERNO: Record<string, string> = {
  superadmin: 'Superadmin',
  moderador: 'Moderador de cuidadores',
  soporte: 'Soporte / SOS',
}

export const DESCRIPCION_ROL_INTERNO: Record<string, string> = {
  superadmin: 'Acceso total',
  moderador: 'Cuidadores, documentos, puertas adentro, reseñas y reportes',
  soporte: 'Alertas SOS, cambios de datos del adulto mayor, solicitudes y reportes',
}

const PERMISOS_POR_ROL: Record<string, Permiso[] | null> = {
  superadmin: null, // null = todos
  moderador: ['cuidadores', 'reportes'],
  soporte: ['soporte', 'reportes'],
}

export function rolInternoDe(usuario: Usuario | null): string {
  return usuario?.rol_interno || 'superadmin'
}

/** Sin permiso requerido (undefined) = cualquier administrador. */
export function tienePermiso(usuario: Usuario | null, permiso?: Permiso): boolean {
  if (!usuario || usuario.rol !== 'administrador') return false
  if (!permiso) return true
  const rol = rolInternoDe(usuario)
  if (!(rol in PERMISOS_POR_ROL)) return false // un valor desconocido no recibe permisos
  const permisos = PERMISOS_POR_ROL[rol]
  return permisos === null || permisos.includes(permiso)
}

export function guardarSesion(token: string, usuario: Usuario): void {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(USER_KEY, JSON.stringify(usuario))
}

export function obtenerToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function obtenerUsuarioSesion(): Usuario | null {
  const raw = localStorage.getItem(USER_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as Usuario
  } catch {
    return null
  }
}

export function cerrarSesion(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
}

export async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = obtenerToken()
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> | undefined),
  }
  if (token) {
    headers['Authorization'] = `Bearer ${token}`
  }

  const respuesta = await fetch(`${API_BASE}${path}`, { ...options, headers })

  // 401 con sesión iniciada = token vencido. Sin token (login) cae al manejo normal de error.
  if (respuesta.status === 401 && token) {
    cerrarSesion()
    window.location.href = '/login'
    throw new Error('Sesión expirada')
  }

  if (!respuesta.ok) {
    const error = await respuesta.json().catch(() => ({}))
    throw new Error(error.detail || `Error ${respuesta.status}`)
  }

  if (respuesta.status === 204) return null as T
  return (await respuesta.json()) as T
}

/**
 * Vuelve a pedir los datos del usuario al servidor (por si su rol cambió desde que
 * inició sesión) y los guarda. Devuelve el usuario actualizado.
 */
export async function refrescarUsuarioSesion(): Promise<Usuario | null> {
  const token = obtenerToken()
  if (!token) return null
  const usuario = await apiFetch<Usuario>('/perfil')
  guardarSesion(token, usuario)
  return usuario
}