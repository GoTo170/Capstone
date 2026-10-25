import 'dart:convert';

import '../../../core/api_client.dart';
import '../../auth/models/profesion_cuidador.dart';
import '../../familiar/services/marketplace_service.dart';
import '../../shared/services/notificaciones_service.dart';

import '../models/actividad_cuidador.dart';
import '../models/perfil_cuidador.dart';
import '../models/servicio_activo.dart';
import '../models/solicitud_servicio.dart';

class CuidadorService {
  // ============================================================
  // SOLICITUDES
  // ============================================================

  static Future<List<SolicitudServicio>>
      listarSolicitudes() async {
    final datos =
        await ApiClient.get(
          '/cuidador/solicitudes',
        ) as List<dynamic>;

    return datos.map((item) {
      final s =
          item as Map<String, dynamic>;

      final estadoTexto =
          s['estado'] as String;

      final estado =
          estadoTexto == 'aceptada'
              ? EstadoSolicitud.aceptada
              : estadoTexto == 'rechazada'
                  ? EstadoSolicitud.rechazada
                  : estadoTexto == 'finalizada'
                      ? EstadoSolicitud
                          .finalizada
                      : EstadoSolicitud.nueva;

      final resolucion =
          s['fecha_resolucion']
              as String?;

      final informacion =
          _nuloSiVacio(
        s['informacion_adicional']
            as String?,
      );

      return SolicitudServicio(
        id: s['id'] as String,

        nombreFamiliar:
            s['familiar_nombre']
                as String,

        nombreAdultoMayor:
            s['adulto_mayor_nombre']
                as String,

        fechaSolicitudTexto:
            _fechaLarga(
          _desdeUtc(
            s['fecha_solicitud']
                as String,
          ),
        ),

        fechaServicioTexto:
            _textoFechas(
          s['fecha_inicio']
              as String?,
          s['fecha_termino']
              as String?,
        ),

        horarioTexto:
            _textoHorario(
          s['hora_inicio']
              as String?,
          s['hora_termino']
              as String?,
        ),

        tipoServicio:
            MarketplaceService
                .nombreServicio(
          s['tipo_servicio']
              as String?,
        ),

        direccion:
            (s['direccion']
                    as String?) ??
                '—',

        informacion:
            informacion ??
                'Sin información adicional',

        mensaje:
            _nuloSiVacio(
          s['mensaje']
              as String?,
        ),

        estado: estado,

        motivoRechazo:
            _textoMotivo(
          s['motivo_rechazo']
              as String?,
          s['motivo_rechazo_detalle']
              as String?,
        ),

        fechaHistorialTexto:
            resolucion == null
                ? null
                : _textoRelativo(
                    DateTime.parse(
                      resolucion,
                    ),
                  ),
      );
    }).toList();
  }

  static Future<void> aceptarSolicitud(
    String id,
  ) async {
    await ApiClient.patch(
      '/solicitudes/$id/aceptar',
    );
  }

  static Future<void> rechazarSolicitud(
    String id,
    String motivoEtiqueta, {
    String? detalle,
  }) async {
    await ApiClient.patch(
      '/solicitudes/$id/rechazar',
      {
        'motivo_rechazo':
            _clavesMotivo[
                    motivoEtiqueta] ??
                'otros',

        'motivo_rechazo_detalle':
            detalle,
      },
    );
  }

  static const Map<String, String>
      _clavesMotivo = {
    'No tengo disponibilidad':
        'no_tengo_disponibilidad',

    'El horario no me acomoda':
        'horario_no_acomoda',

    'La ubicación está fuera de mi zona':
        'ubicacion_fuera_zona',

    'El tipo de cuidado no corresponde a mis servicios':
        'tipo_cuidado_no_corresponde',

    'Otro motivo': 'otros',
  };

  static const Map<String, String>
      _etiquetasMotivo = {
    'no_tengo_disponibilidad':
        'No tengo disponibilidad',

    'horario_no_acomoda':
        'El horario no me acomoda',

    'ubicacion_fuera_zona':
        'La ubicación está fuera de mi zona',

    'tipo_cuidado_no_corresponde':
        'El tipo de cuidado no corresponde a mis servicios',

    'otros': 'Otro motivo',
  };

  static String? _textoMotivo(
    String? clave,
    String? detalle,
  ) {
    if (clave == null) {
      return null;
    }

    if (clave == 'otros' &&
        detalle != null &&
        detalle.trim().isNotEmpty) {
      return detalle;
    }

    return _etiquetasMotivo[clave] ??
        clave;
  }

