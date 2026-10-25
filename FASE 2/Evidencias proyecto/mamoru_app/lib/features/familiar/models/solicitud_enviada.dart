enum EstadoSolicitudEnviada { pendiente, aceptada, rechazada, finalizada }
 
class SolicitudEnviada {
  final String nombreCuidador;
  final String nombreAdultoMayor;
  final String fechaTexto;
  final String horarioTexto;
  final String servicio;
  final EstadoSolicitudEnviada estado;
  final String? motivoRechazo;
 
  const SolicitudEnviada({
    required this.nombreCuidador,
    required this.nombreAdultoMayor,
    required this.fechaTexto,
    required this.horarioTexto,
    required this.servicio,
    required this.estado,
    this.motivoRechazo,
  });
}