enum EstadoSolicitud { nueva, aceptada, rechazada, finalizada }
 
/// Contacto de emergencia del adulto mayor. El cuidador solo lo recibe mientras
/// dura el servicio.
class ContactoEmergenciaServicio {
  final String nombre;
  final String telefono;
  final String? parentesco;
 
  const ContactoEmergenciaServicio({required this.nombre, required this.telefono, this.parentesco});
}
 
class SolicitudServicio {
  /// Texto que se muestra cuando la familia no dejó información adicional.
  static const String sinInformacion = 'Sin información adicional';
 
  final String id;
  final String nombreFamiliar;
  final String nombreAdultoMayor;
  final String fechaSolicitudTexto;
  final String fechaServicioTexto;
  final String horarioTexto;
  final String tipoServicio;
  final String direccion;
  final String informacion;
  final String? mensaje;
  EstadoSolicitud estado;
  String? motivoRechazo;
  String? comentarioHistorial;
  String? fechaHistorialTexto;
 
  // Datos para el servicio en curso. El servidor llena los datos del adulto
  // mayor solo durante el servicio vigente (puedeVerInformacionSensible).
  final String? adultoMayorId;
  final DateTime? inicio;
  final DateTime? termino;
  final bool puedeVerInformacionSensible;
  final int? edadAdultoMayor;
  final String? telefonoAdultoMayor;
  final String? enfermedades;
  final String? alergiaMedicamentos;
  final String? alergiaAlimentos;
  final String? intolerancia;
  final List<ContactoEmergenciaServicio> contactos;
 
  SolicitudServicio({
    required this.id,
    required this.nombreFamiliar,
    required this.nombreAdultoMayor,
    required this.fechaSolicitudTexto,
    required this.fechaServicioTexto,
    required this.horarioTexto,
    required this.tipoServicio,
    required this.direccion,
    required this.informacion,
    this.mensaje,
    this.estado = EstadoSolicitud.nueva,
    this.motivoRechazo,
    this.comentarioHistorial,
    this.fechaHistorialTexto,
    this.adultoMayorId,
    this.inicio,
    this.termino,
    this.puedeVerInformacionSensible = false,
    this.edadAdultoMayor,
    this.telefonoAdultoMayor,
    this.enfermedades,
    this.alergiaMedicamentos,
    this.alergiaAlimentos,
    this.intolerancia,
    this.contactos = const [],
  });
}