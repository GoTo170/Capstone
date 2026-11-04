import '../../../core/api_client.dart';
import '../models/perfil_adulto_mayor_vinculado.dart';
 
/// Ya no se usa aquí (los contactos ahora se proponen con ApiException); se deja por si otra pantalla la nombra.
class ErrorContactos implements Exception {
  final String mensaje;
  const ErrorContactos(this.mensaje);
 
  @override
  String toString() => mensaje;
}
 
/// Resultado de crear o regenerar una invitación.
class InvitacionCreada {
  final String adultoMayorId;
  final String nombreAdultoMayor;
  final String codigo;
 
  const InvitacionCreada({
    required this.adultoMayorId,
    required this.nombreAdultoMayor,
    required this.codigo,
  });
}
 
/// Adulto mayor vinculado al familiar (para la lista del perfil).
class AdultoVinculado {
  final String id;
  final String nombreCompleto;
  final bool accesoActivado;
  final String? fotoUrl;
 
  const AdultoVinculado({
    required this.id,
    required this.nombreCompleto,
    required this.accesoActivado,
    this.fotoUrl,
  });
}
 
/// Operaciones del familiar contra el backend.
class FamiliarService {
  /// Crea al adulto mayor (con su perfil de salud y contactos de emergencia),
  /// lo vincula al familiar y genera la invitación de 48 horas.
  static Future<InvitacionCreada> crearAdultoMayor({
    required String nombre,
    required String apellido,
    required DateTime fechaNacimiento,
    required String relacionFamiliar,
    String? enfermedades,
    String? alergiaMedicamentos,
    String? alergiaAlimentos,
    String? intoleranciaAlimentaria,
    required List<Map<String, dynamic>> contactos,
  }) async {
    final datos = await ApiClient.post('/adultos-mayores', {
      'nombre': nombre,
      'apellido': apellido,
      'fecha_nacimiento': _fechaIso(fechaNacimiento),
      'relacion_familiar': relacionFamiliar,
      'enfermedades': enfermedades,
      'alergia_medicamentos': alergiaMedicamentos,
      'alergia_alimentos': alergiaAlimentos,
      'intolerancia_alimentaria': intoleranciaAlimentaria,
      'contactos': contactos,
    }) as Map<String, dynamic>;
 
    final usuario = datos['usuario'] as Map<String, dynamic>;
    final invitacion = datos['invitacion'] as Map<String, dynamic>;
 
    final nombreCompleto =
        '${usuario['nombre']} ${usuario['apellido'] ?? ''}'.trim();
 
    return InvitacionCreada(
      adultoMayorId: usuario['id'] as String,
      nombreAdultoMayor: nombreCompleto,
      codigo: invitacion['codigo'] as String,
    );
  }
 
  /// Adultos mayores vinculados al familiar que inició sesión.
  static Future<List<AdultoVinculado>> listarAdultosMayores() async {
    final datos = await ApiClient.get('/adultos-mayores') as List<dynamic>;
 
    return datos.map((item) {
      final a = item as Map<String, dynamic>;
      return AdultoVinculado(
        id: a['id'] as String,
        nombreCompleto: '${a['nombre']} ${a['apellido'] ?? ''}'.trim(),
        accesoActivado: a['acceso_activado'] as bool,
        fotoUrl: a['foto_url'] as String?,
      );
    }).toList();
  }
 
  /// Perfil completo de un adulto mayor vinculado (para la pantalla de detalle).
  static Future<PerfilAdultoMayorVinculado> detalleAdultoMayor(String id) async {
    final d = await ApiClient.get('/adultos-mayores/$id') as Map<String, dynamic>;
    return _perfilDesdeJson(d);
  }
 
