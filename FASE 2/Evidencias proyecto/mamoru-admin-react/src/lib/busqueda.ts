export function normalizar(texto: string): string {
  return texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
}

export function contiene(texto: string, termino: string): boolean {
  return normalizar(texto).includes(normalizar(termino.trim()))
}