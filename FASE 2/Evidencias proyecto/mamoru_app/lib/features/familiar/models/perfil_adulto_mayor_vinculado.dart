class ContactoEmergenciaInfo {
  String nombre;
  String telefono;
  String relacion;

  ContactoEmergenciaInfo({required this.nombre, required this.telefono, required this.relacion});

  ContactoEmergenciaInfo copia() => ContactoEmergenciaInfo(nombre: nombre, telefono: telefono, relacion: relacion);
}

class PerfilAdultoMayorVinculado {
  final String id;
  final String nombre;
  final String apellido;
  final String fechaNacimientoTexto;
  final int edad;
  final String telefono;
  final String relacionFamiliar;
  final String correo;
  final bool perfilActivo;

  List<String> condicionesMedicas;
  String indicacionesImportantes;
  List<String> alergiaMedicamentos;
  List<String> alergiaAlimentos;
  List<String> intolerancias;
  List<ContactoEmergenciaInfo> contactosEmergencia;

  bool saludPendienteAprobacion;
  bool alergiasPendienteAprobacion;
  bool contactosPendienteAprobacion;

  PerfilAdultoMayorVinculado({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.fechaNacimientoTexto,
    required this.edad,
    required this.telefono,
    required this.relacionFamiliar,
    required this.correo,
    this.perfilActivo = true,
    required this.condicionesMedicas,
    required this.indicacionesImportantes,
    required this.alergiaMedicamentos,
    required this.alergiaAlimentos,
    required this.intolerancias,
    required this.contactosEmergencia,
    this.saludPendienteAprobacion = false,
    this.alergiasPendienteAprobacion = false,
    this.contactosPendienteAprobacion = false,
  });
}