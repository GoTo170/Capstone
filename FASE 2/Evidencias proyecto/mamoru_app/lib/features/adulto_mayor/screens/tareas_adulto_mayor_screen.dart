import 'dart:async';
 
import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../../familiar/models/actividad.dart';
import '../../familiar/services/tareas_service.dart';
import '../../../core/sesion.dart';
import '../widgets/adulto_mayor_bottom_nav.dart';
 
class TareasAdultoMayorScreen extends StatefulWidget {
  /// Ya no se usa: las tareas se piden al servidor.
  final List<Actividad>? actividades;
 
  const TareasAdultoMayorScreen({super.key, this.actividades});
 
  @override
  State<TareasAdultoMayorScreen> createState() => _TareasAdultoMayorScreenState();
}
 
class _TareasAdultoMayorScreenState extends State<TareasAdultoMayorScreen> {
  List<Actividad> _actividades = [];
  bool _cargando = true;
  String? _error;
  Timer? _timer;
 
  @override
  void initState() {
    super.initState();
    // Se actualiza solo cada 30 segundos, por si la familia agrega tareas.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar(silencioso: true));
    _cargar();
  }
 
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
 
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
    } on ApiException catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }
 
  String get _fechaCompleta {
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final ahora = DateTime.now();
    final dia = dias[ahora.weekday - 1];
    final diaCapitalizado = dia[0].toUpperCase() + dia.substring(1);
    return '$diaCapitalizado, ${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}';
  }
 
  @override
  Widget build(BuildContext context) {
    final actividadesOrdenadas = _actividades;
 
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAFF),
      bottomNavigationBar: AdultoMayorBottomNav(
        seleccionada: PestanaAdultoMayor.tareas,
        nombre: Sesion.usuario?.nombre ?? '',
        actividades: _actividades,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Mis tareas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_fechaCompleta, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El estado de las tareas se registra desde Inicio, en "Próxima actividad".',
                        style: TextStyle(fontSize: 12, color: Colors.deepPurple[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                                TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                              ],
                            ),
                          )
                        : actividadesOrdenadas.isEmpty
                            ? const Center(child: Text('No tienes tareas para hoy.', style: TextStyle(color: Colors.grey, fontSize: 15)))
                            : ListView.separated(
                  itemCount: actividadesOrdenadas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _TarjetaActividadInformativa(
                    actividad: actividadesOrdenadas[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
class _TarjetaActividadInformativa extends StatelessWidget {
  final Actividad actividad;
 
  const _TarjetaActividadInformativa({required this.actividad});
 
  String _formatearHora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.hour)}:${d(f.minute)} hrs';
  }
 
  Color get _colorBorde {
    switch (actividad.estado) {
      case EstadoTarea.realizada:
        return Colors.green.shade200;
      case EstadoTarea.noRealizada:
        return Colors.red.shade200;
      case EstadoTarea.pendiente:
        return Colors.orange.shade100;
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorBorde, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: actividad.tipo.color.withValues(alpha:0.15),
            child: Icon(actividad.tipo.icono, color: actividad.tipo.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(actividad.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    _EtiquetaEstado(estado: actividad.estado),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_formatearHora(actividad.fechaHora), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                if (actividad.notas != null) ...[
                  const SizedBox(height: 6),
                  Text(actividad.notas!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                if (actividad.estado == EstadoTarea.realizada && actividad.horaRegistroEstado != null) ...[
                  const SizedBox(height: 6),
                  Text('Completada a las ${_formatearHora(actividad.horaRegistroEstado!)}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _EtiquetaEstado extends StatelessWidget {
  final EstadoTarea estado;
 
  const _EtiquetaEstado({required this.estado});
 
  @override
  Widget build(BuildContext context) {
    late final String texto;
    late final Color color;
 
    switch (estado) {
      case EstadoTarea.pendiente:
        texto = 'Pendiente';
        color = Colors.orange;
        break;
      case EstadoTarea.realizada:
        texto = 'Completada';
        color = Colors.green;
        break;
      case EstadoTarea.noRealizada:
        texto = 'No realizada';
        color = Colors.red;
        break;
    }
 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha:0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}