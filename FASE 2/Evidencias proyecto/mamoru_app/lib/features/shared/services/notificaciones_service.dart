import '../../../core/api_client.dart';

/// Notificación del usuario (alertas SOS, avisos del sistema, etc.).
class NotificacionApp {
  final String id;
  final String tipo;
  final String mensaje;
  bool leida;
  final DateTime fecha;

  NotificacionApp({
    required this.id,
    required this.tipo,
    required this.mensaje,
    required this.leida,
    required this.fecha,
  });
}

class NotificacionesService {
  /// Notificaciones del usuario, de la más nueva a la más antigua.
  static Future<List<NotificacionApp>> listar() async {
    final datos = await ApiClient.get('/notificaciones') as List<dynamic>;

    final lista = datos.map((item) {
      final n = item as Map<String, dynamic>;
      return NotificacionApp(
        id: n['id'] as String,
        tipo: n['tipo'] as String,
        mensaje: n['mensaje'] as String,
        leida: n['leida'] as bool,
        fecha: _desdeUtc(n['fecha_envio'] as String),
      );
    }).toList();

    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  static Future<void> marcarLeida(String id) async {
    await ApiClient.patch('/notificaciones/$id/leida');
  }

  static Future<void> marcarTodasLeidas() async {
    await ApiClient.patch('/notificaciones/marcar-leidas');
  }

  /// La base de datos guarda esta fecha en hora UTC y sin zona horaria:
  /// se interpreta como UTC y se muestra en la hora local del celular.
  static DateTime _desdeUtc(String texto) {
    final t = DateTime.parse(texto);
    if (t.isUtc) return t.toLocal();
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond, t.microsecond).toLocal();
  }
}