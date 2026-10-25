enum CategoriaProfesion { areaSalud, cuidadoProfesional, asistenciaCompania }

enum TipoDocumentoRequerido {
  tituloOCertificado,
  certificadoAlumnoRegular,
  certificadoODiploma,
  cartaRecomendacion,
  ninguno,
}

class ProfesionCuidador {
  final String id;
  final String nombre;
  final CategoriaProfesion categoria;
  final TipoDocumentoRequerido documentoRequerido;
  final int tarifaCorta; // CLP por hora, periodo 1-3 hrs
  final int tarifaLarga; // CLP por hora, periodo 8-16 hrs
  final int? tarifaPuertasAdentro; // CLP por día, null = no aplica

  const ProfesionCuidador({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.documentoRequerido,
    required this.tarifaCorta,
    required this.tarifaLarga,
    this.tarifaPuertasAdentro,
  });

  int get tarifaIntermedia => (tarifaCorta * 0.8).round(); // 4-7 hrs: corto -20%

  bool get requiereDocumento => documentoRequerido != TipoDocumentoRequerido.ninguno;

  bool get admitePuertasAdentro => tarifaPuertasAdentro != null;

  String get instruccionDocumento {
    switch (documentoRequerido) {
      case TipoDocumentoRequerido.tituloOCertificado:
        return 'Título, certificado de estudios o documento vigente.';
      case TipoDocumentoRequerido.certificadoAlumnoRegular:
        return 'Certificado de alumno regular o documento equivalente.';
      case TipoDocumentoRequerido.certificadoODiploma:
        return 'Certificado o diploma que acredite tu formación como cuidador.';
      case TipoDocumentoRequerido.cartaRecomendacion:
        return 'Carta de recomendación de tu(s) jefe(s) anterior(es), más su número de contacto y correo.';
      case TipoDocumentoRequerido.ninguno:
        return '';
    }
  }
}

String etiquetaCategoria(CategoriaProfesion c) {
  switch (c) {
    case CategoriaProfesion.areaSalud:
      return 'Área de la salud';
    case CategoriaProfesion.cuidadoProfesional:
      return 'Cuidado profesional';
    case CategoriaProfesion.asistenciaCompania:
      return 'Asistencia y compañía';
  }
}

const List<ProfesionCuidador> catalogoProfesiones = [
  ProfesionCuidador(
    id: 'tens',
    nombre: 'Técnico/a en Enfermería (TENS)',
    categoria: CategoriaProfesion.areaSalud,
    documentoRequerido: TipoDocumentoRequerido.tituloOCertificado,
    tarifaCorta: 25000,
    tarifaLarga: 5500,
    tarifaPuertasAdentro: 80000,
  ),
  ProfesionCuidador(
    id: 'auxiliar_enfermeria',
    nombre: 'Auxiliar de enfermería',
    categoria: CategoriaProfesion.areaSalud,
    documentoRequerido: TipoDocumentoRequerido.tituloOCertificado,
    tarifaCorta: 18000,
    tarifaLarga: 4800,
    tarifaPuertasAdentro: 60000,
  ),
  ProfesionCuidador(
    id: 'estudiante_medicina',
    nombre: 'Estudiante de medicina',
    categoria: CategoriaProfesion.areaSalud,
    documentoRequerido: TipoDocumentoRequerido.certificadoAlumnoRegular,
    tarifaCorta: 12000,
    tarifaLarga: 4000,
    tarifaPuertasAdentro: null,
  ),
  ProfesionCuidador(
    id: 'estudiante_enfermeria',
    nombre: 'Estudiante de enfermería',
    categoria: CategoriaProfesion.areaSalud,
    documentoRequerido: TipoDocumentoRequerido.certificadoAlumnoRegular,
    tarifaCorta: 10000,
    tarifaLarga: 3800,
    tarifaPuertasAdentro: null,
  ),
  ProfesionCuidador(
    id: 'estudiante_tens',
    nombre: 'Estudiante técnico en enfermería',
    categoria: CategoriaProfesion.areaSalud,
    documentoRequerido: TipoDocumentoRequerido.certificadoAlumnoRegular,
    tarifaCorta: 8000,
    tarifaLarga: 3500,
    tarifaPuertasAdentro: null,
  ),
  ProfesionCuidador(
    id: 'cuidador_certificado',
    nombre: 'Cuidador/a certificado/a',
    categoria: CategoriaProfesion.cuidadoProfesional,
    documentoRequerido: TipoDocumentoRequerido.certificadoODiploma,
    tarifaCorta: 10000,
    tarifaLarga: 4500,
    tarifaPuertasAdentro: 55000,
  ),
  ProfesionCuidador(
    id: 'cuidador_practico',
    nombre: 'Cuidador/a práctico/a',
    categoria: CategoriaProfesion.cuidadoProfesional,
    documentoRequerido: TipoDocumentoRequerido.cartaRecomendacion,
    tarifaCorta: 8000,
    tarifaLarga: 4000,
    tarifaPuertasAdentro: 45000,
  ),
  ProfesionCuidador(
    id: 'acompanante_adulto_mayor',
    nombre: 'Acompañante de adulto mayor',
    categoria: CategoriaProfesion.asistenciaCompania,
    documentoRequerido: TipoDocumentoRequerido.ninguno,
    tarifaCorta: 7000,
    tarifaLarga: 2500,
    tarifaPuertasAdentro: 42000,
  ),
  ProfesionCuidador(
    id: 'asistente_hogar',
    nombre: 'Asistente de hogar y cuidado',
    categoria: CategoriaProfesion.asistenciaCompania,
    documentoRequerido: TipoDocumentoRequerido.ninguno,
    tarifaCorta: 5000,
    tarifaLarga: 3500,
    tarifaPuertasAdentro: 30000,
  ),
];

List<String> serviciosPorCategoria(CategoriaProfesion categoria) {
  switch (categoria) {
    case CategoriaProfesion.areaSalud:
      return [
        'Acompañamiento y apoyo emocional',
        'Aseo personal y asistencia física',
        'Recordatorio de medicamentos',
        'Administración de medicamentos y toma de signos vitales',
        'Preparación y asistencia en alimentos',
        'Cuidado de alta dependencia',
      ];
    case CategoriaProfesion.cuidadoProfesional:
      return [
        'Acompañamiento y apoyo emocional',
        'Aseo personal y asistencia física',
        'Recordatorio de medicamentos',
        'Preparación y asistencia en alimentos',
        'Cuidado de alta dependencia',
      ];
    case CategoriaProfesion.asistenciaCompania:
      return [
        'Acompañamiento y apoyo emocional',
        'Preparación y asistencia en alimentos',
      ];
  }
}

const List<String> _idsProfesionesMedicas = [
  'tens',
  'auxiliar_enfermeria',
  'estudiante_medicina',
  'estudiante_enfermeria',
  'estudiante_tens',
];

bool esProfesionMedica(String profesionId) => _idsProfesionesMedicas.contains(profesionId);

ProfesionCuidador? buscarProfesionPorId(String id) {
  for (final p in catalogoProfesiones) {
    if (p.id == id) return p;
  }
  return null;
}