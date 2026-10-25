import 'dart:async';
 
import 'package:flutter/material.dart';
import '../models/actividad_cuidador.dart';
import '../models/servicio_activo.dart';
import 'actividades_cuidador_screen.dart';
import 'detalle_servicio_screen.dart';
import '../widgets/cuidador_bottom_nav.dart';
import '../../../core/api_exception.dart';
import '../models/solicitud_servicio.dart';
import '../services/cuidador_service.dart';
import 'solicitudes_servicio_screen.dart';
import '../../shared/chat/chat_fab.dart';
 
class InicioCuidadorScreen extends StatefulWidget {
  final String nombreCuidador;
 
  const InicioCuidadorScreen({super.key, required this.nombreCuidador});
 
  @override
  State<InicioCuidadorScreen> createState() => _InicioCuidadorScreenState();
}
 
class _InicioCuidadorScreenState extends State<InicioCuidadorScreen> {
  // Servicio en curso (lo decide el servidor: aceptado y dentro de su período)
  // y sus actividades.
  ServicioActivo? _servicioActivo;
  final List<ActividadCuidador> _actividades = [];
 
  List<SolicitudServicio> _solicitudes = [];
  bool _cargandoSolicitudes = true;
  String? _errorSolicitudes;
  Timer? _timer;
 
  @override
  void initState() {
    super.initState();
    // Revisa cada 30 segundos si llegaron solicitudes nuevas.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargarSolicitudes(silencioso: true));
    _cargarSolicitudes();
  }
 
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
 
