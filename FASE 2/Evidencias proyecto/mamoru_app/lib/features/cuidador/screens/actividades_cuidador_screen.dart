import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../models/actividad_cuidador.dart';
import '../services/cuidador_service.dart';
import '../widgets/cuidador_bottom_nav.dart';
import 'agregar_observacion_screen.dart';

class ActividadesCuidadorScreen extends StatefulWidget {
  final List<ActividadCuidador> actividades;

  /// Si viene null, muestra las actividades de todos los adultos mayores
  /// para los que el cuidador tiene un servicio vigente.
  ///
  /// Si viene un ID, muestra solamente las actividades de ese adulto mayor.
  final String? adultoMayorId;

  const ActividadesCuidadorScreen({
    super.key,
    this.actividades = const [],
    this.adultoMayorId,
  });

  @override
  State<ActividadesCuidadorScreen> createState() =>
      _ActividadesCuidadorScreenState();
}

enum _Filtro {
  todas,
  pendientes,
  realizadas,
}

class _ActividadesCuidadorScreenState
    extends State<ActividadesCuidadorScreen> {
  _Filtro _filtro = _Filtro.todas;

  String? _idExpandido;
  String? _idGuardando;

  List<ActividadCuidador> _actividades = [];

  bool _cargando = true;
  String? _error;

  String _nombreCuidador = 'Cuidador/a';

  @override
  void initState() {
    super.initState();

    // Si otra pantalla entregó actividades,
    // se muestran temporalmente mientras se consulta el backend.
    _actividades = List<ActividadCuidador>.from(
      widget.actividades,
    );

    _cargarActividades();
    _cargarNombreCuidador();
  }

  // ============================================================
  // Nombre del cuidador
  // ============================================================

  Future<void> _cargarNombreCuidador() async {
    try {
      final perfil = await CuidadorService.miPerfil();

      if (!mounted) return;

      if (perfil.nombre.trim().isNotEmpty) {
        setState(() {
          _nombreCuidador = perfil.nombre.trim();
        });
      }
    } catch (_) {
      // Si falla solamente el nombre, la pantalla puede seguir funcionando.
    }
  }

  // ============================================================
  // Cargar actividades desde FastAPI
  // ============================================================

  Future<void> _cargarActividades({
    bool mostrarCarga = true,
  }) async {
    if (mostrarCarga && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final actividades =
          await CuidadorService.listarActividades();

      if (!mounted) return;

      setState(() {
        _actividades = actividades;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar las actividades.';
      });
    }
  }

  // ============================================================
  // Filtros
  // ============================================================

  bool _esHoy(DateTime fecha) {
    final hoy = DateTime.now();

    return fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
  }

  List<ActividadCuidador> get _actividadesHoy {
    final lista = _actividades.where((actividad) {
      // Solo mostramos las actividades del día actual.
      if (!_esHoy(actividad.horaProgramada)) {
        return false;
      }

      // Si entramos desde el detalle de un servicio,
      // mostramos solo las actividades de ese adulto mayor.
      if (widget.adultoMayorId != null &&
          actividad.adultoMayorId != widget.adultoMayorId) {
        return false;
      }

      return true;
    }).toList();

    lista.sort(
      (a, b) => a.horaProgramada.compareTo(
        b.horaProgramada,
      ),
    );

    return lista;
  }

  List<ActividadCuidador> get _filtradas {
    switch (_filtro) {
      case _Filtro.todas:
        return _actividadesHoy;

      case _Filtro.pendientes:
        return _actividadesHoy
            .where(
              (actividad) =>
                  actividad.estado ==
                  EstadoActividadCuidador.pendiente,
            )
            .toList();

      case _Filtro.realizadas:
        return _actividadesHoy
            .where(
              (actividad) =>
                  actividad.estado ==
                  EstadoActividadCuidador.realizada,
            )
            .toList();
    }
  }

  // ============================================================
  // Fecha
  // ============================================================

  String get _fechaFormateada {
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    const meses = [
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

    final ahora = DateTime.now();

    return '${dias[ahora.weekday - 1]}, '
        '${ahora.day} de '
        '${meses[ahora.month - 1]}';
  }

  // ============================================================
  // Cambiar estado
  // ============================================================

  Future<void> _cambiarEstado(
    ActividadCuidador actividad,
    EstadoActividadCuidador nuevoEstado,
  ) async {
    // Evita guardar dos veces si el usuario presiona rápidamente.
    if (_idGuardando == actividad.id) {
      return;
    }

    // Si la actividad ya tenía un estado,
    // pedimos confirmación antes de modificarlo.
    if (actividad.estado != EstadoActividadCuidador.pendiente) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cambiar estado'),
          content: Text(
            'Esta actividad ya está marcada como '
            '"${_etiquetaEstado(actividad.estado)}". '
            '¿Seguro que quieres cambiarla a '
            '"${_etiquetaEstado(nuevoEstado)}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirmar != true) {
        return;
      }
    }

    setState(() {
      _idGuardando = actividad.id;
    });

    try {
      // El estado se guarda primero en el backend.
      final fechaConfirmacion =
          await CuidadorService.actualizarEstadoActividad(
        actividad.id,
        nuevoEstado,
      );

      if (!mounted) return;

      setState(() {
        actividad.estado = nuevoEstado;

        actividad.horaRegistroEstado =
            fechaConfirmacion ?? DateTime.now();

        _idExpandido = null;
        _idGuardando = null;
      });

      // Si una actividad no se realizó,
      // se abre el formulario de observación.
      if (nuevoEstado == EstadoActividadCuidador.noRealizada) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AgregarObservacionScreen(
              actividad: actividad,
            ),
          ),
        );

        if (!mounted) return;

        setState(() {});
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _idGuardando = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _idGuardando = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar la actividad.',
          ),
        ),
      );
    }
  }

  String _etiquetaEstado(
    EstadoActividadCuidador estado,
  ) {
    switch (estado) {
      case EstadoActividadCuidador.pendiente:
        return 'Pendiente';

      case EstadoActividadCuidador.realizada:
        return 'Realizada';

      case EstadoActividadCuidador.noRealizada:
        return 'No realizada';
    }
  }

  // ============================================================
  // Observaciones
  // ============================================================

  Future<void> _abrirObservacion(
    ActividadCuidador actividad,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarObservacionScreen(
          actividad: actividad,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final todas = _actividadesHoy.length;

    final pendientes = _actividadesHoy
        .where(
          (actividad) =>
              actividad.estado ==
              EstadoActividadCuidador.pendiente,
        )
        .length;

    final realizadas = _actividadesHoy
        .where(
          (actividad) =>
              actividad.estado ==
              EstadoActividadCuidador.realizada,
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),

      bottomNavigationBar: CuidadorBottomNav(
        seleccionada: PestanaCuidador.actividades,
        nombreCuidador: _nombreCuidador,
        servicio: null,
        actividades: _actividades,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // Encabezado
              // ==================================================

              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(
                      context,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actividades',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _fechaFormateada,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ==================================================
              // Filtros
              // ==================================================

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChipFiltro(
                      texto: 'Todas ($todas)',
                      seleccionado:
                          _filtro == _Filtro.todas,
                      onTap: () {
                        setState(() {
                          _filtro = _Filtro.todas;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _ChipFiltro(
                      texto: 'Pendientes ($pendientes)',
                      seleccionado:
                          _filtro == _Filtro.pendientes,
                      color: Colors.orange,
                      onTap: () {
                        setState(() {
                          _filtro = _Filtro.pendientes;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _ChipFiltro(
                      texto: 'Realizadas ($realizadas)',
                      seleccionado:
                          _filtro == _Filtro.realizadas,
                      color: Colors.green,
                      onTap: () {
                        setState(() {
                          _filtro = _Filtro.realizadas;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // Lista
              // ==================================================

              Expanded(
                child: _construirLista(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Lista
  // ============================================================

  Widget _construirLista() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 42,
                color: Colors.grey,
              ),
              const SizedBox(height: 10),
              const Text(
                'No pudimos cargar las actividades',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _cargarActividades();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtradas.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _cargarActividades(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                'No hay actividades para este filtro.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargarActividades(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filtradas.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final actividad = _filtradas[index];

          return _TarjetaActividadCuidador(
            actividad: actividad,
            expandido:
                _idExpandido == actividad.id,

            onTapRegistrar: () {
              setState(() {
                _idExpandido = actividad.id;
              });
            },

            onCerrar: () {
              setState(() {
                _idExpandido = null;
              });
            },

            onMarcarRealizada: () =>
                _cambiarEstado(
              actividad,
              EstadoActividadCuidador.realizada,
            ),

            onMarcarNoRealizada: () =>
                _cambiarEstado(
              actividad,
              EstadoActividadCuidador.noRealizada,
            ),

            onVerAgregarObservacion: () =>
                _abrirObservacion(
              actividad,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Chip de filtro
// ============================================================

class _ChipFiltro extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.color = Colors.pink,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: seleccionado
              ? color
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            color: seleccionado
                ? Colors.white
                : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Tarjeta de actividad
// ============================================================

class _TarjetaActividadCuidador extends StatelessWidget {
  final ActividadCuidador actividad;
  final bool expandido;

  final VoidCallback onTapRegistrar;
  final VoidCallback onCerrar;
  final VoidCallback onMarcarRealizada;
  final VoidCallback onMarcarNoRealizada;
  final VoidCallback onVerAgregarObservacion;

  const _TarjetaActividadCuidador({
    required this.actividad,
    required this.expandido,
    required this.onTapRegistrar,
    required this.onCerrar,
    required this.onMarcarRealizada,
    required this.onMarcarNoRealizada,
    required this.onVerAgregarObservacion,
  });

  String _formatearHora(DateTime fecha) {
    String d(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${d(fecha.hour)}:${d(fecha.minute)}';
  }

  Color get _colorBorde {
    switch (actividad.estado) {
      case EstadoActividadCuidador.realizada:
        return Colors.green.shade200;

      case EstadoActividadCuidador.noRealizada:
        return Colors.red.shade200;

      case EstadoActividadCuidador.pendiente:
        return Colors.orange.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneObservaciones =
        actividad.observaciones.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _colorBorde,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ====================================================
          // Título, descripción y estado
          // ====================================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(
                  right: 10,
                ),
                decoration: BoxDecoration(
                  color: actividad.tipo.color.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  actividad.tipo.icono,
                  size: 20,
                  color: actividad.tipo.color,
                ),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      actividad.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (actividad.descripcion != null &&
                        actividad.descripcion!
                            .trim()
                            .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2,
                        ),
                        child: Text(
                          actividad.descripcion!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              _EtiquetaEstado(
                estado: actividad.estado,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ====================================================
          // Hora programada
          // ====================================================

          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                _formatearHora(
                  actividad.horaProgramada,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          // ====================================================
          // Hora de confirmación
          // ====================================================

          if (actividad.estado !=
                  EstadoActividadCuidador.pendiente &&
              actividad.horaRegistroEstado != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  actividad.estado ==
                          EstadoActividadCuidador.realizada
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 14,
                  color: actividad.estado ==
                          EstadoActividadCuidador.realizada
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_etiquetaCorta(actividad.estado)} '
                    'a las '
                    '${_formatearHora(actividad.horaRegistroEstado!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: actividad.estado ==
                              EstadoActividadCuidador.realizada
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ====================================================
          // Observaciones
          // ====================================================

          if (tieneObservaciones) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: Colors.deepOrange,
                ),
                SizedBox(width: 4),
                Text(
                  'Con observación',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // ====================================================
          // Registrar estado
          // ====================================================

          if (actividad.estado ==
              EstadoActividadCuidador.pendiente) ...[
            if (!expandido)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onTapRegistrar,
                  child: const Text(
                    'Registrar estado',
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMarcarRealizada,
                      icon: const Icon(
                        Icons.check,
                        size: 16,
                      ),
                      label: const Text(
                        'Realizada',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMarcarNoRealizada,
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                      ),
                      label: const Text(
                        'No realizada',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: onCerrar,
                  ),
                ],
              ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onVerAgregarObservacion,
                icon: Icon(
                  tieneObservaciones
                      ? Icons.visibility_outlined
                      : Icons.add,
                  size: 18,
                  color: Colors.deepPurple,
                ),
                label: Text(
                  tieneObservaciones
                      ? 'Ver / agregar observación'
                      : '+ Agregar observación',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.deepPurple.shade100,
                  ),
                  backgroundColor:
                      Colors.deepPurple.withValues(
                    alpha: 0.05,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _etiquetaCorta(
    EstadoActividadCuidador estado,
  ) {
    if (estado ==
        EstadoActividadCuidador.realizada) {
      return 'Realizada';
    }

    return 'Marcada como no realizada';
  }
}

// ============================================================
// Estado visual
// ============================================================

class _EtiquetaEstado extends StatelessWidget {
  final EstadoActividadCuidador estado;

  const _EtiquetaEstado({
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    late final String texto;
    late final Color color;
    late final IconData icono;

    switch (estado) {
      case EstadoActividadCuidador.pendiente:
        texto = 'Pendiente';
        color = Colors.orange;
        icono = Icons.hourglass_top;
        break;

      case EstadoActividadCuidador.realizada:
        texto = 'Realizada';
        color = Colors.green;
        icono = Icons.check_circle;
        break;

      case EstadoActividadCuidador.noRealizada:
        texto = 'No realizada';
        color = Colors.red;
        icono = Icons.cancel;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icono,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}