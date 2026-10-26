from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime, date, time




# ---------- Usuarios ----------


class UsuarioCreate(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    email: EmailStr
    password: str
    rol: str
    telefono: Optional[str] = None
    # Solo se usan cuando rol = "cuidador" (perfil profesional)
    profesion: Optional[str] = None
    es_area_salud: Optional[bool] = None
    experiencia: Optional[str] = None
    servicios_ofrecidos: Optional[str] = None


class UsuarioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    nombre: str
    apellido: Optional[str] = None
    email: Optional[EmailStr] = None
    rol: str
    telefono: Optional[str] = None
    activo: bool
    fecha_creacion: datetime
    foto_url: Optional[str] = None



class LoginRequest(BaseModel):
    email: EmailStr
    password: str
 
 
class VerificarContrasena(BaseModel):
    password_actual: str
 
 
class CambioContrasena(BaseModel):
    password_actual: str
    password_nueva: str




class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut




# ---------- Perfiles de cuidador ----------


class PerfilCuidadorCreate(BaseModel):
    usuario_id: UUID
    experiencia: Optional[str] = None
    servicios_ofrecidos: Optional[str] = None
    ubicacion: Optional[str] = None
    profesion: Optional[str] = None
    tarifa_hora: Optional[float] = None
    es_area_salud: Optional[bool] = False




class PerfilCuidadorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    usuario_id: UUID
    experiencia: Optional[str] = None
    servicios_ofrecidos: Optional[str] = None
    ubicacion: Optional[str] = None
    tarifa_hora: Optional[float] = None
    es_area_salud: bool
    disponible: bool
    valoracion_promedio: float
    estado_validacion: str
    profesion: Optional[str] = None
    documento_url: Optional[str] = None
    fecha_creacion: datetime
    descripcion: Optional[str] = None
    puertas_adentro_pendiente: bool = False
    puertas_adentro_fecha_solicitud: Optional[datetime] = None
    foto_url: Optional[str] = None
    motivo_rechazo: Optional[str] = None
    fecha_validacion: Optional[datetime] = None




class PerfilCuidadorUpdate(BaseModel):
    estado_validacion: str
    motivo_rechazo: Optional[str] = None




# ---------- Perfil de adulto mayor + contactos + invitación ----------


class ContactoEmergenciaCreate(BaseModel):
    nombre: str
    telefono: str
    parentesco: Optional[str] = None
    orden: int




class ContactoEmergenciaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    adulto_mayor_id: UUID
    nombre: str
    telefono: str
    parentesco: Optional[str] = None
    orden: int




class AdultoMayorCreate(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    telefono: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    relacion_familiar: Optional[str] = None
    enfermedades: Optional[str] = None
    alergia_medicamentos: Optional[str] = None
    alergia_alimentos: Optional[str] = None
    intolerancia_alimentaria: Optional[str] = None
    contactos: List[ContactoEmergenciaCreate] = []




class PerfilAdultoMayorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    usuario_id: UUID
    fecha_nacimiento: Optional[date] = None
    enfermedades: Optional[str] = None
    alergia_medicamentos: Optional[str] = None
    alergia_alimentos: Optional[str] = None
    intolerancia_alimentaria: Optional[str] = None




class InvitacionVinculacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    adulto_mayor_id: UUID
    codigo: str
    estado: str
    expira_en: datetime




class AdultoMayorCreadoOut(BaseModel):
    usuario: UsuarioOut
    perfil: PerfilAdultoMayorOut
    contactos: List[ContactoEmergenciaOut]
    invitacion: InvitacionVinculacionOut




class CanjearCodigoRequest(BaseModel):
    codigo: str




# ---------- Vinculaciones ----------


class VinculacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    adulto_mayor_id: UUID
    familiar_id: UUID
    estado: str
    fecha_vinculacion: datetime
    parentesco: Optional[str] = None




# ---------- Solicitudes de servicio ----------


class SolicitudServicioCreate(BaseModel):
    adulto_mayor_id: UUID
    cuidador_id: UUID
    direccion: Optional[str] = None
    fecha_inicio: Optional[date] = None
    hora_inicio: Optional[time] = None
    fecha_termino: Optional[date] = None
    hora_termino: Optional[time] = None
    tipo_servicio: Optional[str] = None
    informacion_adicional: Optional[str] = None
    mensaje: Optional[str] = None




class SolicitudServicioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    solicitante_id: UUID
    adulto_mayor_id: UUID
    cuidador_id: UUID
    estado: str
    direccion: Optional[str] = None
    fecha_inicio: Optional[date] = None
    hora_inicio: Optional[time] = None
    fecha_termino: Optional[date] = None
    hora_termino: Optional[time] = None
    tipo_servicio: Optional[str] = None
    informacion_adicional: Optional[str] = None
    mensaje: Optional[str] = None
    motivo_rechazo: Optional[str] = None
    motivo_rechazo_detalle: Optional[str] = None
    fecha_solicitud: datetime
    fecha_resolucion: Optional[datetime] = None




class SolicitudServicioRechazar(BaseModel):
    motivo_rechazo: str
    motivo_rechazo_detalle: Optional[str] = None




# ---------- Tareas y recordatorios ----------


class TareaRecordatorioCreate(BaseModel):
    adulto_mayor_id: UUID
    titulo: str
    categoria: Optional[str] = None
    descripcion: Optional[str] = None
    fecha_programada: datetime


class TareaRecordatorioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    adulto_mayor_id: UUID
    creado_por_id: Optional[UUID] = None
    titulo: str
    categoria: Optional[str] = None
    descripcion: Optional[str] = None
    estado: str
    fecha_programada: datetime
    fecha_confirmacion: Optional[datetime] = None
    completada_por_rol: Optional[str] = None
    hora_original: Optional[datetime] = None
    es_flexible: bool = False


class TareaRecordatorioEstado(BaseModel):
    estado: str


class SolicitudCambioHorario(BaseModel):
   motivo: Optional[str] = None



# ---------- Bitácora de cuidados ----------


class BitacoraCuidadoCreate(BaseModel):
    tarea_id: UUID
    solicitud_servicio_id: Optional[UUID] = None
    observacion: str
    tipo_incidencia: Optional[str] = "general"




class BitacoraCuidadoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    tarea_id: UUID
    solicitud_servicio_id: Optional[UUID] = None
    autor_id: UUID
    observacion: str
    tipo_incidencia: str
    fecha_registro: datetime




# ---------- Alertas SOS ----------


class AlertaSOSCreate(BaseModel):
    usuario_id: UUID




class AlertaSOSOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    usuario_id: UUID
    estado: str
    fecha_alerta: datetime
    fecha_atencion: Optional[datetime] = None




# ---------- Notificaciones ----------


class NotificacionCreate(BaseModel):
    usuario_id: UUID
    tipo: str
    mensaje: str




class NotificacionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    usuario_id: UUID
    tipo: str
    mensaje: str
    leida: bool
    fecha_envio: datetime




# ---------- Valoraciones ----------


class ValoracionCreate(BaseModel):
    solicitud_id: UUID
    puntuacion: int
    comentario: Optional[str] = None




class ValoracionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    solicitud_id: UUID
    puntuacion: int
    comentario: Optional[str] = None
    fecha: datetime
    reportada: bool
    motivo_reporte: Optional[str] = None
    habilitada: bool




class ValoracionReportar(BaseModel):
    motivo_reporte: str




class ValoracionModerar(BaseModel):
    habilitada: bool




# ---------- Auditoría ----------


class AuditoriaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)


    id: UUID
    administrador_id: UUID
    accion: str
    entidad_tipo: str
    entidad_id: Optional[UUID] = None
    detalle: Optional[str] = None
    fecha: datetime


class UsuarioEstado(BaseModel):
    activo: bool


class MiembroEquipoCreate(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    email: EmailStr
    password: str
    rol: str = "administrador"
    telefono: Optional[str] = None


class FamiliarVinculadoOut(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    fecha_vinculacion: datetime
    foto_url: Optional[str] = None




class MiPerfilAdultoMayorOut(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    foto_url: Optional[str] = None
    familiares: List[FamiliarVinculadoOut]



class AdultoMayorResumenOut(BaseModel):
    id: UUID
    nombre: str
    apellido: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    parentesco: Optional[str] = None
    fecha_vinculacion: datetime
    acceso_activado: bool
    foto_url: Optional[str] = None




class AdultoMayorDetalleOut(AdultoMayorResumenOut):
    telefono: Optional[str] = None
    enfermedades: Optional[str] = None
    alergia_medicamentos: Optional[str] = None
    alergia_alimentos: Optional[str] = None
    intolerancia_alimentaria: Optional[str] = None
    contactos: List[ContactoEmergenciaOut]


class TareaRecordatorioLote(BaseModel):
    adulto_mayor_id: UUID
    titulo: str
    categoria: Optional[str] = None
    descripcion: Optional[str] = None
    fechas: List[datetime]


class ValoracionMarketplaceOut(BaseModel):
    puntuacion: int
    comentario: Optional[str] = None




class CuidadorMarketplaceOut(BaseModel):
    id: UUID
    nombre: str
    apellido: Optional[str] = None
    profesion: Optional[str] = None
    ubicacion: Optional[str] = None
    experiencia: Optional[str] = None
    servicios_ofrecidos: Optional[str] = None
    disponible: bool
    es_area_salud: bool
    calificacion: float
    numero_resenas: int
    valoraciones: List[ValoracionMarketplaceOut]
    descripcion: Optional[str] = None
    foto_url: Optional[str] = None






class SolicitudFamiliarOut(BaseModel):
    id: UUID
    estado: str
    cuidador_nombre: str
    adulto_mayor_nombre: str
    fecha_inicio: Optional[date] = None
    hora_inicio: Optional[time] = None
    fecha_termino: Optional[date] = None
    hora_termino: Optional[time] = None
    tipo_servicio: Optional[str] = None
    motivo_rechazo: Optional[str] = None
    motivo_rechazo_detalle: Optional[str] = None
    fecha_solicitud: datetime
    valoracion_puntuacion: Optional[int] = None


class MiPerfilCuidadorOut(BaseModel):
    nombre: str
    apellido: Optional[str] = None
    email: Optional[str] = None
    telefono: Optional[str] = None
    profesion: Optional[str] = None
    experiencia: Optional[str] = None
    descripcion: Optional[str] = None
    servicios_ofrecidos: Optional[str] = None
    es_area_salud: bool
    estado_validacion: str
    puertas_adentro_pendiente: bool = False
    foto_url: Optional[str] = None




class MiPerfilCuidadorUpdate(BaseModel):
    telefono: Optional[str] = None
    descripcion: Optional[str] = None
    servicios_ofrecidos: Optional[str] = None




class ValoracionCuidadorOut(BaseModel):
    id: UUID
    puntuacion: int
    comentario: Optional[str] = None
    fecha: datetime
    reportada: bool
    motivo_reporte: Optional[str] = None




class ContactoServicioOut(BaseModel):
    nombre: str
    telefono: str
    parentesco: Optional[str] = None




class ValoracionAdminOut(BaseModel):
    id: UUID
    puntuacion: int
    comentario: Optional[str] = None
    fecha: datetime
    reportada: bool
    motivo_reporte: Optional[str] = None
    habilitada: bool
    cuidador_nombre: str
    familiar_nombre: str


class SolicitudCuidadorOut(BaseModel):
    id: UUID


    # Permite relacionar el servicio con las tareas del adulto mayor.
    adulto_mayor_id: UUID


    estado: str
    familiar_nombre: str
    adulto_mayor_nombre: str


    fecha_solicitud: datetime


    fecha_inicio: Optional[date] = None
    hora_inicio: Optional[time] = None
    fecha_termino: Optional[date] = None
    hora_termino: Optional[time] = None


    tipo_servicio: Optional[str] = None
    direccion: Optional[str] = None
    informacion_adicional: Optional[str] = None
    mensaje: Optional[str] = None


    motivo_rechazo: Optional[str] = None
    motivo_rechazo_detalle: Optional[str] = None
    fecha_resolucion: Optional[datetime] = None


    # --------------------------------------------------------
    # Información del adulto mayor: solo se entrega mientras el
    # servicio está aceptado y vigente (ver solicitud_esta_vigente).
    # Fuera de ese período estos campos vienen vacíos.
    # --------------------------------------------------------
    adulto_mayor_edad: Optional[int] = None
    adulto_mayor_telefono: Optional[str] = None


    enfermedades: Optional[str] = None
    alergia_medicamentos: Optional[str] = None
    alergia_alimentos: Optional[str] = None
    intolerancia_alimentaria: Optional[str] = None


    contactos_emergencia: List[ContactoServicioOut] = []


    # True solamente durante un servicio aceptado y vigente.
    puede_ver_informacion_sensible: bool = False


class ContactoSOSOut(BaseModel):
    nombre: str
    telefono: str
    parentesco: Optional[str] = None




class AlertaSOSPanelOut(BaseModel):
    id: UUID
    persona_nombre: str
    persona_telefono: Optional[str] = None
    estado: str
    fecha_alerta: datetime
    fecha_atencion: Optional[datetime] = None
    contactos: List[ContactoSOSOut]
    familiares: List[str]




class AlertaSOSEstadoUpdate(BaseModel):
    estado: str


class PuertasAdentroSolicitud(BaseModel):
    activar: bool




class PuertasAdentroDecision(BaseModel):
    aprobar: bool
    motivo: Optional[str] = None




class FotoPerfilSubir(BaseModel):
    imagen_base64: str
   


class MensajeChatCreate(BaseModel):
    texto: str
 
 
class MensajeChatOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
 
    id: UUID
    solicitud_id: UUID
    autor_id: UUID
    texto: str
    creado_en: Optional[datetime] = None
 
 
class ChatResumenOut(BaseModel):
    solicitud_id: UUID
    contacto_nombre: str
    contacto_foto_url: Optional[str] = None
    adulto_mayor_nombre: str
    estado: str
    puede_escribir: bool
    ultimo_mensaje: Optional[str] = None
    ultimo_mensaje_en: Optional[datetime] = None
    no_leidos: int = 0


class PushToken(BaseModel):
    token: str


class ContactosEmergenciaActualizar(BaseModel):
    contactos: List[ContactoEmergenciaCreate]