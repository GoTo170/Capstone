import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../../familiar/models/actividad.dart';
import '../../familiar/services/tareas_service.dart';
import '../services/adulto_mayor_service.dart';
import '../services/sos_sms_service.dart';
import '../widgets/adulto_mayor_bottom_nav.dart';
import '../../familiar/screens/acciones_horario.dart';
import 'tareas_adulto_mayor_screen.dart';
 
class InicioAdultoMayorScreen extends StatefulWidget {
  final String nombre;
  final List<Actividad>? actividadesIniciales;
 
  const InicioAdultoMayorScreen({super.key, required this.nombre, this.actividadesIniciales});
 
  @override
  State<InicioAdultoMayorScreen> createState() => _InicioAdultoMayorScreenState();
}
 
class _InicioAdultoMayorScreenState extends State<InicioAdultoMayorScreen> {
  List<Actividad> _actividades = [];
  bool _cargando = true;
  String? _error;
  bool _guardando = false;
  final Set<String> _sincronizando = {};
 
  Timer? _timer;
  bool _mostrandoAlertaEnviada = false;
  String _detalleSms = '';
 
  @override
  void initState() {
    super.initState();
    // Revisa cada 30 segundos si alguna tarea pendiente ya "venció"
    // (empezó la siguiente sin haberse registrado) para marcarla como no realizada.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refrescar());
    _cargar();
    // Guarda en el teléfono los contactos de emergencia (para el SMS del SOS)
    // y pide desde ya el permiso de enviar SMS, no en plena emergencia.
    SosSmsService.actualizarContactos();
    WidgetsBinding.instance.addPostFrameCallback((_) => SosSmsService.pedirPermiso());
  }
 
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
 
  List<Actividad> get _ordenadas => [..._actividades]..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
 
  /// Pide al servidor mis actividades y se queda con las de hoy.
  /// Con `silencioso` no muestra el indicador de carga ni los errores.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
 