  /// Igual que detalleAdultoMayor, pero también devuelve la URL de su foto y los
  /// tipos de cambio que esperan aprobación del administrador
  /// ("salud", "alergias", "contactos").
  static Future<({PerfilAdultoMayorVinculado perfil, String? fotoUrl, Set<String> cambiosPendientes})> detalleConFoto(String id) async {
    final d = await ApiClient.get('/adultos-mayores/$id') as Map<String, dynamic>;
    final pendientes = ((d['cambios_pendientes'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toSet();
    final perfil = _perfilDesdeJson(d);
    perfil.saludPendienteAprobacion = pendientes.contains('salud');
    perfil.alergiasPendienteAprobacion = pendientes.contains('alergias');
    return (perfil: perfil, fotoUrl: d['foto_url'] as String?, cambiosPendientes: pendientes);
  }

  static PerfilAdultoMayorVinculado _perfilDesdeJson(Map<String, dynamic> d) {
 
    final fechaTexto = d['fecha_nacimiento'] as String?;
    final nacimiento = fechaTexto == null ? null : DateTime.parse(fechaTexto);
 
    final contactos = (d['contactos'] as List<dynamic>).map((item) {
      final c = item as Map<String, dynamic>;
      return ContactoEmergenciaInfo(
        nombre: c['nombre'] as String,
        telefono: c['telefono'] as String,
        relacion: (c['parentesco'] as String?) ?? '',
      );
    }).toList();
 
    return PerfilAdultoMayorVinculado(
      id: d['id'] as String,
      nombre: d['nombre'] as String,
      apellido: (d['apellido'] as String?) ?? '',
      fechaNacimientoTexto:
          nacimiento == null ? 'No registrada' : _fechaLarga(nacimiento),
      edad: nacimiento == null ? 0 : _edad(nacimiento),
      telefono: (d['telefono'] as String?) ?? 'No registrado',
      relacionFamiliar: (d['parentesco'] as String?) ?? 'No indicada',
      correo: 'Sin correo (ingresa con código)',
      perfilActivo: d['acceso_activado'] as bool,
      condicionesMedicas: _lista(d['enfermedades'] as String?),
      indicacionesImportantes: 'Sin indicaciones registradas.',
      alergiaMedicamentos: _lista(d['alergia_medicamentos'] as String?),
      alergiaAlimentos: _lista(d['alergia_alimentos'] as String?),
      intolerancias: _lista(d['intolerancia_alimentaria'] as String?),
      contactosEmergencia: contactos,
    );
  }
 
  // ------------------------------------------------ cambios con aprobación
  // Ninguno modifica el perfil: el cambio queda pendiente hasta que el
  // administrador lo apruebe en el panel. Si algo falla lanzan ApiException.

  /// Propone nuevas condiciones médicas (un ítem por línea).
  static Future<void> proponerCambioSalud(String adultoMayorId, List<String> condiciones) async {
    await ApiClient.post('/adultos-mayores/$adultoMayorId/cambios', {
      'tipo': 'salud',
      'enfermedades': condiciones.join('\n'),
    });
  }

  /// Propone nuevas alergias e intolerancias (un ítem por línea).
  static Future<void> proponerCambioAlergias(
    String adultoMayorId, {
    required List<String> medicamentos,
    required List<String> alimentos,
    required List<String> intolerancias,
  }) async {
    await ApiClient.post('/adultos-mayores/$adultoMayorId/cambios', {
      'tipo': 'alergias',
      'alergia_medicamentos': medicamentos.join('\n'),
      'alergia_alimentos': alimentos.join('\n'),
      'intolerancia_alimentaria': intolerancias.join('\n'),
    });
  }

  /// Propone nuevos contactos de emergencia (1 a 3).
  static Future<void> proponerCambioContactos(String adultoMayorId, List<ContactoEmergenciaInfo> contactos) async {
    await ApiClient.post('/adultos-mayores/$adultoMayorId/cambios', {
      'tipo': 'contactos',
      'contactos': [
        for (int i = 0; i < contactos.length; i++)
          {
            'nombre': contactos[i].nombre,
            'telefono': contactos[i].telefono,
            'parentesco': contactos[i].relacion,
            'orden': i + 1,
          },
      ],
    });
  }

  /// Genera un código nuevo para un adulto mayor que ya existe.
  /// El código anterior deja de servir.
  static Future<InvitacionCreada> reinvitar(
    String adultoMayorId,
    String nombreAdultoMayor,
  ) async {
    final datos = await ApiClient.post(
      '/adultos-mayores/$adultoMayorId/invitacion',
    ) as Map<String, dynamic>;
 
    return InvitacionCreada(
      adultoMayorId: adultoMayorId,
      nombreAdultoMayor: nombreAdultoMayor,
      codigo: datos['codigo'] as String,
    );
  }
 
  /// Revoca el código pendiente. El adulto mayor sigue vinculado.
  static Future<void> cancelarInvitacion(String adultoMayorId) async {
    await ApiClient.delete('/adultos-mayores/$adultoMayorId/invitacion');
  }
 
  // ---------------------------------------------------------- utilidades
 
  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
 
  /// "2026-10-04": formato de fecha que espera el backend.
  static String _fechaIso(DateTime fecha) {
    final anio = fecha.year.toString().padLeft(4, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    return '$anio-$mes-$dia';
  }
 
  /// "18 de marzo de 1954"
  static String _fechaLarga(DateTime f) =>
      '${f.day} de ${_meses[f.month - 1]} de ${f.year}';
 
  static int _edad(DateTime nacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }
 
  /// Los datos de salud se guardan un ítem por línea.
  static List<String> _lista(String? texto) {
    if (texto == null) return [];
    return texto
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}