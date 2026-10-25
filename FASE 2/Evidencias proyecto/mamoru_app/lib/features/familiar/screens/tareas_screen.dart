import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../models/actividad.dart';
import '../services/tareas_service.dart';
import '../state/familiar_contexto.dart';
import 'nueva_actividad_screen.dart';
import 'seguimiento_screen.dart';
import '../widgets/familiar_bottom_nav.dart';
 
class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});
 
  @override
  State<TareasScreen> createState() => _TareasScreenState();
}
 
enum _Filtro { todas, pendientes, completadas, noRealizadas }
 
class _TareasScreenState extends State<TareasScreen> {
  DateTime _fechaSeleccionada = DateTime.now();
  _Filtro _filtro = _Filtro.todas;
 
  List<Actividad> _actividades = [];
  bool _cargando = true;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _cargar();
  }
 
  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
 
    try {
      await FamiliarContexto.cargar();
 
      final adulto = FamiliarContexto.seleccionado;
      final lista = adulto == null ? <Actividad>[] : await TareasService.listar(adulto.id);
 
      if (!mounted) return;
 
      setState(() {
        _actividades = lista;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }
 
  Future<void> _nuevaActividad() async {
    if (FamiliarContexto.seleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero vincula a un adulto mayor desde tu perfil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
 
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NuevaActividadScreen()));
    if (mounted) _cargar();
  }
 
  DateTime get _fechaMinimaFiltro => DateTime(2026, 1, 1);
  DateTime get _fechaMaximaFiltro => DateTime(DateTime.now().year + 1, 12, 31);
 
  List<Actividad> get _actividadesDelDia {
    final delDia = _actividades.where((a) =>
        a.fechaHora.year == _fechaSeleccionada.year &&
        a.fechaHora.month == _fechaSeleccionada.month &&
        a.fechaHora.day == _fechaSeleccionada.day);
 
    switch (_filtro) {
      case _Filtro.todas:
        return delDia.toList();
      case _Filtro.pendientes:
        return delDia.where((a) => a.estado == EstadoTarea.pendiente).toList();
      case _Filtro.completadas:
        return delDia.where((a) => a.estado == EstadoTarea.realizada).toList();
        case _Filtro.noRealizadas:
        return delDia.where((a) => a.estado == EstadoTarea.noRealizada).toList();
    }
  }
 
  Future<void> _elegirFecha() async {
    final nuevaFecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: _fechaMinimaFiltro,
      lastDate: _fechaMaximaFiltro,
    );
    if (nuevaFecha != null) setState(() => _fechaSeleccionada = nuevaFecha);
  }
 
  String _formatearFecha(DateTime fecha) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(fecha.day)}-${d(fecha.month)}-${fecha.year}';
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Actividades'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SeguimientoScreen(actividades: _actividades)),
                ),
                icon: const Icon(Icons.insights, size: 16),
                label: const Text('Seguimiento', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),
        ],
      ),
              floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.pink,
        onPressed: _nuevaActividad,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const FamiliarBottomNav(seleccionada: PestanaFamiliar.tareas),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Para ${FamiliarContexto.seleccionado?.nombreCompleto ?? 'tu adulto mayor'}', style: const TextStyle(color: Colors.pink)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _elegirFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatearFecha(_fechaSeleccionada)),
                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipFiltro(texto: 'Todas', seleccionado: _filtro == _Filtro.todas, onTap: () => setState(() => _filtro = _Filtro.todas)),
                  const SizedBox(width: 8),
                  _ChipFiltro(texto: 'Pendientes', seleccionado: _filtro == _Filtro.pendientes, onTap: () => setState(() => _filtro = _Filtro.pendientes)),
                  const SizedBox(width: 8),
                  _ChipFiltro(texto: 'Completadas', seleccionado: _filtro == _Filtro.completadas, onTap: () => setState(() => _filtro = _Filtro.completadas)),
                  const SizedBox(width: 8),
                  _ChipFiltro(texto: 'No realizadas', seleccionado: _filtro == _Filtro.noRealizadas, onTap: () => setState(() => _filtro = _Filtro.noRealizadas)),
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
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : _actividadesDelDia.isEmpty
                          ? const Center(child: Text('No hay actividades para este día.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                      itemCount: _actividadesDelDia.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _TarjetaActividad(actividad: _actividadesDelDia[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _ChipFiltro extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
 
  const _ChipFiltro({required this.texto, required this.seleccionado, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.pink : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto, style: TextStyle(color: seleccionado ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
 
class _TarjetaActividad extends StatelessWidget {
  final Actividad actividad;
 
  const _TarjetaActividad({required this.actividad});
 
  String _formatearHora(DateTime fecha) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(fecha.hour)}:${d(fecha.minute)} hrs';
  }
 
  @override
  Widget build(BuildContext context) {
    final completada = actividad.estado == EstadoTarea.realizada;
    final noRealizada = actividad.estado == EstadoTarea.noRealizada;
    final colorEstado = completada ? Colors.green : (noRealizada ? Colors.red : Colors.orange);
    final textoEstado = completada ? 'Realizada' : (noRealizada ? 'No realizada' : 'Pendiente');
    final iconoEstado = completada ? Icons.check_circle : (noRealizada ? Icons.cancel : Icons.hourglass_top);
 
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: completada ? Colors.grey.shade200 : Colors.pink.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: actividad.tipo.color.withValues(alpha: 0.15),
            child: Icon(actividad.tipo.icono, color: actividad.tipo.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        actividad.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: completada ? TextDecoration.lineThrough : null,
                          color: completada ? Colors.grey : Colors.black87,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(iconoEstado, size: 14, color: colorEstado),
                        const SizedBox(width: 4),
                        Text(
                          textoEstado,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorEstado),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: actividad.tipo.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(actividad.tipo.etiqueta, style: TextStyle(fontSize: 11, color: actividad.tipo.color, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(_formatearHora(actividad.fechaHora), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                if (actividad.notas != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(actividad.notas!, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}