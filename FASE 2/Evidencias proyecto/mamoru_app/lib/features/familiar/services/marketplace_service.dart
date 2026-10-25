import '../../../core/api_client.dart';
import '../models/cuidador_marketplace.dart';
import '../models/solicitud_enviada.dart';
 
/// Búsqueda de cuidadores y solicitudes de servicio del familiar.
class MarketplaceService {
  /// Cuidadores verificados, con su calificación y reseñas.
  static Future<List<CuidadorMarketplace>> listarCuidadores() async {
    final datos = await ApiClient.get('/marketplace/cuidadores') as List<dynamic>;
    return datos.map((item) => _aCuidador(item as Map<String, dynamic>)).toList();
  }
 
  /// Envía la solicitud de servicio al cuidador. El servidor vuelve a validar
  /// las fechas, el tipo de servicio y el vínculo con el adulto mayor.
  static Future<void> enviarSolicitud({
    required String adultoMayorId,
    required String cuidadorId,
    required String direccion,
    required DateTime inicio,
    required DateTime termino,
    required String tipoServicio,
    String? informacionAdicional,
    String? mensaje,
  }) async {
    await ApiClient.post('/solicitudes', {
      'adulto_mayor_id': adultoMayorId,
      'cuidador_id': cuidadorId,
      'direccion': direccion,
      'fecha_inicio': _fechaIso(inicio),
      'hora_inicio': _horaIso(inicio),
      'fecha_termino': _fechaIso(termino),
      'hora_termino': _horaIso(termino),
      'tipo_servicio': tipoServicio,
      'informacion_adicional': _nuloSiVacio(informacionAdicional),
      'mensaje': _nuloSiVacio(mensaje),
    });
  }
 
  /// Solicitudes enviadas por el familiar, de la más nueva a la más antigua.
  static Future<List<SolicitudEnviada>> listarSolicitudes() async {
    final datos = await ApiClient.get('/familiar/solicitudes') as List<dynamic>;
 
    return datos.map((item) {
      final s = item as Map<String, dynamic>;
 
      final estadoTexto = s['estado'] as String;
      final estado = estadoTexto == 'aceptada'
          ? EstadoSolicitudEnviada.aceptada
          : estadoTexto == 'rechazada'
              ? EstadoSolicitudEnviada.rechazada
              : estadoTexto == 'finalizada'
                  ? EstadoSolicitudEnviada.finalizada
                  : EstadoSolicitudEnviada.pendiente;
 
      return SolicitudEnviada(
        nombreCuidador: s['cuidador_nombre'] as String,
        nombreAdultoMayor: s['adulto_mayor_nombre'] as String,
        fechaTexto: _textoFechas(s['fecha_inicio'] as String?, s['fecha_termino'] as String?),
        horarioTexto: _textoHorario(s['hora_inicio'] as String?, s['hora_termino'] as String?),
        servicio: nombreServicio(s['tipo_servicio'] as String?),
        estado: estado,
        motivoRechazo: _textoMotivo(s['motivo_rechazo'] as String?, s['motivo_rechazo_detalle'] as String?),
      );
    }).toList();
  }
 
  // ------------------------------------------------------------ nombres
 
  /// Los 5 tipos que se pueden pedir hoy (el sexto, "puertas adentro", se
  /// cotiza por día y todavía no está en el formulario).
  static const Map<String, String> tiposServicio = {
    'acompanamiento_apoyo_emocional': 'Acompañamiento y apoyo emocional',
    'cuidado_fisico_personal': 'Cuidado físico y personal',
    'control_medicamentos': 'Control de medicamentos',
    'alimentacion': 'Alimentación',
    'cuidador_integral': 'Cuidador integral',
  };
 
  static String nombreServicio(String? clave) {
    if (clave == null) return 'Sin especificar';
    if (clave == 'cuidado_puertas_adentro') return 'Cuidado puertas adentro';
    return tiposServicio[clave] ?? clave;
  }
 
  static const Map<String, String> _motivos = {
    'no_tengo_disponibilidad': 'No tengo disponibilidad',
    'horario_no_acomoda': 'El horario no me acomoda',
    'ubicacion_fuera_zona': 'La ubicación está fuera de mi zona',
    'tipo_cuidado_no_corresponde': 'El tipo de cuidado no corresponde a mis servicios',
    'otros': 'Otros',
  };
 
