import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../models/actividad.dart';
import '../services/tareas_service.dart';
import '../state/familiar_contexto.dart';

class NuevaActividadScreen extends StatefulWidget {
  const NuevaActividadScreen({super.key});

  @override
  State<NuevaActividadScreen> createState() => _NuevaActividadScreenState();
}

class _NuevaActividadScreenState extends State<NuevaActividadScreen> {
  final _nombreController = TextEditingController();
  final _notasController = TextEditingController();

  TipoActividad? _tipoSeleccionado;
  TimeOfDay? _horaSeleccionada;
  FrecuenciaMedicamento? _frecuencia;

  // Para actividades que no son medicamento, o medicamento "día específico".
  DateTime? _fechaSeleccionada;
  // Para medicamento "por rango de días".
  DateTime? _fechaInicioRango;
  DateTime? _fechaTerminoRango;

  bool _formularioFueEnviado = false;
  bool _enviando = false;

  // "Diariamente" no tiene fecha de término: se programan los próximos 30 días.
  static const int _diasDiaria = 30;
  // Tope que acepta el servidor por vez.
  static const int _maxActividades = 400;

  DateTime get _fechaMinima => DateTime.now();
  DateTime get _fechaMaxima => DateTime(DateTime.now().year + 1, 12, 31);

  bool get _esMedicamento => _tipoSeleccionado == TipoActividad.medicamento;

  bool get _tipoValido => _tipoSeleccionado != null;
  bool get _nombreValido => _nombreController.text.trim().isNotEmpty;
  bool get _horaValida => _horaSeleccionada != null;

  bool get _frecuenciaValida => !_esMedicamento || _frecuencia != null;

  // Fecha simple: se usa cuando NO es medicamento, o cuando es medicamento "día específico".
  bool get _requiereFechaSimple =>
      !_esMedicamento || _frecuencia == FrecuenciaMedicamento.diaEspecifico;

  bool get _fechaSimpleValida => !_requiereFechaSimple || _fechaSeleccionada != null;

  // Rango: solo cuando es medicamento y la frecuencia elegida es "rango de días".
  bool get _requiereRango =>
      _esMedicamento && _frecuencia == FrecuenciaMedicamento.rangoDeDias;

  bool get _fechaInicioRangoValida => !_requiereRango || _fechaInicioRango != null;

  bool get _fechaTerminoRangoValida =>
      !_requiereRango ||
      (_fechaTerminoRango != null &&
          _fechaInicioRango != null &&
          !_fechaTerminoRango!.isBefore(_fechaInicioRango!));

  Future<void> _elegirFechaSimple() async {
    final nuevaFecha = await showDatePicker(
      context: context,
      initialDate: _fechaMinima,
      firstDate: _fechaMinima,
      lastDate: _fechaMaxima,
    );
    if (nuevaFecha != null) setState(() => _fechaSeleccionada = nuevaFecha);
  }

  Future<void> _elegirFechaInicioRango() async {
    final nuevaFecha = await showDatePicker(
      context: context,
      initialDate: _fechaMinima,
      firstDate: _fechaMinima,
      lastDate: _fechaMaxima,
    );
    if (nuevaFecha != null) {
      setState(() {
        _fechaInicioRango = nuevaFecha;
        // Si la fecha de término quedó antes de la nueva fecha de inicio, se limpia.
        if (_fechaTerminoRango != null && _fechaTerminoRango!.isBefore(nuevaFecha)) {
          _fechaTerminoRango = null;
        }
      });
    }
  }