  // ============================================================
  // SERVICIOS
  // ============================================================

  static Future<List<ServicioActivo>>
      listarServicios() async {
    final datos =
        await ApiClient.get(
          '/cuidador/solicitudes',
        ) as List<dynamic>;

    final servicios =
        <ServicioActivo>[];

    for (final item in datos) {
      final s =
          item as Map<String, dynamic>;

      final estado =
          s['estado'] as String?;

      if (estado != 'aceptada' &&
          estado != 'finalizada') {
        continue;
      }

      final fechaInicio =
          _combinarFechaHoraServicio(
        s['fecha_inicio']
            as String?,
        s['hora_inicio']
            as String?,
      );

      if (fechaInicio == null) {
        continue;
      }

      final fechaTermino =
          _combinarFechaHoraServicio(
        s['fecha_termino']
            as String?,
        s['hora_termino']
            as String?,
      );

      final puedeVerInformacion =
          s['puede_ver_informacion_sensible'] ==
              true;

      servicios.add(
        ServicioActivo(
          id:
              s['id'] as String,

          adultoMayorId:
              s['adulto_mayor_id']
                  as String,

          nombreAdultoMayor:
              (s['adulto_mayor_nombre']
                      as String?) ??
                  'Adulto mayor',

          edad:
              (s['adulto_mayor_edad']
                      as num?)
                  ?.toInt(),

          telefono:
              s['adulto_mayor_telefono']
                  as String?,

          familiarResponsable:
              (s['familiar_nombre']
                      as String?) ??
                  'Familiar',

          fechaInicio:
              fechaInicio,

          fechaTermino:
              fechaTermino,

          informacionImportante:
              _construirInformacionImportante(
            s,
            puedeVerInformacion,
          ),

          finalizadoManualmente:
              estado ==
                  'finalizada',

          vigente: puedeVerInformacion,
          contactos: _aContactos(s['contactos_emergencia'] as List<dynamic>?),
        ),
        
      );
      
    }

    servicios.sort(
      (a, b) =>
          b.fechaInicio.compareTo(
        a.fechaInicio,
      ),
    );

    return servicios;
  }

    static List<ContactoEmergenciaServicio> _aContactos(List<dynamic>? datos) {
    if (datos == null) return const [];

    return datos.map((item) {
      final c = item as Map<String, dynamic>;
      return ContactoEmergenciaServicio(
        nombre: c['nombre'] as String,
        telefono: c['telefono'] as String,
        parentesco: _nuloSiVacio(c['parentesco'] as String?),
      );
    }).toList();
  }

  static DateTime?
      _combinarFechaHoraServicio(
    String? fecha,
    String? hora,
  ) {
    if (fecha == null ||
        fecha.trim().isEmpty) {
      return null;
    }

    final horaNormalizada =
        hora == null ||
                hora.trim().isEmpty
            ? '00:00:00'
            : hora.trim();

    return DateTime.tryParse(
      '${fecha.trim()}T$horaNormalizada',
    );
  }

  static String
      _construirInformacionImportante(
    Map<String, dynamic> datos,
    bool puedeVer,
  ) {
    if (!puedeVer) {
      if (datos['estado'] ==
          'finalizada') {
        return 'La información personal y de cuidado del adulto mayor ya no está disponible porque el servicio finalizó.';
      }

      return 'La información importante del adulto mayor estará disponible durante el período autorizado del servicio.';
    }

    final informacion =
        <String>[];

    void agregar(
      String titulo,
      dynamic valor,
    ) {
      if (valor == null) {
        return;
      }

      final texto =
          valor.toString().trim();

      if (texto.isNotEmpty) {
        informacion.add(
          '$titulo: $texto',
        );
      }
    }

    agregar(
      'Enfermedades',
      datos['enfermedades'],
    );

    agregar(
      'Alergias a medicamentos',
      datos['alergia_medicamentos'],
    );

    agregar(
      'Alergias alimentarias',
      datos['alergia_alimentos'],
    );

    agregar(
      'Intolerancias alimentarias',
      datos[
          'intolerancia_alimentaria'],
    );

    agregar(
      'Información adicional del servicio',
      datos[
          'informacion_adicional'],
    );

    if (informacion.isEmpty) {
      return 'Sin información importante registrada.';
    }

    return informacion.join('\n');
  }

