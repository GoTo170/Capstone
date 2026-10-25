export interface PerfilCuidador {
  id: string
  usuario_id: string
  experiencia: string | null
  servicios_ofrecidos: string | null
  ubicacion: string | null
  tarifa_hora: number | null
  es_area_salud: boolean
  disponible: boolean
  valoracion_promedio: number
  estado_validacion: string
  profesion: string | null
  documento_url: string | null
  fecha_creacion: string
    descripcion: string | null
  foto_url: string | null
  puertas_adentro_pendiente: boolean
  puertas_adentro_fecha_solicitud: string | null
}

export interface SolicitudServicio {
  id: string
  solicitante_id: string
  adulto_mayor_id: string
  cuidador_id: string
  estado: string
  direccion: string | null
  fecha_inicio: string | null
  hora_inicio: string | null
  fecha_termino: string | null
  hora_termino: string | null
  tipo_servicio: string | null
  informacion_adicional: string | null
  mensaje: string | null
  motivo_rechazo: string | null
  motivo_rechazo_detalle: string | null
  fecha_solicitud: string
  fecha_resolucion: string | null
}

export interface AlertaSOS {
  id: string
  usuario_id: string
  estado: string
  fecha_alerta: string
  fecha_atencion: string | null
}

export interface RegistroAuditoria {
  id: string
  administrador_id: string
  accion: string
  entidad_tipo: string
  entidad_id: string | null
  detalle: string | null
  fecha: string
}

export interface Notificacion {
  id: string
  usuario_id: string
  tipo: string
  mensaje: string
  leida: boolean
  fecha_envio: string
}

export interface ContextoLayout {
  refrescarPendientes: () => void
  refrescarSOS: () => void
}

export interface ContactoSOS {
  nombre: string
  telefono: string
  parentesco: string | null
}

export interface AlertaSOSPanel {
  id: string
  persona_nombre: string
  persona_telefono: string | null
  estado: string
  fecha_alerta: string
  fecha_atencion: string | null
  contactos: ContactoSOS[]
  familiares: string[]
}
export interface Valoracion {
  id: string
  solicitud_id: string
  puntuacion: number
  comentario: string | null
  fecha: string
  reportada: boolean
  motivo_reporte: string | null
  habilitada: boolean
}