  Future<void> _elegirFechaTerminoRango() async {
    final base = _fechaInicioRango ?? _fechaMinima;
    final nuevaFecha = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: base,
      lastDate: _fechaMaxima,
    );
    if (nuevaFecha != null) setState(() => _fechaTerminoRango = nuevaFecha);
  }

  Future<void> _elegirHora() async {
    final nuevaHora = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (nuevaHora != null) setState(() => _horaSeleccionada = nuevaHora);
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar fecha';
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(fecha.day)}-${d(fecha.month)}-${fecha.year}';
  }

  String _formatearHora(TimeOfDay? hora) {
    if (hora == null) return 'Seleccionar hora';
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(hora.hour)}:${d(hora.minute)}';
  }

  /// Fechas y horas en que se programa la actividad.
  List<DateTime> _fechasProgramadas() {
    final hora = _horaSeleccionada!;
    DateTime conHora(DateTime dia) => DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);

    if (_esMedicamento && _frecuencia == FrecuenciaMedicamento.diaria) {
      final hoy = DateTime.now();
      return [for (int i = 0; i < _diasDiaria; i++) conHora(DateTime(hoy.year, hoy.month, hoy.day + i))];
    }

    if (_requiereRango) {
      final inicio = _fechaInicioRango!;
      final termino = _fechaTerminoRango!;
      // Se cuentan los días en UTC para que el cambio de hora no altere el resultado.
      final dias = DateTime.utc(termino.year, termino.month, termino.day)
          .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
          .inDays;
      return [for (int i = 0; i <= dias; i++) conHora(DateTime(inicio.year, inicio.month, inicio.day + i))];
    }

    return [conHora(_fechaSeleccionada!)];
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _crearActividad() async {
    setState(() => _formularioFueEnviado = true);

    final valido = _tipoValido &&
        _nombreValido &&
        _horaValida &&
        _frecuenciaValida &&
        _fechaSimpleValida &&
        _fechaInicioRangoValida &&
        _fechaTerminoRangoValida;

    if (!valido || _enviando) return;

    final adulto = FamiliarContexto.seleccionado;
    if (adulto == null) {
      _avisar('Primero vincula a un adulto mayor desde tu perfil.');
      return;
    }

    // Solo se programan fechas y horas que todavía no pasaron.
    final ahora = DateTime.now();
    final fechas = _fechasProgramadas().where((f) => f.isAfter(ahora)).toList();

    if (fechas.isEmpty) {
      _avisar('La fecha y hora elegidas ya pasaron. Elige otra.');
      return;
    }
    if (fechas.length > _maxActividades) {
      _avisar('Son demasiadas actividades de una vez (máximo $_maxActividades). Acorta el rango de días.');
      return;
    }

    setState(() => _enviando = true);

    try {
      final notas = _notasController.text.trim();

      await TareasService.crear(
        adultoMayorId: adulto.id,
        titulo: _nombreController.text.trim(),
        tipo: _tipoSeleccionado!,
        notas: notas.isEmpty ? null : notas,
        fechas: fechas,
      );

      if (!mounted) return;

      final mensajero = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            fechas.length == 1 ? 'Actividad creada correctamente.' : '${fechas.length} actividades creadas correctamente.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Nueva actividad'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Para ${FamiliarContexto.seleccionado?.nombreCompleto ?? 'tu adulto mayor'}', style: const TextStyle(color: Colors.pink)),
            const SizedBox(height: 20),
            _Etiqueta(texto: 'TIPO DE ACTIVIDAD', conError: _formularioFueEnviado && !_tipoValido),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: TipoActividad.values.map((tipo) {
                final seleccionado = _tipoSeleccionado == tipo;
                return InkWell(
                  onTap: () => setState(() {
                    _tipoSeleccionado = tipo;
                    // Al cambiar de tipo, se limpian los campos dependientes del flujo anterior.
                    _frecuencia = null;
                    _fechaSeleccionada = null;
                    _fechaInicioRango = null;
                    _fechaTerminoRango = null;
                  }),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: seleccionado ? tipo.color.withValues(alpha: 0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: seleccionado ? tipo.color : Colors.grey.shade300, width: seleccionado ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tipo.icono, color: tipo.color, size: 26),
                        const SizedBox(height: 6),
                        Text(tipo.etiqueta, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _Etiqueta(texto: 'NOMBRE DE LA ACTIVIDAD *', conError: _formularioFueEnviado && !_nombreValido),
            const SizedBox(height: 6),
            TextField(
              controller: _nombreController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ej: Tomar Metformina 500mg',
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _formularioFueEnviado && !_nombreValido ? Colors.red : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _formularioFueEnviado && !_nombreValido ? Colors.red : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---------- Caso: NO es medicamento -> Fecha y Hora juntas ----------
            if (!_esMedicamento) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CampoFechaHora(
                      etiqueta: 'FECHA',
                      valor: _formatearFecha(_fechaSeleccionada),
                      icono: Icons.calendar_today,
                      conError: _formularioFueEnviado && !_fechaSimpleValida,
                      onTap: _elegirFechaSimple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoFechaHora(
                      etiqueta: 'HORA',
                      valor: _formatearHora(_horaSeleccionada),
                      icono: Icons.access_time,
                      conError: _formularioFueEnviado && !_horaValida,
                      onTap: _elegirHora,
                    ),
                  ),
                ],
              ),
            ],

            // ---------- Caso: ES medicamento -> Hora, luego Frecuencia, luego Fecha(s) ----------
            if (_esMedicamento) ...[
              _CampoFechaHora(
                etiqueta: 'HORA',
                valor: _formatearHora(_horaSeleccionada),
                icono: Icons.access_time,
                conError: _formularioFueEnviado && !_horaValida,
                onTap: _elegirHora,
              ),
              const SizedBox(height: 20),
              _Etiqueta(texto: 'FRECUENCIA DEL MEDICAMENTO', conError: _formularioFueEnviado && !_frecuenciaValida),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipOpcion(
                    texto: 'Diariamente',
                    seleccionado: _frecuencia == FrecuenciaMedicamento.diaria,
                    onTap: () => setState(() {
                      _frecuencia = FrecuenciaMedicamento.diaria;
                      _fechaSeleccionada = null;
                      _fechaInicioRango = null;
                      _fechaTerminoRango = null;
                    }),
                  ),
                  _ChipOpcion(
                    texto: 'Por un rango de días',
                    seleccionado: _frecuencia == FrecuenciaMedicamento.rangoDeDias,
                    onTap: () => setState(() {
                      _frecuencia = FrecuenciaMedicamento.rangoDeDias;
                      _fechaSeleccionada = null;
                    }),
                  ),
                  _ChipOpcion(
                    texto: 'Día específico',
                    seleccionado: _frecuencia == FrecuenciaMedicamento.diaEspecifico,
                    onTap: () => setState(() {
                      _frecuencia = FrecuenciaMedicamento.diaEspecifico;
                      _fechaInicioRango = null;
                      _fechaTerminoRango = null;
                    }),
                  ),
                ],
              ),

              // "Día específico" -> una sola fecha.
              if (_frecuencia == FrecuenciaMedicamento.diaEspecifico) ...[
                const SizedBox(height: 14),
                _CampoFechaHora(
                  etiqueta: 'FECHA',
                  valor: _formatearFecha(_fechaSeleccionada),
                  icono: Icons.calendar_today,
                  conError: _formularioFueEnviado && !_fechaSimpleValida,
                  onTap: _elegirFechaSimple,
                ),
              ],

              // "Por rango de días" -> fecha de inicio y de término.
              if (_frecuencia == FrecuenciaMedicamento.rangoDeDias) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CampoFechaHora(
                        etiqueta: 'FECHA DE INICIO',
                        valor: _formatearFecha(_fechaInicioRango),
                        icono: Icons.event_available,
                        conError: _formularioFueEnviado && !_fechaInicioRangoValida,
                        onTap: _elegirFechaInicioRango,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CampoFechaHora(
                        etiqueta: 'FECHA DE TÉRMINO',
                        valor: _formatearFecha(_fechaTerminoRango),
                        icono: Icons.event_busy,
                        conError: _formularioFueEnviado && !_fechaTerminoRangoValida,
                        onTap: _elegirFechaTerminoRango,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 20),
            const _Etiqueta(texto: 'NOTAS / INSTRUCCIONES (OPCIONAL)', conError: false),
            const SizedBox(height: 6),
            TextField(
              controller: _notasController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: 2 tabletas con el desayuno, con agua',
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _enviando ? null : _crearActividad,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check),
              label: Text(_enviando ? 'Creando…' : 'Crear actividad para ${(FamiliarContexto.seleccionado?.nombreCompleto ?? 'tu adulto mayor').split(' ').first}'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool conError;

  const _Etiqueta({required this.texto, required this.conError});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: conError ? Colors.red : Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }
}

class _CampoFechaHora extends StatelessWidget {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Etiqueta(texto: etiqueta, conError: conError),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: conError ? Colors.red : Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(valor, overflow: TextOverflow.ellipsis)),
                Icon(icono, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipOpcion extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipOpcion({required this.texto, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.pink : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto, style: TextStyle(color: seleccionado ? Colors.white : Colors.black87, fontSize: 13)),
      ),
    );
  }
}