  static Future<void> finalizarServicio(
    String servicioId,
  ) async {
    await ApiClient.patch(
      '/solicitudes/$servicioId/finalizar',
    );
  }

  // ============================================================
  // ACTIVIDADES
  // ============================================================

  static Future<List<ActividadCuidador>> listarActividades() async {
    final resultados = await Future.wait([
      ApiClient.get('/tareas'),
      ApiClient.get('/bitacora'),
    ]);
 
    final tareas = resultados[0] as List<dynamic>;
    final bitacora = resultados[1] as List<dynamic>;
 
    final observacionesPorTarea = <String, List<ObservacionActividad>>{};
 
    for (final item in bitacora) {
      final registro = item as Map<String, dynamic>;
      final tareaId = registro['tarea_id'] as String;
 
      observacionesPorTarea.putIfAbsent(tareaId, () => []).add(
            ObservacionActividad(
              // La bitácora la fecha la base de datos, en hora UTC: aquí SÍ se convierte.
              fecha: _desdeUtc(registro['fecha_registro'] as String),
              texto: (registro['observacion'] as String?) ?? '',
            ),
          );
    }
 
    for (final lista in observacionesPorTarea.values) {
      lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    }
 
    final actividades = tareas.map((item) {
      final tarea = item as Map<String, dynamic>;
      final id = tarea['id'] as String;
      final fechaConfirmacion = tarea['fecha_confirmacion'] as String?;
 
      return ActividadCuidador(
        id: id,
        adultoMayorId: tarea['adulto_mayor_id'] as String,
        titulo: (tarea['titulo'] as String?) ?? 'Actividad',
        descripcion: _nuloSiVacio(tarea['descripcion'] as String?),
        // La hora programada y la de confirmación se guardan en hora local, sin
        // zona: se leen tal cual (NO se convierten desde UTC, o se corren).
        horaProgramada: DateTime.parse(tarea['fecha_programada'] as String),
        tipo: _tipoActividadDesdeCategoria(tarea['categoria'] as String?),
        estado: _estadoActividadDesdeBackend(tarea['estado'] as String?),
        horaRegistroEstado: fechaConfirmacion == null ? null : DateTime.parse(fechaConfirmacion),
        observaciones: observacionesPorTarea[id] ?? [],
      );
    }).toList();
 
    actividades.sort((a, b) => a.horaProgramada.compareTo(b.horaProgramada));
 
    return actividades;
  }
 
  static Future<DateTime?> actualizarEstadoActividad(
    String tareaId,
    EstadoActividadCuidador estado,
  ) async {
    final datos = await ApiClient.patch(
      '/tareas/$tareaId/estado',
      {
        'estado': _estadoActividadParaBackend(estado),
      },
    ) as Map<String, dynamic>;
 
    final fecha = datos['fecha_confirmacion'] as String?;
 
    if (fecha == null) {
      return null;
    }
 
    // El servidor la guarda con su hora local, sin zona: se lee tal cual.
    return DateTime.parse(fecha);
  }

  static Future<ObservacionActividad>
      agregarObservacionActividad(
    String tareaId,
    String observacion,
  ) async {
    final datos =
        await ApiClient.post(
      '/bitacora',
      {
        'tarea_id': tareaId,
        'observacion':
            observacion.trim(),
        'tipo_incidencia':
            'general',
      },
    ) as Map<String, dynamic>;

    return ObservacionActividad(
      fecha:
          _desdeUtc(
        datos['fecha_registro']
            as String,
      ),

      texto:
          datos['observacion']
              as String,
    );
  }

  static EstadoActividadCuidador
      _estadoActividadDesdeBackend(
    String? estado,
  ) {
    switch (estado) {
      case 'realizada':
        return EstadoActividadCuidador
            .realizada;

      case 'no_realizada':
        return EstadoActividadCuidador
            .noRealizada;

      default:
        return EstadoActividadCuidador
            .pendiente;
    }
  }

  static String
      _estadoActividadParaBackend(
    EstadoActividadCuidador estado,
  ) {
    switch (estado) {
      case EstadoActividadCuidador
            .pendiente:
        return 'pendiente';

      case EstadoActividadCuidador
            .realizada:
        return 'realizada';

      case EstadoActividadCuidador
            .noRealizada:
        return 'no_realizada';
    }
  }

