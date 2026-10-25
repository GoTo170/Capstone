class ChatMensaje {
  final String id;
  final String texto;
  final bool esPropio;

  /// Hora local del dispositivo (para mostrarla).
  final DateTime hora;

  /// Fecha de creación en UTC, tal como la guardó el servidor.
  final DateTime creadoUtc;

  const ChatMensaje({
    required this.id,
    required this.texto,
    required this.esPropio,
    required this.hora,
    required this.creadoUtc,
  });
}