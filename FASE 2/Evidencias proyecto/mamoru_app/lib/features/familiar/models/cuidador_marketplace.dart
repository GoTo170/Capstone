import '../../auth/models/profesion_cuidador.dart';
 
class ValoracionMarketplace {
  final String autor;
  final int estrellas;
  final String comentario;
 
  const ValoracionMarketplace({
    required this.autor,
    required this.estrellas,
    required this.comentario,
  });
}
 
 
// ==========================================================
// TARIFAS POR PROFESIÓN
// ==========================================================
 
class TarifaProfesion {
  final int periodoCorto;
  final int periodoLargo;
  final int? puertasAdentro;
 
  const TarifaProfesion({
    required this.periodoCorto,
    required this.periodoLargo,
    this.puertasAdentro,
  });
 
  // 4 a 7 horas:
  // se aplica un descuento del 20% sobre la tarifa corta.
  int get periodoIntermedio =>
      (periodoCorto * 0.80).round();
}
 
 
const Map<String, TarifaProfesion> tarifasPorProfesion = {
  'TENS': TarifaProfesion(
    periodoCorto: 25000,
    periodoLargo: 5500,
    puertasAdentro: 80000,
  ),
 
  'Auxiliar de enfermería': TarifaProfesion(
    periodoCorto: 18000,
    periodoLargo: 4800,
    puertasAdentro: 60000,
  ),
 
  'Estudiante de medicina': TarifaProfesion(
    periodoCorto: 12000,
    periodoLargo: 4000,
  ),
 
  'Estudiante de enfermería': TarifaProfesion(
    periodoCorto: 10000,
    periodoLargo: 3800,
  ),
 
  'Estudiante TENS': TarifaProfesion(
    periodoCorto: 8000,
    periodoLargo: 3500,
  ),
 
  'Cuidador certificado': TarifaProfesion(
    periodoCorto: 10000,
    periodoLargo: 4500,
    puertasAdentro: 55000,
  ),
 
  'Cuidador práctico': TarifaProfesion(
    periodoCorto: 8000,
    periodoLargo: 4000,
    puertasAdentro: 45000,
  ),
 
  'Acompañante de adulto mayor': TarifaProfesion(
    periodoCorto: 7000,
    periodoLargo: 2500,
    puertasAdentro: 42000,
  ),
 
  'Asistente de hogar y cuidado': TarifaProfesion(
    periodoCorto: 5000,
    periodoLargo: 3500,
    puertasAdentro: 30000,
  ),
};
 
 
// ==========================================================
// CUIDADOR MARKETPLACE
// ==========================================================
 
class CuidadorMarketplace {
  final String id;
  final String nombre;
  final String profesion;
 
  final bool verificado;
  final double calificacion;
  final int numeroResenas;
  final String ciudad;
 
  final int experienciaAnios;
  final String disponibilidad;
  final String descripcion;
 
  final List<String> servicios;
  final List<ValoracionMarketplace> valoraciones;
 
  /// Ofrece la modalidad de cuidado diario "puertas adentro".
  final bool puertasAdentro;
 
  /// Dirección de su foto de perfil (null si no tiene).
  final String? fotoUrl;
 
  /// El servidor lo tiene marcado como profesional del área de la salud.
  final bool esAreaSalud;
 
  const CuidadorMarketplace({
    required this.id,
    required this.nombre,
    required this.profesion,
    required this.verificado,
    required this.calificacion,
    required this.numeroResenas,
    required this.ciudad,
    required this.experienciaAnios,
    required this.disponibilidad,
    required this.descripcion,
    required this.servicios,
    required this.valoraciones,
    this.puertasAdentro = false,
    this.fotoUrl,
    this.esAreaSalud = false,
  });
 
  /// Tarifa de la profesión del cuidador. El registro y esta tabla nombran
  /// distinto a algunas profesiones (por ejemplo "Técnico/a en Enfermería
  /// (TENS)" y "TENS"): si no hay coincidencia exacta, se busca en el
  /// catálogo del registro, que tiene las mismas tarifas.
  TarifaProfesion? get tarifa {
    final exacta = tarifasPorProfesion[profesion];
    if (exacta != null) return exacta;
 
    for (final p in catalogoProfesiones) {
      if (p.nombre == profesion) {
        return TarifaProfesion(
          periodoCorto: p.tarifaCorta,
          periodoLargo: p.tarifaLarga,
          puertasAdentro: p.tarifaPuertasAdentro,
        );
      }
    }
    return null;
  }
 