  static TipoActividadCuidador
      _tipoActividadDesdeCategoria(
    String? categoria,
  ) {
    final texto =
        (categoria ?? '')
            .trim()
            .toLowerCase()
            .replaceAll(
              'á',
              'a',
            )
            .replaceAll(
              'é',
              'e',
            )
            .replaceAll(
              'í',
              'i',
            )
            .replaceAll(
              'ó',
              'o',
            )
            .replaceAll(
              'ú',
              'u',
            );

    if (texto.contains(
          'medicamento',
        ) ||
        texto.contains(
          'medicacion',
        )) {
      return TipoActividadCuidador
          .medicamento;
    }

    if (texto.contains(
          'comida',
        ) ||
        texto.contains(
          'alimentacion',
        ) ||
        texto.contains(
          'desayuno',
        ) ||
        texto.contains(
          'almuerzo',
        ) ||
        texto.contains(
          'cena',
        )) {
      return TipoActividadCuidador
          .comida;
    }

    if (texto.contains(
          'higiene',
        ) ||
        texto.contains(
          'aseo',
        )) {
      return TipoActividadCuidador
          .higiene;
    }

    if (texto.contains(
          'cita',
        ) ||
        texto.contains(
          'medica',
        ) ||
        texto.contains(
          'control',
        )) {
      return TipoActividadCuidador
          .citaMedica;
    }

    if (texto.contains(
      'evento',
    )) {
      return TipoActividadCuidador
          .evento;
    }

    if (texto.contains(
      'mascota',
    )) {
      return TipoActividadCuidador
          .mascota;
    }

    if (texto.contains(
      'recordatorio',
    )) {
      return TipoActividadCuidador
          .recordatorio;
    }

    return TipoActividadCuidador
        .otro;
  }

  // ============================================================
  // PERFIL
  // ============================================================

  static const String
      _marcaPuertasAdentro =
      'Cuidado puertas adentro';

  static Future<PerfilCuidadorData>
      miPerfil() async {
    final datos =
        await ApiClient.get(
          '/cuidador/mi-perfil',
        ) as Map<String, dynamic>;

    return _aPerfil(datos);
  }

  static Future<PerfilCuidadorData>
      guardarPerfil(
    PerfilCuidadorData perfil,
  ) async {
    final datos =
        await ApiClient.patch(
      '/cuidador/mi-perfil',
      {
        'telefono':
            perfil.telefono.trim(),

        'descripcion':
            perfil
                .descripcionPersonal
                .trim(),

        'servicios_ofrecidos':
            perfil
                .especialidadesSeleccionadas
                .join('\n'),
      },
    ) as Map<String, dynamic>;

    return _aPerfil(datos);
  }

  static Future<PerfilCuidadorData>
      subirFoto(
    List<int> bytes,
  ) async {
    final datos =
        await ApiClient.put(
      '/cuidador/mi-foto',
      {
        'imagen_base64':
            base64Encode(bytes),
      },
    ) as Map<String, dynamic>;

    return _aPerfil(datos);
  }

  static Future<PerfilCuidadorData>
      quitarFoto() async {
    final datos =
        await ApiClient.delete(
          '/cuidador/mi-foto',
        ) as Map<String, dynamic>;

    return _aPerfil(datos);
  }

  static Future<PerfilCuidadorData>
      cambiarPuertasAdentro(
    bool activar,
  ) async {
    final datos =
        await ApiClient.post(
      '/cuidador/puertas-adentro',
      {
        'activar': activar,
      },
    ) as Map<String, dynamic>;

    return _aPerfil(datos);
  }

  static Future<NotificacionApp?>
      ultimoAvisoPuertasAdentro() async {
    final lista =
        await NotificacionesService
            .listar();

    for (final n in lista) {
      final esAviso =
          n.tipo ==
                  'puertas_adentro_aprobada' ||
              n.tipo ==
                  'puertas_adentro_rechazada';

      if (esAviso && !n.leida) {
        return n;
      }
    }

    return null;
  }

