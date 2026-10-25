"""Notificaciones push al celular con Firebase Cloud Messaging (API HTTP v1).

Cómo funciona:
- La app registra el identificador (token) del celular en /push/registrar.
- Cada vez que se guarda una Notificacion en la base de datos, al terminar la
  transacción se envía también como push a los celulares de ese usuario.
- Si Firebase no está configurado (falta FIREBASE_CREDENTIALS_JSON), no hace nada
  y el resto del servidor funciona igual.

Variables de entorno (una de las dos):
  FIREBASE_CREDENTIALS_JSON  contenido completo del archivo de la cuenta de servicio
  FIREBASE_CREDENTIALS_FILE  ruta a ese archivo (para tu PC)
"""
import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from jose import jwt
from sqlalchemy import event
from sqlalchemy.orm import Session, object_session

import models
from database import SessionLocal

URL_TOKEN_GOOGLE = "https://oauth2.googleapis.com/token"
ALCANCE_FCM = "https://www.googleapis.com/auth/firebase.messaging"
TIMEOUT_SEGUNDOS = 10

_credenciales_cache = None
_credenciales_cargadas = False
_acceso = {"token": None, "vence": 0.0}
_candado = threading.Lock()

# Título de la notificación según el tipo que se guarda en la base de datos.
TITULOS = {
    "solicitud_nueva": "Nueva solicitud de servicio",
    "solicitud_aceptada": "Solicitud aceptada",
    "solicitud_rechazada": "Solicitud rechazada",
    "servicio_finalizado": "Servicio finalizado",
    "alerta_sos": "Alerta SOS",
    "alerta_sos_atendida": "Alerta SOS atendida",
    "nueva_resena": "Nueva valoración",
    "resena_revisada": "Reseña revisada",
    "actividad_adelantada": "Actividad adelantada",
    "cambio_horario_pedido": "Cambio de horario",
    "puertas_adentro_aprobada": "Puertas adentro aprobada",
    "perfil_rechazado": "Perfil de cuidador",
    "chat_mensaje": "Mensaje nuevo",
}


def _cargar_credenciales():
    global _credenciales_cache, _credenciales_cargadas
    if _credenciales_cargadas:
        return _credenciales_cache
    _credenciales_cargadas = True
    texto = os.getenv("FIREBASE_CREDENTIALS_JSON", "").strip()
    if not texto:
        ruta = os.getenv("FIREBASE_CREDENTIALS_FILE", "").strip()
        if ruta and os.path.exists(ruta):
            with open(ruta, encoding="utf-8") as f:
                texto = f.read()
    if not texto:
        print("[push] Firebase no configurado: no se enviarán notificaciones push")
        return None
    try:
        datos = json.loads(texto)
        for campo in ("project_id", "client_email", "private_key"):
            if not datos.get(campo):
                raise ValueError(f"falta {campo}")
        _credenciales_cache = datos
    except Exception as e:  # noqa: BLE001
        print(f"[push] Credenciales de Firebase inválidas: {e}")
        _credenciales_cache = None
    return _credenciales_cache


def configurado() -> bool:
    return _cargar_credenciales() is not None


def _token_acceso(cred):
    """Token OAuth de Google para la cuenta de servicio (se reutiliza ~50 minutos)."""
    with _candado:
        if _acceso["token"] and time.time() < _acceso["vence"]:
            return _acceso["token"]
        ahora = int(time.time())
        asercion = jwt.encode(
            {
                "iss": cred["client_email"],
                "scope": ALCANCE_FCM,
                "aud": URL_TOKEN_GOOGLE,
                "iat": ahora,
                "exp": ahora + 3600,
            },
            cred["private_key"],
            algorithm="RS256",
        )
        cuerpo = urllib.parse.urlencode({
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": asercion,
        }).encode()
        peticion = urllib.request.Request(URL_TOKEN_GOOGLE, data=cuerpo, method="POST")
        with urllib.request.urlopen(peticion, timeout=TIMEOUT_SEGUNDOS) as r:
            datos = json.loads(r.read().decode())
        _acceso["token"] = datos["access_token"]
        _acceso["vence"] = time.time() + int(datos.get("expires_in", 3600)) - 600
        return _acceso["token"]


