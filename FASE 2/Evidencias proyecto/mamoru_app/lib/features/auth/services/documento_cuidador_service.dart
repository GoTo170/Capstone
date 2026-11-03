import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
 
import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import '../../../core/sesion.dart';
 
/// Error al subir el documento (con un mensaje listo para mostrar).
class DocumentoException implements Exception {
  final String mensaje;
  const DocumentoException(this.mensaje);
 
  @override
  String toString() => mensaje;
}
 
/// Documento (PDF o imagen) que acredita la profesión del cuidador.
/// El administrador lo revisa en el panel antes de aprobar o rechazar el perfil.
class DocumentoCuidadorService {
  /// Mismo tope que acepta el servidor.
  static const int maxBytes = 5 * 1024 * 1024;
 
  static const Duration _tiempoMaximo = Duration(seconds: 90);
 
  /// Lee el archivo elegido con el selector (null si no se pudo leer).
  static Future<List<int>?> leerBytes(PlatformFile archivo) async {
    try {
      return await archivo.readAsBytes();
    } catch (_) {
      return null;
    }
  }
 
  /// true si el archivo supera el tope que acepta el servidor.
  static Future<bool> demasiadoGrande(PlatformFile archivo) async {
    try {
      final largo = await archivo.length();
      return largo != null && largo > maxBytes;
    } catch (_) {
      return false; // si no se puede medir, el servidor igual lo revisa
    }
  }
 
  /// Sube (o reemplaza) el documento del cuidador que tiene la sesión iniciada.
  /// Devuelve si el servidor lo registró.
  static Future<bool> subir(List<int> bytes) async {
    if (bytes.length > maxBytes) {
      throw const DocumentoException('El documento pesa más de 5 MB. Elige uno más liviano.');
    }
 
    http.Response respuesta;
    try {
      respuesta = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/cuidador/mi-documento'),
            headers: {
              'Content-Type': 'application/json',
              if (Sesion.token != null) 'Authorization': 'Bearer ${Sesion.token}',
            },
            body: jsonEncode({'archivo_base64': base64Encode(bytes)}),
          )
          .timeout(_tiempoMaximo);
    } catch (_) {
      throw const DocumentoException('No se pudo conectar con el servidor. Revisa tu conexión.');
    }
 
    dynamic cuerpo;
    try {
      cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
    } catch (_) {
      cuerpo = null;
    }
 
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      final detalle = cuerpo is Map ? cuerpo['detail'] : null;
      throw DocumentoException(
        detalle is String ? detalle : 'No se pudo guardar el documento (error ${respuesta.statusCode}).',
      );
    }
 
    return cuerpo is Map && cuerpo['tiene_documento'] == true;
  }
 
  /// Si el cuidador ya adjuntó su documento.
  static Future<bool> tieneDocumento() async {
    final datos = await ApiClient.get('/cuidador/mi-perfil') as Map<String, dynamic>;
    return datos['tiene_documento'] == true;
  }
}
 