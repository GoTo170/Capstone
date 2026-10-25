import type { Usuario } from './api'

// Supabase guarda las fechas que genera la propia base de datos (registro de
// usuarios, auditoría, solicitudes, alertas SOS) en hora UTC y sin indicar la
// zona. Aquí se interpretan como UTC y se muestran en la hora local del
// navegador. Si algún día la base se configura con la hora local de Chile,
// cambia esta constante a false.
const BD_GUARDA_EN_UTC = true

/** Convierte el texto de fecha que entrega el servidor en una fecha local. */
export function aFechaLocal(iso: string): Date {
  // "2026-10-06": solo fecha, sin hora: no hay nada que convertir.
  if (/^\d{4}-\d{2}-\d{2}$/.test(iso)) return new Date(`${iso}T00:00:00`)

  const tieneZona = /(Z|[+-]\d{2}:?\d{2})$/.test(iso)
  if (BD_GUARDA_EN_UTC && !tieneZona) return new Date(`${iso}Z`)

  return new Date(iso)
}

/** Día local de una fecha del servidor, como "2026-10-06" (para filtros). */
export function diaLocal(iso: string): string {
  const f = aFechaLocal(iso)
  const dos = (n: number) => String(n).padStart(2, '0')
  return `${f.getFullYear()}-${dos(f.getMonth() + 1)}-${dos(f.getDate())}`
}

export function formatearFechaHora(iso: string): string {
  return aFechaLocal(iso).toLocaleDateString('es-CL', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatearFecha(iso: string): string {
  return aFechaLocal(iso).toLocaleDateString('es-CL')
}

export function formatearFechaCompleta(iso: string): string {
  return aFechaLocal(iso).toLocaleString('es-CL', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

// Para fechas sin hora ("2026-10-01"): se arma a mano para evitar desfases de zona horaria
export function formatearFechaIso(fecha: string): string {
  const [anio, mes, dia] = fecha.split('-')
  return `${dia}/${mes}/${anio}`
}

// "09:00:00" -> "09:00"
export function formatearHora(hora: string): string {
  return hora.slice(0, 5)
}

export function nombreCompleto(usuario: Usuario): string {
  return usuario.apellido ? `${usuario.nombre} ${usuario.apellido}` : usuario.nombre
}