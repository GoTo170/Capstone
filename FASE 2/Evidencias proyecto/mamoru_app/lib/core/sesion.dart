import 'dart:async';
import 'dart:convert';
 
import 'package:shared_preferences/shared_preferences.dart';
 
import 'push_service.dart';
 
/// Datos básicos del usuario que inició sesión.
class UsuarioSesion {
  final String id;
  final String nombre;
  final String? apellido;
  final String? email;
  final String rol;
  final String? telefono;
  final String? fotoUrl;
 
  const UsuarioSesion({
    required this.id,
    required this.nombre,
    this.apellido,
    this.email,
    required this.rol,
    this.telefono,
    this.fotoUrl,
  });
 
  factory UsuarioSesion.fromJson(Map<String, dynamic> json) {
    return UsuarioSesion(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String?,
      email: json['email'] as String?,
      rol: json['rol'] as String,
      telefono: json['telefono'] as String?,
      fotoUrl: json['foto_url'] as String?,
    );
  }
 
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'rol': rol,
        'telefono': telefono,
        'foto_url': fotoUrl,
      };
 
  String get nombreCompleto {
    final a = apellido;
    return (a == null || a.isEmpty) ? nombre : '$nombre $a';
  }
}
 
/// Sesión actual de la app (token + usuario).
///
/// Se guarda también en el teléfono, así al cerrar y volver a abrir la app
/// no hay que iniciar sesión de nuevo. Es esencial para el adulto mayor,
/// que entra con un código de un solo uso y no tiene contraseña.
class Sesion {
  static const String _claveToken = 'mamoru_token';
  static const String _claveUsuario = 'mamoru_usuario';
 
  static String? _token;
  static UsuarioSesion? _usuario;
 
  static String? get token => _token;
  static UsuarioSesion? get usuario => _usuario;
  static bool get activa => _token != null;
 
  /// Lee la sesión guardada en el teléfono. Se llama una vez al abrir la app.
  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_claveToken);
    final usuarioJson = prefs.getString(_claveUsuario);
 
    if (token == null || usuarioJson == null) return;
 
    try {
      _usuario = UsuarioSesion.fromJson(
        jsonDecode(usuarioJson) as Map<String, dynamic>,
      );
      _token = token;
    } catch (_) {
      // Datos dañados: se descartan.
      _token = null;
      _usuario = null;
      await prefs.remove(_claveToken);
      await prefs.remove(_claveUsuario);
    }
  }
 
  /// Guarda la sesión en memoria y en el teléfono.
  static Future<void> iniciar(String token, UsuarioSesion usuario) async {
    _token = token;
    _usuario = usuario;
 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveToken, token);
    await prefs.setString(_claveUsuario, jsonEncode(usuario.toJson()));
  }
 
  /// Actualiza los datos del usuario (por ejemplo, tras cambiar la foto)
  /// sin tocar el token.
  static Future<void> actualizarUsuario(UsuarioSesion usuario) async {
    _usuario = usuario;
    if (_token == null) return;
 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveUsuario, jsonEncode(usuario.toJson()));
  }
 
  /// Cierra la sesión. En memoria es inmediato; el borrado en el teléfono
  /// continúa en segundo plano.
  static void cerrar() {
    final tokenAnterior = _token;
    _token = null;
    _usuario = null;
 
    // Este celular deja de recibir los avisos push de la cuenta que se cierra.
    if (tokenAnterior != null) {
      unawaited(PushService.quitarDispositivo(tokenAnterior));
    }
 
    unawaited(_borrarGuardado());
  }
 
  static Future<void> _borrarGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveToken);
    await prefs.remove(_claveUsuario);
  }
}
 