  // Esto permite que tu código antiguo que usa
  // cuidador.precioHora siga funcionando.
  int get precioHora =>
      tarifa?.periodoCorto ?? 0;
 
  /// La tarifa por hora más baja (se aplica a los servicios largos).
  int get precioDesde {
    final t = tarifa;
    if (t == null) return 0;
    final tarifas = [t.periodoCorto, t.periodoIntermedio, t.periodoLargo];
    return tarifas.reduce((a, b) => a < b ? a : b);
  }
 
  /// Muestra la modalidad puertas adentro solo si la ofrece y su profesión
  /// tiene tarifa diaria.
  bool get ofrecePuertasAdentro => puertasAdentro && tarifa?.puertasAdentro != null;
}
 
/// 25000 -> "$25.000"
String formatearPrecioCLP(int valor) {
  final conPuntos = valor.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );
  return '\$$conPuntos';
}
 
 
const List<String> catalogoServiciosMarketplace = [
  'Administración de medicamentos',
  'Higiene personal',
  'Compañía',
  'Traslados médicos',
  'Primeros auxilios',
  'Fisioterapia',
  'Ejercicios de movilidad',
  'Prevención de caídas',
  'Preparación de alimentos',
  'Limpieza del hogar',
];
 
 
final List<CuidadorMarketplace> cuidadoresDeEjemplo = [
  CuidadorMarketplace(
    id: 'c1',
    nombre: 'María García',
    profesion: 'TENS',
    verificado: true,
    calificacion: 4.8,
    numeroResenas: 3,
    ciudad: 'Guadalajara, Jalisco',
    experienciaAnios: 8,
    disponibilidad: 'Lunes a Viernes, 7am - 7pm',
    descripcion:
        'TENS con 8 años de experiencia en cuidado de adultos mayores. Especializada en pacientes con diabetes e hipertensión.',
    servicios: const [
      'Administración de medicamentos',
      'Higiene personal',
      'Compañía',
      'Traslados médicos',
      'Primeros auxilios',
    ],
    valoraciones: const [
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 5,
        comentario:
            'Excelente cuidadora, muy atenta y profesional. Mi mamá la adora.',
      ),
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 5,
        comentario:
            'Muy puntual y responsable. Recomendada al 100%.',
      ),
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 4,
        comentario:
            'Buena atención, muy amable con el paciente.',
      ),
    ],
  ),
 
  CuidadorMarketplace(
    id: 'c2',
    nombre: 'Luis Hernández',
    profesion: 'Cuidador certificado',
    verificado: true,
    calificacion: 4.5,
    numeroResenas: 2,
    ciudad: 'Guadalajara, Jalisco',
    experienciaAnios: 6,
    disponibilidad: 'Lunes a Sábado, 8am - 6pm',
    descripcion:
        'Cuidador certificado con experiencia en adultos mayores y apoyo en movilidad.',
    servicios: const [
      'Ejercicios de movilidad',
      'Prevención de caídas',
      'Compañía',
    ],
    valoraciones: const [
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 5,
        comentario:
            'Ayudó mucho a mi papá durante su recuperación.',
      ),
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 4,
        comentario:
            'Buen profesional, siempre puntual.',
      ),
    ],
  ),
 
  CuidadorMarketplace(
    id: 'c3',
    nombre: 'Ana López',
    profesion: 'Asistente de hogar y cuidado',
    verificado: true,
    calificacion: 4.9,
    numeroResenas: 2,
    ciudad: 'Tlaquepaque, Jalisco',
    experienciaAnios: 3,
    disponibilidad: 'Todos los días, 9am - 5pm',
    descripcion:
        'Asistente con experiencia en compañía y apoyo en actividades del hogar para adultos mayores.',
    servicios: const [
      'Compañía',
      'Preparación de alimentos',
      'Limpieza del hogar',
    ],
    valoraciones: const [
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 5,
        comentario:
            'Muy cariñosa y atenta con mi abuela.',
      ),
      ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: 5,
        comentario:
            'Excelente trato, muy recomendada.',
      ),
    ],
  ),
];