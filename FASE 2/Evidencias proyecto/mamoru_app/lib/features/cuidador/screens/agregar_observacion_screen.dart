import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../models/actividad_cuidador.dart';
import '../services/cuidador_service.dart';

class AgregarObservacionScreen extends StatefulWidget {
  final ActividadCuidador actividad;

  const AgregarObservacionScreen({
    super.key,
    required this.actividad,
  });

  @override
  State<AgregarObservacionScreen> createState() =>
      _AgregarObservacionScreenState();
}

class _AgregarObservacionScreenState
    extends State<AgregarObservacionScreen> {
  final TextEditingController _controller =
      TextEditingController();

  static const int _limiteCaracteres = 500;

  bool _guardando = false;

  bool get _puedeGuardar {
    return _controller.text.trim().isNotEmpty &&
        !_guardando;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // Guardar observación
  // ============================================================

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;

    final texto = _controller.text.trim();

    setState(() {
      _guardando = true;
    });

    try {
      final observacion =
          await CuidadorService.agregarObservacionActividad(
        widget.actividad.id,
        texto,
      );

      if (!mounted) return;

      setState(() {
        // Solo agregamos la observación local
        // después de que el backend confirme que fue guardada.
        widget.actividad.observaciones.add(
          observacion,
        );

        _controller.clear();
        _guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Observación guardada. '
            'Ya no podrás editarla ni eliminarla.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar la observación.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // Formatos
  // ============================================================

  String _formatearFecha(DateTime fecha) {
    String d(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${fecha.year}-'
        '${d(fecha.month)}-'
        '${d(fecha.day)}';
  }

  String _formatearHora(DateTime fecha) {
    String d(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${d(fecha.hour)}:'
        '${d(fecha.minute)}';
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF7F5),

      body: SafeArea(
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
                8,
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
                    ),
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Agregar observación',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      Text(
                        'Será visible para la familia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==================================================
            // Contenido
            // ==================================================

            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    // ============================================
                    // Actividad relacionada
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
                          0xFFEAF4FB,
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
                          const Text(
                            'ACTIVIDAD RELACIONADA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Colors.blue,
                              letterSpacing:
                                  0.5,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            widget.actividad.titulo,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          if (widget
                                  .actividad
                                  .descripcion !=
                              null &&
                              widget
                                  .actividad
                                  .descripcion!
                                  .trim()
                                  .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top: 2,
                              ),

                              child: Text(
                                widget
                                    .actividad
                                    .descripcion!,
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.black87,
                                ),
                              ),
                            ),

                          const SizedBox(
                            height: 4,
                          ),

                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 13,
                                color:
                                    Colors.grey,
                              ),

                              const SizedBox(
                                width: 4,
                              ),

                              Text(
                                '${_formatearHora(widget.actividad.horaProgramada)} '
                                '· '
                                '${_formatearFecha(widget.actividad.horaProgramada)}',
                                style:
                                    const TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ============================================
                    // Aviso
                    // ============================================

                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFFDF3D8,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color:
                                Colors.orange,
                          ),

                          SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child:
                                Text.rich(
                              TextSpan(
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                ),

                                children: [
                                  TextSpan(
                                    text:
                                        'Una vez guardada, la observación ',
                                  ),

                                  TextSpan(
                                    text:
                                        'no podrá ser modificada.',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  TextSpan(
                                    text:
                                        ' El familiar podrá verla en su aplicación.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ============================================
                    // Observaciones previas
                    // ============================================

                    if (widget
                        .actividad
                        .observaciones
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 18,
                      ),

                      const Text(
                        'OBSERVACIONES PREVIAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              Colors.grey,
                          letterSpacing:
                              0.5,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      for (final observacion
                          in widget
                              .actividad
                              .observaciones)
                        Container(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),

                          padding:
                              const EdgeInsets.all(
                            12,
                          ),

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Text(
                                '${_formatearFecha(observacion.fecha)} '
                                '· '
                                '${_formatearHora(observacion.fecha)}',
                                style:
                                    const TextStyle(
                                  fontSize: 11,
                                  color:
                                      Colors.grey,
                                ),
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              Text(
                                observacion.texto,
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              const Text(
                                'No se puede editar',
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  color:
                                      Colors.grey,
                                  fontStyle:
                                      FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(
                      height: 18,
                    ),

                    // ============================================
                    // Nueva observación
                    // ============================================

                    const Text(
                      'NUEVA OBSERVACIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.grey,
                        letterSpacing:
                            0.5,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller:
                          _controller,

                      enabled:
                          !_guardando,

                      maxLength:
                          _limiteCaracteres,

                      maxLines: 5,

                      onChanged: (_) {
                        setState(() {});
                      },

                      decoration:
                          InputDecoration(
                        hintText:
                            'Escribe aquí tu observación sobre esta actividad: '
                            'cómo estuvo el adulto mayor, si hubo algo relevante, '
                            'resultados de mediciones, etc.',

                        hintStyle:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              Colors.grey,
                        ),

                        filled: true,

                        fillColor:
                            Colors.white,

                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),

                        counterText:
                            '${_controller.text.length} caracteres',
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // Guardar
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20,
              ),

              child: SizedBox(
                width:
                    double.infinity,

                child: ElevatedButton(
                  onPressed:
                      _puedeGuardar
                          ? _guardar
                          : null,

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blue,

                    disabledBackgroundColor:
                        Colors.blue.withValues(
                      alpha: 0.35,
                    ),

                    foregroundColor:
                        Colors.white,

                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        30,
                      ),
                    ),
                  ),

                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar observación',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}