    try {
      final lista = await TareasService.listarMias();
 
      if (!mounted) return;
 
      setState(() {
        _actividades = TareasService.deHoy(lista);
        _cargando = false;
        _error = null;
      });
 
      await _marcarVencidasComoNoRealizadas();
    } on ApiException catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }
 
  Future<void> _refrescar() => _cargar(silencioso: true);
 
  void _reemplazar(Actividad nueva) {
    final index = _actividades.indexWhere((a) => a.id == nueva.id);
    if (index >= 0) _actividades[index] = nueva;
  }
 
  /// Una actividad pendiente "vence" cuando empieza la siguiente sin haberse
  /// registrado: se marca como no realizada también en el servidor.
  /// Si falla (por ejemplo, sin conexión), se reintenta en el siguiente ciclo.
  Future<void> _marcarVencidasComoNoRealizadas() async {
    final ordenadas = _ordenadas;
    final ahora = DateTime.now();
    final vencidas = <Actividad>[];
 
    for (int i = 0; i < ordenadas.length - 1; i++) {
      final actual = ordenadas[i];
      final siguiente = ordenadas[i + 1];
      if (actual.estado == EstadoTarea.pendiente && !ahora.isBefore(siguiente.fechaHora)) {
        vencidas.add(actual);
      }
    }
 
    for (final actividad in vencidas) {
      final id = actividad.id;
      if (id == null || _sincronizando.contains(id)) continue;
 
      _sincronizando.add(id);
      try {
        final actualizada = await TareasService.actualizarEstado(id, EstadoTarea.noRealizada);
        if (!mounted) return;
        setState(() => _reemplazar(actualizada));
      } on ApiException {
        // Se reintenta en el siguiente ciclo (cada 30 segundos).
      } finally {
        _sincronizando.remove(id);
      }
    }
  }
 
  int get _completadas => _actividades.where((a) => a.estado == EstadoTarea.realizada).length;
  int get _pendientes => _actividades.where((a) => a.estado == EstadoTarea.pendiente).length;
  int get _noRealizadas => _actividades.where((a) => a.estado == EstadoTarea.noRealizada).length;
  int get _total => _actividades.length;
 
  bool get _todoResuelto => _pendientes == 0;
 
  Actividad? get _proximaActividad {
    final pendientes = _actividades.where((a) => a.estado == EstadoTarea.pendiente).toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return pendientes.isEmpty ? null : pendientes.first;
  }
 
  bool _puedeMarcar(Actividad actividad) {
    final habilitaDesde = actividad.fechaHora.subtract(const Duration(minutes: 10));
    return !DateTime.now().isBefore(habilitaDesde);
  }
 
  String get _saludo {
    final hora = DateTime.now().hour;
    if (hora < 12) return '¡Buenos días, ${widget.nombre}!';
    if (hora < 19) return '¡Buenas tardes, ${widget.nombre}!';
    return '¡Buenas noches, ${widget.nombre}!';
  }
 
  Future<void> _marcarActividad(Actividad actividad, EstadoTarea nuevoEstado) async {
    final id = actividad.id;
    if (id == null || !_puedeMarcar(actividad) || _guardando) return;
 
    setState(() => _guardando = true);
 
    try {
      final actualizada = await TareasService.actualizarEstado(id, nuevoEstado);
 
      if (!mounted) return;
 
      setState(() => _reemplazar(actualizada));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
 
  Future<void> _confirmarSOS() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Confirmas la alerta de emergencia?', textAlign: TextAlign.center),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Confirmar SOS'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
 
    if (confirmado != true) return;
 
    // 1) Aviso a la familia dentro de Mamoru (necesita internet).
    String? errorServidor;
    try {
      await AdultoMayorService.enviarSOS();
    } on ApiException catch (e) {
      errorServidor = e.mensaje;
    }
 
    // 2) SMS a los contactos de emergencia, desde el chip de este teléfono.
    final sms = await SosSmsService.enviar(widget.nombre);
 
    if (!mounted) return;
 
    if (errorServidor != null && !sms.salioAlgo) {
      // No salió nada: es importante que sepa que la alerta NO salió.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la alerta. $errorServidor Inténtalo de nuevo o llama a un familiar.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
 
    setState(() {
      _detalleSms = _textoSms(sms, servidorOk: errorServidor == null);
      _mostrandoAlertaEnviada = true;
    });
    Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _mostrandoAlertaEnviada = false);
    });
  }
 
  String _textoSms(ResultadoSms sms, {required bool servidorOk}) {
    final partes = <String>[];
    if (servidorOk) partes.add('Tu familia ha sido notificada en Mamoru.');
    if (!servidorOk) partes.add('No pudimos avisar por internet.');
    switch (sms.estado) {
      case EstadoSms.enviado:
        partes.add('También enviamos un SMS a tus contactos de emergencia.');
        break;
      case EstadoSms.parcial:
        partes.add('Enviamos SMS a ${sms.enviados} de ${sms.total} contactos de emergencia.');
        break;
      case EstadoSms.sinPermiso:
        partes.add('No se enviaron SMS porque falta el permiso para enviar mensajes.');
        break;
      case EstadoSms.sinContactos:
        partes.add('No hay contactos de emergencia guardados para enviar SMS.');
        break;
      case EstadoSms.noDisponible:
        break;
      case EstadoSms.error:
        partes.add('No se pudo enviar el SMS a tus contactos. Si puedes, llámalos.');
        break;
    }
    return partes.join(' ');
  }
 
  String _formatearHora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.hour)}:${d(f.minute)} hrs';
  }
 
  @override
  Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFAFF),
        bottomNavigationBar: AdultoMayorBottomNav(
          seleccionada: PestanaAdultoMayor.inicio,
          nombre: widget.nombre,
          actividades: _actividades,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ---------- Contenido que sí hace scroll ----------
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 12),
                                  TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE3D9F6), Color(0xFFFDEDEB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_saludo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('¿Cómo te sientes hoy?', style: TextStyle(fontSize: 15, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_mostrandoAlertaEnviada) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(color: const Color(0xFFFBE3E3), borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  children: [
                                    const Icon(Icons.notifications_active, color: Colors.red, size: 28),
                                    const SizedBox(height: 6),
                                    const Text('Alerta enviada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                                    const SizedBox(height: 2),
                                    Text(_detalleSms, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(child: Text('Mis actividades de hoy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                                      TextButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const TareasAdultoMayorScreen()),
                                        ),
                                        child: const Text('Ver todas'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _CajaEstadistica(numero: _completadas, etiqueta: 'Completadas', color: Colors.green, fondo: const Color(0xFFDFF3E3)),
                                      const SizedBox(width: 10),
                                      _CajaEstadistica(numero: _pendientes, etiqueta: 'Pendientes', color: Colors.deepOrange, fondo: const Color(0xFFFCE6E6)),
                                      const SizedBox(width: 10),
                                      _CajaEstadistica(numero: _noRealizadas, etiqueta: 'No realizadas', color: Colors.red, fondo: const Color(0xFFFBDCDC)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: _total == 0 ? 0 : _completadas / _total,
                                      minHeight: 10,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation(Colors.green),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: _todoResuelto
                                        ? const Text('Tareas completadas ¡Felicidades! 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))
                                        : Text('$_completadas de $_total actividades completadas', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('PRÓXIMA ACTIVIDAD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                                  const SizedBox(height: 10),
                                  if (_proximaActividad == null)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      child: Text('No tienes más actividades pendientes por hoy. 🎉', style: TextStyle(color: Colors.grey)),
                                    )
                                  else ...[
                                    Builder(builder: (context) {
                                      final actividad = _proximaActividad!;
                                      final habilitado = _puedeMarcar(actividad);
 
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(actividad.tipo.icono, color: actividad.tipo.color, size: 26),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(actividad.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                                      Text(_formatearHora(actividad.fechaHora), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                      if (actividad.notas != null) ...[
                                                        const SizedBox(height: 6),
                                                        Text(actividad.notas!, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (actividad.id != null) ...[
                                            const SizedBox(height: 10),
                                            AccionesHorario(
                                              id: actividad.id!,
                                              titulo: actividad.titulo,
                                              categoria: actividad.tipo.name,
                                              horaProgramada: actividad.fechaHora,
                                              pendiente: true,
                                              // Al adelantar, la hora pasa a "ahora" y se habilitan los botones.
                                              onAdelantada: () => _cargar(silencioso: true),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: habilitado && !_guardando ? () => _marcarActividad(actividad, EstadoTarea.realizada) : null,
                                              icon: const Icon(Icons.check),
                                              label: const Text('Marcar como completada', style: TextStyle(fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                disabledBackgroundColor: Colors.green.withOpacity(0.35),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: habilitado && !_guardando ? () => _marcarActividad(actividad, EstadoTarea.noRealizada) : null,
                                              icon: const Icon(Icons.close),
                                              label: const Text('No pude hacerla'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                disabledForegroundColor: Colors.red.withOpacity(0.35),
                                                side: BorderSide(color: habilitado ? Colors.red : Colors.red.withOpacity(0.35)),
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Disponible desde 10 minutos antes de la hora. Si no se registra antes de la siguiente tarea, se marcará como no realizada.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ---------- Botón SOS: fijo, siempre visible, no hace scroll ----------
              Container(
                padding: const EdgeInsets.fromLTRB(5, 12, 5, 16),
                decoration: BoxDecoration(
                color: const Color(0xFFFBFAFF),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 5, offset: const Offset(0, -3))],
              ),
              child: ElevatedButton.icon(
                  onPressed: _confirmarSOS,
                  icon: const Icon(Icons.warning_amber_rounded, size: 26),
                  label: const Text('BOTÓN DE EMERGENCIA (SOS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF16C6C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
 
class _CajaEstadistica extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final Color color;
  final Color fondo;
 
  const _CajaEstadistica({required this.numero, required this.etiqueta, required this.color, required this.fondo});
 
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$numero', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(etiqueta, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}