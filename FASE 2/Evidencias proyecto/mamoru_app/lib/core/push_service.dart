import 'dart:async';
import 'dart:convert';
 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
 
import 'api_client.dart';
import 'api_config.dart';
 
/// Notificaciones push (Firebase Cloud Messaging).
///
/// Si Firebase no está configurado en el proyecto, todo esto se desactiva solo y
/// la app funciona igual que antes (las notificaciones se siguen viendo en la campana).
class PushService {
  static bool _listo = false;
  static bool _sesionActiva = false;
  static String? _tokenActual;
  static StreamSubscription<String>? _suscripcionToken;
 
  /// Se llama una vez al abrir la app, antes de runApp().
  static Future<void> iniciar() async {
    try {
      await Firebase.initializeApp();
      _listo = true;
    } catch (_) {
      _listo = false;
    }
  }
 
  /// Pide permiso para avisar y le dice al servidor a qué celular enviar los avisos.
  /// Se llama después de iniciar sesión. Nunca lanza errores.
  static Future<void> registrarDispositivo() async {
    if (!_listo) return;
 
    try {
      final mensajeria = FirebaseMessaging.instance;
 
      final permiso = await mensajeria.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) return;
 
      final token = await mensajeria.getToken();
      if (token == null) return;
 
      _tokenActual = token;
      _sesionActiva = true;
      await ApiClient.post('/push/registrar', {'token': token});
 
      // Firebase puede cambiar el identificador del celular con el tiempo.
      _suscripcionToken ??= mensajeria.onTokenRefresh.listen((nuevo) async {
        _tokenActual = nuevo;
        if (!_sesionActiva) return;
        try {
          await ApiClient.post('/push/registrar', {'token': nuevo});
        } catch (_) {}
      });
    } catch (_) {
      // Sin permiso, sin Google Play Services o sin conexión: la app sigue funcionando.
    }
  }
 
  /// Se llama al cerrar sesión (recibe el token de la sesión que se cierra, porque
  /// en ese momento ya se está borrando). Así el celular deja de recibir avisos de esa cuenta.
  static Future<void> quitarDispositivo(String tokenSesion) async {
    _sesionActiva = false;
    final tokenCelular = _tokenActual;
    if (!_listo || tokenCelular == null) return;
 
    try {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/push/quitar'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSesion',
            },
            body: jsonEncode({'token': tokenCelular}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
 
    try {
      // Con un identificador nuevo en el próximo inicio de sesión.
      await FirebaseMessaging.instance.deleteToken();
      _tokenActual = null;
    } catch (_) {}
  }
}