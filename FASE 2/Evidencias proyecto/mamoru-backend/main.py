import os
import time as reloj
import random
import uuid
import string
from datetime import date, datetime, timedelta, time, timezone

from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import engine, get_db, Base
import models
import schemas
import push
from security import hash_password, verify_password, crear_token_acceso, verificar_token

from almacenamiento import (
    ErrorAlmacenamiento,
    borrar_foto,
    decodificar_imagen_base64,
    detectar_imagen,
    estado_almacenamiento,
    subir_foto,
)

# Hora de Chile: en la nube el servidor trabaja en UTC.
os.environ.setdefault("TZ", "America/Santiago")
if hasattr(reloj, "tzset"):
    reloj.tzset()

Base.metadata.create_all(bind=engine, checkfirst=True)
 
# Cada notificación que se guarda sale también como push al celular (si Firebase está configurado).
push.registrar_eventos()

app = FastAPI(title="Mamoru API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security_scheme = HTTPBearer()


# ============================================================
# Autenticación y autorización
# ============================================================

def obtener_usuario_actual(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: Session = Depends(get_db),
):
    token = credentials.credentials
    payload = verificar_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    usuario = db.query(models.Usuario).filter(models.Usuario.id == payload.get("sub")).first()
    if usuario is None:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    if not usuario.activo:
        raise HTTPException(status_code=401, detail="Cuenta desactivada")
    return usuario


def requerir_administrador(usuario_actual: models.Usuario = Depends(obtener_usuario_actual)):
    if usuario_actual.rol != "administrador":
        raise HTTPException(status_code=403, detail="Esta acción requiere permisos de administrador")
    return usuario_actual


def requerir_rol(rol_esperado: str):
    def dependencia(usuario_actual: models.Usuario = Depends(obtener_usuario_actual)):
        if usuario_actual.rol != rol_esperado:
            raise HTTPException(status_code=403, detail=f"Esta acción requiere el rol '{rol_esperado}'")
        return usuario_actual
    return dependencia


# ============================================================
# Funciones de apoyo
# ============================================================

def registrar_auditoria(db, admin_id, accion, entidad_tipo, entidad_id=None, detalle=None):
    registro = models.Auditoria(
        administrador_id=admin_id,
        accion=accion,
        entidad_tipo=entidad_tipo,
        entidad_id=entidad_id,
        detalle=detalle,
    )
    db.add(registro)
    db.commit()


def notificar_administradores(db, tipo, mensaje):
    administradores = db.query(models.Usuario).filter(models.Usuario.rol == "administrador").all()
    for admin in administradores:
        db.add(models.Notificacion(usuario_id=admin.id, tipo=tipo, mensaje=mensaje))
    db.commit()


def generar_codigo(longitud: int = 6) -> str:
    return "".join(random.choices(string.digits, k=longitud))

MAX_ADULTOS_MAYORES_POR_FAMILIAR = 2
EDAD_MINIMA_ADULTO_MAYOR = 60
MINUTOS_SESION_MOVIL = 60 * 24 * 7           # familiar y cuidador: 7 días
MINUTOS_SESION_ADULTO_MAYOR = 60 * 24 * 365  # adulto mayor: 1 año (no tiene contraseña)


def generar_codigo_invitacion(db) -> str:
    """Código con el formato de la app: 4 letras + guion + 4 números (ej: PRVP-9290).
    No usa I ni O para que no se confundan con 1 y 0."""
    letras = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    while True:
        codigo = "".join(random.choices(letras, k=4)) + "-" + "".join(random.choices(string.digits, k=4))
        ya_existe = db.query(models.InvitacionVinculacion).filter(
            models.InvitacionVinculacion.codigo == codigo
        ).first()
        if not ya_existe:
            return codigo


def calcular_edad(nacimiento: date) -> int:
    hoy = date.today()
    return hoy.year - nacimiento.year - ((hoy.month, hoy.day) < (nacimiento.month, nacimiento.day))


def familiar_tiene_vinculacion(db, familiar_id, adulto_mayor_id) -> bool:
    v = db.query(models.Vinculacion).filter(
        models.Vinculacion.familiar_id == familiar_id,
        models.Vinculacion.adulto_mayor_id == adulto_mayor_id,
        models.Vinculacion.estado == "activa",
    ).first()
    return v is not None


def cuidador_tiene_acceso(db, cuidador_usuario_id, adulto_mayor_id) -> bool:
    """Un cuidador tiene acceso a un adulto mayor solo si tiene un servicio
    ACEPTADO con ese adulto mayor Y la fecha/hora actual está dentro del
    período autorizado (fecha/hora inicio - fecha/hora término)."""
    perfil = db.query(models.PerfilCuidador).filter(
        models.PerfilCuidador.usuario_id == cuidador_usuario_id
    ).first()
    if not perfil:
        return False

    ahora = datetime.now()
    servicios = db.query(models.SolicitudServicio).filter(
        models.SolicitudServicio.cuidador_id == perfil.id,
        models.SolicitudServicio.adulto_mayor_id == adulto_mayor_id,
        models.SolicitudServicio.estado == "aceptada",
    ).all()

    for s in servicios:
        if s.fecha_inicio and s.fecha_termino:
            inicio = datetime.combine(s.fecha_inicio, s.hora_inicio or time.min)
            termino = datetime.combine(s.fecha_termino, s.hora_termino or time.max)
            if inicio <= ahora <= termino:
                return True
    return False


# ============================================================
# Básicos
# ============================================================

@app.get("/")
def inicio():
    return {"mensaje": "Mamoru API funcionando"}


@app.get("/salud")
def salud():
    return {"estado": "ok"}


@app.get("/salud-db")
def salud_db(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"conexion_base_datos": "ok"}


# ============================================================
# Usuarios / autenticación
# ============================================================

@app.post("/usuarios", response_model=schemas.UsuarioOut)
def crear_usuario(usuario: schemas.UsuarioCreate, db: Session = Depends(get_db)):
    if usuario.rol not in ("familiar", "cuidador"):
        raise HTTPException(
            status_code=400,
            detail="El autoregistro solo está permitido para los roles 'familiar' y 'cuidador'",
        )

    ya_existe = db.query(models.Usuario).filter(models.Usuario.email == usuario.email).first()
    if ya_existe:
        raise HTTPException(status_code=400, detail="Ya existe un usuario con ese correo")

    nuevo_usuario = models.Usuario(
        nombre=usuario.nombre,
        apellido=usuario.apellido,
        email=usuario.email,
        password_hash=hash_password(usuario.password),
        rol=usuario.rol,
        telefono=usuario.telefono,
    )
    db.add(nuevo_usuario)
    db.flush()

    if usuario.rol == "cuidador":
        db.add(
            models.PerfilCuidador(
                usuario_id=nuevo_usuario.id,
                profesion=usuario.profesion,
                es_area_salud=bool(usuario.es_area_salud),
                experiencia=usuario.experiencia,
                servicios_ofrecidos=usuario.servicios_ofrecidos,
            )
        )

    db.commit()
    db.refresh(nuevo_usuario)
    return nuevo_usuario


@app.get("/usuarios", response_model=list[schemas.UsuarioOut])
def listar_usuarios(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    return db.query(models.Usuario).all()

@app.patch("/usuarios/{usuario_id}/estado", response_model=schemas.UsuarioOut)
def cambiar_estado_usuario(
    usuario_id: str,
    datos: schemas.UsuarioEstado,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if str(usuario.id) == str(usuario_actual.id) and not datos.activo:
        raise HTTPException(status_code=400, detail="No puedes deshabilitar tu propia cuenta")

    usuario.activo = datos.activo
    db.commit()
    db.refresh(usuario)

    accion = "Habilitó cuenta" if datos.activo else "Deshabilitó cuenta"
    detalle = f"{usuario.nombre} {usuario.apellido or ''}".strip()
    registrar_auditoria(db, usuario_actual.id, accion, "usuario", usuario.id, detalle)

    return usuario

ROLES_INTERNOS = ("administrador",)


@app.post("/usuarios/equipo", response_model=schemas.UsuarioOut)
def crear_miembro_equipo(
    datos: schemas.MiembroEquipoCreate,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    if datos.rol not in ROLES_INTERNOS:
        raise HTTPException(status_code=400, detail="Rol no permitido para el equipo interno")
    if len(datos.password) < 8:
        raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 8 caracteres")

    ya_existe = db.query(models.Usuario).filter(models.Usuario.email == datos.email).first()
    if ya_existe:
        raise HTTPException(status_code=400, detail="Ya existe un usuario con ese correo")

    nuevo = models.Usuario(
        nombre=datos.nombre,
        apellido=datos.apellido,
        email=datos.email,
        password_hash=hash_password(datos.password),
        rol=datos.rol,
        telefono=datos.telefono,
        email_verificado=True,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)

    detalle = f"{nuevo.nombre} {nuevo.apellido or ''}".strip() + f" ({nuevo.rol})"
    registrar_auditoria(db, usuario_actual.id, "Creó miembro del equipo", "usuario", nuevo.id, detalle)

    return nuevo

@app.post("/login", response_model=schemas.Token)
def login(datos: schemas.LoginRequest, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(models.Usuario.email == datos.email).first()

    if not usuario or not usuario.password_hash or not verify_password(datos.password, usuario.password_hash):
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")

    if not usuario.activo:
        raise HTTPException(status_code=403, detail="Esta cuenta está desactivada")

    minutos = None if usuario.rol == "administrador" else MINUTOS_SESION_MOVIL
    token = crear_token_acceso({"sub": str(usuario.id), "rol": usuario.rol}, minutos=minutos)
    usuario_out = schemas.UsuarioOut.model_validate(usuario)

    return schemas.Token(access_token=token, usuario=usuario_out)


@app.get("/perfil", response_model=schemas.UsuarioOut)
@app.get("/perfil", response_model=schemas.UsuarioOut)
def mi_perfil(usuario_actual: models.Usuario = Depends(obtener_usuario_actual)):
    return usuario_actual
 
 
LARGO_MINIMO_CONTRASENA = 8
 
 
@app.post("/perfil/verificar-contrasena")
def verificar_contrasena_actual(
    datos: schemas.VerificarContrasena,
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    """Paso 1 del cambio de contraseña: comprueba la contraseña actual de quien está conectado."""
    if not usuario_actual.password_hash or not verify_password(datos.password_actual, usuario_actual.password_hash):
        raise HTTPException(status_code=400, detail="La contraseña actual no es correcta")
    return {"ok": True}
 
 
@app.patch("/perfil/contrasena")
def cambiar_mi_contrasena(
    datos: schemas.CambioContrasena,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    """Cambia la contraseña de quien está conectado (nunca la de otra persona)."""
    if not usuario_actual.password_hash or not verify_password(datos.password_actual, usuario_actual.password_hash):
        raise HTTPException(status_code=400, detail="La contraseña actual no es correcta")
    if len(datos.password_nueva) < LARGO_MINIMO_CONTRASENA:
        raise HTTPException(status_code=400, detail=f"La contraseña nueva debe tener al menos {LARGO_MINIMO_CONTRASENA} caracteres")
    if datos.password_nueva == datos.password_actual:
        raise HTTPException(status_code=400, detail="La contraseña nueva debe ser distinta de la actual")
 
    usuario_actual.password_hash = hash_password(datos.password_nueva)
    db.commit()
 
    if usuario_actual.rol == "administrador":
        registrar_auditoria(db, usuario_actual.id, "Cambió su contraseña", "usuario", usuario_actual.id, None)
 
    return {"ok": True}


# ============================================================
# Cuidadores
# ============================================================

@app.get("/cuidadores", response_model=list[schemas.PerfilCuidadorOut])
def listar_cuidadores(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    query = db.query(models.PerfilCuidador)
    if usuario_actual.rol != "administrador":
        query = query.filter(models.PerfilCuidador.estado_validacion == "aprobado")
    return query.all()


@app.get("/cuidadores/mi-perfil", response_model=schemas.PerfilCuidadorOut)
def mi_perfil_cuidador(
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    perfil = db.query(models.PerfilCuidador).filter(
        models.PerfilCuidador.usuario_id == cuidador_actual.id
    ).first()
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil de cuidador no encontrado")
    return perfil


@app.patch("/cuidadores/{cuidador_id}", response_model=schemas.PerfilCuidadorOut)
def actualizar_estado_cuidador(
    cuidador_id: str,
    datos: schemas.PerfilCuidadorUpdate,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    if datos.estado_validacion not in ("pendiente", "aprobado", "rechazado"):
        raise HTTPException(status_code=400, detail="estado_validacion inválido")

    perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == cuidador_id).first()
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil de cuidador no encontrado")

    motivo = (datos.motivo_rechazo or "").strip()
    if datos.estado_validacion == "rechazado":
        if not motivo:
            raise HTTPException(status_code=400, detail="Escribe el motivo del rechazo")
        if len(motivo) > 300:
            raise HTTPException(status_code=400, detail="El motivo es demasiado largo (máximo 300 caracteres)")
    else:
        motivo = ""  # al aprobar o volver a pendiente se borra un motivo anterior
 
    estado_anterior = perfil.estado_validacion
    perfil.estado_validacion = datos.estado_validacion
    perfil.motivo_rechazo = motivo or None
    if datos.estado_validacion in ("aprobado", "rechazado"):
        perfil.fecha_validacion = text("now()")
 
    # El cuidador recibe el motivo en sus notificaciones (solo la primera vez que se rechaza).
    if datos.estado_validacion == "rechazado" and estado_anterior != "rechazado":
        db.add(models.Notificacion(
            usuario_id=perfil.usuario_id,
            tipo="perfil_rechazado",
            mensaje=f"Tu perfil de cuidador fue rechazado: {motivo}",
        ))
 
    db.commit()
    db.refresh(perfil)
 
    if datos.estado_validacion == "aprobado":
        accion = "Aprobó cuidador"
    elif datos.estado_validacion == "rechazado":
        accion = "Rechazó cuidador"
    else:
        accion = f"Cambió estado de cuidador a {datos.estado_validacion}"
    registrar_auditoria(db, usuario_actual.id, accion, "perfil_cuidador", perfil.id, motivo or None)

    return perfil


# ============================================================
# Adulto mayor / vinculaciones / invitaciones
# ============================================================

@app.post("/adultos-mayores", response_model=schemas.AdultoMayorCreadoOut)
def crear_adulto_mayor(
    datos: schemas.AdultoMayorCreate,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    # --- Validaciones (antes de tocar la base de datos) ---
    if datos.fecha_nacimiento is None:
        raise HTTPException(status_code=400, detail="La fecha de nacimiento es obligatoria")

    edad = calcular_edad(datos.fecha_nacimiento)
    if datos.fecha_nacimiento > date.today() or edad > 120:
        raise HTTPException(status_code=400, detail="La fecha de nacimiento no es válida")
    if edad < EDAD_MINIMA_ADULTO_MAYOR:
        raise HTTPException(
            status_code=400,
            detail=f"El adulto mayor debe tener al menos {EDAD_MINIMA_ADULTO_MAYOR} años",
        )

    if datos.relacion_familiar and len(datos.relacion_familiar) > 50:
        raise HTTPException(status_code=400, detail="La relación familiar es demasiado larga (máximo 50 caracteres)")

    if len(datos.contactos) < 1:
        raise HTTPException(status_code=400, detail="Debes agregar al menos un contacto de emergencia")
    if len(datos.contactos) > 3:
        raise HTTPException(status_code=400, detail="Máximo 3 contactos de emergencia")
    for contacto in datos.contactos:
        if len(contacto.telefono.strip()) > 20:
            raise HTTPException(
                status_code=400,
                detail="El teléfono de un contacto es demasiado largo (máximo 20 caracteres)",
            )

    vinculados = db.query(models.Vinculacion).filter(
        models.Vinculacion.familiar_id == familiar_actual.id,
        models.Vinculacion.estado == "activa",
    ).count()
    if vinculados >= MAX_ADULTOS_MAYORES_POR_FAMILIAR:
        raise HTTPException(
            status_code=400,
            detail=f"Ya alcanzaste el máximo de {MAX_ADULTOS_MAYORES_POR_FAMILIAR} adultos mayores vinculados",
        )

    # --- Creación (todo o nada) ---
    try:
        nuevo_usuario = models.Usuario(
            nombre=datos.nombre,
            apellido=datos.apellido,
            rol="adulto_mayor",
            telefono=datos.telefono,
        )
        db.add(nuevo_usuario)
        db.flush()

        nuevo_perfil = models.PerfilAdultoMayor(
            usuario_id=nuevo_usuario.id,
            fecha_nacimiento=datos.fecha_nacimiento,
            enfermedades=datos.enfermedades,
            alergia_medicamentos=datos.alergia_medicamentos,
            alergia_alimentos=datos.alergia_alimentos,
            intolerancia_alimentaria=datos.intolerancia_alimentaria,
        )
        db.add(nuevo_perfil)

        nuevos_contactos = []
        for contacto in datos.contactos:
            nuevo_contacto = models.ContactoEmergencia(
                adulto_mayor_id=nuevo_usuario.id,
                nombre=contacto.nombre,
                telefono=contacto.telefono.strip(),
                parentesco=contacto.parentesco,
                orden=contacto.orden,
            )
            db.add(nuevo_contacto)
            nuevos_contactos.append(nuevo_contacto)

        db.add(models.Vinculacion(
            adulto_mayor_id=nuevo_usuario.id,
            familiar_id=familiar_actual.id,
            estado="activa",
            parentesco=datos.relacion_familiar,
        ))

        nueva_invitacion = models.InvitacionVinculacion(
            adulto_mayor_id=nuevo_usuario.id,
            creado_por_familiar_id=familiar_actual.id,
            codigo=generar_codigo_invitacion(db),
            estado="pendiente",
            expira_en=datetime.now() + timedelta(hours=48),
        )
        db.add(nueva_invitacion)

        db.commit()
        db.refresh(nuevo_usuario)
        db.refresh(nuevo_perfil)
        db.refresh(nueva_invitacion)
        for c in nuevos_contactos:
            db.refresh(c)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="No se pudo crear el adulto mayor; no se guardó ningún cambio.",
        )

    return schemas.AdultoMayorCreadoOut(
        usuario=nuevo_usuario,
        perfil=nuevo_perfil,
        contactos=nuevos_contactos,
        invitacion=nueva_invitacion,
    )


@app.post("/invitaciones/canjear", response_model=schemas.Token)
def canjear_invitacion(datos: schemas.CanjearCodigoRequest, db: Session = Depends(get_db)):
    invitacion = (
        db.query(models.InvitacionVinculacion)
        .filter(models.InvitacionVinculacion.codigo == datos.codigo.strip().upper())
        .order_by(models.InvitacionVinculacion.creado_en.desc())
        .first()
    )

    if not invitacion:
        raise HTTPException(status_code=404, detail="Código inválido")

    if invitacion.estado != "pendiente":
        raise HTTPException(status_code=400, detail="Este código ya fue utilizado o revocado")

    if invitacion.expira_en < datetime.now():
        invitacion.estado = "expirado"
        db.commit()
        raise HTTPException(status_code=400, detail="Este código ya expiró")

    invitacion.estado = "usado"
    invitacion.utilizado_en = datetime.now()
    db.commit()

    adulto_mayor = db.query(models.Usuario).filter(models.Usuario.id == invitacion.adulto_mayor_id).first()
    token = crear_token_acceso(
        {"sub": str(adulto_mayor.id), "rol": adulto_mayor.rol},
        minutos=MINUTOS_SESION_ADULTO_MAYOR,
    )
    usuario_out = schemas.UsuarioOut.model_validate(adulto_mayor)

    return schemas.Token(access_token=token, usuario=usuario_out)

@app.post("/adultos-mayores/{adulto_mayor_id}/invitacion", response_model=schemas.InvitacionVinculacionOut)
def regenerar_invitacion(
    adulto_mayor_id: str,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    if not familiar_tiene_vinculacion(db, familiar_actual.id, adulto_mayor_id):
        raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")

    # Las invitaciones pendientes anteriores dejan de servir
    db.query(models.InvitacionVinculacion).filter(
        models.InvitacionVinculacion.adulto_mayor_id == adulto_mayor_id,
        models.InvitacionVinculacion.estado == "pendiente",
    ).update({"estado": "revocado"})

    nueva = models.InvitacionVinculacion(
        adulto_mayor_id=adulto_mayor_id,
        creado_por_familiar_id=familiar_actual.id,
        codigo=generar_codigo_invitacion(db),
        estado="pendiente",
        expira_en=datetime.now() + timedelta(hours=48),
    )
    db.add(nueva)
    db.commit()
    db.refresh(nueva)
    return nueva

def acceso_activado(db, adulto_mayor_id) -> bool:
    """True si el adulto mayor ya entró alguna vez con un código de invitación."""
    usada = db.query(models.InvitacionVinculacion).filter(
        models.InvitacionVinculacion.adulto_mayor_id == adulto_mayor_id,
        models.InvitacionVinculacion.estado == "usado",
    ).first()
    return usada is not None


@app.get("/adultos-mayores", response_model=list[schemas.AdultoMayorResumenOut])
def listar_adultos_mayores(
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    vinculaciones = db.query(models.Vinculacion).filter(
        models.Vinculacion.familiar_id == familiar_actual.id,
        models.Vinculacion.estado == "activa",
    ).order_by(models.Vinculacion.fecha_vinculacion).all()

    resultado = []
    for v in vinculaciones:
        usuario = db.query(models.Usuario).filter(models.Usuario.id == v.adulto_mayor_id).first()
        if not usuario:
            continue
        perfil = db.query(models.PerfilAdultoMayor).filter(
            models.PerfilAdultoMayor.usuario_id == usuario.id
        ).first()
        resultado.append(schemas.AdultoMayorResumenOut(
            id=usuario.id,
            nombre=usuario.nombre,
            apellido=usuario.apellido,
            fecha_nacimiento=perfil.fecha_nacimiento if perfil else None,
            parentesco=v.parentesco,
            fecha_vinculacion=v.fecha_vinculacion,
            acceso_activado=acceso_activado(db, usuario.id),
            foto_url=usuario.foto_url,
        ))
    return resultado


@app.get("/adultos-mayores/{adulto_mayor_id}", response_model=schemas.AdultoMayorDetalleOut)
def detalle_adulto_mayor(
    adulto_mayor_id: str,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    vinculacion = db.query(models.Vinculacion).filter(
        models.Vinculacion.familiar_id == familiar_actual.id,
        models.Vinculacion.adulto_mayor_id == adulto_mayor_id,
        models.Vinculacion.estado == "activa",
    ).first()
    if not vinculacion:
        raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")

    usuario = db.query(models.Usuario).filter(models.Usuario.id == adulto_mayor_id).first()
    perfil = db.query(models.PerfilAdultoMayor).filter(
        models.PerfilAdultoMayor.usuario_id == adulto_mayor_id
    ).first()
    contactos = db.query(models.ContactoEmergencia).filter(
        models.ContactoEmergencia.adulto_mayor_id == adulto_mayor_id
    ).order_by(models.ContactoEmergencia.orden).all()

    return schemas.AdultoMayorDetalleOut(
        id=usuario.id,
        nombre=usuario.nombre,
        apellido=usuario.apellido,
        fecha_nacimiento=perfil.fecha_nacimiento if perfil else None,
        parentesco=vinculacion.parentesco,
        fecha_vinculacion=vinculacion.fecha_vinculacion,
        acceso_activado=acceso_activado(db, usuario.id),
        foto_url=usuario.foto_url,
        telefono=usuario.telefono,
        enfermedades=perfil.enfermedades if perfil else None,
        alergia_medicamentos=perfil.alergia_medicamentos if perfil else None,
        alergia_alimentos=perfil.alergia_alimentos if perfil else None,
        intolerancia_alimentaria=perfil.intolerancia_alimentaria if perfil else None,
        contactos=contactos,
    )


@app.delete("/adultos-mayores/{adulto_mayor_id}/invitacion")
def revocar_invitacion(
    adulto_mayor_id: str,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    if not familiar_tiene_vinculacion(db, familiar_actual.id, adulto_mayor_id):
        raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")

    revocadas = db.query(models.InvitacionVinculacion).filter(
        models.InvitacionVinculacion.adulto_mayor_id == adulto_mayor_id,
        models.InvitacionVinculacion.estado == "pendiente",
    ).update({"estado": "revocado"})
    db.commit()
    return {"ok": True, "revocadas": revocadas}


@app.get("/adulto-mayor/mi-perfil", response_model=schemas.MiPerfilAdultoMayorOut)
def mi_perfil_adulto_mayor(
    db: Session = Depends(get_db),
    adulto_actual: models.Usuario = Depends(requerir_rol("adulto_mayor")),
):
    perfil = db.query(models.PerfilAdultoMayor).filter(
        models.PerfilAdultoMayor.usuario_id == adulto_actual.id
    ).first()

    vinculaciones = db.query(models.Vinculacion).filter(
        models.Vinculacion.adulto_mayor_id == adulto_actual.id,
        models.Vinculacion.estado == "activa",
    ).order_by(models.Vinculacion.fecha_vinculacion).all()

    familiares = []
    for v in vinculaciones:
        familiar = db.query(models.Usuario).filter(models.Usuario.id == v.familiar_id).first()
        if familiar:
            familiares.append(schemas.FamiliarVinculadoOut(
                nombre=familiar.nombre,
                apellido=familiar.apellido,
                fecha_vinculacion=v.fecha_vinculacion,
                foto_url=familiar.foto_url,
            ))

    return schemas.MiPerfilAdultoMayorOut(
        nombre=adulto_actual.nombre,
        apellido=adulto_actual.apellido,
        fecha_nacimiento=perfil.fecha_nacimiento if perfil else None,
        foto_url=adulto_actual.foto_url,
        familiares=familiares,
    )


@app.get("/vinculaciones", response_model=list[schemas.VinculacionOut])
def listar_vinculaciones(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    query = db.query(models.Vinculacion)
    if usuario_actual.rol == "familiar":
        query = query.filter(models.Vinculacion.familiar_id == usuario_actual.id)
    elif usuario_actual.rol == "adulto_mayor":
        query = query.filter(models.Vinculacion.adulto_mayor_id == usuario_actual.id)
    elif usuario_actual.rol != "administrador":
        raise HTTPException(status_code=403, detail="No autorizado")
    return query.all()


# ============================================================
# Tareas
# ============================================================

@app.post("/tareas", response_model=schemas.TareaRecordatorioOut)
def crear_tarea(
    datos: schemas.TareaRecordatorioCreate,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    if not familiar_tiene_vinculacion(db, familiar_actual.id, datos.adulto_mayor_id):
        raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")

    nueva = models.TareaRecordatorio(
        adulto_mayor_id=datos.adulto_mayor_id,
        creado_por_id=familiar_actual.id,
        titulo=datos.titulo,
        categoria=datos.categoria,
        descripcion=datos.descripcion,
        fecha_programada=datos.fecha_programada,
    )
    db.add(nueva)
    db.commit()
    db.refresh(nueva)
    return nueva

MAX_TAREAS_POR_LOTE = 400


@app.post("/tareas/lote", response_model=list[schemas.TareaRecordatorioOut])
def crear_tareas_lote(
    datos: schemas.TareaRecordatorioLote,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    if not familiar_tiene_vinculacion(db, familiar_actual.id, datos.adulto_mayor_id):
        raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")

    titulo = datos.titulo.strip()
    if not titulo:
        raise HTTPException(status_code=400, detail="El título es obligatorio")
    if len(titulo) > 150:
        raise HTTPException(status_code=400, detail="El título es demasiado largo (máximo 150 caracteres)")
    if datos.categoria and len(datos.categoria) > 50:
        raise HTTPException(status_code=400, detail="La categoría es demasiado larga")
    if not datos.fechas:
        raise HTTPException(status_code=400, detail="Debes indicar al menos una fecha")
    if len(datos.fechas) > MAX_TAREAS_POR_LOTE:
        raise HTTPException(
            status_code=400,
            detail=f"Máximo {MAX_TAREAS_POR_LOTE} actividades por vez",
        )

    nuevas = []
    for fecha in sorted(set(datos.fechas)):
        tarea = models.TareaRecordatorio(
            adulto_mayor_id=datos.adulto_mayor_id,
            creado_por_id=familiar_actual.id,
            titulo=titulo,
            categoria=datos.categoria,
            descripcion=datos.descripcion,
            fecha_programada=fecha,
        )
        db.add(tarea)
        nuevas.append(tarea)

    db.commit()
    for tarea in nuevas:
        db.refresh(tarea)
    return nuevas


@app.patch("/notificaciones/{notificacion_id}/leida")
def marcar_notificacion_leida(
    notificacion_id: str,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    notificacion = db.query(models.Notificacion).filter(
        models.Notificacion.id == notificacion_id,
        models.Notificacion.usuario_id == usuario_actual.id,
    ).first()
    if not notificacion:
        raise HTTPException(status_code=404, detail="Notificación no encontrada")

    notificacion.leida = True
    db.commit()
    return {"ok": True}

def marcar_tareas_vencidas(db, adultos_ids, ahora=None):
    """Marca como 'no_realizada' las tareas pendientes que ya vencieron.
 
    Una tarea vence cuando empieza la siguiente tarea del mismo día (la que
    tiene una hora posterior) sin que se haya registrado. La última tarea del
    día no vence. Es la misma regla que aplica la app del adulto mayor, pero
    aquí vale aunque su app esté cerrada.
 
    Queda como hora de registro la hora en que empezó la tarea siguiente.
    Devuelve cuántas tareas marcó.
    """
    ids = list(adultos_ids)
    if not ids:
        return 0
    ahora = ahora or datetime.now()
 
    candidatas = db.query(models.TareaRecordatorio).filter(
        models.TareaRecordatorio.adulto_mayor_id.in_(ids),
        models.TareaRecordatorio.estado == "pendiente",
        models.TareaRecordatorio.fecha_programada <= ahora,
    ).all()
    if not candidatas:
        return 0
 
    dias = {t.fecha_programada.date() for t in candidatas}
    inicio_dias = datetime.combine(min(dias), time.min)
 
    # Todas las tareas ya iniciadas de esos adultos y días (de cualquier estado).
    iniciadas = db.query(models.TareaRecordatorio).filter(
        models.TareaRecordatorio.adulto_mayor_id.in_(ids),
        models.TareaRecordatorio.fecha_programada >= inicio_dias,
        models.TareaRecordatorio.fecha_programada <= ahora,
    ).order_by(models.TareaRecordatorio.fecha_programada.asc()).all()
 
    por_dia = {}
    for t in iniciadas:
        por_dia.setdefault((t.adulto_mayor_id, t.fecha_programada.date()), []).append(t)
 
    marcadas = 0
    for lista in por_dia.values():
        for i, tarea in enumerate(lista):
            if tarea.estado != "pendiente":
                continue
            siguiente = next((x for x in lista[i + 1:] if x.fecha_programada > tarea.fecha_programada), None)
            if siguiente is None:
                continue  # es la última del día: no vence
            tarea.estado = "no_realizada"
            tarea.fecha_confirmacion = siguiente.fecha_programada
            tarea.completada_por_id = None
            tarea.completada_por_rol = "sistema"
            marcadas += 1

 
    if marcadas:
        db.commit()
    return marcadas
 
 
@app.get("/tareas", response_model=list[schemas.TareaRecordatorioOut])
def listar_tareas(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    if usuario_actual.rol == "adulto_mayor":
        marcar_tareas_vencidas(db, [usuario_actual.id])
        return db.query(models.TareaRecordatorio).filter(
            models.TareaRecordatorio.adulto_mayor_id == usuario_actual.id
        ).all()
 
    if usuario_actual.rol == "familiar":
        ids_vinculados = [
            v.adulto_mayor_id for v in db.query(models.Vinculacion).filter(
                models.Vinculacion.familiar_id == usuario_actual.id,
                models.Vinculacion.estado == "activa",
            ).all()
        ]
        marcar_tareas_vencidas(db, ids_vinculados)
        return db.query(models.TareaRecordatorio).filter(
            models.TareaRecordatorio.adulto_mayor_id.in_(ids_vinculados)
        ).all()
 
    if usuario_actual.rol == "cuidador":
        perfil = db.query(models.PerfilCuidador).filter(
            models.PerfilCuidador.usuario_id == usuario_actual.id
        ).first()
        if not perfil:
            return []
 
        ahora = datetime.now()
        servicios = db.query(models.SolicitudServicio).filter(
            models.SolicitudServicio.cuidador_id == perfil.id,
            models.SolicitudServicio.estado == "aceptada",
        ).all()
 
        ids_adultos = set()
        for s in servicios:
            if s.fecha_inicio and s.fecha_termino:
                inicio = datetime.combine(s.fecha_inicio, s.hora_inicio or time.min)
                termino = datetime.combine(s.fecha_termino, s.hora_termino or time.max)
                if inicio <= ahora <= termino:
                    ids_adultos.add(s.adulto_mayor_id)
 
        marcar_tareas_vencidas(db, ids_adultos, ahora)
        return db.query(models.TareaRecordatorio).filter(
            models.TareaRecordatorio.adulto_mayor_id.in_(ids_adultos)
        ).all()
 
    if usuario_actual.rol == "administrador":
        return db.query(models.TareaRecordatorio).all()
 
    return []

@app.patch("/tareas/{tarea_id}/estado", response_model=schemas.TareaRecordatorioOut)
def actualizar_estado_tarea(
    tarea_id: str,
    datos: schemas.TareaRecordatorioEstado,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    if datos.estado not in ("pendiente", "realizada", "no_realizada"):
        raise HTTPException(status_code=400, detail="Estado inválido")

    tarea = db.query(models.TareaRecordatorio).filter(models.TareaRecordatorio.id == tarea_id).first()
    if not tarea:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")

    autorizado = (
        (usuario_actual.rol == "adulto_mayor" and tarea.adulto_mayor_id == usuario_actual.id)
        or (usuario_actual.rol == "cuidador" and cuidador_tiene_acceso(db, usuario_actual.id, tarea.adulto_mayor_id))
        or (usuario_actual.rol == "administrador")
    )
    if not autorizado:
        raise HTTPException(status_code=403, detail="No autorizado para modificar esta tarea")

    tarea.estado = datos.estado
    tarea.fecha_confirmacion = datetime.now()
    if datos.estado == "pendiente":
        tarea.completada_por_id = None
        tarea.completada_por_rol = None
    else:
        # Queda registrado quién la marcó, para que el seguimiento no diga siempre "el cuidador".
        tarea.completada_por_id = usuario_actual.id
        tarea.completada_por_rol = usuario_actual.rol
    db.commit()
    db.refresh(tarea)
    return tarea
    
    
MINUTOS_MAXIMOS_ADELANTO = 30
    
    
def _tarea_con_acceso(db, tarea_id, usuario_actual):
    """Busca la actividad y comprueba que quien pide es el adulto mayor o su cuidador vigente."""
    tarea = db.query(models.TareaRecordatorio).filter(models.TareaRecordatorio.id == tarea_id).first()
    if not tarea:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    autorizado = (
        (usuario_actual.rol == "adulto_mayor" and tarea.adulto_mayor_id == usuario_actual.id)
        or (usuario_actual.rol == "cuidador" and cuidador_tiene_acceso(db, usuario_actual.id, tarea.adulto_mayor_id))
    )
    if not autorizado:
        raise HTTPException(status_code=403, detail="No autorizado para modificar esta tarea")
    return tarea
    
    
def _familiares_del_adulto(db, adulto_mayor_id):
    return [
        v.familiar_id for v in db.query(models.Vinculacion).filter(
            models.Vinculacion.adulto_mayor_id == adulto_mayor_id,
            models.Vinculacion.estado == "activa",
        ).all()
    ]
    
    
def _hora_texto(f):
    return f.strftime("%H:%M")
    
    
@app.post("/tareas/{tarea_id}/adelantar", response_model=schemas.TareaRecordatorioOut)
def adelantar_tarea(
    tarea_id: str,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
    ):
    """Pasa una actividad flexible a la hora actual, si falta poco para su hora."""
    tarea = _tarea_con_acceso(db, tarea_id, usuario_actual)
    
    if not tarea.es_flexible:
        raise HTTPException(
            status_code=400,
            detail="Esta actividad tiene horario estricto y no se puede adelantar. Puedes avisar al responsable si necesita cambiarse",
        )
    if tarea.estado != "pendiente":
        raise HTTPException(status_code=400, detail="Solo se puede adelantar una actividad pendiente")
    
    ahora = datetime.now().replace(second=0, microsecond=0)
    if tarea.fecha_programada <= ahora:
        raise HTTPException(status_code=400, detail="Esta actividad ya llegó a su hora")
    if tarea.fecha_programada - ahora > timedelta(minutes=MINUTOS_MAXIMOS_ADELANTO):
        raise HTTPException(
            status_code=400,
            detail=f"Solo se puede adelantar hasta {MINUTOS_MAXIMOS_ADELANTO} minutos antes de su hora ({_hora_texto(tarea.fecha_programada)})",
        )
    
    hora_anterior = tarea.fecha_programada
    if tarea.hora_original is None:
        tarea.hora_original = hora_anterior
    tarea.fecha_programada = ahora
    
    quien = "El adulto mayor" if usuario_actual.rol == "adulto_mayor" else "El cuidador"
    for familiar_id in _familiares_del_adulto(db, tarea.adulto_mayor_id):
        db.add(models.Notificacion(
            usuario_id=familiar_id,
            tipo="actividad_adelantada",
            mensaje=f"{quien} adelantó «{tarea.titulo}»: de las {_hora_texto(hora_anterior)} a las {_hora_texto(ahora)}",
        ))
    db.commit()
    db.refresh(tarea)
    return tarea
    
    
@app.post("/tareas/{tarea_id}/solicitar-cambio")
def solicitar_cambio_horario(
    tarea_id: str,
    datos: schemas.SolicitudCambioHorario,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
    ):
    """Para actividades de horario estricto: Mamoru no las mueve, solo avisa a la familia."""
    tarea = _tarea_con_acceso(db, tarea_id, usuario_actual)
    if tarea.estado != "pendiente":
        raise HTTPException(status_code=400, detail="Solo se puede pedir un cambio en una actividad pendiente")
    
    motivo = (datos.motivo or "").strip()
    if len(motivo) > 200:
        raise HTTPException(status_code=400, detail="El motivo es demasiado largo (máximo 200 caracteres)")
    
    quien = "El adulto mayor" if usuario_actual.rol == "adulto_mayor" else "El cuidador"
    mensaje = f"{quien} pide revisar el horario de «{tarea.titulo}» ({_hora_texto(tarea.fecha_programada)})"
    if motivo:
        mensaje += f": {motivo}"
    
    familiares = _familiares_del_adulto(db, tarea.adulto_mayor_id)
    for familiar_id in familiares:
        db.add(models.Notificacion(usuario_id=familiar_id, tipo="cambio_horario_pedido", mensaje=mensaje))
    db.commit()
    return {"ok": True, "avisados": len(familiares)}



# ============================================================
# Bitácora de cuidados
# ============================================================

@app.post("/bitacora", response_model=schemas.BitacoraCuidadoOut)
def crear_registro_bitacora(
    datos: schemas.BitacoraCuidadoCreate,
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    tarea = db.query(models.TareaRecordatorio).filter(models.TareaRecordatorio.id == datos.tarea_id).first()
    if not tarea:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")

    if not cuidador_tiene_acceso(db, cuidador_actual.id, tarea.adulto_mayor_id):
        raise HTTPException(status_code=403, detail="No tienes un servicio vigente para este adulto mayor")

    nuevo = models.BitacoraCuidado(
        tarea_id=datos.tarea_id,
        solicitud_servicio_id=datos.solicitud_servicio_id,
        autor_id=cuidador_actual.id,
        observacion=datos.observacion,
        tipo_incidencia=datos.tipo_incidencia,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@app.get("/bitacora", response_model=list[schemas.BitacoraCuidadoOut])
def listar_bitacora(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    if usuario_actual.rol == "administrador":
        return db.query(models.BitacoraCuidado).all()

    if usuario_actual.rol == "cuidador":
        return db.query(models.BitacoraCuidado).filter(
            models.BitacoraCuidado.autor_id == usuario_actual.id
        ).all()

    if usuario_actual.rol == "familiar":
        ids_vinculados = [
            v.adulto_mayor_id for v in db.query(models.Vinculacion).filter(
                models.Vinculacion.familiar_id == usuario_actual.id,
                models.Vinculacion.estado == "activa",
            ).all()
        ]
        ids_tareas = [
            t.id for t in db.query(models.TareaRecordatorio).filter(
                models.TareaRecordatorio.adulto_mayor_id.in_(ids_vinculados)
            ).all()
        ]
        return db.query(models.BitacoraCuidado).filter(
            models.BitacoraCuidado.tarea_id.in_(ids_tareas)
        ).all()

    return []


# ============================================================
# Solicitudes de servicio
# ============================================================

def obtener_solicitud_de_cuidador(db, solicitud_id, usuario_actual):
    solicitud = db.query(models.SolicitudServicio).filter(models.SolicitudServicio.id == solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")

    perfil = db.query(models.PerfilCuidador).filter(
        models.PerfilCuidador.usuario_id == usuario_actual.id
    ).first()
    if not perfil or solicitud.cuidador_id != perfil.id:
        raise HTTPException(status_code=403, detail="No autorizado sobre esta solicitud")

    return solicitud


TIPOS_SERVICIO = (
   "acompanamiento_apoyo_emocional",
   "cuidado_fisico_personal",
   "control_medicamentos",
   "alimentacion",
   "cuidador_integral",
   "cuidado_puertas_adentro",
)
MAX_HORAS_SERVICIO = 16
 
 
def validar_solicitud(datos, ahora, servicios_del_cuidador=()):
   """Reglas de una solicitud de servicio, antes de guardarla.
 
   El tipo de servicio es uno de los que el cuidador marcó en su perfil
   (se guarda con el mismo nombre) o una de las claves antiguas."""
   if datos.tipo_servicio not in TIPOS_SERVICIO and datos.tipo_servicio not in servicios_del_cuidador:
       raise HTTPException(status_code=400, detail="Ese servicio no lo ofrece el cuidador")
   if not datos.direccion or not datos.direccion.strip():
       raise HTTPException(status_code=400, detail="La dirección es obligatoria")
   if not (datos.fecha_inicio and datos.hora_inicio and datos.fecha_termino and datos.hora_termino):
       raise HTTPException(status_code=400, detail="Indica la fecha y hora de inicio y de término")
 
   inicio = datetime.combine(datos.fecha_inicio, datos.hora_inicio)
   termino = datetime.combine(datos.fecha_termino, datos.hora_termino)
 
   if termino <= inicio:
       raise HTTPException(status_code=400, detail="La hora de término debe ser posterior a la de inicio")
   if inicio < ahora - timedelta(minutes=5):
       raise HTTPException(status_code=400, detail="La fecha y hora de inicio ya pasaron")
   if (termino - inicio) > timedelta(hours=MAX_HORAS_SERVICIO) and datos.tipo_servicio != "cuidado_puertas_adentro":
       raise HTTPException(
           status_code=400,
           detail=f"Un servicio de más de {MAX_HORAS_SERVICIO} horas debe ser de tipo puertas adentro",
       )

 
@app.post("/solicitudes", response_model=schemas.SolicitudServicioOut)
def crear_solicitud(
   datos: schemas.SolicitudServicioCreate,
   db: Session = Depends(get_db),
   familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
   if not familiar_tiene_vinculacion(db, familiar_actual.id, datos.adulto_mayor_id):
       raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")
 
   perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == datos.cuidador_id).first()
   if not perfil or perfil.estado_validacion != "aprobado":
       raise HTTPException(status_code=404, detail="Ese cuidador no está disponible")
 
   servicios_del_cuidador = [l for l in lineas_de(perfil.servicios_ofrecidos) if l != MARCA_PUERTAS_ADENTRO]
   validar_solicitud(datos, datetime.now(), servicios_del_cuidador)
 
   nueva = models.SolicitudServicio(
       solicitante_id=familiar_actual.id,
       adulto_mayor_id=datos.adulto_mayor_id,
       cuidador_id=datos.cuidador_id,
       direccion=datos.direccion.strip(),
       fecha_inicio=datos.fecha_inicio,
       hora_inicio=datos.hora_inicio,
       fecha_termino=datos.fecha_termino,
       hora_termino=datos.hora_termino,
       tipo_servicio=datos.tipo_servicio,
       informacion_adicional=datos.informacion_adicional,
       mensaje=datos.mensaje,
   )
   db.add(nueva)
   db.add(models.Notificacion(
       usuario_id=perfil.usuario_id,
       tipo="solicitud_nueva",
       mensaje=f"{familiar_actual.nombre} te envió una solicitud de servicio",
   ))
   db.commit()
   db.refresh(nueva)
   return nueva
 
 
@app.get("/familiar/solicitudes", response_model=list[schemas.SolicitudFamiliarOut])
def listar_solicitudes_familiar(
   db: Session = Depends(get_db),
   familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
   solicitudes = db.query(models.SolicitudServicio).filter(
       models.SolicitudServicio.solicitante_id == familiar_actual.id
   ).order_by(models.SolicitudServicio.fecha_solicitud.desc()).all()
 
   resultado = []
   for s in solicitudes:
       perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == s.cuidador_id).first()
       cuidador = db.query(models.Usuario).filter(models.Usuario.id == perfil.usuario_id).first() if perfil else None
       adulto = db.query(models.Usuario).filter(models.Usuario.id == s.adulto_mayor_id).first()
       valoracion = db.query(models.Valoracion).filter(models.Valoracion.solicitud_id == s.id).first()

       resultado.append(schemas.SolicitudFamiliarOut(
           id=s.id,
           estado=s.estado,
           cuidador_nombre=f"{cuidador.nombre} {cuidador.apellido or ''}".strip() if cuidador else "Cuidador",
           adulto_mayor_nombre=f"{adulto.nombre} {adulto.apellido or ''}".strip() if adulto else "Adulto mayor",
           fecha_inicio=s.fecha_inicio,
           hora_inicio=s.hora_inicio,
           fecha_termino=s.fecha_termino,
           hora_termino=s.hora_termino,
           tipo_servicio=s.tipo_servicio,
           motivo_rechazo=s.motivo_rechazo,
           motivo_rechazo_detalle=s.motivo_rechazo_detalle,
           fecha_solicitud=s.fecha_solicitud,
           valoracion_puntuacion=valoracion.puntuacion if valoracion else None,
       ))
   return resultado



@app.get("/solicitudes", response_model=list[schemas.SolicitudServicioOut])
def listar_solicitudes(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    if usuario_actual.rol == "administrador":
        return db.query(models.SolicitudServicio).all()

    if usuario_actual.rol == "familiar":
        return db.query(models.SolicitudServicio).filter(
            models.SolicitudServicio.solicitante_id == usuario_actual.id
        ).all()

    if usuario_actual.rol == "cuidador":
        perfil = db.query(models.PerfilCuidador).filter(
            models.PerfilCuidador.usuario_id == usuario_actual.id
        ).first()
        if not perfil:
            return []
        return db.query(models.SolicitudServicio).filter(
            models.SolicitudServicio.cuidador_id == perfil.id
        ).all()

    return []


@app.patch("/solicitudes/{solicitud_id}/finalizar", response_model=schemas.SolicitudServicioOut)
def finalizar_solicitud(
    solicitud_id: str,
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    solicitud = obtener_solicitud_de_cuidador(db, solicitud_id, cuidador_actual)
 
    if solicitud.estado != "aceptada":
        raise HTTPException(status_code=400, detail="Solo se puede finalizar un servicio aceptado")
 
    # Un servicio que todavía no comienza no se puede cerrar. Uno cuyo período ya
    # terminó sí: el cuidador debe poder finalizarlo para que la familia lo valore.
    if solicitud.fecha_inicio:
        inicio = datetime.combine(solicitud.fecha_inicio, solicitud.hora_inicio or time.min)
        if datetime.now() < inicio:
            raise HTTPException(status_code=400, detail="El servicio todavía no ha comenzado")
 
    adulto = db.query(models.Usuario).filter(models.Usuario.id == solicitud.adulto_mayor_id).first()
    nombre_adulto = f"{adulto.nombre} {adulto.apellido or ''}".strip() if adulto else "el adulto mayor"

    recien_finalizada = solicitud.estado != "finalizada"
    solicitud.estado = "finalizada"
    if recien_finalizada:
        # Avisa al familiar que ya puede valorar al cuidador y dónde hacerlo.
        nombre_cuidador = f"{cuidador_actual.nombre} {cuidador_actual.apellido or ''}".strip()
        db.add(models.Notificacion(
            usuario_id=solicitud.solicitante_id,
            tipo="servicio_finalizado",
            mensaje=f"El servicio con {nombre_cuidador} finalizó. Ya puedes valorarlo en Solicitudes → Finalizada.",
        ))
    db.commit()
    db.refresh(solicitud)
    return solicitud

MOTIVOS_RECHAZO = (
   "no_tengo_disponibilidad",
   "horario_no_acomoda",
   "ubicacion_fuera_zona",
   "tipo_cuidado_no_corresponde",
   "otros",
)
EXIGIR_PERFIL_COMPLETO = True
 
 
def validar_rechazo(datos):
   if datos.motivo_rechazo not in MOTIVOS_RECHAZO:
       raise HTTPException(status_code=400, detail="Motivo de rechazo no válido")
   detalle = (datos.motivo_rechazo_detalle or "").strip()
   if datos.motivo_rechazo == "otros" and not detalle:
       raise HTTPException(status_code=400, detail="Escribe el motivo del rechazo")
   if len(detalle) > 300:
       raise HTTPException(status_code=400, detail="El motivo es demasiado largo (máximo 300 caracteres)")
   return detalle or None
 
 
def obtener_perfil_del_cuidador(db, usuario):
   perfil = db.query(models.PerfilCuidador).filter(
       models.PerfilCuidador.usuario_id == usuario.id
   ).first()
   if not perfil:
       raise HTTPException(status_code=404, detail="Perfil de cuidador no encontrado")
   return perfil

# ============================================================
# Perfil del cuidador
# ============================================================
 
@app.get("/cuidador/mi-perfil", response_model=schemas.MiPerfilCuidadorOut)
def ver_mi_perfil_cuidador(
   db: Session = Depends(get_db),
   cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
   perfil = obtener_perfil_del_cuidador(db, cuidador_actual)
   return armar_mi_perfil_cuidador(cuidador_actual, perfil)
 
 
@app.patch("/cuidador/mi-perfil", response_model=schemas.MiPerfilCuidadorOut)
def actualizar_mi_perfil_cuidador(
    datos: schemas.MiPerfilCuidadorUpdate,
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    perfil = obtener_perfil_del_cuidador(db, cuidador_actual)

    if datos.telefono is not None:
        telefono = datos.telefono.strip()
        if not telefono:
            raise HTTPException(status_code=400, detail="El teléfono es obligatorio")
        if len(telefono) > 20:
            raise HTTPException(status_code=400, detail="El teléfono es demasiado largo (máximo 20 caracteres)")
        cuidador_actual.telefono = telefono

    if datos.descripcion is not None:
        descripcion = datos.descripcion.strip()
        if len(descripcion) > 500:
            raise HTTPException(status_code=400, detail="La descripción no puede superar los 500 caracteres")
        perfil.descripcion = descripcion or None

    if datos.servicios_ofrecidos is not None:
        perfil.servicios_ofrecidos = servicios_para_guardar(perfil, datos.servicios_ofrecidos)

    db.commit()
    db.refresh(cuidador_actual)
    db.refresh(perfil)
    return armar_mi_perfil_cuidador(cuidador_actual, perfil)
 
 
@app.get("/cuidador/valoraciones", response_model=list[schemas.ValoracionCuidadorOut])
def listar_valoraciones_cuidador(
   db: Session = Depends(get_db),
   cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
   perfil = db.query(models.PerfilCuidador).filter(
       models.PerfilCuidador.usuario_id == cuidador_actual.id
   ).first()
   if not perfil:
       return []
 
   # Se muestran las visibles y las que él mismo reportó (en revisión).
   resenas = (
       db.query(models.Valoracion)
       .join(models.SolicitudServicio, models.SolicitudServicio.id == models.Valoracion.solicitud_id)
       .filter(
           models.SolicitudServicio.cuidador_id == perfil.id,
           (models.Valoracion.habilitada == True) | (models.Valoracion.reportada == True),
       )
       .order_by(models.Valoracion.fecha.desc())
       .all()
   )
   return [
       schemas.ValoracionCuidadorOut(
           id=r.id,
           puntuacion=r.puntuacion,
           comentario=r.comentario,
           fecha=r.fecha,
           reportada=r.reportada,
           motivo_reporte=r.motivo_reporte,
       )
       for r in resenas
   ]
 
 
# ============================================================
# Solicitudes recibidas por el cuidador
# ============================================================
 
def solicitud_esta_vigente(s, ahora) -> bool:
    """Un servicio está vigente si fue ACEPTADO y 'ahora' cae dentro de su
    período (fecha y hora de inicio - fecha y hora de término).

    Es la misma regla de cuidador_tiene_acceso, pero aplicada a UNA solicitud:
    así los datos sensibles se entregan solo para el servicio que está en curso
    y no para los anteriores o futuros del mismo adulto mayor."""
    if s.estado != "aceptada" or not (s.fecha_inicio and s.fecha_termino):
        return False

    inicio = datetime.combine(s.fecha_inicio, s.hora_inicio or time.min)
    termino = datetime.combine(s.fecha_termino, s.hora_termino or time.max)
    return inicio <= ahora <= termino


@app.get("/cuidador/solicitudes", response_model=list[schemas.SolicitudCuidadorOut])
def listar_solicitudes_cuidador(
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    perfil = db.query(models.PerfilCuidador).filter(
        models.PerfilCuidador.usuario_id == cuidador_actual.id
    ).first()
    if not perfil:
        return []

    solicitudes = db.query(models.SolicitudServicio).filter(
        models.SolicitudServicio.cuidador_id == perfil.id
    ).order_by(models.SolicitudServicio.fecha_solicitud.desc()).all()

    ahora = datetime.now()
    resultado = []

    for s in solicitudes:
        familiar = db.query(models.Usuario).filter(models.Usuario.id == s.solicitante_id).first()
        adulto = db.query(models.Usuario).filter(models.Usuario.id == s.adulto_mayor_id).first()

        # La salud y los contactos de emergencia solo se consultan (y se
        # entregan) durante el servicio vigente.
        vigente = solicitud_esta_vigente(s, ahora)

        perfil_adulto = None
        contactos = []
        if vigente:
            perfil_adulto = db.query(models.PerfilAdultoMayor).filter(
                models.PerfilAdultoMayor.usuario_id == s.adulto_mayor_id
            ).first()
            contactos = db.query(models.ContactoEmergencia).filter(
                models.ContactoEmergencia.adulto_mayor_id == s.adulto_mayor_id
            ).order_by(models.ContactoEmergencia.orden).all()

        edad = None
        if perfil_adulto and perfil_adulto.fecha_nacimiento:
            edad = calcular_edad(perfil_adulto.fecha_nacimiento)

        resultado.append(schemas.SolicitudCuidadorOut(
            id=s.id,
            adulto_mayor_id=s.adulto_mayor_id,
            estado=s.estado,
            familiar_nombre=f"{familiar.nombre} {familiar.apellido or ''}".strip() if familiar else "Familiar",
            adulto_mayor_nombre=f"{adulto.nombre} {adulto.apellido or ''}".strip() if adulto else "Adulto mayor",
            fecha_solicitud=s.fecha_solicitud,
            fecha_inicio=s.fecha_inicio,
            hora_inicio=s.hora_inicio,
            fecha_termino=s.fecha_termino,
            hora_termino=s.hora_termino,
            tipo_servicio=s.tipo_servicio,
            direccion=s.direccion,
            informacion_adicional=s.informacion_adicional,
            mensaje=s.mensaje,
            motivo_rechazo=s.motivo_rechazo,
            motivo_rechazo_detalle=s.motivo_rechazo_detalle,
            fecha_resolucion=s.fecha_resolucion,
            adulto_mayor_edad=edad,
            adulto_mayor_telefono=adulto.telefono if (adulto and vigente) else None,
            enfermedades=perfil_adulto.enfermedades if perfil_adulto else None,
            alergia_medicamentos=perfil_adulto.alergia_medicamentos if perfil_adulto else None,
            alergia_alimentos=perfil_adulto.alergia_alimentos if perfil_adulto else None,
            intolerancia_alimentaria=perfil_adulto.intolerancia_alimentaria if perfil_adulto else None,
            contactos_emergencia=[
                schemas.ContactoServicioOut(nombre=c.nombre, telefono=c.telefono, parentesco=c.parentesco)
                for c in contactos
            ],
            puede_ver_informacion_sensible=vigente,
        ))

    return resultado
 
 
def solicitud_pendiente_del_cuidador(db, solicitud_id, usuario_actual):
   solicitud = obtener_solicitud_de_cuidador(db, solicitud_id, usuario_actual)
   if solicitud.estado != "pendiente":
       raise HTTPException(status_code=400, detail="Esta solicitud ya fue respondida")
   return solicitud
 
 
@app.patch("/solicitudes/{solicitud_id}/aceptar", response_model=schemas.SolicitudServicioOut)
def aceptar_solicitud(
   solicitud_id: str,
   db: Session = Depends(get_db),
   cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
   solicitud = solicitud_pendiente_del_cuidador(db, solicitud_id, cuidador_actual)
   solicitud.estado = "aceptada"
   solicitud.fecha_resolucion = datetime.now()
   db.add(models.Notificacion(
       usuario_id=solicitud.solicitante_id,
       tipo="solicitud_aceptada",
       mensaje=f"{cuidador_actual.nombre} aceptó tu solicitud de servicio",
   ))
   db.commit()
   db.refresh(solicitud)
   return solicitud
 
 
@app.patch("/solicitudes/{solicitud_id}/rechazar", response_model=schemas.SolicitudServicioOut)
def rechazar_solicitud(
   solicitud_id: str,
   datos: schemas.SolicitudServicioRechazar,
   db: Session = Depends(get_db),
   cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
   solicitud = solicitud_pendiente_del_cuidador(db, solicitud_id, cuidador_actual)
   detalle = validar_rechazo(datos)
 
   solicitud.estado = "rechazada"
   solicitud.motivo_rechazo = datos.motivo_rechazo
   solicitud.motivo_rechazo_detalle = detalle
   solicitud.fecha_resolucion = datetime.now()
   db.add(models.Notificacion(
       usuario_id=solicitud.solicitante_id,
       tipo="solicitud_rechazada",
       mensaje=f"{cuidador_actual.nombre} rechazó tu solicitud de servicio",
   ))
   db.commit()
   db.refresh(solicitud)
   return solicitud

MARCA_PUERTAS_ADENTRO = "Cuidado puertas adentro"


def ahora_utc():
    """Hora UTC sin zona, igual que las fechas que genera la base de datos."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def lineas_de(texto):
    return [l.strip() for l in (texto or "").split("\n") if l.strip()]


def tiene_puertas_adentro(perfil) -> bool:
    """La modalidad activa se guarda como una línea más en servicios_ofrecidos."""
    return MARCA_PUERTAS_ADENTRO in lineas_de(perfil.servicios_ofrecidos)


def fijar_puertas_adentro(perfil, activo: bool):
    lineas = [l for l in lineas_de(perfil.servicios_ofrecidos) if l != MARCA_PUERTAS_ADENTRO]
    if activo:
        lineas.append(MARCA_PUERTAS_ADENTRO)
    perfil.servicios_ofrecidos = "\n".join(lineas) or None


def servicios_para_guardar(perfil, texto_entrante):
    """Especialidades que envía el cuidador al editar su perfil.

    La modalidad puertas adentro NO se puede cambiar por aquí: se ignora la
    línea si la envían y se conserva tal como está. Solo cambia con la
    aprobación del administrador (o dejando de ofrecerla)."""
    lineas = [l for l in lineas_de(texto_entrante) if l != MARCA_PUERTAS_ADENTRO]
    if tiene_puertas_adentro(perfil):
        lineas.append(MARCA_PUERTAS_ADENTRO)
    return "\n".join(lineas) or None


def aplicar_solicitud_puertas_adentro(perfil, activar: bool) -> str:
    """Aplica lo que pide el cuidador. Activar la modalidad queda pendiente de
    aprobación; dejar de ofrecerla es inmediato.
    Devuelve 'pendiente' o 'desactivada'."""
    if perfil.estado_validacion != "aprobado":
        raise HTTPException(status_code=400, detail="Tu perfil todavía no está aprobado")

    activa = tiene_puertas_adentro(perfil)

    if activar:
        if activa:
            raise HTTPException(status_code=400, detail="Ya ofreces la modalidad puertas adentro")
        if perfil.puertas_adentro_pendiente:
            raise HTTPException(status_code=400, detail="Ya tienes una solicitud pendiente de aprobación")
        perfil.puertas_adentro_pendiente = True
        perfil.puertas_adentro_fecha_solicitud = ahora_utc()
        return "pendiente"

    if not activa and not perfil.puertas_adentro_pendiente:
        raise HTTPException(status_code=400, detail="No ofreces la modalidad puertas adentro")
    fijar_puertas_adentro(perfil, False)
    perfil.puertas_adentro_pendiente = False
    perfil.puertas_adentro_fecha_solicitud = None
    return "desactivada"


def aplicar_decision_puertas_adentro(perfil, aprobar: bool):
    if not perfil.puertas_adentro_pendiente:
        raise HTTPException(status_code=400, detail="Este cuidador no tiene una solicitud pendiente")
    if aprobar:
        fijar_puertas_adentro(perfil, True)
    perfil.puertas_adentro_pendiente = False
    perfil.puertas_adentro_fecha_solicitud = None


# ============================================================
# Modalidad "puertas adentro"
# ============================================================

@app.post("/cuidador/puertas-adentro", response_model=schemas.MiPerfilCuidadorOut)
def solicitar_cambio_puertas_adentro(
    datos: schemas.PuertasAdentroSolicitud,
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    perfil = obtener_perfil_del_cuidador(db, cuidador_actual)
    resultado = aplicar_solicitud_puertas_adentro(perfil, datos.activar)
    db.commit()

    if resultado == "pendiente":
        notificar_administradores(
            db,
            "puertas_adentro_solicitada",
            f"{cuidador_actual.nombre} solicitó activar la modalidad puertas adentro",
        )

    db.refresh(cuidador_actual)
    db.refresh(perfil)
    return armar_mi_perfil_cuidador(cuidador_actual, perfil)


@app.patch("/cuidadores/{cuidador_id}/puertas-adentro", response_model=schemas.PerfilCuidadorOut)
def resolver_puertas_adentro(
    cuidador_id: str,
    datos: schemas.PuertasAdentroDecision,
    db: Session = Depends(get_db),
    admin_actual: models.Usuario = Depends(requerir_administrador),
):
    perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == cuidador_id).first()
    if not perfil:
        raise HTTPException(status_code=404, detail="Cuidador no encontrado")

    motivo = (datos.motivo or "").strip()
    if len(motivo) > 300:
        raise HTTPException(status_code=400, detail="El motivo es demasiado largo (máximo 300 caracteres)")

    aplicar_decision_puertas_adentro(perfil, datos.aprobar)

    cuidador = db.query(models.Usuario).filter(models.Usuario.id == perfil.usuario_id).first()
    nombre = f"{cuidador.nombre} {cuidador.apellido or ''}".strip() if cuidador else "Cuidador"

    if datos.aprobar:
        mensaje = "Tu solicitud de modalidad puertas adentro fue aprobada"
    else:
        mensaje = "Tu solicitud de modalidad puertas adentro fue rechazada"
        if motivo:
            mensaje += f": {motivo}"

    db.add(models.Notificacion(
        usuario_id=perfil.usuario_id,
        tipo="puertas_adentro_aprobada" if datos.aprobar else "puertas_adentro_rechazada",
        mensaje=mensaje,
    ))
    db.commit()
    db.refresh(perfil)

    accion = "Aprobó modalidad puertas adentro" if datos.aprobar else "Rechazó modalidad puertas adentro"
    registrar_auditoria(db, admin_actual.id, accion, "perfil_cuidador", perfil.id, nombre)

    return perfil

# Cuando la app ya permita subir la foto, cambia esto a True: sin foto, el perfil
# no se mostrará a las familias (así lo define el diseño de la app).
EXIGIR_FOTO_PERFIL = False


def perfil_cuidador_completo(perfil, usuario) -> bool:
    """Perfil listo para mostrarse a las familias: descripción, al menos una
    especialidad (la modalidad puertas adentro no cuenta como especialidad),
    teléfono y, si se exige, foto."""
    especialidades = [l for l in lineas_de(perfil.servicios_ofrecidos) if l != MARCA_PUERTAS_ADENTRO]
    return bool(
        perfil.descripcion and perfil.descripcion.strip()
        and especialidades
        and usuario.telefono and usuario.telefono.strip()
        and (perfil.foto_url or not EXIGIR_FOTO_PERFIL)
    )


def armar_mi_perfil_cuidador(usuario, perfil):
    return schemas.MiPerfilCuidadorOut(
        nombre=usuario.nombre,
        apellido=usuario.apellido,
        email=usuario.email,
        telefono=usuario.telefono,
        profesion=perfil.profesion,
        experiencia=perfil.experiencia,
        descripcion=perfil.descripcion,
        servicios_ofrecidos=perfil.servicios_ofrecidos,
        es_area_salud=perfil.es_area_salud,
        estado_validacion=perfil.estado_validacion,
        puertas_adentro_pendiente=perfil.puertas_adentro_pendiente,
        foto_url=perfil.foto_url,
    )


# ============================================================
# Foto de perfil del cuidador (Supabase Storage)
# ============================================================

@app.put("/cuidador/mi-foto", response_model=schemas.MiPerfilCuidadorOut)
def subir_mi_foto(
    datos: schemas.FotoPerfilSubir,
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    perfil = obtener_perfil_del_cuidador(db, cuidador_actual)

    try:
        contenido = decodificar_imagen_base64(datos.imagen_base64)
        extension, tipo_contenido = detectar_imagen(contenido)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    try:
        url_nueva = subir_foto(str(cuidador_actual.id), contenido, tipo_contenido, extension)
    except ErrorAlmacenamiento as e:
        print(f"[almacenamiento] {e.mensaje} | {e.detalle}")
        raise HTTPException(status_code=502, detail=e.mensaje)

    url_anterior = perfil.foto_url
    perfil.foto_url = url_nueva
    db.commit()

    if url_anterior:
        borrar_foto(url_anterior)

    db.refresh(cuidador_actual)
    db.refresh(perfil)
    return armar_mi_perfil_cuidador(cuidador_actual, perfil)


@app.delete("/cuidador/mi-foto", response_model=schemas.MiPerfilCuidadorOut)
def quitar_mi_foto(
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    perfil = obtener_perfil_del_cuidador(db, cuidador_actual)

    url_anterior = perfil.foto_url
    perfil.foto_url = None
    db.commit()

    if url_anterior:
        borrar_foto(url_anterior)

    db.refresh(cuidador_actual)
    db.refresh(perfil)
    return armar_mi_perfil_cuidador(cuidador_actual, perfil)


@app.get("/admin/almacenamiento")
def diagnostico_almacenamiento(
    admin_actual: models.Usuario = Depends(requerir_administrador),
):
    """Revisa que el almacenamiento de archivos esté bien configurado."""
    return estado_almacenamiento()

# ============================================================
# Marketplace
# ============================================================
 
@app.get("/marketplace/cuidadores", response_model=list[schemas.CuidadorMarketplaceOut])
def listar_cuidadores_marketplace(
   db: Session = Depends(get_db),
   familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
   perfiles = db.query(models.PerfilCuidador).filter(
       models.PerfilCuidador.estado_validacion == "aprobado"
   ).all()
 
   resultado = []
   for perfil in perfiles:
       usuario = db.query(models.Usuario).filter(models.Usuario.id == perfil.usuario_id).first()
       if not usuario or not usuario.activo:
           continue
       if EXIGIR_PERFIL_COMPLETO and not perfil_cuidador_completo(perfil, usuario):
           continue
 
       resenas = (
           db.query(models.Valoracion)
           .join(models.SolicitudServicio, models.SolicitudServicio.id == models.Valoracion.solicitud_id)
           .filter(
               models.SolicitudServicio.cuidador_id == perfil.id,
               models.Valoracion.habilitada == True,
           )
           .order_by(models.Valoracion.fecha.desc())
           .all()
       )
       promedio = round(sum(r.puntuacion for r in resenas) / len(resenas), 1) if resenas else 0.0
 
       resultado.append(schemas.CuidadorMarketplaceOut(
           id=perfil.id,
           nombre=usuario.nombre,
           apellido=usuario.apellido,
           profesion=perfil.profesion,
           foto_url=perfil.foto_url,
           ubicacion=perfil.ubicacion,
           experiencia=perfil.experiencia,
           descripcion=perfil.descripcion,
           servicios_ofrecidos=perfil.servicios_ofrecidos,
           disponible=perfil.disponible,
           es_area_salud=perfil.es_area_salud,
           calificacion=promedio,
           numero_resenas=len(resenas),
           valoraciones=[
               schemas.ValoracionMarketplaceOut(puntuacion=r.puntuacion, comentario=r.comentario)
               for r in resenas[:20]
           ],
       ))
   return resultado



# ============================================================
# Notificaciones
# ============================================================

@app.get("/notificaciones", response_model=list[schemas.NotificacionOut])
def listar_notificaciones(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    return db.query(models.Notificacion).filter(
        models.Notificacion.usuario_id == usuario_actual.id
    ).all()


@app.patch("/notificaciones/marcar-leidas")
def marcar_notificaciones_leidas(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    db.query(models.Notificacion).filter(
        models.Notificacion.usuario_id == usuario_actual.id,
        models.Notificacion.leida == False,
    ).update({"leida": True})
    db.commit()
    return {"ok": True}


# ============================================================
# Alertas SOS
# ============================================================

@app.post("/alertas-sos", response_model=schemas.AlertaSOSOut)
def crear_alerta_sos(
    db: Session = Depends(get_db),
    adulto_mayor_actual: models.Usuario = Depends(requerir_rol("adulto_mayor")),
):
    nueva = models.AlertaSOS(usuario_id=adulto_mayor_actual.id)
    db.add(nueva)
    db.commit()
    db.refresh(nueva)

    familiares = db.query(models.Vinculacion).filter(
        models.Vinculacion.adulto_mayor_id == adulto_mayor_actual.id,
        models.Vinculacion.estado == "activa",
    ).all()
    for v in familiares:
        db.add(models.Notificacion(
            usuario_id=v.familiar_id,
            tipo="alerta_sos",
            mensaje=f"{adulto_mayor_actual.nombre} activó el botón SOS",
        ))
    db.commit()

    return nueva


@app.get("/alertas-sos", response_model=list[schemas.AlertaSOSOut])
def listar_alertas_sos(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    if usuario_actual.rol == "administrador":
        return db.query(models.AlertaSOS).all()

    if usuario_actual.rol == "adulto_mayor":
        return db.query(models.AlertaSOS).filter(
            models.AlertaSOS.usuario_id == usuario_actual.id
        ).all()

    if usuario_actual.rol == "familiar":
        ids_vinculados = [
            v.adulto_mayor_id for v in db.query(models.Vinculacion).filter(
                models.Vinculacion.familiar_id == usuario_actual.id,
                models.Vinculacion.estado == "activa",
            ).all()
        ]
        return db.query(models.AlertaSOS).filter(
            models.AlertaSOS.usuario_id.in_(ids_vinculados)
        ).all()

    return []


# ============================================================
# Valoraciones
# ============================================================

NOTA_MINIMA = 1
NOTA_MAXIMA = 5
LARGO_MAXIMO_COMENTARIO = 500
 
 
def recalcular_valoracion_promedio(db, perfil_id):
    """Deja en el perfil del cuidador el promedio de sus reseñas visibles (1 decimal).
    Las reseñas ocultas o en revisión no cuentan. Sin reseñas queda en 0.
    No hace commit: lo hace quien la llama."""
    db.flush()  # que la reseña recién creada o cambiada entre en la cuenta
    notas = [
        nota for (nota,) in db.query(models.Valoracion.puntuacion)
        .join(models.SolicitudServicio, models.SolicitudServicio.id == models.Valoracion.solicitud_id)
        .filter(
            models.SolicitudServicio.cuidador_id == perfil_id,
            models.Valoracion.habilitada == True,
        )
        .all()
    ]
    promedio = round(sum(notas) / len(notas), 1) if notas else 0.0
    perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == perfil_id).first()
    if perfil:
        perfil.valoracion_promedio = promedio
    return promedio
 
 
@app.post("/valoraciones", response_model=schemas.ValoracionOut)
def crear_valoracion(
    datos: schemas.ValoracionCreate,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    if datos.puntuacion < NOTA_MINIMA or datos.puntuacion > NOTA_MAXIMA:
        raise HTTPException(status_code=400, detail="La nota debe ser un número entero de 1 a 5")
 
    comentario = (datos.comentario or "").strip() or None
    if comentario and len(comentario) > LARGO_MAXIMO_COMENTARIO:
        raise HTTPException(
            status_code=400,
            detail=f"El comentario es demasiado largo (máximo {LARGO_MAXIMO_COMENTARIO} caracteres)",
        )
 
    solicitud = db.query(models.SolicitudServicio).filter(models.SolicitudServicio.id == datos.solicitud_id).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    if solicitud.solicitante_id != familiar_actual.id:
        raise HTTPException(status_code=403, detail="Esta solicitud no te pertenece")
    if solicitud.estado != "finalizada":
        raise HTTPException(status_code=400, detail="Solo puedes valorar un servicio finalizado")
 
    ya_valorado = db.query(models.Valoracion).filter(models.Valoracion.solicitud_id == datos.solicitud_id).first()
    if ya_valorado:
        raise HTTPException(status_code=400, detail="Esta solicitud ya tiene una valoración")
 
    nueva = models.Valoracion(
        solicitud_id=datos.solicitud_id,
        puntuacion=datos.puntuacion,
        comentario=comentario,
    )
    db.add(nueva)
 
    recalcular_valoracion_promedio(db, solicitud.cuidador_id)
 
    perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == solicitud.cuidador_id).first()
    if perfil:
        db.add(models.Notificacion(
            usuario_id=perfil.usuario_id,
            tipo="nueva_resena",
            mensaje=f"Recibiste una nueva valoración: {datos.puntuacion} de 5 estrellas",
        ))
 
    db.commit()
    db.refresh(nueva)
    return nueva


@app.post("/valoraciones/{valoracion_id}/reportar", response_model=schemas.ValoracionOut)
def reportar_valoracion(
    valoracion_id: str,
    datos: schemas.ValoracionReportar,
    db: Session = Depends(get_db),
    cuidador_actual: models.Usuario = Depends(requerir_rol("cuidador")),
):
    valoracion = db.query(models.Valoracion).filter(models.Valoracion.id == valoracion_id).first()
    if not valoracion:
        raise HTTPException(status_code=404, detail="Valoración no encontrada")

    solicitud = db.query(models.SolicitudServicio).filter(
        models.SolicitudServicio.id == valoracion.solicitud_id
    ).first()
    perfil = db.query(models.PerfilCuidador).filter(
        models.PerfilCuidador.usuario_id == cuidador_actual.id
    ).first()
    if not solicitud or not perfil or solicitud.cuidador_id != perfil.id:
        raise HTTPException(status_code=403, detail="Esta valoración no corresponde a tu perfil")

    if valoracion.reportada:
        raise HTTPException(status_code=400, detail="Esta reseña ya está en revisión")
    if valoracion.motivo_reporte:
        raise HTTPException(status_code=400, detail="Esta reseña ya fue revisada por un administrador")
    if not valoracion.habilitada:
        raise HTTPException(status_code=400, detail="Esta reseña no está visible")
 
    motivo = (datos.motivo_reporte or "").strip()
    if not motivo:
        raise HTTPException(status_code=400, detail="Indica el motivo del reporte")
    if len(motivo) > 300:
        raise HTTPException(status_code=400, detail="El motivo es demasiado largo (máximo 300 caracteres)")
 
    valoracion.reportada = True
    valoracion.motivo_reporte = motivo
    valoracion.habilitada = False  # se oculta mientras un administrador la revisa
 
    recalcular_valoracion_promedio(db, solicitud.cuidador_id)  # una reseña oculta no cuenta en el promedio
 
    db.commit()
    db.refresh(valoracion)
 
    notificar_administradores(db, "resena_reportada", f"Reseña reportada ({valoracion.puntuacion} de 5): {motivo}")
 
    return valoracion


@app.patch("/valoraciones/{valoracion_id}/moderar", response_model=schemas.ValoracionOut)
def moderar_valoracion(
    valoracion_id: str,
    datos: schemas.ValoracionModerar,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    valoracion = db.query(models.Valoracion).filter(models.Valoracion.id == valoracion_id).first()
    if not valoracion:
        raise HTTPException(status_code=404, detail="Valoración no encontrada")

    estaba_reportada = bool(valoracion.reportada)
    valoracion.habilitada = datos.habilitada
    valoracion.reportada = False

    solicitud = db.query(models.SolicitudServicio).filter(
        models.SolicitudServicio.id == valoracion.solicitud_id
    ).first()
    if solicitud:
        recalcular_valoracion_promedio(db, solicitud.cuidador_id)
 
        # Si el cuidador había reportado la reseña, se le avisa qué se resolvió.
        if estaba_reportada:
            perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == solicitud.cuidador_id).first()
            if perfil:
                if datos.habilitada:
                    mensaje = "Revisamos tu reporte: la reseña se mantiene visible."
                else:
                    mensaje = "Revisamos tu reporte: la reseña fue ocultada y ya no cuenta en tu promedio."
                db.add(models.Notificacion(usuario_id=perfil.usuario_id, tipo="resena_revisada", mensaje=mensaje))
 
    db.commit()
    db.refresh(valoracion)
 
    if estaba_reportada:
        accion = "Rechazó reporte de reseña" if datos.habilitada else "Aceptó reporte de reseña"
    else:
        accion = "Habilitó reseña" if datos.habilitada else "Deshabilitó reseña"

    return valoracion


@app.get("/valoraciones", response_model=list[schemas.ValoracionOut])
def listar_valoraciones(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    if usuario_actual.rol == "administrador":
        return db.query(models.Valoracion).all()
    return db.query(models.Valoracion).filter(models.Valoracion.habilitada == True).all()

@app.get("/admin/resenas", response_model=list[schemas.ValoracionAdminOut])
def listar_resenas_admin(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    """Todas las reseñas con quién las escribió y a quién, para moderarlas en el panel."""
    filas = (
        db.query(models.Valoracion, models.SolicitudServicio)
        .join(models.SolicitudServicio, models.SolicitudServicio.id == models.Valoracion.solicitud_id)
        .order_by(models.Valoracion.fecha.desc())
        .all()
    )
 
    def nombre(usuario, defecto):
        if not usuario:
            return defecto
        return f"{usuario.nombre} {usuario.apellido or ''}".strip()
 
    resultado = []
    for v, s in filas:
        perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == s.cuidador_id).first()
        cuidador = db.query(models.Usuario).filter(models.Usuario.id == perfil.usuario_id).first() if perfil else None
        familiar = db.query(models.Usuario).filter(models.Usuario.id == s.solicitante_id).first()
        resultado.append(schemas.ValoracionAdminOut(
            id=v.id,
            puntuacion=v.puntuacion,
            comentario=v.comentario,
            fecha=v.fecha,
            reportada=bool(v.reportada),
            motivo_reporte=v.motivo_reporte,
            habilitada=v.habilitada is not False,
            cuidador_nombre=nombre(cuidador, "Cuidador"),
            familiar_nombre=nombre(familiar, "Familiar"),
        ))
    return resultado
# ============================================================
# Auditoría
# ============================================================

@app.get("/auditoria", response_model=list[schemas.AuditoriaOut])
def listar_auditoria(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(requerir_administrador),
):
    return db.query(models.Auditoria).order_by(models.Auditoria.fecha.desc()).all()


ESTADOS_SOS_FINALES = ("atendida", "cancelada")


# ============================================================
# Alertas SOS en el panel del administrador
# ============================================================

@app.get("/admin/alertas-sos", response_model=list[schemas.AlertaSOSPanelOut])
def listar_alertas_sos_panel(
    db: Session = Depends(get_db),
    admin_actual: models.Usuario = Depends(requerir_administrador),
):
    alertas = db.query(models.AlertaSOS).order_by(models.AlertaSOS.fecha_alerta.desc()).all()

    resultado = []
    for a in alertas:
        persona = db.query(models.Usuario).filter(models.Usuario.id == a.usuario_id).first()
        contactos = db.query(models.ContactoEmergencia).filter(
            models.ContactoEmergencia.adulto_mayor_id == a.usuario_id
        ).order_by(models.ContactoEmergencia.orden).all()
        familiares = (
            db.query(models.Usuario)
            .join(models.Vinculacion, models.Vinculacion.familiar_id == models.Usuario.id)
            .filter(
                models.Vinculacion.adulto_mayor_id == a.usuario_id,
                models.Vinculacion.estado == "activa",
            )
            .all()
        )
        

        resultado.append(schemas.AlertaSOSPanelOut(
            id=a.id,
            persona_nombre=f"{persona.nombre} {persona.apellido or ''}".strip() if persona else "Persona desconocida",
            persona_telefono=persona.telefono if persona else None,
            estado=a.estado,
            fecha_alerta=a.fecha_alerta,
            fecha_atencion=a.fecha_atencion,
            contactos=[
                schemas.ContactoSOSOut(nombre=c.nombre, telefono=c.telefono, parentesco=c.parentesco)
                for c in contactos
            ],
            familiares=[f"{f.nombre} {f.apellido or ''}".strip() for f in familiares],
        ))
    return resultado


@app.patch("/alertas-sos/{alerta_id}/estado", response_model=schemas.AlertaSOSOut)
def actualizar_estado_alerta_sos(
    alerta_id: str,
    datos: schemas.AlertaSOSEstadoUpdate,
    db: Session = Depends(get_db),
    admin_actual: models.Usuario = Depends(requerir_administrador),
):
    if datos.estado not in ESTADOS_SOS_FINALES:
        raise HTTPException(status_code=400, detail="Estado no válido (usa 'atendida' o 'cancelada')")

    alerta = db.query(models.AlertaSOS).filter(models.AlertaSOS.id == alerta_id).first()
    if not alerta:
        raise HTTPException(status_code=404, detail="Alerta no encontrada")
    if alerta.estado != "activa":
        raise HTTPException(status_code=400, detail="Esta alerta ya fue cerrada")

    persona = db.query(models.Usuario).filter(models.Usuario.id == alerta.usuario_id).first()
    nombre = f"{persona.nombre} {persona.apellido or ''}".strip() if persona else "Persona desconocida"

    alerta.estado = datos.estado
    # Hora UTC, igual que la fecha de la alerta (que pone la base de datos).
    alerta.fecha_atencion = datetime.now(timezone.utc).replace(tzinfo=None)

    # Se avisa a los familiares cuando el equipo atiende la alerta.
    if datos.estado == "atendida":
        vinculaciones = db.query(models.Vinculacion).filter(
            models.Vinculacion.adulto_mayor_id == alerta.usuario_id,
            models.Vinculacion.estado == "activa",
        ).all()
        for v in vinculaciones:
            db.add(models.Notificacion(
                usuario_id=v.familiar_id,
                tipo="alerta_sos_atendida",
                mensaje=f"La alerta SOS de {nombre} fue atendida por el equipo de Mamoru",
            ))

    db.commit()
    db.refresh(alerta)

    accion = "Marcó alerta SOS como atendida" if datos.estado == "atendida" else "Canceló alerta SOS"
    registrar_auditoria(db, admin_actual.id, accion, "alerta_sos", alerta.id, nombre)

    return alerta


 
# ============================================================
# Chat entre la familia y el cuidador
# ============================================================
# Hay un chat por solicitud. Participan quien envió la solicitud (familiar)
# y el cuidador que la recibió. Se habilita cuando el cuidador la acepta; al
# finalizar el servicio queda solo de lectura.
 
MAX_LARGO_MENSAJE_CHAT = 1000
ESTADOS_CON_CHAT = ("aceptada", "finalizada")
 
 
def obtener_solicitud_para_chat(db, solicitud_id, usuario):
    """Devuelve (solicitud, otro_usuario) si el usuario participa en el chat."""
    solicitud = db.query(models.SolicitudServicio).filter(
        models.SolicitudServicio.id == solicitud_id
    ).first()
    if not solicitud:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
 
    perfil = db.query(models.PerfilCuidador).filter(
        models.PerfilCuidador.id == solicitud.cuidador_id
    ).first()
    cuidador_usuario_id = perfil.usuario_id if perfil else None
 
    if usuario.id == solicitud.solicitante_id:
        otro_id = cuidador_usuario_id
    elif usuario.id == cuidador_usuario_id:
        otro_id = solicitud.solicitante_id
    else:
        raise HTTPException(status_code=403, detail="No participas en este chat")
 
    if solicitud.estado not in ESTADOS_CON_CHAT:
        raise HTTPException(status_code=400, detail="El chat se habilita cuando el cuidador acepta la solicitud")
 
    otro = db.query(models.Usuario).filter(models.Usuario.id == otro_id).first()
    return solicitud, otro
 
 
def nombre_completo(usuario, por_defecto):
    if not usuario:
        return por_defecto
    return f"{usuario.nombre} {usuario.apellido or ''}".strip()
 
 
@app.get("/chats", response_model=list[schemas.ChatResumenOut])
def listar_chats(
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    """Conversaciones del usuario (familiar o cuidador), la más reciente primero."""
    if usuario_actual.rol == "familiar":
        solicitudes = db.query(models.SolicitudServicio).filter(
            models.SolicitudServicio.solicitante_id == usuario_actual.id,
            models.SolicitudServicio.estado.in_(ESTADOS_CON_CHAT),
        ).all()
    elif usuario_actual.rol == "cuidador":
        perfil_propio = db.query(models.PerfilCuidador).filter(
            models.PerfilCuidador.usuario_id == usuario_actual.id
        ).first()
        if not perfil_propio:
            return []
        solicitudes = db.query(models.SolicitudServicio).filter(
            models.SolicitudServicio.cuidador_id == perfil_propio.id,
            models.SolicitudServicio.estado.in_(ESTADOS_CON_CHAT),
        ).all()
    else:
        return []
 
    resultado = []
    for s in solicitudes:
        perfil = db.query(models.PerfilCuidador).filter(models.PerfilCuidador.id == s.cuidador_id).first()
        if usuario_actual.rol == "familiar":
            otro = db.query(models.Usuario).filter(models.Usuario.id == perfil.usuario_id).first() if perfil else None
            foto = perfil.foto_url if perfil else None
            nombre_otro = nombre_completo(otro, "Cuidador")
        else:
            otro = db.query(models.Usuario).filter(models.Usuario.id == s.solicitante_id).first()
            foto = otro.foto_url if otro else None
            nombre_otro = nombre_completo(otro, "Familiar")

 
        adulto = db.query(models.Usuario).filter(models.Usuario.id == s.adulto_mayor_id).first()
 
        ultimo = db.query(models.MensajeChat).filter(
            models.MensajeChat.solicitud_id == s.id
        ).order_by(models.MensajeChat.creado_en.desc()).first()
 
        no_leidos = db.query(models.MensajeChat).filter(
            models.MensajeChat.solicitud_id == s.id,
            models.MensajeChat.autor_id != usuario_actual.id,
            models.MensajeChat.leido_en.is_(None),
        ).count()
 
        resultado.append(schemas.ChatResumenOut(
            solicitud_id=s.id,
            contacto_nombre=nombre_otro,
            contacto_foto_url=foto,
            adulto_mayor_nombre=nombre_completo(adulto, "Adulto mayor"),
            estado=s.estado,
            puede_escribir=(s.estado == "aceptada"),
            ultimo_mensaje=ultimo.texto if ultimo else None,
            ultimo_mensaje_en=ultimo.creado_en if ultimo else None,
            no_leidos=no_leidos,
        ))
 
    # Primero las que tienen mensajes más nuevos; las sin mensajes, al final.
    resultado.sort(key=lambda c: c.ultimo_mensaje_en or datetime.min, reverse=True)
    return resultado
 
 
@app.get("/solicitudes/{solicitud_id}/mensajes", response_model=list[schemas.MensajeChatOut])
def listar_mensajes_chat(
    solicitud_id: uuid.UUID,
    desde: datetime = None,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    """Mensajes del chat, del más antiguo al más nuevo. Con `desde` devuelve
    solo los posteriores a esa fecha (para actualizar sin bajar todo otra vez).
    Los mensajes del otro quedan marcados como leídos."""
    obtener_solicitud_para_chat(db, solicitud_id, usuario_actual)
 
    db.query(models.MensajeChat).filter(
        models.MensajeChat.solicitud_id == solicitud_id,
        models.MensajeChat.autor_id != usuario_actual.id,
        models.MensajeChat.leido_en.is_(None),
    ).update({"leido_en": ahora_utc()}, synchronize_session=False)
    db.commit()
 
    consulta = db.query(models.MensajeChat).filter(models.MensajeChat.solicitud_id == solicitud_id)
    if desde is not None:
        consulta = consulta.filter(models.MensajeChat.creado_en > desde.replace(tzinfo=None))
        return consulta.order_by(models.MensajeChat.creado_en.asc()).all()
 
    # Carga inicial: los últimos 300, en orden cronológico.
    ultimos = consulta.order_by(models.MensajeChat.creado_en.desc()).limit(300).all()
    return list(reversed(ultimos))
 
 
@app.post("/solicitudes/{solicitud_id}/mensajes", response_model=schemas.MensajeChatOut)
def enviar_mensaje_chat(
    solicitud_id: uuid.UUID,
    datos: schemas.MensajeChatCreate,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    solicitud, _otro = obtener_solicitud_para_chat(db, solicitud_id, usuario_actual)
 
    if solicitud.estado != "aceptada":
        raise HTTPException(status_code=400, detail="El servicio ya finalizó: el chat quedó solo de lectura")
 
    texto = (datos.texto or "").strip()
    if not texto:
        raise HTTPException(status_code=400, detail="Escribe un mensaje")
    if len(texto) > MAX_LARGO_MENSAJE_CHAT:
        raise HTTPException(status_code=400, detail=f"El mensaje no puede pasar de {MAX_LARGO_MENSAJE_CHAT} caracteres")
 
    nuevo = models.MensajeChat(
        solicitud_id=solicitud_id,
        autor_id=usuario_actual.id,
        texto=texto,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
 
    # Aviso push a la otra persona del chat.
    if _otro is not None:
        push.notificar_usuario(
            _otro.id,
            "chat_mensaje",
            f"{nombre_completo(usuario_actual, 'Alguien')}: {texto[:120]}",
            {"solicitud_id": str(solicitud_id)},
        )
    return nuevo


# ============================================================
# Foto de perfil del familiar y del adulto mayor (Supabase Storage)
# ============================================================
 
def requerir_usuario_con_foto(usuario_actual: models.Usuario = Depends(obtener_usuario_actual)):
   """Familiar y adulto mayor cambian su propia foto (el cuidador usa /cuidador/mi-foto)."""
   if usuario_actual.rol not in ("familiar", "adulto_mayor"):
       raise HTTPException(status_code=403, detail="Esta acción requiere el rol 'familiar' o 'adulto_mayor'")
   return usuario_actual
 
@app.put("/mi-foto", response_model=schemas.UsuarioOut)
def subir_foto_del_familiar(
   datos: schemas.FotoPerfilSubir,
   db: Session = Depends(get_db),
   familiar_actual: models.Usuario = Depends(requerir_usuario_con_foto),
):
   try:
       contenido = decodificar_imagen_base64(datos.imagen_base64)
       extension, tipo_contenido = detectar_imagen(contenido)
   except ValueError as e:
       raise HTTPException(status_code=400, detail=str(e))
 
   try:
       url_nueva = subir_foto(str(familiar_actual.id), contenido, tipo_contenido, extension)
   except ErrorAlmacenamiento as e:
       print(f"[almacenamiento] {e.mensaje} | {e.detalle}")
       raise HTTPException(status_code=502, detail=e.mensaje)
 
   url_anterior = familiar_actual.foto_url
   familiar_actual.foto_url = url_nueva
   db.commit()
 
   if url_anterior:
       borrar_foto(url_anterior)
 
   db.refresh(familiar_actual)
   return familiar_actual
 
 
@app.delete("/mi-foto", response_model=schemas.UsuarioOut)
def quitar_foto_del_familiar(
   db: Session = Depends(get_db),
   familiar_actual: models.Usuario = Depends(requerir_usuario_con_foto),
):
   url_anterior = familiar_actual.foto_url
   familiar_actual.foto_url = None
   db.commit()
 
   if url_anterior:
       borrar_foto(url_anterior)
 
   db.refresh(familiar_actual)
   return familiar_actual


# ============================================================
# Notificaciones push: celulares de cada usuario
# ============================================================
 
MAX_DISPOSITIVOS_POR_USUARIO = 10
 
 
@app.post("/push/registrar")
def registrar_dispositivo_push(
    datos: schemas.PushToken,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    """La app envía el identificador de este celular al iniciar sesión."""
    token = (datos.token or "").strip()
    if len(token) < 20 or len(token) > 4096:
        raise HTTPException(status_code=400, detail="Identificador de dispositivo no válido")
 
    existente = db.query(models.DispositivoPush).filter(models.DispositivoPush.token == token).first()
    if existente:
        # Si el celular cambió de cuenta, pasa a la cuenta nueva.
        existente.usuario_id = usuario_actual.id
        existente.fecha_actualizacion = datetime.now(timezone.utc).replace(tzinfo=None)
    else:
        db.add(models.DispositivoPush(usuario_id=usuario_actual.id, token=token))
    db.commit()
 
    # Se conservan solo los celulares más recientes de la cuenta.
    propios = db.query(models.DispositivoPush).filter(
        models.DispositivoPush.usuario_id == usuario_actual.id
    ).order_by(models.DispositivoPush.fecha_actualizacion.desc()).all()
    for sobrante in propios[MAX_DISPOSITIVOS_POR_USUARIO:]:
        db.delete(sobrante)
    if len(propios) > MAX_DISPOSITIVOS_POR_USUARIO:
        db.commit()
 
    return {"ok": True}
 
 
@app.post("/push/quitar")
def quitar_dispositivo_push(
    datos: schemas.PushToken,
    db: Session = Depends(get_db),
    usuario_actual: models.Usuario = Depends(obtener_usuario_actual),
):
    """La app lo llama al cerrar sesión, para no seguir recibiendo avisos de esa cuenta."""
    db.query(models.DispositivoPush).filter(
        models.DispositivoPush.token == (datos.token or "").strip(),
        models.DispositivoPush.usuario_id == usuario_actual.id,
    ).delete()
    db.commit()
    return {"ok": True}

def _adulto_del_familiar(db, familiar_id, adulto_mayor_id):
    if not familiar_tiene_vinculacion(db, familiar_id, adulto_mayor_id):
        raise HTTPException(status_code=403, detail="No tienes una vinculación activa con ese adulto mayor")
    adulto = db.query(models.Usuario).filter(models.Usuario.id == adulto_mayor_id).first()
    if not adulto:
        raise HTTPException(status_code=404, detail="Adulto mayor no encontrado")
    return adulto
 
 
@app.put("/adultos-mayores/{adulto_mayor_id}/foto")
def subir_foto_del_adulto_mayor(
    adulto_mayor_id: str,
    datos: schemas.FotoPerfilSubir,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    adulto = _adulto_del_familiar(db, familiar_actual.id, adulto_mayor_id)
 
    try:
        contenido = decodificar_imagen_base64(datos.imagen_base64)
        extension, tipo_contenido = detectar_imagen(contenido)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
 
    try:
        url_nueva = subir_foto(str(adulto.id), contenido, tipo_contenido, extension)
    except ErrorAlmacenamiento as e:
        print(f"[almacenamiento] {e.mensaje} | {e.detalle}")
        raise HTTPException(status_code=502, detail=e.mensaje)
 
    url_anterior = adulto.foto_url
    adulto.foto_url = url_nueva
    db.commit()
 
    if url_anterior:
        borrar_foto(url_anterior)
 
    return {"foto_url": url_nueva}
 
 
@app.delete("/adultos-mayores/{adulto_mayor_id}/foto")
def quitar_foto_del_adulto_mayor(
    adulto_mayor_id: str,
    db: Session = Depends(get_db),
    familiar_actual: models.Usuario = Depends(requerir_rol("familiar")),
):
    adulto = _adulto_del_familiar(db, familiar_actual.id, adulto_mayor_id)
 
    url_anterior = adulto.foto_url
    adulto.foto_url = None
    db.commit()
 
    if url_anterior:
        borrar_foto(url_anterior)
 
    return {"foto_url": None}