def _enviar_fcm(token_dispositivo, titulo, cuerpo, datos=None):
    """Envía un push a un celular. Devuelve "ok", "token_invalido" o "error"."""
    cred = _cargar_credenciales()
    if not cred:
        return "error"
    mensaje = {
        "message": {
            "token": token_dispositivo,
            "notification": {"title": titulo, "body": cuerpo},
            "data": {k: str(v) for k, v in (datos or {}).items()},
            "android": {"priority": "HIGH"},
        }
    }
    try:
        acceso = _token_acceso(cred)
        url = f"https://fcm.googleapis.com/v1/projects/{cred['project_id']}/messages:send"
        peticion = urllib.request.Request(
            url,
            data=json.dumps(mensaje).encode(),
            headers={"Authorization": f"Bearer {acceso}", "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(peticion, timeout=TIMEOUT_SEGUNDOS):
            return "ok"
    except urllib.error.HTTPError as e:
        detalle = ""
        try:
            detalle = e.read().decode()
        except Exception:  # noqa: BLE001
            pass
        # El celular ya no existe (app desinstalada o token vencido): se borra.
        if e.code == 404 or "UNREGISTERED" in detalle or ("INVALID_ARGUMENT" in detalle and "token" in detalle.lower()):
            return "token_invalido"
        print(f"[push] Firebase respondió {e.code}: {detalle[:200]}")
        return "error"
    except Exception as e:  # noqa: BLE001
        print(f"[push] No se pudo enviar: {e}")
        return "error"


def _enviar_pendientes(pendientes):
    """pendientes: lista de (usuario_id, tipo, texto, datos). Corre en un hilo aparte."""
    if not configurado():
        return
    db = SessionLocal()
    try:
        for usuario_id, tipo, texto, datos in pendientes:
            dispositivos = db.query(models.DispositivoPush).filter(
                models.DispositivoPush.usuario_id == usuario_id
            ).all()
            for d in dispositivos:
                resultado = _enviar_fcm(
                    d.token,
                    TITULOS.get(tipo, "Mamoru"),
                    texto,
                    {"tipo": tipo, **(datos or {})},
                )
                if resultado == "token_invalido":
                    db.delete(d)
        db.commit()
    except Exception as e:  # noqa: BLE001
        print(f"[push] Error enviando pendientes: {e}")
        db.rollback()
    finally:
        db.close()


def enviar_en_segundo_plano(pendientes):
    """No espera a Firebase: la respuesta de la API no se demora por el push."""
    if not pendientes or not configurado():
        return
    threading.Thread(target=_enviar_pendientes, args=(list(pendientes),), daemon=True).start()


def notificar_usuario(usuario_id, tipo, texto, datos=None):
    """Para avisos que no se guardan como Notificacion (por ejemplo, un mensaje de chat)."""
    enviar_en_segundo_plano([(usuario_id, tipo, texto, datos)])


def registrar_eventos():
    """Conecta la base de datos con el envío: cada Notificacion guardada sale como push."""

    @event.listens_for(models.Notificacion, "after_insert")
    def _al_insertar(mapper, connection, target):
        sesion = object_session(target)
        if sesion is not None:
            sesion.info.setdefault("push_pendientes", []).append(
                (target.usuario_id, target.tipo, target.mensaje, None)
            )

    @event.listens_for(Session, "after_commit")
    def _al_confirmar(sesion):
        pendientes = sesion.info.pop("push_pendientes", None)
        if pendientes:
            enviar_en_segundo_plano(pendientes)

    @event.listens_for(Session, "after_rollback")
    def _al_deshacer(sesion):
        sesion.info.pop("push_pendientes", None)