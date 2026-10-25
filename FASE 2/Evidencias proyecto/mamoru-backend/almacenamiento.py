"""Archivos en Supabase Storage (fotos de perfil de los cuidadores).

Usa solo la librería estándar de Python: no hay que instalar nada nuevo.
La clave de servicio (SUPABASE_SERVICE_KEY) es SECRETA: vive solo en el .env
del backend. Nunca debe ir en la app, en el panel ni en GitHub.
"""
import base64
import binascii
import json
import os
import urllib.error
import urllib.request
import uuid

from dotenv import load_dotenv

load_dotenv()

BUCKET_FOTOS = "fotos-perfil"
MAX_BYTES_FOTO = 600 * 1024  # la app reduce la foto a ~200 KB; este es el tope
TIEMPO_MAXIMO = 15  # segundos de espera por el servicio de archivos


class ErrorAlmacenamiento(Exception):
    """Falló el servicio de archivos.

    `mensaje` es seguro de mostrar a la persona que usa la app.
    `detalle` y `codigo` son para el registro del servidor y el diagnóstico."""

    def __init__(self, mensaje, detalle="", codigo=None):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.detalle = detalle
        self.codigo = codigo


# ---------------------------------------------------------------- imagen

# Solo se aceptan estos formatos, y se reconocen por su contenido (no por lo que
# diga el cliente): así no se puede subir un SVG, un HTML ni un PDF disfrazados.
def detectar_imagen(datos: bytes):
    """Devuelve (extensión, tipo de contenido) o lanza ValueError."""
    if datos[:3] == b"\xff\xd8\xff":
        return "jpg", "image/jpeg"
    if datos[:8] == b"\x89PNG\r\n\x1a\n":
        return "png", "image/png"
    if datos[:4] == b"RIFF" and datos[8:12] == b"WEBP":
        return "webp", "image/webp"
    raise ValueError("El archivo no es una imagen válida (usa JPG, PNG o WEBP)")


def decodificar_imagen_base64(texto: str) -> bytes:
    """Pasa de base64 a bytes, validando que no esté vacía ni sea muy grande."""
    if not texto or not texto.strip():
        raise ValueError("No se recibió ninguna imagen")

    limpio = texto.strip()
    if limpio.startswith("data:") and "," in limpio:  # "data:image/jpeg;base64,...."
        limpio = limpio.split(",", 1)[1]
    limpio = "".join(limpio.split())  # quita espacios y saltos de línea

    # Se revisa el tamaño antes de decodificar, para no gastar memoria en vano.
    if len(limpio) > (MAX_BYTES_FOTO * 4) // 3 + 8:
        raise ValueError(f"La foto es demasiado grande (máximo {MAX_BYTES_FOTO // 1024} KB)")

    try:
        datos = base64.b64decode(limpio, validate=True)
    except (binascii.Error, ValueError):
        raise ValueError("La imagen no se pudo leer (base64 inválido)")

    if not datos:
        raise ValueError("No se recibió ninguna imagen")
    if len(datos) > MAX_BYTES_FOTO:
        raise ValueError(f"La foto es demasiado grande (máximo {MAX_BYTES_FOTO // 1024} KB)")
    return datos


# ---------------------------------------------------------------- Supabase

def _config():
    url = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
    clave = os.getenv("SUPABASE_SERVICE_KEY", "").strip()
    if not url or not clave:
        raise ErrorAlmacenamiento(
            "El almacenamiento de archivos no está disponible por ahora",
            "Faltan SUPABASE_URL o SUPABASE_SERVICE_KEY en el .env",
        )
    return url, clave


