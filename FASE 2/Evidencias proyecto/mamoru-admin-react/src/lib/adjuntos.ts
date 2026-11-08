// Archivos que se pueden adjuntar a los correos que se envían desde el panel.
// Los mismos límites los valida el servidor.
export const MAX_ADJUNTOS = 5
export const MAX_BYTES_ADJUNTOS = 3 * 1024 * 1024
export const EXTENSIONES_ADJUNTO = ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv']

export interface AdjuntoEnvio {
  nombre: string
  contenido: string // archivo en base64
}

export function formatearPeso(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function extensionDe(nombre: string): string {
  const punto = nombre.lastIndexOf('.')
  return punto >= 0 ? nombre.slice(punto + 1).toLowerCase() : ''
}

// Suma los archivos nuevos a los que ya había; si alguno no cumple, no se agrega y se explica por qué.
export function agregarAdjuntos(actuales: File[], nuevos: File[]): { archivos: File[]; error: string } {
  const archivos = [...actuales]
  let error = ''

  for (const archivo of nuevos) {
    if (archivos.some((a) => a.name === archivo.name && a.size === archivo.size)) continue
    if (!EXTENSIONES_ADJUNTO.includes(extensionDe(archivo.name))) {
      error = `«${archivo.name}»: tipo de archivo no permitido.`
      continue
    }
    if (archivos.length >= MAX_ADJUNTOS) {
      error = `Máximo ${MAX_ADJUNTOS} archivos.`
      break
    }
    const total = archivos.reduce((suma, a) => suma + a.size, 0) + archivo.size
    if (total > MAX_BYTES_ADJUNTOS) {
      error = `«${archivo.name}» no cabe: los adjuntos pueden pesar ${formatearPeso(MAX_BYTES_ADJUNTOS)} en total.`
      continue
    }
    archivos.push(archivo)
  }
  return { archivos, error }
}

function leerBase64(archivo: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const lector = new FileReader()
    lector.onload = () => {
      const resultado = String(lector.result ?? '')
      resolve(resultado.slice(resultado.indexOf(',') + 1))
    }
    lector.onerror = () => reject(new Error(`No se pudo leer «${archivo.name}».`))
    lector.readAsDataURL(archivo)
  })
}

export async function archivosABase64(archivos: File[]): Promise<AdjuntoEnvio[]> {
  return Promise.all(archivos.map(async (a) => ({ nombre: a.name, contenido: await leerBase64(a) })))
}