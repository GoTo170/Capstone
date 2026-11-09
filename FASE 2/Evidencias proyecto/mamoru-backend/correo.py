"""Envío de correos con la API de Brevo (sin librerías extra).

Variables de entorno (Render): BREVO_API_KEY, BREVO_REMITENTE_EMAIL, BREVO_REMITENTE_NOMBRE.
Si falta la clave, no envía nada y no rompe la app.
"""
import base64
import html
import json
import os
import threading
import urllib.error
import urllib.request

URL_BREVO = "https://api.brevo.com/v3/smtp/email"


def texto_a_html(texto):
    """Texto escrito en el panel a HTML, respetando saltos de línea y líneas en blanco."""
    limpio = (texto or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    return html.escape(limpio).replace("\n", "<br>")


# Adjuntos permitidos al enviar correos desde el panel.
EXTENSIONES_ADJUNTO = {"pdf", "png", "jpg", "jpeg", "gif", "webp", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv"}
MAX_ADJUNTOS = 5
MAX_BYTES_ADJUNTOS = 3 * 1024 * 1024


def preparar_adjuntos(adjuntos):
    """Valida los archivos (nombre, tipo, peso) y los deja en el formato de Brevo. Lanza ValueError si algo no sirve."""
    if not adjuntos:
        return []
    if len(adjuntos) > MAX_ADJUNTOS:
        raise ValueError(f"Máximo {MAX_ADJUNTOS} archivos adjuntos")
    total = 0
    salida = []
    for a in adjuntos:
        nombre = os.path.basename((getattr(a, "nombre", "") or "").replace("\\", "/")).strip()[:100]
        extension = nombre.rsplit(".", 1)[-1].lower() if "." in nombre else ""
        if not nombre or extension not in EXTENSIONES_ADJUNTO:
            raise ValueError(f"Tipo de archivo no permitido: {nombre or 'sin nombre'}")
        try:
            crudo = base64.b64decode(getattr(a, "contenido", "") or "", validate=True)
        except Exception:
            raise ValueError(f"No se pudo leer el archivo {nombre}")
        if not crudo:
            raise ValueError(f"El archivo {nombre} está vacío")
        total += len(crudo)
        if total > MAX_BYTES_ADJUNTOS:
            raise ValueError("Los adjuntos pesan más de 3 MB en total")
        salida.append({"name": nombre, "content": base64.b64encode(crudo).decode("ascii")})
    return salida


def correo_configurado() -> bool:
    return bool(os.getenv("BREVO_API_KEY") and os.getenv("BREVO_REMITENTE_EMAIL"))


def _enviar(destinatario, asunto, cuerpo_html, adjuntos=None, responder_a=None):
    cuerpo = {
        "sender": {"name": os.getenv("BREVO_REMITENTE_NOMBRE", "Mamoru"), "email": os.getenv("BREVO_REMITENTE_EMAIL")},
        "to": [{"email": destinatario}],
        "subject": asunto,
        "htmlContent": cuerpo_html,
    }
    if adjuntos:
        cuerpo["attachment"] = adjuntos
    if responder_a:
        cuerpo["replyTo"] = {"email": responder_a}
    peticion = urllib.request.Request(
        URL_BREVO,
        data=json.dumps(cuerpo).encode("utf-8"),
        headers={"api-key": os.getenv("BREVO_API_KEY", ""), "content-type": "application/json", "accept": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(peticion, timeout=15) as respuesta:
            return respuesta.status < 300, ""
    except urllib.error.HTTPError as error:
        detalle = error.read().decode("utf-8", "ignore")[:300]
        print(f"[correo] Brevo respondió {error.code}: {detalle}")
        return False, f"Brevo respondió {error.code}: {detalle}"
    except Exception as error:  # red caída, timeout, etc.
        print(f"[correo] Error enviando correo: {error}")
        return False, str(error)


def enviar_correo(destinatario, asunto, cuerpo_html, esperar=False, adjuntos=None, responder_a=None):
    """Envía en segundo plano (la app no espera a Brevo). Con esperar=True devuelve (ok, detalle)."""
    if not destinatario or not correo_configurado():
        return False, "Correo no configurado"
    if esperar:
        return _enviar(destinatario, asunto, cuerpo_html, adjuntos, responder_a)
    threading.Thread(target=_enviar, args=(destinatario, asunto, cuerpo_html, adjuntos, responder_a), daemon=True).start()
    return True, ""


def _plantilla(titulo, parrafos):
    # Un bloque que ya empieza con una etiqueta HTML se inserta tal cual; el resto va dentro de un párrafo.
    cuerpo = "".join(p if p.startswith("<") else f"<p style='margin:0 0 12px;line-height:1.5'>{p}</p>" for p in parrafos)
    return (
        "<div style='font-family:Arial,sans-serif;color:#222;max-width:520px;margin:auto;padding:24px'>"
        f"<h2 style='color:#2f6f5e;margin:0 0 16px'>{titulo}</h2>{cuerpo}"
        "<hr style='border:none;border-top:1px solid #ddd;margin:20px 0'>"
        "<p style='font-size:12px;color:#777'>Mensaje automático de Mamoru. Por favor no respondas a este correo.</p></div>"
    )


def correo_cuidador_aprobado(nombre):
    n = html.escape(nombre or "")
    return "Tu perfil de cuidador fue aprobado", _plantilla(
        "¡Tu perfil fue aprobado!",
        [f"Hola {n},", "Nuestro equipo revisó tus datos y documentos y tu perfil de cuidador en Mamoru quedó <b>aprobado</b>.",
         "Ya puedes <b>iniciar sesión</b> en la app de Mamoru con tu correo y contraseña, recibir solicitudes de familias y comenzar a trabajar."],
    )


def correo_cuidador_rechazado(nombre, motivo):
    n = html.escape(nombre or "")
    m = texto_a_html(motivo or "No se indicó un motivo.")
    return "Revisión de tu perfil de cuidador", _plantilla(
        "Tu perfil no pudo ser aprobado",
        [f"Hola {n},", "Revisamos tu perfil de cuidador en Mamoru y por ahora no pudimos aprobarlo.",
         "<p style='margin:0 0 6px'><b>Motivo:</b></p>"
         f"<div style='margin:0 0 14px;padding:10px 14px;background:#f6f6f6;border-left:3px solid #c0392b;line-height:1.5'>{m}</div>",
         "Puedes corregir lo indicado desde la app y volver a enviarlo para una nueva revisión."],
    )


def correo_codigo_verificacion(nombre, codigo, minutos):
    n = html.escape(nombre or "")
    c = html.escape(str(codigo))
    return "Tu código de verificación de Mamoru", _plantilla(
        "Verifica tu correo",
        [f"Hola {n},", "Usa este código para confirmar tu correo y terminar de crear tu cuenta en Mamoru:",
         f"<p style='font-size:34px;letter-spacing:10px;font-weight:bold;text-align:center;margin:18px 0;color:#2f6f5e'>{c}</p>",
         f"El código vence en {minutos} minutos. Si tú no creaste una cuenta en Mamoru, ignora este mensaje."],
    )


def correo_mensaje_equipo(nombre_destino, mensaje, nombre_admin):
    n = html.escape(nombre_destino or "")
    a = html.escape(nombre_admin or "el equipo")
    return _plantilla(
        "Mensaje del equipo de Mamoru",
        [f"Hola {n},",
         f"<div style='margin:0 0 14px;line-height:1.5'>{texto_a_html(mensaje)}</div>",
         f"<p style='font-size:12px;color:#777;margin:0 0 12px'>Enviado por {a}, del equipo de Mamoru. Puedes responder a este correo.</p>"],
    )


def correo_aviso_equipo(nombre, mensaje):
    n = html.escape(nombre or "")
    return "Aviso de Mamoru", _plantilla(
        "Nuevo aviso en el panel",
        [f"Hola {n},", f"<div style='margin:0 0 14px;padding:10px 14px;background:#f6f6f6;border-left:3px solid #2f6f5e;line-height:1.5'>{texto_a_html(mensaje)}</div>",
         "Entra al panel para revisarlo. Puedes desactivar estos correos en Configuración → Notificaciones."],
    )


def correo_restablecer_contrasena(nombre, enlace, minutos):
    n = html.escape(nombre or "")
    e = html.escape(enlace, quote=True)
    return "Restablece tu contraseña de Mamoru", _plantilla(
        "¿Pediste cambiar tu contraseña?",
        [f"Hola {n},", "Recibimos una solicitud para cambiar la contraseña de tu cuenta de Mamoru. ¿Fuiste tú?",
         f"<p style='text-align:center;margin:22px 0'><a href='{e}' style='background:#2f6f5e;color:#fff;text-decoration:none;"
         "padding:12px 26px;border-radius:8px;font-weight:bold;display:inline-block'>Sí, fui yo: crear mi nueva contraseña</a></p>",
         f"El enlace vence en {minutos} minutos y solo se puede usar una vez.",
         "<p style='margin:0 0 12px;line-height:1.5'><b>Si no fuiste tú</b>, ignora este correo: tu contraseña seguirá siendo la misma.</p>",
         f"<p style='font-size:12px;color:#777;word-break:break-all'>Si el botón no funciona, copia este enlace en tu navegador:<br>{e}</p>"],
    )


def correo_contrasena_cambiada(nombre):
    n = html.escape(nombre or "")
    return "Tu contraseña de Mamoru fue cambiada", _plantilla(
        "Contraseña actualizada",
        [f"Hola {n},", "La contraseña de tu cuenta de Mamoru se cambió correctamente.",
         "Si no fuiste tú, comunícate con el equipo de Mamoru de inmediato."],
    )


_ROLES_EQUIPO = {
    "superadmin": ("Superadmin", "tendrás acceso total al panel: usuarios, equipo, cuidadores, soporte, reportes y auditoría."),
    "moderador": ("Moderador de cuidadores", "te encargarás de revisar y validar a los cuidadores, sus documentos, la modalidad puertas adentro, las reseñas y los reportes."),
    "soporte": ("Soporte / SOS", "te encargarás de atender las alertas SOS, los cambios de datos del adulto mayor, las solicitudes y los reportes."),
}


def correo_bienvenida_equipo(nombre, rol_interno, email, panel_url, creado_por=""):
    n = html.escape(nombre or "")
    etiqueta, funcion = _ROLES_EQUIPO.get(rol_interno or "superadmin", _ROLES_EQUIPO["superadmin"])
    quien = html.escape(creado_por or "")
    consulta = f"Si tienes dudas, consulta con {quien}, quien creó tu cuenta." if quien else "Si tienes dudas, consulta con quien creó tu cuenta."
    return "Te damos la bienvenida al equipo de Mamoru", _plantilla(
        "¡Te damos la bienvenida a Mamoru!",
        [f"Hola {n},",
         "Estamos muy contentos de que te sumes al equipo de Mamoru. Te deseamos mucho éxito en esta nueva etapa: tu trabajo ayuda a cuidar mejor a los adultos mayores y a las familias que confían en nosotros.",
         f"<div style='margin:0 0 14px;padding:10px 14px;background:#f6f6f6;border-left:3px solid #2f6f5e;line-height:1.5'>"
         f"<b>Tu rol:</b> {etiqueta}<br>En este rol {funcion}</div>",
         consulta],
    )
