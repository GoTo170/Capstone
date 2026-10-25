enum EstadoSolicitudEnviada { pendiente, aceptada, rechazada, finalizada }

class SolicitudEnviada {
  final String id;
  final String nombreCuidador;
  final String nombreAdultoMayor;
  final String fechaTexto;
  final String horarioTexto;
  final String servicio;
  final EstadoSolicitudEnviada estado;
  final String? motivoRechazo;
  final int? valoracion; // nota (1 a 5) que ya dio el familiar; null si aún no valora

  const SolicitudEnviada({
    this.id = '',
    required this.nombreCuidador,
    required this.nombreAdultoMayor,
    required this.fechaTexto,
    required this.horarioTexto,
    required this.servicio,
    required this.estado,
    this.motivoRechazo,
    this.valoracion,
  });
}