import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../models/actividad_cuidador.dart';
import '../models/servicio_activo.dart';
import '../services/cuidador_service.dart';
import 'actividades_cuidador_screen.dart';
import 'finalizar_servicio_screen.dart';
import '../widgets/tarjeta_contactos_emergencia.dart';

class DetalleServicioScreen extends StatefulWidget {
  final ServicioActivo servicio;

  /// Se mantiene para no romper otras pantallas
  /// que todavía puedan enviar una lista inicial.
  final List<ActividadCuidador> actividades;

  const DetalleServicioScreen({
    super.key,
    required this.servicio,
    this.actividades = const [],
  });

  @override
  State<DetalleServicioScreen> createState() =>
      _DetalleServicioScreenState();
}

class _DetalleServicioScreenState
    extends State<DetalleServicioScreen> {
  List<ActividadCuidador> _actividades = [];

  bool _cargandoActividades = true;
  String? _errorActividades;

  @override
  void initState() {
    super.initState();

    // Si otra pantalla envió actividades,
    // conservamos solamente las del adulto mayor
    // relacionado con este servicio.
    _actividades = widget.actividades
        .where(
          (actividad) =>
              actividad.adultoMayorId ==
              widget.servicio.adultoMayorId,
        )
        .toList();

    _cargarActividades();
  }

  // ============================================================
  // Cargar actividades reales
  // ============================================================

  Future<void> _cargarActividades({
    bool mostrarCarga = true,
  }) async {
    // Un servicio finalizado ya no debería tener acceso
    // operativo a las tareas del adulto mayor.
    if (widget.servicio.estaFinalizado) {
      if (!mounted) return;

      setState(() {
        _cargandoActividades = false;
        _errorActividades = null;
      });

      return;
    }

    if (mostrarCarga && mounted) {
      setState(() {
        _cargandoActividades = true;
        _errorActividades = null;
      });
    }

    try {
      final todas =
          await CuidadorService.listarActividades();

      // GET /tareas puede devolver actividades de más de un
      // adulto mayor cuando existen varios servicios vigentes.
      // Aquí dejamos solamente las correspondientes
      // a este servicio.
      final propias = todas
          .where(
            (actividad) =>
                actividad.adultoMayorId ==
                widget.servicio.adultoMayorId,
          )
          .toList();

      propias.sort(
        (a, b) => a.horaProgramada.compareTo(
          b.horaProgramada,
        ),
      );

      if (!mounted) return;

      setState(() {
        _actividades = propias;
        _cargandoActividades = false;
        _errorActividades = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _cargandoActividades = false;
        _errorActividades = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargandoActividades = false;
        _errorActividades =
            'No se pudieron cargar las actividades.';
      });
    }
  }

  // ============================================================
  // Resumen de actividades
  // ============================================================

  int get _realizadas {
    return _actividades
        .where(
          (actividad) =>
              actividad.estado ==
              EstadoActividadCuidador.realizada,
        )
        .length;
  }

  int get _pendientes {
    return _actividades
        .where(
          (actividad) =>
              actividad.estado ==
              EstadoActividadCuidador.pendiente,
        )
        .length;
  }

  int get _noRealizadas {
    return _actividades
        .where(
          (actividad) =>
              actividad.estado ==
              EstadoActividadCuidador.noRealizada,
        )
        .length;
  }

  int get _totalObservaciones {
    return _actividades.fold(
      0,
      (total, actividad) =>
          total + actividad.observaciones.length,
    );
  }

  List<MapEntry<String, ObservacionActividad>>
      get _observacionesRecientes {
    final lista =
        <MapEntry<String, ObservacionActividad>>[];

    for (final actividad in _actividades) {
      for (final observacion
          in actividad.observaciones) {
        lista.add(
          MapEntry(
            actividad.titulo,
            observacion,
          ),
        );
      }
    }

    lista.sort(
      (a, b) =>
          b.value.fecha.compareTo(a.value.fecha),
    );

    return lista;
  }

  // ============================================================
  // Ir a actividades
  // ============================================================

  Future<void> _irAActividades() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActividadesCuidadorScreen(
          actividades: _actividades,
          adultoMayorId:
              widget.servicio.adultoMayorId,
        ),
      ),
    );

    if (!mounted) return;

    // Al volver actualizamos el resumen.
    await _cargarActividades(
      mostrarCarga: false,
    );
  }

  // ============================================================
  // Finalizar servicio
  // ============================================================

  Future<void> _irAFinalizar() async {
    final finalizado =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FinalizarServicioScreen(
          servicio: widget.servicio,
          realizadas: _realizadas,
          pendientes: _pendientes,
          noRealizadas: _noRealizadas,
          observaciones: _totalObservaciones,
        ),
      ),
    );

    if (finalizado == true) {
      if (!mounted) return;

      setState(() {});

      Navigator.pop(
        context,
        widget.servicio,
      );
    }
  }

  // ============================================================
  // Formatos
  // ============================================================

  String _formatearFecha(
    DateTime fecha,
  ) {
    String d(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${fecha.year}-'
        '${d(fecha.month)}-'
        '${d(fecha.day)}';
  }

  String _formatearFechaHora(
    DateTime fecha,
  ) {
    String d(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${_formatearFecha(fecha)} '
        '${d(fecha.hour)}:'
        '${d(fecha.minute)}';
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final finalizado =
        widget.servicio.estaFinalizado;

    final String edadTexto;

    if (widget.servicio.edad != null) {
      edadTexto =
          '${widget.servicio.edad} años';
    } else {
      edadTexto =
          'Edad no disponible';
    }

    final telefono =
        widget.servicio.telefono?.trim();

    return Scaffold(
      backgroundColor:
          const Color(0xFFEAF4FB),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,

            children: [
              // ==================================================
              // Encabezado
              // ==================================================

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  8,
                  8,
                  16,
                  12,
                ),

                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                      ),

                      onPressed: () =>
                          Navigator.pop(
                        context,
                        widget.servicio,
                      ),
                    ),

                    const Text(
                      'Detalle del servicio',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // Adulto mayor
              // ==================================================

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Color(0xFFF6D998),

                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            widget.servicio
                                .nombreAdultoMayor,

                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                            height: 2,
                          ),

                          Text(
                            edadTexto,
                            style:
                                const TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.grey,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 12,
                                color:
                                    Colors.grey,
                              ),

                              const SizedBox(
                                width: 4,
                              ),

                              Expanded(
                                child: Text(
                                  telefono != null &&
                                          telefono
                                              .isNotEmpty
                                      ? telefono
                                      : 'Teléfono no disponible',

                                  style:
                                      const TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Row(
                            children: [
                              const Icon(
                                Icons.home_rounded,
                                size: 12,
                                color:
                                    Colors.grey,
                              ),

                              const SizedBox(
                                width: 4,
                              ),

                              Expanded(
                                child: Text(
                                  'Familiar responsable: '
                                  '${widget.servicio.familiarResponsable}',

                                  style:
                                      const TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    // ============================================
                    // Información importante
                    // ============================================

                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFFDF3D8,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons
                                    .warning_amber_rounded,
                                color:
                                    Colors.orange,
                                size: 18,
                              ),

                              SizedBox(
                                width: 6,
                              ),

                              Text(
                                'INFORMACIÓN IMPORTANTE',
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  color:
                                      Colors.orange,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            widget.servicio
                                .informacionImportante,

                            style:
                                const TextStyle(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ============================================
                    // Estado de carga de actividades
                    // ============================================

                    if (_cargandoActividades)
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          bottom: 12,
                        ),

                        child:
                            LinearProgressIndicator(),
                      ),

                    if (_errorActividades !=
                        null)
                      Container(
                        margin:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),

                        padding:
                            const EdgeInsets.all(
                          10,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.red.shade50,

                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color:
                                  Colors.red,
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child: Text(
                                _errorActividades!,
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            TextButton(
                              onPressed: () {
                                _cargarActividades();
                              },

                              child:
                                  const Text(
                                'Reintentar',
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ============================================
                    // Resumen de actividades
                    // ============================================
                    TarjetaContactosEmergencia(contactos: widget.servicio.contactos),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Resumen(
                          numero:
                              _realizadas,
                          etiqueta:
                              'Realizadas',
                          color:
                              Colors.green,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        _Resumen(
                          numero:
                              _pendientes,
                          etiqueta:
                              'Pendientes',
                          color:
                              Colors.orange,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        _Resumen(
                          numero:
                              _noRealizadas,
                          etiqueta:
                              'No realizadas',
                          color:
                              Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ============================================
                    // Período
                    // ============================================

                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Período',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    _DatoServicio(
                                  etiqueta:
                                      'INICIO',

                                  valor:
                                      _formatearFechaHora(
                                    widget.servicio
                                        .fechaInicio,
                                  ),
                                ),
                              ),

                              const Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color:
                                    Colors.grey,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child:
                                    _DatoServicio(
                                  etiqueta:
                                      'TÉRMINO',

                                  valor: widget
                                              .servicio
                                              .fechaTermino ==
                                          null
                                      ? 'En curso'
                                      : _formatearFechaHora(
                                          widget
                                              .servicio
                                              .fechaTermino!,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ============================================
                    // Observaciones
                    // ============================================

                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,

                        children: [
                          Row(
                            children: [
                              const Text(
                                'Observaciones',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const Spacer(),

                              if (_observacionesRecientes
                                  .isNotEmpty)
                                Text(
                                  '$_totalObservaciones en total',
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                            ],
                          ),

                          if (_observacionesRecientes
                              .isEmpty)
                            const Padding(
                              padding:
                                  EdgeInsets
                                      .symmetric(
                                vertical: 8,
                              ),

                              child: Text(
                                'Aún no hay observaciones registradas.',
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ),

                          for (final entry
                              in _observacionesRecientes
                                  .take(2)) ...[
                            const Divider(
                              height: 16,
                            ),

                            Text(
                              entry.key,

                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Colors.blue,
                                fontSize: 13,
                              ),
                            ),

                            Text(
                              _formatearFechaHora(
                                entry.value.fecha,
                              ),

                              style:
                                  const TextStyle(
                                fontSize: 11,
                                color:
                                    Colors.grey,
                              ),
                            ),

                            const SizedBox(
                              height: 2,
                            ),

                            Text(
                              entry.value.texto,
                              style:
                                  const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ============================================
                    // Ver actividades
                    // ============================================

                    ElevatedButton(
                      onPressed:
                          finalizado
                              ? null
                              : _irAActividades,

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.blue,

                        foregroundColor:
                            Colors.white,

                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            30,
                          ),
                        ),
                      ),

                      child: Text(
                        finalizado
                            ? 'Actividades no disponibles'
                            : 'Ver actividades →',
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ============================================
                    // Finalizar servicio
                    // ============================================

                    OutlinedButton(
                      onPressed:
                          finalizado
                              ? null
                              : _irAFinalizar,

                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            Colors.red,

                        side: BorderSide(
                          color:
                              finalizado
                                  ? Colors.grey
                                  : Colors.red,
                        ),

                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            30,
                          ),
                        ),
                      ),

                      child: Text(
                        finalizado
                            ? 'Servicio finalizado'
                            : 'Finalizar servicio',
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Resumen
// ============================================================

class _Resumen extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final Color color;

  const _Resumen({
    required this.numero,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color:
              color.withValues(
            alpha: 0.12,
          ),

          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),

        child: Column(
          children: [
            Text(
              '$numero',

              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
                color: color,
              ),
            ),

            Text(
              etiqueta,

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Dato del servicio
// ============================================================

class _DatoServicio extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoServicio({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          etiqueta,

          style:
              const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            letterSpacing: 0.4,
          ),
        ),

        const SizedBox(
          height: 2,
        ),

        Text(
          valor,

          style:
              const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}