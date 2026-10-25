import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../models/actividad.dart';
 
/// Actividades (tareas y recordatorios) del adulto mayor.
class TareasService {
  /// Actividades de un adulto mayor, ordenadas por fecha y hora.
  /// El servidor devuelve las de todos los adultos mayores vinculados al
  /// familiar; aquí se filtra la del adulto mayor elegido.
  static Future<List<Actividad>> listar(String adultoMayorId) async {
    final datos = await ApiClient.get('/tareas') as List<dynamic>;
    final observaciones = await _observacionesPorTarea();
 
    final lista = <Actividad>[];
    for (final item in datos) {
      final tarea = item as Map<String, dynamic>;
      if (tarea['adulto_mayor_id'] != adultoMayorId) continue;
      lista.add(_aActividad(tarea, observaciones[tarea['id']]));
    }
 
    lista.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return lista;
  }
 
  /// Crea la actividad en cada una de las fechas indicadas (todo o nada).
  static Future<void> crear({
    required String adultoMayorId,
    required String titulo,
    required TipoActividad tipo,
    String? notas,
    required List<DateTime> fechas,
  }) async {
    await ApiClient.post('/tareas/lote', {
      'adulto_mayor_id': adultoMayorId,
      'titulo': titulo,
      'categoria': tipo.name,
      'descripcion': notas,
      'fechas': fechas.map(_fechaHoraIso).toList(),
    });
  }
 
  /// Mis actividades (para el adulto mayor): el servidor devuelve solo las suyas.
  static Future<List<Actividad>> listarMias() async {
    final datos = await ApiClient.get('/tareas') as List<dynamic>;
 
    final lista = datos.map((item) => _aActividad(item as Map<String, dynamic>)).toList();
    lista.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return lista;
  }
 
  /// Solo las actividades programadas para hoy.
  static List<Actividad> deHoy(List<Actividad> actividades) {
    final hoy = DateTime.now();
    return actividades
        .where((a) => a.fechaHora.year == hoy.year && a.fechaHora.month == hoy.month && a.fechaHora.day == hoy.day)
        .toList();
  }
 
  /// Registra una actividad como realizada o no realizada.
  static Future<Actividad> actualizarEstado(String id, EstadoTarea estado) async {
    final datos = await ApiClient.patch('/tareas/$id/estado', {
      'estado': estado == EstadoTarea.realizada
          ? 'realizada'
          : estado == EstadoTarea.noRealizada
              ? 'no_realizada'
              : 'pendiente',
    }) as Map<String, dynamic>;
 
    return _aActividad(datos);
  }
 
  /// Pasa una actividad flexible a la hora actual (hasta 30 min antes de su hora).
  static Future<Actividad> adelantar(String id) async {
    final datos = await ApiClient.post('/tareas/$id/adelantar', {}) as Map<String, dynamic>;
    return _aActividad(datos);
  }
 
  /// Para actividades de horario estricto: avisa a la familia que se necesita revisar la hora.
  static Future<void> solicitarCambio(String id, {String? motivo}) async {
    final texto = motivo?.trim() ?? '';
    await ApiClient.post('/tareas/$id/solicitar-cambio', {
      if (texto.isNotEmpty) 'motivo': texto,
    });
  }
 
  /// Observaciones que dejó el cuidador, por actividad. Si no se pueden traer,
  /// las actividades se muestran igual, solo que sin observaciones.
  static Future<Map<String, List<_ObservacionCuidador>>> _observacionesPorTarea() async {
    try {
      final datos = await ApiClient.get('/bitacora') as List<dynamic>;
      final mapa = <String, List<_ObservacionCuidador>>{};
 
      for (final item in datos) {
        final r = item as Map<String, dynamic>;
        final texto = ((r['observacion'] as String?) ?? '').trim();
        if (texto.isEmpty) continue;
 
        mapa.putIfAbsent(r['tarea_id'] as String, () => []).add(
              // La bitácora la fecha la base de datos, en hora UTC.
              _ObservacionCuidador(texto: texto, fecha: _desdeUtc(r['fecha_registro'] as String)),
            );
      }
 
      for (final lista in mapa.values) {
        lista.sort((a, b) => a.fecha.compareTo(b.fecha));
      }
      return mapa;
    } on ApiException {
      return {};
    }
  }
 
  static DateTime _desdeUtc(String texto) {
    final t = DateTime.parse(texto);
    if (t.isUtc) return t.toLocal();
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond, t.microsecond).toLocal();
  }
 
  static String _hora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.hour)}:${d(f.minute)}';
  }
 
  static Actividad _aActividad(Map<String, dynamic> tarea, [List<_ObservacionCuidador>? observaciones]) {
    final categoria = tarea['categoria'] as String?;
    final tipo = TipoActividad.values.firstWhere(
      (t) => t.name == categoria,
      orElse: () => TipoActividad.otro,
    );
 
    final estadoTexto = tarea['estado'] as String?;
    final estado = estadoTexto == 'realizada'
        ? EstadoTarea.realizada
        : estadoTexto == 'no_realizada'
            ? EstadoTarea.noRealizada
            : EstadoTarea.pendiente;
 
    final confirmacion = tarea['fecha_confirmacion'] as String?;
    final notas = tarea['descripcion'] as String?;
    final horaOriginal = tarea['hora_original'] as String?;
 
    // Una observación se muestra con su hora; si hay dos, cada una lleva su hora
    // delante y se muestran juntas.
    final obs = observaciones ?? const <_ObservacionCuidador>[];
    String? textoObservacion;
    DateTime? horaObservacion;
    if (obs.length == 1) {
      textoObservacion = obs.first.texto;
      horaObservacion = obs.first.fecha;
    } else if (obs.length > 1) {
      textoObservacion = obs.map((o) => '${_hora(o.fecha)} · ${o.texto}').join('\n');
    }
 
    return Actividad(
      id: tarea['id'] as String,
      titulo: tarea['titulo'] as String,
      tipo: tipo,
      fechaHora: DateTime.parse(tarea['fecha_programada'] as String),
      notas: (notas == null || notas.trim().isEmpty) ? null : notas,
      estado: estado,
      horaRegistroEstado: confirmacion == null ? null : DateTime.parse(confirmacion),
      observacionCuidador: textoObservacion,
      horaObservacion: horaObservacion,
      completadaPorRol: tarea['completada_por_rol'] as String?,
      horaOriginal: horaOriginal == null ? null : DateTime.parse(horaOriginal),
      esFlexible: (tarea['es_flexible'] as bool?) ?? false,
    );
  }
 
  /// "2026-10-04T09:30:00": fecha y hora local, sin zona horaria.
  static String _fechaHoraIso(DateTime f) {
    String d(int n, [int largo = 2]) => n.toString().padLeft(largo, '0');
    return '${d(f.year, 4)}-${d(f.month)}-${d(f.day)}T${d(f.hour)}:${d(f.minute)}:00';
  }
}
 
class _ObservacionCuidador {
  final String texto;
  final DateTime fecha;
 
  const _ObservacionCuidador({required this.texto, required this.fecha});
}