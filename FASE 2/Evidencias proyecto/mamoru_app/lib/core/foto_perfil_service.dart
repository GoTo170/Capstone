import 'dart:convert';
 
import 'package:http/http.dart' as http;
 
import 'api_config.dart';
import 'sesion.dart';
 
/// Error al subir o quitar la foto (con un mensaje listo para mostrar).
class FotoException implements Exception {
  final String mensaje;
  const FotoException(this.mensaje);
 
  @override
  String toString() => mensaje;
}
 
/// Foto de perfil del familiar y del adulto mayor (se guarda en Supabase Storage,
/// igual que la del cuidador). Actualiza también la sesión guardada en el teléfono.
class FotoPerfilService {
  static const Duration _tiempoMaximo = Duration(seconds: 60);
 
  static Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json',
        if (Sesion.token != null) 'Authorization': 'Bearer ${Sesion.token}',
      };
 
  static Future<UsuarioSesion> subir(List<int> bytes) async {
    final respuesta = await _enviar(
      () => http.put(
        Uri.parse('${ApiConfig.baseUrl}/mi-foto'),
        headers: _cabeceras,
        body: jsonEncode({'imagen_base64': base64Encode(bytes)}),
      ),
    );
    return _procesar(respuesta);
  }
 
  static Future<UsuarioSesion> quitar() async {
    final respuesta = await _enviar(
      () => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/mi-foto'),
        headers: _cabeceras,
      ),
    );
    return _procesar(respuesta);
  }
 
  /// Foto del adulto mayor: la sube el familiar vinculado. Devuelve la URL nueva.
  static Future<String?> subirAdultoMayor(String adultoMayorId, List<int> bytes) async {
    final respuesta = await _enviar(
      () => http.put(
        Uri.parse('${ApiConfig.baseUrl}/adultos-mayores/$adultoMayorId/foto'),
        headers: _cabeceras,
        body: jsonEncode({'imagen_base64': base64Encode(bytes)}),
      ),
    );
    return _leerCuerpo(respuesta)['foto_url'] as String?;
  }
 
  static Future<void> quitarAdultoMayor(String adultoMayorId) async {
    final respuesta = await _enviar(
      () => http.delete(
        Uri.parse('${ApiConfig.baseUrl}/adultos-mayores/$adultoMayorId/foto'),
        headers: _cabeceras,
      ),
    );
    _leerCuerpo(respuesta);
  }
 
  static Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(_tiempoMaximo);
    } catch (_) {
      throw const FotoException('No se pudo conectar con el servidor. Revisa tu conexión.');
    }
  }
 
  static Future<UsuarioSesion> _procesar(http.Response respuesta) async {
    final usuario = UsuarioSesion.fromJson(_leerCuerpo(respuesta));
    await Sesion.actualizarUsuario(usuario);
    return usuario;
  }
 
  /// Devuelve el JSON de una respuesta correcta o lanza FotoException con el motivo.
  static Map<String, dynamic> _leerCuerpo(http.Response respuesta) {
    dynamic cuerpo;
    try {
      cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
    } catch (_) {
      cuerpo = null;
    }
 
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      final detalle = cuerpo is Map ? cuerpo['detail'] : null;
      throw FotoException(
        detalle is String ? detalle : 'No se pudo guardar la foto (error ${respuesta.statusCode}).',
      );
    }
 
    return cuerpo is Map<String, dynamic> ? cuerpo : <String, dynamic>{};
  }
}
 