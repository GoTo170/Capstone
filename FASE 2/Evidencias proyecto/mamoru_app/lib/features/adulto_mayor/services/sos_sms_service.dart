import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
 
enum EstadoSms {
  /// Se mandó el SMS a todos los contactos.
  enviado,
 
  /// Se mandó a algunos, a otros no.
  parcial,
 
  /// El usuario no dio permiso para enviar SMS.
  sinPermiso,
 
  /// No hay contactos de emergencia guardados en el teléfono.
  sinContactos,
 
  /// Este teléfono no puede enviar SMS desde la app (iPhone, sin chip, etc.).
  noDisponible,
 
  /// Falló el envío.
  error,
}
 
class ResultadoSms {
  final EstadoSms estado;
  final int enviados;
  final int total;
 
  const ResultadoSms(this.estado, {this.enviados = 0, this.total = 0});
 
  bool get salioAlgo => enviados > 0;
}
 
/// Avisa por SMS a los contactos de emergencia, desde el chip del propio
/// teléfono del adulto mayor (no usa internet ni servicios de pago; se
/// descuenta del plan o saldo de ese teléfono).
class SosSmsService {
  static const MethodChannel _canal = MethodChannel('mamoru/sms');
  static const String _clave = 'sos_contactos';
 
  static bool get _esAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
 
  /// Descarga los contactos de emergencia y los guarda en el teléfono,
  /// para que el SMS funcione aunque en ese momento no haya internet.
  /// Si falla, se queda con los que ya tenía guardados.
  static Future<void> actualizarContactos() async {
    try {
      final datos = await ApiClient.get('/adulto-mayor/mis-contactos') as List<dynamic>;
      final lista = datos.map((item) {
        final c = item as Map<String, dynamic>;
        return {
          'nombre': (c['nombre'] ?? '').toString(),
          'telefono': (c['telefono'] ?? '').toString(),
        };
      }).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode(lista));
    } on ApiException {
      // Sin conexión o sesión vencida: se usan los guardados.
    } catch (_) {
      // Nunca debe romper la pantalla de inicio.
    }
  }
 
  /// Pide el permiso de enviar SMS (solo Android). Devuelve si quedó concedido.
  static Future<bool> pedirPermiso() async {
    if (!_esAndroid) return false;
    try {
      return (await _canal.invokeMethod<bool>('pedirPermiso')) ?? false;
    } catch (_) {
      return false;
    }
  }
 
  static Future<List<String>> _numerosGuardados() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_clave);
    if (texto == null) return [];
    try {
      final lista = jsonDecode(texto) as List<dynamic>;
      final numeros = <String>[];
      for (final item in lista) {
        final n = normalizarNumero((item as Map<String, dynamic>)['telefono']?.toString() ?? '');
        if (n != null && !numeros.contains(n)) numeros.add(n);
      }
      return numeros;
    } catch (_) {
      return [];
    }
  }
 
  /// Deja el número en formato internacional (+569XXXXXXXX).
  /// Devuelve null si no parece un teléfono.
  static String? normalizarNumero(String bruto) {
    var n = bruto.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n.isEmpty) return null;
    if (n.startsWith('+')) {
      // ya viene con código de país
    } else if (n.startsWith('56') && n.length == 11) {
      n = '+$n';
    } else if (n.startsWith('9') && n.length == 9) {
      n = '+56$n';
    } else if (n.length == 8) {
      n = '+569$n';
    }
    final digitos = n.replaceAll('+', '').length;
    return digitos >= 8 ? n : null;
  }
 
  static String _sinTildes(String t) {
    const de = 'áéíóúüñÁÉÍÓÚÜÑ¡¿';
    const a = 'aeiouunAEIOUUN!?';
    var r = t;
    for (var i = 0; i < de.length; i++) {
      r = r.replaceAll(de[i], a[i]);
    }
    return r;
  }
 
  /// Manda el SMS de emergencia a todos los contactos guardados.
  static Future<ResultadoSms> enviar(String nombre) async {
    if (!_esAndroid) return const ResultadoSms(EstadoSms.noDisponible);
 
    final numeros = await _numerosGuardados();
    if (numeros.isEmpty) return const ResultadoSms(EstadoSms.sinContactos);
 
    if (!await pedirPermiso()) {
      return ResultadoSms(EstadoSms.sinPermiso, total: numeros.length);
    }
 
    // Sin tildes para que el SMS quepa en un solo mensaje.
    final texto = _sinTildes('ALERTA SOS: $nombre necesita ayuda urgente. Mensaje enviado desde Mamoru.');
 
    try {
      final r = await _canal.invokeMapMethod<String, int>('enviar', {
        'numeros': numeros,
        'texto': texto,
      });
      final enviados = r?['enviados'] ?? 0;
      final total = numeros.length;
      if (enviados == total) return ResultadoSms(EstadoSms.enviado, enviados: enviados, total: total);
      if (enviados > 0) return ResultadoSms(EstadoSms.parcial, enviados: enviados, total: total);
      return ResultadoSms(EstadoSms.error, total: total);
    } catch (_) {
      return ResultadoSms(EstadoSms.error, total: numeros.length);
    }
  }
}
 