  static String? _textoMotivo(String? clave, String? detalle) {
    if (clave == null) return null;
    final base = _motivos[clave] ?? clave;
    if (clave == 'otros' && detalle != null && detalle.trim().isNotEmpty) {
      return '$base: $detalle';
    }
    return base;
  }
 
  // ------------------------------------------------------------ cuidador
 
  static CuidadorMarketplace _aCuidador(Map<String, dynamic> c) {
    final profesion = (c['profesion'] as String?) ?? 'Cuidador/a';
    final experiencia = c['experiencia'] as String?;
    final disponible = c['disponible'] as bool;
 
    final lineas = ((c['servicios_ofrecidos'] as String?) ?? '')
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
 
    // "Cuidado puertas adentro" es una modalidad con tarifa propia, no una
    // especialidad: no se muestra como servicio.
    const marcaPuertasAdentro = 'Cuidado puertas adentro';
    final puertasAdentro = lineas.contains(marcaPuertasAdentro);
    final servicios = lineas.where((s) => s != marcaPuertasAdentro).toList();
 
    final valoraciones = (c['valoraciones'] as List<dynamic>).map((item) {
      final v = item as Map<String, dynamic>;
      return ValoracionMarketplace(
        autor: 'Anónimo',
        estrellas: v['puntuacion'] as int,
        comentario: (v['comentario'] as String?) ?? '',
      );
    }).toList();
 
    // La experiencia se guarda como texto ("5 años de experiencia").
    final anios = int.tryParse(RegExp(r'\d+').firstMatch(experiencia ?? '')?.group(0) ?? '') ?? 0;
 
    return CuidadorMarketplace(
      id: c['id'] as String,
      nombre: '${c['nombre']} ${c['apellido'] ?? ''}'.trim(),
      profesion: profesion,
      verificado: true,
      calificacion: (c['calificacion'] as num).toDouble(),
      numeroResenas: c['numero_resenas'] as int,
      ciudad: (c['ubicacion'] as String?) ?? 'Ubicación no indicada',
      experienciaAnios: anios,
      disponibilidad: disponible ? 'Disponible' : 'No disponible por ahora',
      descripcion: ((c['descripcion'] as String?)?.trim().isNotEmpty ?? false)
          ? (c['descripcion'] as String).trim()
          : ((experiencia == null || experiencia.trim().isEmpty) ? profesion : '$profesion · $experiencia'),
      servicios: servicios,
      valoraciones: valoraciones,
      puertasAdentro: puertasAdentro,
      fotoUrl: c['foto_url'] as String?,
      esAreaSalud: (c['es_area_salud'] as bool?) ?? false,
    );
  }
 
  // ------------------------------------------------------------ formatos
 
  static String _d(int n) => n.toString().padLeft(2, '0');
 
  /// "2026-10-04": formato de fecha que espera el servidor.
  static String _fechaIso(DateTime f) => '${f.year.toString().padLeft(4, '0')}-${_d(f.month)}-${_d(f.day)}';
 
  /// "09:30:00": formato de hora que espera el servidor.
  static String _horaIso(DateTime f) => '${_d(f.hour)}:${_d(f.minute)}:00';
 
  static String? _nuloSiVacio(String? texto) {
    final limpio = texto?.trim();
    return (limpio == null || limpio.isEmpty) ? null : limpio;
  }
 
  /// "2026-10-06" -> "06-10-2026"
  static String _fechaCorta(String iso) {
    final partes = iso.split('-');
    return partes.length == 3 ? '${partes[2]}-${partes[1]}-${partes[0]}' : iso;
  }
 
  static String _textoFechas(String? inicio, String? termino) {
    if (inicio == null) return '—';
    if (termino == null || termino == inicio) return _fechaCorta(inicio);
    return '${_fechaCorta(inicio)} → ${_fechaCorta(termino)}';
  }
 
  /// "09:00:00" -> "09:00"
  static String _horaCorta(String hora) => hora.length >= 5 ? hora.substring(0, 5) : hora;
 
  static String _textoHorario(String? inicio, String? termino) {
    if (inicio == null || termino == null) return '—';
    return '${_horaCorta(inicio)}-${_horaCorta(termino)}';
  }
}