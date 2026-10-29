import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../models/cuidador_marketplace.dart';
import '../services/marketplace_service.dart';
import '../state/familiar_contexto.dart';
 
class SolicitudServicioScreen extends StatefulWidget {
  final CuidadorMarketplace cuidador;
 
  const SolicitudServicioScreen({
    super.key,
    required this.cuidador,
  });
 
  @override
  State<SolicitudServicioScreen> createState() =>
      _SolicitudServicioScreenState();
}
 
class _SolicitudServicioScreenState
    extends State<SolicitudServicioScreen> {
  // =========================================================
  // CONTROLLERS
  // =========================================================
 
  final _direccionController = TextEditingController();
  final _informacionController = TextEditingController();
  final _mensajeController = TextEditingController();
 
  // =========================================================
  // FECHAS Y HORAS
  // =========================================================
 
  DateTime? _fechaInicio;
  TimeOfDay? _horaInicio;
 
  DateTime? _fechaTermino;
  TimeOfDay? _horaTermino;
 
  String? _tipoServicio;
 
  bool _formularioFueEnviado = false;
  bool _enviando = false;
 
  // =========================================================
  // DISPOSE
  // =========================================================
 
  @override
  void dispose() {
    _direccionController.dispose();
    _informacionController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }
 
  // =========================================================
  // RANGO DE FECHAS
  // =========================================================
 
  DateTime get _fechaMinima => DateTime.now();
 
  DateTime get _fechaMaxima =>
      DateTime(DateTime.now().year + 1, 12, 31);
 
  // =========================================================
  // VALIDACIONES
  // =========================================================
 
  bool get _direccionValida =>
      _direccionController.text.trim().isNotEmpty;
 
  bool get _fechaInicioValida =>
      _fechaInicio != null;
 
  bool get _horaInicioValida =>
      _horaInicio != null;
 
  bool get _fechaTerminoValida {
    if (_fechaTermino == null) {
      return false;
    }
 
    if (_fechaInicio == null) {
      return true;
    }
 
    return !_fechaTermino!.isBefore(_fechaInicio!);
  }
 
  bool get _horaTerminoValida {
    if (_horaTermino == null) {
      return false;
    }
 
    if (_inicioCompleto == null ||
        _terminoCompleto == null) {
      return true;
    }
 
    return _terminoCompleto!.isAfter(
      _inicioCompleto!,
    );
  }
 
  bool get _tipoValido =>
      _tipoServicio != null;
 
  /// Clave de la modalidad de cuidado por día (la misma que usa el servidor).
  static const String _clavePuertasAdentro = 'cuidado_puertas_adentro';
 
  bool get _esPuertasAdentro => _tipoServicio == _clavePuertasAdentro;
 
  bool get _formularioValido =>
      _direccionValida &&
      _fechaInicioValida &&
      _horaInicioValida &&
      _fechaTerminoValida &&
      _horaTerminoValida &&
      _tipoValido &&
      _cotizacionValida;
 
  // =========================================================
  // FECHA/HORA COMPLETA
  // =========================================================
 
  DateTime? get _inicioCompleto {
    if (_fechaInicio == null ||
        _horaInicio == null) {
      return null;
    }
 
    return DateTime(
      _fechaInicio!.year,
      _fechaInicio!.month,
      _fechaInicio!.day,
      _horaInicio!.hour,
      _horaInicio!.minute,
    );
  }
 
  DateTime? get _terminoCompleto {
    if (_fechaTermino == null ||
        _horaTermino == null) {
      return null;
    }
 
    return DateTime(
      _fechaTermino!.year,
      _fechaTermino!.month,
      _fechaTermino!.day,
      _horaTermino!.hour,
      _horaTermino!.minute,
    );
  }
 
  // =========================================================
  // CÁLCULO DE DURACIÓN
  // =========================================================
 
  int? get _duracionMinutos {
    final inicio = _inicioCompleto;
    final termino = _terminoCompleto;
 
    if (inicio == null || termino == null) {
      return null;
    }
 
    final minutos =
        termino.difference(inicio).inMinutes;
 
    if (minutos <= 0) {
      return null;
    }
 
    return minutos;
  }
 
  double? get _horasServicio {
    final minutos = _duracionMinutos;
 
    if (minutos == null) {
      return null;
    }
 
    return minutos / 60;
  }
 
  String get _duracionFormateada {
    final minutos = _duracionMinutos;
 
    if (minutos == null) {
      return '';
    }
 
    final horas = minutos ~/ 60;
    final minutosRestantes = minutos % 60;
 
    if (horas == 0) {
      return '$minutosRestantes min';
    }
 
    if (minutosRestantes == 0) {
      if (horas == 1) {
        return '1 hora';
      }
 
      return '$horas horas';
    }
 
    return '$horas h $minutosRestantes min';
  }
 
  // =========================================================
  // TARIFAS
  // =========================================================
 
  TarifaProfesion? get _tarifaProfesion =>
      widget.cuidador.tarifa;
 
  int? get _tarifaHoraAplicada {
    final horas = _horasServicio;
    final tarifa = _tarifaProfesion;
 
    if (horas == null || tarifa == null) {
      return null;
    }
 
    // 1 a 3 horas
    if (horas <= 3) {
      return tarifa.periodoCorto;
    }
 
    // 4 a 7 horas
    // 20% de descuento sobre tarifa corta.
    if (horas <= 7) {
      return tarifa.periodoIntermedio;
    }
 
    // 8 a 16 horas
    if (horas <= 16) {
      return tarifa.periodoLargo;
    }
 
    return null;
  }
 
  String get _nombrePeriodo {
    final horas = _horasServicio;
 
    if (horas == null) {
      return '';
    }
 
    if (horas <= 3) {
      return 'Período corto';
    }
 
    if (horas <= 7) {
      return 'Período intermedio';
    }
 
    if (horas <= 16) {
      return 'Período largo';
    }
 
    return 'Fuera de rango';
  }
 
  // =========================================================
  // TOTAL COTIZACIÓN
  // =========================================================
 
  /// Días que se cobran en puertas adentro: uno por cada 24 horas (o fracción)
  /// entre el inicio y el término, con un mínimo de 1.
  int? get _diasPuertasAdentro {
    final minutos = _duracionMinutos;
 
    if (minutos == null) {
      return null;
    }
 
    return (minutos / (24 * 60)).ceil();
  }
 
  int? get _tarifaDiaria => _tarifaProfesion?.puertasAdentro;
 
  double? get _totalCotizacion {
    if (_esPuertasAdentro) {
      final dias = _diasPuertasAdentro;
      final diaria = _tarifaDiaria;
 
      if (dias == null || diaria == null) {
        return null;
      }
 
      return (dias * diaria).toDouble();
    }
 
    final horas = _horasServicio;
    final tarifaHora = _tarifaHoraAplicada;
 
    if (horas == null ||
        tarifaHora == null) {
      return null;
    }
 
    return horas * tarifaHora;
  }
 
  bool get _cotizacionValida {
    if (_esPuertasAdentro) {
      return widget.cuidador.ofrecePuertasAdentro &&
          _diasPuertasAdentro != null &&
          _tarifaDiaria != null;
    }
 
    final horas = _horasServicio;
 
    return horas != null &&
        horas > 0 &&
        horas <= 16 &&
        _tarifaHoraAplicada != null;
  }
 
  // =========================================================
  // FORMATEADORES
  // =========================================================
 
  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Seleccionar';
    }
 
    String dosDigitos(int numero) =>
        numero.toString().padLeft(2, '0');
 
    return '${dosDigitos(fecha.day)}-'
        '${dosDigitos(fecha.month)}-'
        '${fecha.year}';
  }
 
  String _formatearHora(TimeOfDay? hora) {
    if (hora == null) {
      return 'Seleccionar';
    }
 
    String dosDigitos(int numero) =>
        numero.toString().padLeft(2, '0');
 
    return '${dosDigitos(hora.hour)}:'
        '${dosDigitos(hora.minute)}';
  }
 
  String _formatearCLP(num valor) {
    final numero = valor.round();
    final texto = numero.toString();
 
    final buffer = StringBuffer();
 
    for (int i = 0; i < texto.length; i++) {
      if (i != 0 &&
          (texto.length - i) % 3 == 0) {
        buffer.write('.');
      }
 
      buffer.write(texto[i]);
    }
 
    return '\$${buffer.toString()}';
  }
 
  // =========================================================
  // SELECCIONAR FECHAS
  // =========================================================
 
  Future<void> _elegirFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? _fechaMinima,
      firstDate: _fechaMinima,
      lastDate: _fechaMaxima,
    );
 
    if (fecha != null) {
      setState(() {
        _fechaInicio = fecha;
 
        // Si la fecha de término quedó antes,
        // la reiniciamos.
        if (_fechaTermino != null &&
            _fechaTermino!.isBefore(fecha)) {
          _fechaTermino = null;
          _horaTermino = null;
        }
      });
    }
  }
 
  Future<void> _elegirFechaTermino() async {
    final fechaBase =
        _fechaInicio ?? _fechaMinima;
 
    final fecha = await showDatePicker(
      context: context,
      initialDate:
          _fechaTermino ?? fechaBase,
      firstDate: fechaBase,
      lastDate: _fechaMaxima,
    );
 
    if (fecha != null) {
      setState(() {
        _fechaTermino = fecha;
      });
    }
  }
 
  // =========================================================
  // SELECCIONAR HORAS
  // =========================================================
 
  Future<void> _elegirHoraInicio() async {
    final hora = await showTimePicker(
      context: context,
      initialTime:
          _horaInicio ?? TimeOfDay.now(),
    );
 
    if (hora != null) {
      setState(() {
        _horaInicio = hora;
      });
    }
  }
 
  Future<void> _elegirHoraTermino() async {
    final hora = await showTimePicker(
      context: context,
      initialTime:
          _horaTermino ?? TimeOfDay.now(),
    );
 
    if (hora != null) {
      setState(() {
        _horaTermino = hora;
      });
    }
  }
 
  // =========================================================
  // ENVIAR SOLICITUD
  // =========================================================
 
  Future<void> _enviar() async {
    setState(() {
      _formularioFueEnviado = true;
    });
 
    if (!_formularioValido) {
      if (!_esPuertasAdentro &&
          _duracionMinutos != null &&
          _horasServicio != null &&
          _horasServicio! > 16) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.cuidador.ofrecePuertasAdentro
                  ? 'La solicitud supera las 16 horas. '
                      'Elige "Cuidado puertas adentro" como tipo de servicio.'
                  : 'La solicitud supera las 16 horas y este cuidador '
                      'no ofrece la modalidad puertas adentro.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
 
    final adulto = FamiliarContexto.seleccionado;
    if (adulto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero vincula a un adulto mayor desde tu perfil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
 
    if (_enviando) return;
 
    final total = _totalCotizacion!;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
 
    setState(() {
      _enviando = true;
    });
 
    try {
      await MarketplaceService.enviarSolicitud(
        adultoMayorId: adulto.id,
        cuidadorId: widget.cuidador.id,
        direccion: _direccionController.text.trim(),
        inicio: _inicioCompleto!,
        termino: _terminoCompleto!,
        tipoServicio: _tipoServicio!,
        informacionAdicional: _informacionController.text,
        mensaje: _mensajeController.text,
      );
 
      if (!mounted) return;
 
      navegador.pop();
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            'Solicitud enviada. '
            'Total estimado: ${_formatearCLP(total)}',
          ),
        ),
      );
    } on ApiException catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }
 
  // =========================================================
  // TARJETA COTIZACIÓN
  // =========================================================
 
  Widget _buildCotizacion() {
    final horas = _horasServicio;
    final tarifa = _tarifaProfesion;
    final tarifaHora =
        _tarifaHoraAplicada;
    final total = _totalCotizacion;
 
    // -------------------------------------------------------
    // Aún faltan fecha u hora.
    // -------------------------------------------------------
 
    if (_inicioCompleto == null ||
        _terminoCompleto == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0FB),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color:
                const Color(0xFFE0D8F0),
          ),
        ),
        child: const Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.calculate_outlined,
              color: Colors.deepPurple,
              size: 22,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cotización del servicio',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Selecciona la fecha y hora de inicio y término '
                    'para calcular automáticamente el valor.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
 
    // -------------------------------------------------------
    // Fecha/hora inválida.
    // -------------------------------------------------------
 
    if (_duracionMinutos == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              const Color(0xFFFFEEEE),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: Colors.red.shade200,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'La fecha y hora de término deben ser posteriores al inicio.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
 
    // -------------------------------------------------------
    // No existe tarifa.
    // -------------------------------------------------------
 
    if (tarifa == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color:
                Colors.orange.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  'Tarifa no disponible',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'No existe una tarifa registrada para '
              '${widget.cuidador.profesion}.',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
 
    // -------------------------------------------------------
    // Puertas adentro: se cotiza por día.
    // -------------------------------------------------------
 
    if (_esPuertasAdentro) {
      final dias = _diasPuertasAdentro;
      final diaria = tarifa.puertasAdentro;
 
      if (dias == null || diaria == null || total == null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Text(
            'No hay una tarifa diaria registrada para este cuidador.',
            style: TextStyle(fontSize: 12),
          ),
        );
      }
 
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FBF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA9DFC9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF3FAE85),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Cotización del servicio',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF2E7D62),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _filaCotizacion('Profesión', widget.cuidador.profesion),
            const SizedBox(height: 8),
            _filaCotizacion('Modalidad', 'Cuidado puertas adentro'),
            const SizedBox(height: 8),
            _filaCotizacion('Duración', _duracionFormateada),
            const SizedBox(height: 8),
            _filaCotizacion('Días a cobrar', dias == 1 ? '1 día' : '$dias días'),
            const SizedBox(height: 8),
            _filaCotizacion('Valor por día', '${_formatearCLP(diaria)} / día'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Text(
              '${dias == 1 ? '1 día' : '$dias días'} × ${_formatearCLP(diaria)} por día',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL ESTIMADO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D62),
                    ),
                  ),
                ),
                Text(
                  _formatearCLP(total),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D62),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'En la modalidad puertas adentro se cobra un valor fijo por día: '
                      'cada 24 horas (o fracción) entre el inicio y el término cuenta como un día.',
                      style: TextStyle(fontSize: 10, height: 1.4, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
 
    // -------------------------------------------------------
    // Más de 16 horas.
    // -------------------------------------------------------
 
    if (horas != null && horas > 16) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              const Color(0xFFFFF5E6),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color:
                const Color(0xFFF4C987),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Duración superior a 16 horas',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
 
            const SizedBox(height: 8),
 
            Text(
              'La duración seleccionada es '
              '$_duracionFormateada.',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
 
            const SizedBox(height: 8),
 
            if (widget.cuidador.ofrecePuertasAdentro && tarifa.puertasAdentro != null)
              Text(
                'Este cuidador dispone de la modalidad puertas adentro por '
                '${_formatearCLP(tarifa.puertasAdentro!)} al día. '
                'Elígela en "Tipo de servicio".',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              )
            else
              const Text(
                'Este cuidador no ofrece la modalidad puertas adentro.',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
          ],
        ),
      );
    }
 
    if (tarifaHora == null ||
        total == null) {
      return const SizedBox.shrink();
    }
 
    // -------------------------------------------------------
    // COTIZACIÓN CORRECTA
    // -------------------------------------------------------
 
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF0FBF6),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFA9DFC9),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF3FAE85),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Cotización del servicio',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 15,
                  color:
                      Color(0xFF2E7D62),
                ),
              ),
            ],
          ),
 
          const SizedBox(height: 14),
 
          _filaCotizacion(
            'Profesión',
            widget.cuidador.profesion,
          ),
 
          const SizedBox(height: 8),
 
          _filaCotizacion(
            'Duración',
            _duracionFormateada,
          ),
 
          const SizedBox(height: 8),
 
          _filaCotizacion(
            'Tarifa aplicada',
            _nombrePeriodo,
          ),
 
          const SizedBox(height: 8),
 
          _filaCotizacion(
            'Valor por hora',
            '${_formatearCLP(tarifaHora)} / hora',
          ),
 
          if (horas != null &&
              horas > 3 &&
              horas <= 7) ...[
            const SizedBox(height: 8),
 
            _filaCotizacion(
              'Descuento',
              '20% sobre período corto',
            ),
 
            const SizedBox(height: 5),
 
            Text(
              'Tarifa corta: '
              '${_formatearCLP(tarifa.periodoCorto)} → '
              '${_formatearCLP(tarifa.periodoIntermedio)} / hora',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF479B78),
              ),
            ),
          ],
 
          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Divider(height: 1),
          ),
 
          Text(
            '$_duracionFormateada × '
            '${_formatearCLP(tarifaHora)} por hora',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
 
          const SizedBox(height: 8),
 
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'TOTAL ESTIMADO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF2E7D62),
                  ),
                ),
              ),
 
              Text(
                _formatearCLP(total),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF2E7D62),
                ),
              ),
            ],
          ),
 
          const SizedBox(height: 12),
 
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.7,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'El valor se calcula automáticamente según '
                    'la duración solicitada y la tarifa asociada '
                    'a la profesión del cuidador.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color:
                          Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  // =========================================================
  // FILA DE COTIZACIÓN
  // =========================================================
 
  Widget _filaCotizacion(
    String titulo,
    String valor,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
 
  // =========================================================
  // OPCIÓN DEL DESPLEGABLE DE SERVICIOS
  // =========================================================
 
  DropdownMenuItem<String> _opcionServicio(String valor, String texto) {
    return DropdownMenuItem<String>(
      value: valor,
      child: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
 
  // =========================================================
  // BUILD
  // =========================================================
 
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          const Color(0xFFFFF7F5),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      insetPadding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // =================================================
              // ENCABEZADO
              // =================================================
 
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Solicitud de servicio',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Completa los datos',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
 
              const SizedBox(height: 14),
 
              // =================================================
              // ADULTO MAYOR
              // =================================================
 
              Container(
                padding:
                    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEDE7F6),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADULTO MAYOR',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            Colors.deepPurple,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      FamiliarContexto.seleccionado?.nombreCompleto ?? 'Adulto mayor',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
 
              const SizedBox(height: 14),
 
              // =================================================
              // DIRECCIÓN
              // =================================================
 
              _Etiqueta(
                texto:
                    'Dirección del servicio *',
                conError:
                    _formularioFueEnviado &&
                        !_direccionValida,
              ),
 
              const SizedBox(height: 6),
 
              TextField(
                controller:
                    _direccionController,
                onChanged: (_) {
                  setState(() {});
                },
                decoration:
                    _decoracionCampo(
                  conError:
                      _formularioFueEnviado &&
                          !_direccionValida,
                  hint:
                      'Ej: Av. Providencia 1234',
                ),
              ),
 
              const SizedBox(height: 14),
 
              // =================================================
              // INICIO
              // =================================================
 
              Row(
                children: [
                  Expanded(
                    child:
                        _CampoFechaHora(
                      etiqueta:
                          'Fecha de inicio *',
                      valor:
                          _formatearFecha(
                        _fechaInicio,
                      ),
                      icono: Icons
                          .calendar_today,
                      conError:
                          _formularioFueEnviado &&
                              !_fechaInicioValida,
                      onTap:
                          _elegirFechaInicio,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        _CampoFechaHora(
                      etiqueta:
                          'Hora de inicio *',
                      valor:
                          _formatearHora(
                        _horaInicio,
                      ),
                      icono:
                          Icons.access_time,
                      conError:
                          _formularioFueEnviado &&
                              !_horaInicioValida,
                      onTap:
                          _elegirHoraInicio,
                    ),
                  ),
                ],
              ),
 
              const SizedBox(height: 14),
 
              // =================================================
              // TÉRMINO
              // =================================================
 
              Row(
                children: [
                  Expanded(
                    child:
                        _CampoFechaHora(
                      etiqueta:
                          'Fecha de término *',
                      valor:
                          _formatearFecha(
                        _fechaTermino,
                      ),
                      icono: Icons
                          .calendar_today,
                      conError:
                          _formularioFueEnviado &&
                              !_fechaTerminoValida,
                      onTap:
                          _elegirFechaTermino,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        _CampoFechaHora(
                      etiqueta:
                          'Hora de término *',
                      valor:
                          _formatearHora(
                        _horaTermino,
                      ),
                      icono:
                          Icons.access_time,
                      conError:
                          _formularioFueEnviado &&
                              !_horaTerminoValida,
                      onTap:
                          _elegirHoraTermino,
                    ),
                  ),
                ],
              ),
 
              const SizedBox(height: 14),
 
              // =================================================
              // TIPO SERVICIO
              // =================================================
 
              _Etiqueta(
                texto:
                    'Tipo de servicio *',
                conError:
                    _formularioFueEnviado &&
                        !_tipoValido,
              ),
 
              const SizedBox(height: 6),
 
              DropdownButtonFormField<String>(
                initialValue:
                    _tipoServicio,
                hint: const Text(
                  'Seleccionar servicio',
                  style:
                      TextStyle(fontSize: 13),
                ),
                decoration:
                    _decoracionCampo(
                  conError:
                      _formularioFueEnviado &&
                          !_tipoValido,
                ),
                isExpanded: true,
                // Solo los servicios que el cuidador marcó en su perfil,
                // con el mismo nombre que ahí tienen.
                items: [
                  ...widget.cuidador.servicios
                      .toSet()
                      .map((nombre) => _opcionServicio(nombre, nombre)),
                  // Solo si el cuidador tiene activada la modalidad en su perfil.
                  if (widget.cuidador.ofrecePuertasAdentro)
                    _opcionServicio(
                      _clavePuertasAdentro,
                      'Cuidado puertas adentro (cotización por día)',
                    ),
                ],
                onChanged: (valor) {
                  setState(() {
                    _tipoServicio = valor;
                  });
                },
              ),
 
              // =================================================
              // COTIZACIÓN
              // =================================================
 
              const SizedBox(height: 18),
 
              _buildCotizacion(),
 
              const SizedBox(height: 18),
 
              // =================================================
              // INFORMACIÓN ADICIONAL
              // =================================================
 
              const _Etiqueta(
                texto:
                    'Información adicional (opcional)',
                conError: false,
              ),
 
              const SizedBox(height: 6),
 
              TextField(
                controller:
                    _informacionController,
                maxLines: 2,
                decoration:
                    _decoracionCampo(
                  hint:
                      'Alergias, movilidad, indicaciones...',
                ),
              ),
 
              const SizedBox(height: 14),
 
              // =================================================
              // MENSAJE ADICIONAL
              // =================================================
 
              const _Etiqueta(
                texto:
                    'Mensaje adicional (opcional)',
                conError: false,
              ),
 
              const SizedBox(height: 6),
 
              TextField(
                controller:
                    _mensajeController,
                maxLines: 2,
                decoration:
                    _decoracionCampo(
                  hint:
                      'Escribe un mensaje para el cuidador...',
                ),
              ),
 
              const SizedBox(height: 18),
 
              // =================================================
              // BOTÓN
              // =================================================
 
              ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.pink,
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets
                          .symmetric(
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
                child: _enviando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enviar solicitud de servicio',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
 
              const SizedBox(height: 8),
 
              const Center(
                child: Text(
                  'El chat se habilitará cuando el cuidador acepte.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  // =========================================================
  // DECORACIÓN CAMPOS
  // =========================================================
 
  InputDecoration _decoracionCampo({
    bool conError = false,
    String? hint,
  }) {
    final color = conError
        ? Colors.red
        : Colors.grey.shade300;
 
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: BorderSide(
          color: color,
          width: 2,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: BorderSide(
          color: color,
          width: 2,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide: BorderSide(
          color: conError
              ? Colors.red
              : Colors.pink,
          width: 2,
        ),
      ),
    );
  }
}
 
// ===========================================================
// ETIQUETA
// ===========================================================
 
class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool conError;
 
  const _Etiqueta({
    required this.texto,
    required this.conError,
  });
 
  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: conError
            ? Colors.red
            : Colors.black87,
      ),
    );
  }
}
 
// ===========================================================
// CAMPO FECHA / HORA
// ===========================================================
 
class _CampoFechaHora
    extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final IconData icono;
  final bool conError;
  final VoidCallback onTap;
 
  const _CampoFechaHora({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.conError,
    required this.onTap,
  });
 
  @override
  Widget build(BuildContext context) {
    final color = conError
        ? Colors.red
        : Colors.grey.shade300;
 
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _Etiqueta(
          texto: etiqueta,
          conError: conError,
        ),
 
        const SizedBox(height: 6),
 
        InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: color,
                width: 2,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    valor,
                    style:
                        const TextStyle(
                      fontSize: 12,
                    ),
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  icono,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}