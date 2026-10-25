import 'solicitud_servicio.dart';
 
class ServicioActivo {
  final String id;
  final String adultoMayorId;
  final String nombreAdultoMayor;
 
  final int? edad;
  final String? telefono;
 
  final String familiarResponsable;
 
  final DateTime fechaInicio;
  DateTime? fechaTermino;
 
  final String informacionImportante;
 
  bool finalizadoManualmente;
 
  /// El servidor lo da por en curso: aceptado y dentro de su período.
  final bool vigente;
 
  /// Contactos de emergencia del adulto mayor. Solo llegan mientras el
  /// servicio está vigente.
  final List<ContactoEmergenciaServicio> contactos;
 
  ServicioActivo({
    required this.id,
    required this.adultoMayorId,
    required this.nombreAdultoMayor,
    this.edad,
    this.telefono,
    required this.familiarResponsable,
    required this.fechaInicio,
    this.fechaTermino,
    required this.informacionImportante,
    this.finalizadoManualmente = false,
    this.vigente = false,
    this.contactos = const [],
  });
 
  bool get estaFinalizado => finalizadoManualmente;
 
  bool get puedeFinalizarse => !estaFinalizado;
}
 
class Observacion {
  final String actividadTitulo;
  final DateTime fecha;
  final String texto;
 
  const Observacion({
    required this.actividadTitulo,
    required this.fecha,
    required this.texto,
  });
}