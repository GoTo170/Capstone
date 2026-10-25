import '../../../core/api_client.dart';
import '../../../core/sesion.dart';
import 'chat_mensaje.dart';
 
/// Una conversación: una por cada servicio aceptado o finalizado.
class ChatResumen {
  final String solicitudId;
  final String contactoNombre;
  final String? contactoFotoUrl;
  final String adultoMayorNombre;
  final bool finalizado;
  final bool puedeEscribir;
  final String? ultimoMensaje;
  final DateTime? ultimoMensajeEn;
  final int noLeidos;
 
  const ChatResumen({
    required this.solicitudId,
    required this.contactoNombre,
    required this.contactoFotoUrl,
    required this.adultoMayorNombre,
    required this.finalizado,
    required this.puedeEscribir,
    required this.ultimoMensaje,
    required this.ultimoMensajeEn,
    required this.noLeidos,
  });
}
 
/// Chat entre la familia y el cuidador de un servicio.
class ChatService {
  /// Conversaciones del usuario, la más reciente primero.
  static Future<List<ChatResumen>> listarChats() async {
    final datos = await ApiClient.get('/chats') as List<dynamic>;
 
    return datos.map((item) {
      final c = item as Map<String, dynamic>;
      final ultimaFecha = c['ultimo_mensaje_en'] as String?;
      return ChatResumen(
        solicitudId: c['solicitud_id'] as String,
        contactoNombre: c['contacto_nombre'] as String,
        contactoFotoUrl: c['contacto_foto_url'] as String?,
        adultoMayorNombre: c['adulto_mayor_nombre'] as String,
        finalizado: (c['estado'] as String) == 'finalizada',
        puedeEscribir: c['puede_escribir'] as bool,
        ultimoMensaje: c['ultimo_mensaje'] as String?,
        ultimoMensajeEn: ultimaFecha == null ? null : _utcALocal(ultimaFecha),
        noLeidos: (c['no_leidos'] as num).toInt(),
      );
    }).toList();
  }
 
  /// Total de mensajes sin leer, para el número rojo del botón de chat.
  static int totalNoLeidos(List<ChatResumen> chats) =>
      chats.fold<int>(0, (suma, c) => suma + c.noLeidos);
 
  /// Mensajes de una conversación, del más antiguo al más nuevo.
  /// Con [despuesDe] trae solo los posteriores a esa fecha.
  static Future<List<ChatMensaje>> listarMensajes(
    String solicitudId, {
    DateTime? despuesDe,
  }) async {
    var ruta = '/solicitudes/$solicitudId/mensajes';
    if (despuesDe != null) {
      ruta += '?desde=${Uri.encodeQueryComponent(despuesDe.toUtc().toIso8601String())}';
    }
    final datos = await ApiClient.get(ruta) as List<dynamic>;
    return datos.map((item) => _aMensaje(item as Map<String, dynamic>)).toList();
  }
 
  static Future<ChatMensaje> enviar(String solicitudId, String texto) async {
    final datos = await ApiClient.post(
      '/solicitudes/$solicitudId/mensajes',
      {'texto': texto},
    ) as Map<String, dynamic>;
    return _aMensaje(datos);
  }
 
  static ChatMensaje _aMensaje(Map<String, dynamic> m) {
    final utc = _comoUtc(m['creado_en'] as String);
    return ChatMensaje(
      id: m['id'] as String,
      texto: m['texto'] as String,
      esPropio: m['autor_id'] == Sesion.usuario?.id,
      hora: utc.toLocal(),
      creadoUtc: utc,
    );
  }
 
  /// El servidor guarda estas fechas en hora UTC, sin indicar la zona.
  static DateTime _comoUtc(String texto) {
    final t = DateTime.parse(texto);
    if (t.isUtc) return t;
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond, t.microsecond);
  }
 
  static DateTime _utcALocal(String texto) => _comoUtc(texto).toLocal();
}