def _pedir(metodo, url, clave, cuerpo=None, tipo_contenido=None):
    # Supabase tiene dos formatos de clave secreta:
    # - la antigua "service_role" (empieza con "eyJ"): va en las dos cabeceras;
    # - la nueva "sb_secret_..." (no es un JWT): va solo en "apikey".
    cabeceras = {"apikey": clave}
    if not clave.startswith("sb_"):
        cabeceras["Authorization"] = f"Bearer {clave}"
    if tipo_contenido:
        cabeceras["Content-Type"] = tipo_contenido

    peticion = urllib.request.Request(url, data=cuerpo, method=metodo, headers=cabeceras)
    try:
        with urllib.request.urlopen(peticion, timeout=TIEMPO_MAXIMO) as respuesta:
            return respuesta.status, respuesta.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:  # antes que URLError: es una subclase
        texto = ""
        try:
            texto = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        raise ErrorAlmacenamiento(
            "No se pudo guardar la foto. Inténtalo de nuevo más tarde",
            f"HTTP {e.code} en {metodo} {url}: {texto}",
            codigo=e.code,
        ) from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ErrorAlmacenamiento(
            "No se pudo conectar con el servicio de archivos. Inténtalo de nuevo más tarde",
            f"{metodo} {url}: {e}",
        ) from e


def _prefijo_publico(url_base):
    return f"{url_base}/storage/v1/object/public/{BUCKET_FOTOS}/"


def subir_foto(usuario_id: str, contenido: bytes, tipo_contenido: str, extension: str) -> str:
    """Sube la foto y devuelve su URL pública. Cada foto tiene un nombre nuevo,
    así nunca se muestra una versión antigua guardada en caché."""
    url_base, clave = _config()
    ruta = f"cuidadores/{usuario_id}/{uuid.uuid4().hex}.{extension}"

    _pedir("POST", f"{url_base}/storage/v1/object/{BUCKET_FOTOS}/{ruta}", clave, contenido, tipo_contenido)
    return _prefijo_publico(url_base) + ruta


def borrar_foto(url_foto: str) -> None:
    """Borra una foto anterior. Es 'lo mejor posible': si falla, no se detiene nada."""
    try:
        url_base, clave = _config()
        prefijo = _prefijo_publico(url_base)
        if not url_foto or not url_foto.startswith(prefijo):
            return  # no es una foto de este espacio: no se toca
        ruta = url_foto[len(prefijo):]
        _pedir("DELETE", f"{url_base}/storage/v1/object/{BUCKET_FOTOS}/{ruta}", clave)
    except ErrorAlmacenamiento as e:
        print(f"[almacenamiento] No se pudo borrar la foto anterior: {e.detalle}")


def estado_almacenamiento() -> dict:
    """Revisa que todo esté bien configurado (para el diagnóstico del administrador)."""
    try:
        url_base, clave = _config()
    except ErrorAlmacenamiento:
        return {
            "configurado": False,
            "bucket_existe": False,
            "bucket_publico": False,
            "diagnostico": "Faltan SUPABASE_URL o SUPABASE_SERVICE_KEY en el archivo .env del backend.",
        }

    try:
        _, texto = _pedir("GET", f"{url_base}/storage/v1/bucket/{BUCKET_FOTOS}", clave)
    except ErrorAlmacenamiento as e:
        detalle = (e.detalle or "").lower()
        if e.codigo in (401, 403):
            diagnostico = "La clave SUPABASE_SERVICE_KEY no es válida. Usa la clave de servicio (service_role), no la pública."
        elif e.codigo in (400, 404) or "not found" in detalle:
            diagnostico = f"El espacio «{BUCKET_FOTOS}» no existe. Créalo en Supabase → Storage → New bucket (marcado como público)."
        elif e.codigo is None:
            diagnostico = "No hay conexión con Supabase. Revisa SUPABASE_URL y tu internet."
        else:
            diagnostico = f"Supabase respondió con un error ({e.codigo})."
        return {"configurado": True, "bucket_existe": False, "bucket_publico": False, "diagnostico": diagnostico}

    try:
        publico = bool(json.loads(texto).get("public"))
    except (ValueError, AttributeError):
        publico = False

    return {
        "configurado": True,
        "bucket_existe": True,
        "bucket_publico": publico,
        "diagnostico": (
            "Todo listo: las fotos se pueden subir y mostrar."
            if publico
            else f"El espacio «{BUCKET_FOTOS}» existe pero NO es público: las fotos no se verían. "
                 "Actívalo en Storage → fotos-perfil → Edit bucket → Public bucket."
        ),
    }