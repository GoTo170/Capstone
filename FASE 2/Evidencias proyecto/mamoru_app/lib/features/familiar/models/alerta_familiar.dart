enum TipoAlertaFamiliar { informacion, sos, tareaVencida }

class AlertaFamiliar {
  final String? id;
  final TipoAlertaFamiliar tipo;
  final String titulo;
  final String texto;
  final DateTime hora;
  bool leida;

  AlertaFamiliar({
    this.id,
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.hora,
    this.leida = false,
  });
}