  Future<void> _cargarSolicitudes({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargandoSolicitudes = true;
        _errorSolicitudes = null;
      });
    }
 
    try {
      final lista = await CuidadorService.listarSolicitudes();
 
      if (!mounted) return;
 
      setState(() {
        _solicitudes = lista;
        _cargandoSolicitudes = false;
        _errorSolicitudes = null;
      });
 
      await _actualizarServicioActivo();
    } on ApiException catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        _errorSolicitudes = e.mensaje;
        _cargandoSolicitudes = false;
      });
    }
  }
 
  /// Busca el servicio en curso y trae sus actividades. Si no hay ninguno, el
  /// inicio muestra "No tienes servicios activos".
  Future<void> _actualizarServicioActivo() async {
    try {
      final servicios = await CuidadorService.listarServicios();
 
      final vigentes = servicios.where((s) => s.vigente && !s.estaFinalizado).toList()
        ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));
 
      if (vigentes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _servicioActivo = null;
          _actividades.clear();
        });
        return;
      }
 
      final servicio = vigentes.first;
      final todas = await CuidadorService.listarActividades();
 
      // Solo las actividades de este adulto mayor dentro del período del servicio.
      final delServicio = todas.where((a) {
        if (a.adultoMayorId != servicio.adultoMayorId) return false;
        if (a.horaProgramada.isBefore(servicio.fechaInicio)) return false;
        final termino = servicio.fechaTermino;
        return termino == null || !a.horaProgramada.isAfter(termino);
      }).toList();
 
      if (!mounted) return;
 
      setState(() {
        _servicioActivo = servicio;
        _actividades
          ..clear()
          ..addAll(delServicio);
      });
    } on ApiException {
      // Se conserva lo último que se había cargado.
    }
  }
 
  Future<void> _abrirActividades() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActividadesCuidadorScreen(actividades: _actividades)),
    );
    if (mounted) _actualizarServicioActivo(); // lo marcado allí se refleja al volver
  }
 
  Future<void> _abrirSolicitudes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SolicitudesServicioScreen(solicitudes: _solicitudes)),
    );
    if (mounted) {
      setState(() {}); // refresca el contador al volver
      _cargarSolicitudes(silencioso: true); // aceptar una solicitud puede dejar un servicio en curso
    }
  }
 
  int get _solicitudesNuevas => _solicitudes.where((s) => s.estado == EstadoSolicitud.nueva).length;
 
  /// Las actividades del servicio que están programadas para hoy, por hora.
  List<ActividadCuidador> get _actividadesHoy {
    final hoy = DateTime.now();
    return _actividades
        .where((a) => a.horaProgramada.year == hoy.year && a.horaProgramada.month == hoy.month && a.horaProgramada.day == hoy.day)
        .toList()
      ..sort((a, b) => a.horaProgramada.compareTo(b.horaProgramada));
  }
 
  int get _pendientes => _actividadesHoy.where((a) => a.estado == EstadoActividadCuidador.pendiente).length;
  int get _realizadas => _actividadesHoy.where((a) => a.estado == EstadoActividadCuidador.realizada).length;
  int get _noRealizadas => _actividadesHoy.where((a) => a.estado == EstadoActividadCuidador.noRealizada).length;
 
  ActividadCuidador? get _proximaActividad {
    final pendientes = _actividadesHoy.where((a) => a.estado == EstadoActividadCuidador.pendiente).toList();
    return pendientes.isEmpty ? null : pendientes.first;
  }
 
  String get _fechaFormateada {
    // La fecha se obtiene siempre del sistema, nunca se ingresa manualmente.
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final ahora = DateTime.now();
    return '${dias[ahora.weekday - 1]}, ${ahora.day} de ${meses[ahora.month - 1]} · ${ahora.year}';
  }
 
  String _formatearHora(DateTime fecha) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(fecha.hour)}:${d(fecha.minute)}';
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      // El chat vuelve cuando haya un servicio activo con una familia.
      floatingActionButton: const ChatFab(),
      bottomNavigationBar: CuidadorBottomNav(
        seleccionada: PestanaCuidador.inicio,
        nombreCuidador: widget.nombreCuidador,
        servicio: _servicioActivo,
        actividades: _actividades,),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('HOLA,', style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 0.5)),
                          ],
                        ),
                        Row(
                          children: [
                            Text(widget.nombreCuidador, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            const Icon(Icons.waving_hand_rounded, color: Colors.amber, size: 22),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_fechaFormateada, style: const TextStyle(color: Colors.blue, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Contador(numero: _pendientes, etiqueta: 'Pendientes', color: Colors.orange),
                  const SizedBox(width: 10),
                  _Contador(numero: _realizadas, etiqueta: 'Realizadas', color: Colors.green),
                  const SizedBox(width: 10),
                  _Contador(numero: _noRealizadas, etiqueta: 'No realizadas', color: Colors.red),
                ],
              ),
              const SizedBox(height: 16),
              if (_cargandoSolicitudes) ...[
                const Row(
                  children: [
                    SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Cargando solicitudes…', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_errorSolicitudes != null) ...[
                Row(
                  children: [
                    Expanded(child: Text(_errorSolicitudes!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                    TextButton(onPressed: _cargarSolicitudes, child: const Text('Reintentar')),
                  ],
                ),
                const SizedBox(height: 8),
              ] else if (_solicitudesNuevas > 0) ...[
                _TarjetaSolicitudesNuevas(
                  cantidad: _solicitudesNuevas,
                  onTap: _abrirSolicitudes,
                ),
                const SizedBox(height: 16),
              ] else if (_solicitudes.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _abrirSolicitudes,
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Ver historial de solicitudes'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_servicioActivo == null)
                const _TarjetaVacia(
                  icono: Icons.medical_information_outlined,
                  texto: 'No tienes servicios activos',
                )
              else
                _TarjetaServicioActivo(
                  servicio: _servicioActivo!,
                  actividadesHoy: _actividadesHoy.length,
                  onVerServicio: () async {
                    final actualizado = await Navigator.push<ServicioActivo>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleServicioScreen(servicio: _servicioActivo!, actividades: _actividades),
                      ),
                    );
                    if (actualizado != null) {
                      setState(() {
                        if (actualizado.estaFinalizado) {
                          // Ya no está en curso: la tarjeta desaparece al instante.
                          _servicioActivo = null;
                          _actividades.clear();
                        } else {
                          _servicioActivo = actualizado;
                        }
                      });
                    }
                    if (mounted) _actualizarServicioActivo();
                  },
                ),
              const SizedBox(height: 16),
              if (_proximaActividad == null)
                _TarjetaVacia(
                  icono: Icons.event_available,
                  texto: _actividadesHoy.isEmpty ? 'No tienes actividades para hoy' : 'No quedan actividades pendientes para hoy',
                )
              else
                _TarjetaProximaActividad(
                  actividad: _proximaActividad!,
                  horaTexto: _formatearHora(_proximaActividad!.horaProgramada),
                  onVerTodas: _abrirActividades,
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Actividades de hoy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _abrirActividades,
                    child: const Text('Ver todas →'),
                  ),
                ],
              ),
              for (final actividad in _actividadesHoy)
                _FilaActividadHoy(
                  actividad: actividad,
                  horaTexto: _formatearHora(actividad.horaProgramada),
                  onTap: _abrirActividades,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
 
class _Contador extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final Color color;
 
  const _Contador({required this.numero, required this.etiqueta, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('$numero', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(etiqueta, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
 
class _TarjetaVacia extends StatelessWidget {
  final IconData icono;
  final String texto;
 
  const _TarjetaVacia({required this.icono, required this.texto});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icono, size: 32, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(texto, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
 
class _TarjetaServicioActivo extends StatelessWidget {
  final ServicioActivo servicio;
  final int actividadesHoy;
  final VoidCallback onVerServicio;
 
  const _TarjetaServicioActivo({required this.servicio, required this.actividadesHoy, required this.onVerServicio});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Servicio activo', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text('Activo', style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(radius: 26, backgroundColor: Color(0xFFF6D998), child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(servicio.nombreAdultoMayor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (servicio.edad != null) Text('${servicio.edad} años', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(servicio.familiarResponsable, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DatoServicio(etiqueta: 'INICIO', valor: _formatearFecha(servicio.fechaInicio)),
              ),
              Expanded(
                child: _DatoServicio(etiqueta: 'ACTIVIDADES HOY', valor: '$actividadesHoy asignadas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onVerServicio,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Ver servicio →'),
          ),
        ],
      ),
    );
  }
 
  String _formatearFecha(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${f.year}-${d(f.month)}-${d(f.day)}';
  }
}
 
class _DatoServicio extends StatelessWidget {
  final String etiqueta;
  final String valor;
 
  const _DatoServicio({required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.4)),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
 
class _TarjetaProximaActividad extends StatelessWidget {
  final ActividadCuidador actividad;
  final String horaTexto;
  final VoidCallback onVerTodas;
 
  const _TarjetaProximaActividad({required this.actividad, required this.horaTexto, required this.onVerTodas});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFDFF3E3), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PRÓXIMA ACTIVIDAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(actividad.tipo.icono, color: actividad.tipo.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actividad.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (actividad.descripcion != null)
                      Text(actividad.descripcion!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text(horaTexto, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onVerTodas,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              foregroundColor: Colors.green[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Ver todas las actividades →'),
          ),
        ],
      ),
    );
    
  }
}
class _TarjetaSolicitudesNuevas extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;
 
  const _TarjetaSolicitudesNuevas({required this.cantidad, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFDF3D8), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: Colors.orange[200], child: Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Solicitudes nuevas', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Revisa los datos antes de aceptar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
 
/// Una actividad de hoy en la lista del inicio: hora, estado y cuántas
/// observaciones tiene.
class _FilaActividadHoy extends StatelessWidget {
  final ActividadCuidador actividad;
  final String horaTexto;
  final VoidCallback onTap;
 
  const _FilaActividadHoy({required this.actividad, required this.horaTexto, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    final Color color;
    final String etiqueta;
 
    switch (actividad.estado) {
      case EstadoActividadCuidador.realizada:
        color = Colors.green;
        etiqueta = 'Realizada';
        break;
      case EstadoActividadCuidador.noRealizada:
        color = Colors.red;
        etiqueta = 'No realizada';
        break;
      case EstadoActividadCuidador.pendiente:
        color = Colors.orange;
        etiqueta = 'Pendiente';
        break;
    }
 
    final cantidadObservaciones = actividad.observaciones.length;
 
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(actividad.tipo.icono, color: actividad.tipo.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actividad.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (actividad.descripcion != null)
                      Text(
                        actividad.descripcion!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    if (cantidadObservaciones > 0)
                      Text(
                        cantidadObservaciones == 1 ? '1 observación' : '$cantidadObservaciones observaciones',
                        style: const TextStyle(fontSize: 11, color: Colors.deepPurple),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(horaTexto, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(etiqueta, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}