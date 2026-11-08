"""Envío de correos con la API de Brevo (sin librerías extra).

Variables de entorno (Render): BREVO_API_KEY, BREVO_REMITENTE_EMAIL, BREVO_REMITENTE_NOMBRE.
Si falta la clave, no envía nada y no rompe la app.
"""
import html
import json
import os
import threading
import urllib.error
import urllib.request

URL_BREVO = "https://api.brevo.com/v3/smtp/email"


def correo_configurado() -> bool:
    return bool(os.getenv("BREVO_API_KEY") and os.getenv("BREVO_REMITENTE_EMAIL"))


def _enviar(destinatario, asunto, cuerpo_html):
    cuerpo = {
        "sender": {"name": os.getenv("BREVO_REMITENTE_NOMBRE", "Mamoru"), "email": os.getenv("BREVO_REMITENTE_EMAIL")},
        "to": [{"email": destinatario}],
        "subject": asunto,
        "htmlContent": cuerpo_html,
    }
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


def enviar_correo(destinatario, asunto, cuerpo_html, esperar=False):
    """Envía en segundo plano (la app no espera a Brevo). Con esperar=True devuelve (ok, detalle)."""
    if not destinatario or not correo_configurado():
        return False, "Correo no configurado"
    if esperar:
        return _enviar(destinatario, asunto, cuerpo_html)
    threading.Thread(target=_enviar, args=(destinatario, asunto, cuerpo_html), daemon=True).start()
    return True, ""


def _plantilla(titulo, parrafos):
    cuerpo = "".join(f"<p style='margin:0 0 12px;line-height:1.5'>{p}</p>" for p in parrafos)
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
         "Ya puedes abrir la app, recibir solicitudes de familias y comenzar a trabajar."],
    )


def correo_cuidador_rechazado(nombre, motivo):
    n = html.escape(nombre or "")
    m = html.escape(motivo or "No se indicó un motivo.")
    return "Revisión de tu perfil de cuidador", _plantilla(
        "Tu perfil no pudo ser aprobado",
        [f"Hola {n},", "Revisamos tu perfil de cuidador en Mamoru y por ahora no pudimos aprobarlo.",
         f"<b>Motivo:</b> {m}", "Puedes corregir lo indicado desde la app y volver a enviarlo para una nueva revisión."],
    )