  static PerfilCuidadorData _aPerfil(
    Map<String, dynamic> d,
  ) {
    final profesionNombre =
        (d['profesion']
                as String?) ??
            '';

    ProfesionCuidador? info;

    for (final p
        in catalogoProfesiones) {
      if (p.nombre ==
          profesionNombre) {
        info = p;
        break;
      }
    }

    final lineas =
        ((d['servicios_ofrecidos']
                    as String?) ??
                '')
            .split('\n')
            .map(
              (l) => l.trim(),
            )
            .where(
              (l) =>
                  l.isNotEmpty,
            )
            .toList();

    final experiencia =
        d['experiencia']
            as String?;

    final anios =
        int.tryParse(
          RegExp(
            r'\d+',
          )
                  .firstMatch(
                    experiencia ??
                        '',
                  )
                  ?.group(0) ??
              '',
        ) ??
        0;

    final fotoUrl =
        d['foto_url']
            as String?;

    return PerfilCuidadorData(
      nombre:
          d['nombre'] as String,

      apellido:
          (d['apellido']
                  as String?) ??
              '',

      correo:
          (d['email']
                  as String?) ??
              '',

      profesionId:
          info?.id ?? '',

      profesionNombre:
          profesionNombre.isEmpty
              ? 'Sin profesión indicada'
              : profesionNombre,

      experienciaAnios:
          anios,

      telefono:
          (d['telefono']
                  as String?) ??
              '',

      descripcionPersonal:
          (d['descripcion']
                  as String?) ??
              '',

      especialidadesSeleccionadas:
          lineas
              .where(
                (l) =>
                    l !=
                    _marcaPuertasAdentro,
              )
              .toSet(),

      tieneFotoPerfil:
          fotoUrl != null &&
              fotoUrl.isNotEmpty,

      fotoUrl: fotoUrl,

      puertasAdentroActivo:
          lineas.contains(
        _marcaPuertasAdentro,
      ),

      puertasAdentroPendienteAprobacion:
          (d['puertas_adentro_pendiente']
                  as bool?) ??
              false,
    );
  }

  // ============================================================
  // RESEÑAS
  // ============================================================

  static Future<List<Valoracion>>
      listarValoraciones() async {
    final datos =
        await ApiClient.get(
          '/cuidador/valoraciones',
        ) as List<dynamic>;

    return datos.map((item) {
      final v =
          item
              as Map<String, dynamic>;

      return Valoracion(
        id:
            v['id'] as String,

        autor:
            'Anónimo',

        estrellas:
            v['puntuacion']
                as int,

        comentario:
            (v['comentario']
                    as String?) ??
                '',

        fecha:
            _desdeUtc(
          v['fecha'] as String,
        ),

        solicitudRevisionEnviada:
            v['reportada']
                as bool,

        motivoRevision:
            v['motivo_reporte']
                as String?,
      );
    }).toList();
  }

  static Future<void>
      reportarValoracion(
    String id,
    String motivo,
  ) async {
    await ApiClient.post(
      '/valoraciones/$id/reportar',
      {
        'motivo_reporte':
            motivo,
      },
    );
  }

  // ============================================================
  // FORMATOS
  // ============================================================

  static const List<String>
      _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String? _nuloSiVacio(
    String? texto,
  ) {
    final limpio =
        texto?.trim();

    return limpio == null ||
            limpio.isEmpty
        ? null
        : limpio;
  }

  static DateTime _desdeUtc(
    String texto,
  ) {
    final t =
        DateTime.parse(texto);

    if (t.isUtc) {
      return t.toLocal();
    }

    return DateTime.utc(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute,
      t.second,
      t.millisecond,
      t.microsecond,
    ).toLocal();
  }

  static String _fechaLarga(
    DateTime f,
  ) =>
      '${f.day} de ${_meses[f.month - 1]} de ${f.year}';

  static String _textoRelativo(
    DateTime f,
  ) {
    final ahora =
        DateTime.now();

    if (f.year == ahora.year &&
        f.month == ahora.month &&
        f.day == ahora.day) {
      return 'Hoy';
    }

    return '${f.day} de ${_meses[f.month - 1]}';
  }

  static String _fechaCorta(
    String iso,
  ) {
    final partes =
        iso.split('-');

    return partes.length == 3
        ? '${partes[2]}-${partes[1]}-${partes[0]}'
        : iso;
  }

  static String _textoFechas(
    String? inicio,
    String? termino,
  ) {
    if (inicio == null) {
      return '—';
    }

    if (termino == null ||
        termino == inicio) {
      return _fechaCorta(
        inicio,
      );
    }

    return '${_fechaCorta(inicio)} → ${_fechaCorta(termino)}';
  }

  static String _horaCorta(
    String hora,
  ) =>
      hora.length >= 5
          ? hora.substring(
              0,
              5,
            )
          : hora;

  static String _textoHorario(
    String? inicio,
    String? termino,
  ) {
    if (inicio == null ||
        termino == null) {
      return '—';
    }

    return '${_horaCorta(inicio)}-${_horaCorta(termino)}';
  }
}