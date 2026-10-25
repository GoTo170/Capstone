import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/sesion.dart';

/// Operaciones de autenticación contra el backend.
class AuthService {
  /// Inicia sesión y deja guardada la sesión (token + usuario).
  static Future<UsuarioSesion> iniciarSesion(
    String email,
    String password,
  ) async {
    // Por si quedara una sesión anterior: el login se hace siempre "limpio".
    Sesion.cerrar();

    final datos = await ApiClient.post('/login', {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;

    final usuario = UsuarioSesion.fromJson(
      datos['usuario'] as Map<String, dynamic>,
    );

    await Sesion.iniciar(datos['access_token'] as String, usuario);

    return usuario;
  }

  /// Crea una cuenta de familiar o cuidador.
  static Future<void> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String rol,
    String? profesion,
    bool? esAreaSalud,
    String? experiencia,
    String? serviciosOfrecidos,
  }) async {
    final cuerpo = <String, dynamic>{
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'password': password,
      'rol': rol,
    };

    // Datos del perfil profesional: solo aplican al cuidador.
    if (rol == 'cuidador') {
      cuerpo['profesion'] = profesion;
      cuerpo['es_area_salud'] = esAreaSalud;
      cuerpo['experiencia'] = experiencia;
      cuerpo['servicios_ofrecidos'] = serviciosOfrecidos;
    }

    await ApiClient.post('/usuarios', cuerpo);
  }

  /// El adulto mayor entra con el código de invitación (sin correo ni clave).
  static Future<UsuarioSesion> canjearInvitacion(String codigo) async {
    Sesion.cerrar();

    final datos = await ApiClient.post('/invitaciones/canjear', {
      'codigo': codigo,
    }) as Map<String, dynamic>;

    final usuario = UsuarioSesion.fromJson(
      datos['usuario'] as Map<String, dynamic>,
    );

    await Sesion.iniciar(datos['access_token'] as String, usuario);

    return usuario;
  }

  /// Si hay una sesión guardada en el teléfono, la valida con el servidor.
  ///
  /// Devuelve el usuario, o null si no hay sesión o ya no es válida
  /// (token vencido o cuenta desactivada). Otros errores, como no tener
  /// conexión, se propagan para poder reintentar sin perder la sesión.
  static Future<UsuarioSesion?> restaurarSesion() async {
    final token = Sesion.token;
    if (token == null) return null;

    try {
      final datos = await ApiClient.get('/perfil') as Map<String, dynamic>;
      final usuario = UsuarioSesion.fromJson(datos);
      await Sesion.iniciar(token, usuario);
      return usuario;
    } on ApiException catch (e) {
      if (e.codigo == 401) return null;
      rethrow;
    }
  }

  /// Estado de validación del cuidador: pendiente, aprobado o rechazado.
  static Future<String> estadoValidacionCuidador() async {
    final datos =
        await ApiClient.get('/cuidadores/mi-perfil') as Map<String, dynamic>;
    return datos['estado_validacion'] as String;
  }

  static void cerrarSesion() => Sesion.cerrar();
}