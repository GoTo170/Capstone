export interface Requisito {
  texto: string
  ok: boolean
}

/** Regla de contraseña de Mamoru (la misma del registro en la app; el servidor la vuelve a comprobar). */
export function requisitosDe(p: string): Requisito[] {
  return [
    { texto: 'Mínimo 8 caracteres', ok: p.length >= 8 },
    { texto: '1 mayúscula', ok: /[A-ZÁÉÍÓÚÑÜ]/.test(p) },
    { texto: '1 minúscula', ok: /[a-záéíóúñü]/.test(p) },
    { texto: '1 número', ok: /[0-9]/.test(p) },
    { texto: '1 carácter especial', ok: /[^A-Za-z0-9ÁÉÍÓÚÑÜáéíóúñü\s]/.test(p) },
  ]
}

export function cumpleRequisitos(p: string): boolean {
  return requisitosDe(p).every((r) => r.ok)
}

export const MENSAJE_REQUISITOS =
  'La contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula, un número y un carácter especial.'