import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'sesion.dart';

/// Cliente único para hablar con el backend FastAPI.
/// Agrega el token de la sesión, convierte JSON y traduce los errores.
class ApiClient {
  static const Duration _tiempoMaximo = Duration(seconds: 15);
  // Subir una imagen toma más que una consulta normal.
  static const Duration _tiempoSubida = Duration(seconds: 45);

  static Future<dynamic> get(String ruta) => _enviar('GET', ruta);

  static Future<dynamic> post(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar('POST', ruta, cuerpo);

  static Future<dynamic> patch(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar('PATCH', ruta, cuerpo);

  static Future<dynamic> put(String ruta, [Map<String, dynamic>? cuerpo]) =>
      _enviar('PUT', ruta, cuerpo, _tiempoSubida);

  static Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  static Future<dynamic> _enviar(
    String metodo,
    String ruta, [
    Map<String, dynamic>? cuerpo,
    Duration? espera,
  ]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$ruta');
    final token = Sesion.token;

    final peticion = http.Request(metodo, uri);
    peticion.headers['Content-Type'] = 'application/json';
    peticion.headers['Accept'] = 'application/json';
    if (token != null) {
      peticion.headers['Authorization'] = 'Bearer $token';
    }
    if (cuerpo != null) {
      peticion.body = jsonEncode(cuerpo);
    }

    late http.Response respuesta;

    try {
      final flujo = await peticion.send().timeout(espera ?? _tiempoMaximo);
      respuesta = await http.Response.fromStream(flujo);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Inténtalo nuevamente.',
      );
    } on SocketException {
      throw const ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    } on http.ClientException {
      throw const ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }

    // Se decodifica como UTF-8 a mano para que las tildes y la ñ lleguen bien.
    final dynamic datos = respuesta.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(respuesta.bodyBytes));

    // 401 con sesión iniciada = token vencido o cuenta desactivada.
    if (respuesta.statusCode == 401 && token != null) {
      Sesion.cerrar();
      throw const ApiException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        401,
      );
    }

    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      throw ApiException(
        _mensajeDeError(datos, respuesta.statusCode),
        respuesta.statusCode,
      );
    }

    return datos;
  }

  static String _mensajeDeError(dynamic datos, int codigo) {
    if (datos is Map<String, dynamic>) {
      final detalle = datos['detail'];
      if (detalle is String) return detalle;
      if (detalle is List) return 'Revisa los datos ingresados.';
    }
    return 'Error del servidor ($codigo).';
  }
}