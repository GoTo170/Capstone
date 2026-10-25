import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../models/actividad_cuidador.dart';
import '../models/servicio_activo.dart';
import '../services/cuidador_service.dart';
import '../widgets/cuidador_bottom_nav.dart';
import 'detalle_servicio_screen.dart';

class ServiciosCuidadorScreen
    extends StatefulWidget {
  const ServiciosCuidadorScreen({
    super.key,
  });

  @override
  State<ServiciosCuidadorScreen>
      createState() =>
          _ServiciosCuidadorScreenState();
}

class _ServiciosCuidadorScreenState
    extends State<ServiciosCuidadorScreen> {
  List<ServicioActivo> _servicios =
      [];

  final List<ActividadCuidador>
      _actividades = [];

  bool _cargando = true;

  String? _error;

  String _nombreCuidador =
      'Cuidador/a';

  @override
  void initState() {
    super.initState();

    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final servicios =
          await CuidadorService
              .listarServicios();

      String nombre =
          _nombreCuidador;

      try {
        final perfil =
            await CuidadorService
                .miPerfil();

        if (perfil.nombre
            .trim()
            .isNotEmpty) {
          nombre =
              perfil.nombre.trim();
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        _servicios =
            servicios;

        _nombreCuidador =
            nombre;

        _cargando =
            false;

        _error =
            null;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cargando =
            false;

        _error =
            e.mensaje;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cargando =
            false;

        _error =
            'No se pudieron cargar los servicios.';
      });
    }
  }

  Future<void> _abrirDetalle(
    ServicioActivo servicio,
  ) async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
            DetalleServicioScreen(
          servicio:
              servicio,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _cargarDatos();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final actuales =
        _servicios
            .where(
              (s) =>
                  !s.estaFinalizado,
            )
            .toList();

    final anteriores =
        _servicios
            .where(
              (s) =>
                  s.estaFinalizado,
            )
            .toList();

    final total =
        actuales.length +
            anteriores.length;

    final ServicioActivo?
        servicioActual =
        actuales.isNotEmpty
            ? actuales.first
            : null;

    return Scaffold(
      backgroundColor:
          const Color(
        0xFFFFF7F5,
      ),

      bottomNavigationBar:
          CuidadorBottomNav(
        seleccionada:
            PestanaCuidador
                .servicios,

        nombreCuidador:
            _nombreCuidador,

        servicio:
            servicioActual,

        actividades:
            _actividades,
      ),

      body: SafeArea(
        child:
            _construirContenido(
          actuales,
          anteriores,
          total,
        ),
      ),
    );
  }

  Widget _construirContenido(
    List<ServicioActivo> actuales,
    List<ServicioActivo> anteriores,
    int total,
  ) {
    if (_cargando) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline,
                size: 46,
                color: Colors.red,
              ),

              const SizedBox(
                height: 12,
              ),

              const Text(
                'No pudimos cargar tus servicios',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 16,
              ),

              ElevatedButton.icon(
                onPressed:
                    _cargarDatos,

                icon:
                    const Icon(
                  Icons.refresh,
                ),

                label:
                    const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _cargarDatos,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          16,
        ),

        children: [
          const Text(
            'Mis servicios',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            total == 1
                ? '1 servicio en total'
                : '$total servicios en total',
            style:
                const TextStyle(
              color: Colors.blue,
              fontSize: 13,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          if (total == 0)
            Container(
              padding:
                  const EdgeInsets.all(
                30,
              ),

              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child:
                  const Column(
                children: [
                  Icon(
                    Icons
                        .medical_services_outlined,
                    size: 46,
                    color:
                        Colors.grey,
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    'Aún no tienes servicios',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                  SizedBox(
                    height: 6,
                  ),
                  Text(
                    'Los servicios que aceptes aparecerán aquí.',
                    textAlign:
                        TextAlign
                            .center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          if (actuales
              .isNotEmpty) ...[
            const _EtiquetaGrupo(
              texto:
                  'ACTUALES',
            ),

            const SizedBox(
              height: 10,
            ),

            for (final servicio
                in actuales)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),

                child:
                    _TarjetaServicio(
                  servicio:
                      servicio,

                  esActual:
                      true,

                  onVer: () =>
                      _abrirDetalle(
                    servicio,
                  ),
                ),
              ),
          ],

          if (anteriores
              .isNotEmpty) ...[
            const SizedBox(
              height: 8,
            ),

            const _EtiquetaGrupo(
              texto:
                  'ANTERIORES',
            ),

            const SizedBox(
              height: 10,
            ),

            for (final servicio
                in anteriores)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),

                child:
                    _TarjetaServicio(
                  servicio:
                      servicio,

                  esActual:
                      false,

                  onVer: () =>
                      _abrirDetalle(
                    servicio,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EtiquetaGrupo
    extends StatelessWidget {
  final String texto;

  const _EtiquetaGrupo({
    required this.texto,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      texto,
      style:
          const TextStyle(
        fontSize: 11,
        fontWeight:
            FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _TarjetaServicio
    extends StatelessWidget {
  final ServicioActivo servicio;

  final bool esActual;

  final VoidCallback onVer;

  const _TarjetaServicio({
    required this.servicio,
    required this.esActual,
    required this.onVer,
  });

  String _formatearFecha(
    DateTime fecha,
  ) {
    String d(int n) =>
        n.toString().padLeft(
              2,
              '0',
            );

    return '${fecha.year}-${d(fecha.month)}-${d(fecha.day)}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final datosPersona =
        <String>[
      if (servicio.edad != null)
        '${servicio.edad} años',

      servicio
          .familiarResponsable,
    ];

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,

        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor:
                    Color(
                  0xFFF6D998,
                ),
                child: Icon(
                  Icons.person,
                  color:
                      Colors.white,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      servicio
                          .nombreAdultoMayor,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    Text(
                      datosPersona.join(
                        ' · ',
                      ),

                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    if (esActual)
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              8,
                          vertical:
                              2,
                        ),

                        decoration:
                            BoxDecoration(
                          color: Colors
                              .green[50],

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: Row(
                          mainAxisSize:
                              MainAxisSize
                                  .min,

                          children: [
                            Icon(
                              Icons
                                  .circle,
                              size: 7,
                              color: Colors
                                  .green[700],
                            ),

                            const SizedBox(
                              width:
                                  4,
                            ),

                            Text(
                              'Activo',
                              style:
                                  TextStyle(
                                fontSize:
                                    11,
                                color: Colors
                                    .green[700
],
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              8,
                          vertical:
                              2,
                        ),

                        decoration:
                            BoxDecoration(
                          color: Colors
                              .grey
                              .shade200,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child:
                            const Text(
                          'Finalizado',
                          style:
                              TextStyle(
                            fontSize:
                                11,
                            color: Colors
                                .black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 13,
                color: Colors.grey,
              ),

              const SizedBox(
                width: 6,
              ),

              Expanded(
                child: Text(
                  esActual
                      ? 'Inicio: ${_formatearFecha(servicio.fechaInicio)}'
                      : '${_formatearFecha(servicio.fechaInicio)} → ${servicio.fechaTermino != null ? _formatearFecha(servicio.fechaTermino!) : '-'}',

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
            height: 12,
          ),

          if (esActual)
            ElevatedButton(
              onPressed:
                  onVer,

              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    Colors.blue,

                foregroundColor:
                    Colors.white,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    24,
                  ),
                ),
              ),

              child:
                  const Text(
                'Ver servicio →',
              ),
            )
          else
            OutlinedButton(
              onPressed:
                  onVer,

              child:
                  const Text(
                'Ver historial →',
              ),
            ),
        ],
      ),
    );
  }
}