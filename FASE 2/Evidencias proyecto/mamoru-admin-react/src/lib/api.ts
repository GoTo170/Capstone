export const API_BASE = 'http://127.0.0.1:8000'

const TOKEN_KEY = 'mamoru_token'
const USER_KEY = 'mamoru_usuario'

export interface Usuario {
  id: string
  nombre: string
  apellido: string | null
  email: string | null
  rol: string
  telefono: string | null
  activo: boolean
  fecha_creacion: string
}

export interface LoginResponse {
  access_token: string
  token_type: string
  usuario: Usuario
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