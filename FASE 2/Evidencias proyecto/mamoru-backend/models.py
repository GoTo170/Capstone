import uuid
from sqlalchemy import Column, String, Boolean, TIMESTAMP, Numeric, Text, ForeignKey, Integer, Date, Time, text
from sqlalchemy.dialects.postgresql import UUID
from database import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    nombre = Column(String(150), nullable=False)
    apellido = Column(String(150))
    email = Column(String(150), unique=True)
    password_hash = Column(String(255))
    rol = Column(String(20), nullable=False)
    telefono = Column(String(20))
    activo = Column(Boolean, default=True)
    codigo_verificacion = Column(String(10))
    codigo_verificacion_expira = Column(TIMESTAMP)
    email_verificado = Column(Boolean, default=False)
    foto_url = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=text("now()"))


class PerfilCuidador(Base):
    __tablename__ = "perfiles_cuidador"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    experiencia = Column(Text)
    servicios_ofrecidos = Column(Text)
    ubicacion = Column(String(150))
    tarifa_hora = Column(Numeric(10, 2))
    es_area_salud = Column(Boolean, default=False)
    disponible = Column(Boolean, default=True)
    valoracion_promedio = Column(Numeric(2, 1), default=0.0)
    estado_validacion = Column(String(20), default="pendiente")
    profesion = Column(String(150))
    documento_url = Column(String(500))
    fecha_validacion = Column(TIMESTAMP)
    motivo_rechazo = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=text("now()"))
    descripcion = Column(Text)
    puertas_adentro_pendiente = Column(Boolean, nullable=False, default=False, server_default=text("false"))
    puertas_adentro_fecha_solicitud = Column(TIMESTAMP)
    foto_url = Column(Text)


class PerfilAdultoMayor(Base):
    __tablename__ = "perfiles_adulto_mayor"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), unique=True, nullable=False)
    fecha_nacimiento = Column(Date)
    enfermedades = Column(Text)
    alergia_medicamentos = Column(Text)
    alergia_alimentos = Column(Text)
    intolerancia_alimentaria = Column(Text)
    fecha_creacion = Column(TIMESTAMP, server_default=text("now()"))


class ContactoEmergencia(Base):
    __tablename__ = "contactos_emergencia"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    adulto_mayor_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    nombre = Column(String(150), nullable=False)
    telefono = Column(String(20), nullable=False)
    parentesco = Column(String(50))
    orden = Column(Integer, nullable=False)
    fecha_creacion = Column(TIMESTAMP, server_default=text("now()"))


class InvitacionVinculacion(Base):
    __tablename__ = "invitaciones_vinculacion"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    adulto_mayor_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    creado_por_familiar_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    token_hash = Column(String(255))
    codigo = Column(String(10), nullable=False)
    estado = Column(String(20), default="pendiente")
    expira_en = Column(TIMESTAMP, nullable=False)
    utilizado_en = Column(TIMESTAMP)
    creado_en = Column(TIMESTAMP, server_default=text("now()"))


class Vinculacion(Base):
    __tablename__ = "vinculaciones"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    adulto_mayor_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    familiar_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    estado = Column(String(20), default="activa")
    fecha_vinculacion = Column(TIMESTAMP, server_default=text("now()"))
    parentesco = Column(String(50))


class SolicitudServicio(Base):
    __tablename__ = "solicitudes_servicio"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    solicitante_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    adulto_mayor_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    cuidador_id = Column(UUID(as_uuid=True), ForeignKey("perfiles_cuidador.id", ondelete="CASCADE"), nullable=False)
    estado = Column(String(20), default="pendiente")
    direccion = Column(String(255))
    fecha_inicio = Column(Date)
    hora_inicio = Column(Time)
    fecha_termino = Column(Date)
    hora_termino = Column(Time)
    tipo_servicio = Column(String(100))
    informacion_adicional = Column(Text)
    mensaje = Column(Text)
    motivo_rechazo = Column(String(50))
    motivo_rechazo_detalle = Column(Text)
    fecha_solicitud = Column(TIMESTAMP, server_default=text("now()"))
    fecha_resolucion = Column(TIMESTAMP)


class TareaRecordatorio(Base):
    __tablename__ = "tareas_recordatorios"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    adulto_mayor_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    creado_por_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"))
    titulo = Column(String(150), nullable=False)
    categoria = Column(String(50))
    descripcion = Column(Text)
    estado = Column(String(20), default="pendiente")
    fecha_programada = Column(TIMESTAMP, nullable=False)
    fecha_confirmacion = Column(TIMESTAMP)
    # Quién registró la actividad como realizada / no realizada (null = nadie aún o el sistema).
    completada_por_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"))
    completada_por_rol = Column(String(20))  # adulto_mayor, cuidador, administrador, sistema
    # Hora que tenía antes de adelantarla (null = nunca se adelantó).
    hora_original = Column(TIMESTAMP)
 
    @property
    def es_flexible(self) -> bool:
       """Las flexibles se pueden adelantar; las de horario estricto (medicamentos, citas…) no."""
       return (self.categoria or "") in CATEGORIAS_FLEXIBLES
 
 
# Categorías que se pueden adelantar. Todo lo demás se trata como horario estricto.
CATEGORIAS_FLEXIBLES = {"comida", "higiene", "evento", "mascota"}



class BitacoraCuidado(Base):
    __tablename__ = "bitacora_cuidados"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    tarea_id = Column(UUID(as_uuid=True), ForeignKey("tareas_recordatorios.id", ondelete="CASCADE"), nullable=False)
    solicitud_servicio_id = Column(UUID(as_uuid=True), ForeignKey("solicitudes_servicio.id", ondelete="SET NULL"))
    autor_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    observacion = Column(Text, nullable=False)
    tipo_incidencia = Column(String(50), default="general")
    fecha_registro = Column(TIMESTAMP, server_default=text("now()"))


class AlertaSOS(Base):
    __tablename__ = "alertas_sos"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    estado = Column(String(20), default="activa")
    fecha_alerta = Column(TIMESTAMP, server_default=text("now()"))
    fecha_atencion = Column(TIMESTAMP)


class Notificacion(Base):
    __tablename__ = "notificaciones"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    tipo = Column(String(30), nullable=False)
    mensaje = Column(Text, nullable=False)
    leida = Column(Boolean, default=False)
    fecha_envio = Column(TIMESTAMP, server_default=text("now()"))


class Valoracion(Base):
    __tablename__ = "valoraciones"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    solicitud_id = Column(UUID(as_uuid=True), ForeignKey("solicitudes_servicio.id", ondelete="CASCADE"), nullable=False)
    puntuacion = Column(Integer, nullable=False)
    comentario = Column(Text)
    fecha = Column(TIMESTAMP, server_default=text("now()"))
    reportada = Column(Boolean, default=False)
    motivo_reporte = Column(Text)
    habilitada = Column(Boolean, default=True)


class Auditoria(Base):
    __tablename__ = "auditoria"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    administrador_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=False)
    accion = Column(String(100), nullable=False)
    entidad_tipo = Column(String(50), nullable=False)
    entidad_id = Column(UUID(as_uuid=True))
    detalle = Column(Text)
    fecha = Column(TIMESTAMP, server_default=text("now()"))


class DispositivoPush(Base):
    """Celular de un usuario donde se envían las notificaciones push."""
    __tablename__ = "dispositivos_push"
 
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("uuid_generate_v4()"))
    usuario_id = Column(UUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    token = Column(Text, nullable=False, unique=True)
    plataforma = Column(String(20), default="android")
    fecha_actualizacion = Column(TIMESTAMP, server_default=text("now()"))
 