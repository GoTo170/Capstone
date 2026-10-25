import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../core/sesion.dart';
import '../../shared/services/notificaciones_service.dart';
import '../models/actividad.dart';
import '../services/familiar_service.dart';
import '../services/tareas_service.dart';
import '../state/familiar_contexto.dart';
import '../widgets/familiar_bottom_nav.dart';
import '../widgets/menu_navegacion_button.dart';
import 'alertas_screen.dart';
import 'tareas_screen.dart';
import 'vincular_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _cargando = true;
  String? _error;
  List<Actividad> _actividades = [];
  List<NotificacionApp> _notificaciones = [];

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
      final actividades = adulto == null ? <Actividad>[] : await TareasService.listar(adulto.id);
      final notificaciones = await NotificacionesService.listar();

      if (!mounted) return;

      setState(() {
        _actividades = actividades;
        _notificaciones = notificaciones;
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

  Future<void> _cambiarAdulto(String id) async {
    FamiliarContexto.seleccionar(id);
    await _cargar();
  }

  Future<void> _vincular() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VincularScreen()));
    if (mounted) _cargar();
  }

  void _irA(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  /// Actividades programadas para hoy, en orden de hora.
  List<Actividad> get _deHoy {
    final hoy = DateTime.now();
    return _actividades
        .where((a) => a.fechaHora.year == hoy.year && a.fechaHora.month == hoy.month && a.fechaHora.day == hoy.day)
        .toList();
  }

  String _hora(DateTime f) => '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

  String _horaAlerta(DateTime f) {
    final ahora = DateTime.now();
    final esHoy = f.year == ahora.year && f.month == ahora.month && f.day == ahora.day;
    if (esHoy) return _hora(f);
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}, ${_hora(f)}';
  }

  List<_Alerta> get _alertasRecientes {
    return _notificaciones.take(3).map((n) {
      final tipo = n.tipo == 'alerta_sos'
          ? _TipoAlerta.sos
          : n.tipo == 'tarea_vencida'
              ? _TipoAlerta.tareaAtrasada
              : _TipoAlerta.observacion;
      return _Alerta(tipo: tipo, texto: n.mensaje, hora: _horaAlerta(n.fecha));
    }).toList();
  }

  Widget _vistaError() {
    return Center(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final adulto = FamiliarContexto.seleccionado;
    final deHoy = _deHoy;
    final completadas = deHoy.where((a) => a.estado == EstadoTarea.realizada).length;
    final pendientes = deHoy.where((a) => a.estado == EstadoTarea.pendiente).length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFFF7F5),
        elevation: 0,
        title: const Text('BIENVENIDO/A', style: TextStyle(fontSize: 11, color: Colors.grey)),
        actions: const [MenuNavegacionButton()],
      ),
      // El chat vuelve cuando haya un servicio activo con un cuidador.
      bottomNavigationBar: const FamiliarBottomNav(seleccionada: PestanaFamiliar.inicio),
      backgroundColor: const Color(0xFFFFF7F5),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _vistaError()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                Sesion.usuario?.nombre ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.waving_hand_rounded, color: Colors.amber, size: 20),
                          ],
                        ),
                      ),
                      if (adulto == null)
                        _TarjetaSinAdultos(onVincular: _vincular)
                      else ...[
                        if (FamiliarContexto.adultos.length > 1) ...[
                          _SelectorAdulto(
                            adultos: FamiliarContexto.adultos,
                            seleccionadoId: adulto.id,
                            onSeleccionar: _cambiarAdulto,
                          ),
                          const SizedBox(height: 8),
                        ],
                        _TarjetaEstadoAdultoMayor(
                          nombre: adulto.nombreCompleto,
                          accesoActivado: adulto.accesoActivado,
                          onVerTareas: () => _irA(const TareasScreen()),
                        ),
                        const SizedBox(height: 12),
                        _TarjetaResumenActividades(completadas: completadas, pendientes: pendientes, total: deHoy.length),
                        const SizedBox(height: 16),
                        _TarjetaActividadesHoy(
                          actividades: deHoy
                              .take(5)
                              .map((a) => _Actividad(
                                    titulo: a.titulo,
                                    hora: _hora(a.fechaHora),
                                    completada: a.estado == EstadoTarea.realizada,
                                  ))
                              .toList(),
                          onVerTodas: () => _irA(const TareasScreen()),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _TarjetaAlertasRecientes(alertas: _alertasRecientes, onVerTodas: () => _irA(const AlertasScreen())),
                    ],
                  ),
                ),
    );
  }
}

// ---------- Modelos y widgets ya existentes (sin cambios) ----------

class _Actividad {
  final String titulo;
  final String hora;
  final bool completada;
  const _Actividad({required this.titulo, required this.hora, required this.completada});
}

enum _TipoAlerta { observacion, sos, tareaAtrasada }

class _Alerta {
  final _TipoAlerta tipo;
  final String texto;
  final String hora;
  const _Alerta({required this.tipo, required this.texto, required this.hora});
}

class _TarjetaEstadoAdultoMayor extends StatelessWidget {
  final String nombre;
  final bool accesoActivado;
  final VoidCallback onVerTareas;
  const _TarjetaEstadoAdultoMayor({required this.nombre, required this.accesoActivado, required this.onVerTareas});

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 28, backgroundColor: Color(0xFFF6D998), child: Icon(Icons.person, size: 32, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bajo tu cuidado', style: TextStyle(color: Colors.pink, fontSize: 12)),
                Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: accesoActivado ? Colors.green : Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      accesoActivado ? 'Con acceso activo' : 'Invitación pendiente',
                      style: TextStyle(color: accesoActivado ? Colors.green : Colors.orange, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(onPressed: onVerTareas, child: const Text('Ver tareas →')),
        ],
      ),
    );
  }
}

class _TarjetaResumenActividades extends StatelessWidget {
  final int completadas;
  final int pendientes;
  final int total;
  const _TarjetaResumenActividades({required this.completadas, required this.pendientes, required this.total});

  @override
  Widget build(BuildContext context) {
    final progreso = total == 0 ? 0.0 : completadas / total;
    return _Tarjeta(
      child: Column(
        children: [
          Row(
            children: [
              _CajaEstadistica(numero: completadas, etiqueta: 'Completadas', color: const Color(0xFFDFF3E3), colorTexto: Colors.green),
              const SizedBox(width: 10),
              _CajaEstadistica(numero: pendientes, etiqueta: 'Pendientes', color: const Color(0xFFFCE6E6), colorTexto: Colors.deepOrange),
              const SizedBox(width: 10),
              _CajaEstadistica(numero: total, etiqueta: 'Total', color: const Color(0xFFEDE3F7), colorTexto: Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progreso, minHeight: 8, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(Colors.green)),
          ),
        ],
      ),
    );
  }
}

class _CajaEstadistica extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final Color color;
  final Color colorTexto;
  const _CajaEstadistica({required this.numero, required this.etiqueta, required this.color, required this.colorTexto});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$numero', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorTexto)),
            const SizedBox(height: 4),
            Text(etiqueta, style: TextStyle(fontSize: 12, color: colorTexto)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaActividadesHoy extends StatelessWidget {
  final List<_Actividad> actividades;
  final VoidCallback onVerTodas;
  const _TarjetaActividadesHoy({required this.actividades, required this.onVerTodas});

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actividades de hoy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (actividades.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No hay actividades programadas para hoy.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ...actividades.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(radius: 16, backgroundColor: a.completada ? Colors.green[50] : Colors.grey[200], child: Icon(a.completada ? Icons.check : Icons.schedule, size: 16, color: a.completada ? Colors.green : Colors.grey[600])),
                  const SizedBox(width: 10),
                  Expanded(child: Text(a.titulo, style: TextStyle(decoration: a.completada ? TextDecoration.lineThrough : null, color: a.completada ? Colors.grey : Colors.black87))),
                  Text(a.hora, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: TextButton(onPressed: onVerTodas, child: const Text('Ver todas las actividades →'))),
        ],
      ),
    );
  }
}

class _TarjetaAlertasRecientes extends StatelessWidget {
  final List<_Alerta> alertas;
  final VoidCallback onVerTodas;
  const _TarjetaAlertasRecientes({required this.alertas, required this.onVerTodas});

  IconData _iconoPara(_TipoAlerta tipo) {
    switch (tipo) {
      case _TipoAlerta.observacion:
        return Icons.info_outline;
      case _TipoAlerta.sos:
        return Icons.warning_amber_rounded;
      case _TipoAlerta.tareaAtrasada:
        return Icons.schedule;
    }
  }

  Color _colorPara(_TipoAlerta tipo) {
    switch (tipo) {
      case _TipoAlerta.observacion:
        return Colors.blue;
      case _TipoAlerta.sos:
        return Colors.red;
      case _TipoAlerta.tareaAtrasada:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Alertas recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), TextButton(onPressed: onVerTodas, child: const Text('Ver todas'))]),
          if (alertas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin alertas por ahora.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ...alertas.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconoPara(a.tipo), size: 20, color: _colorPara(a.tipo)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.texto, style: const TextStyle(fontSize: 13)), Text(a.hora, style: TextStyle(fontSize: 11, color: Colors.grey[600]))])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;
  const _Tarjeta({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: child,
    );
  }
}


class _TarjetaSinAdultos extends StatelessWidget {
  final VoidCallback onVincular;
  const _TarjetaSinAdultos({required this.onVincular});

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Aún no tienes adultos mayores vinculados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Invita a la persona que cuidas para ver sus actividades y recibir sus alertas.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onVincular,
            icon: const Icon(Icons.link),
            label: const Text('Vincular adulto mayor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorAdulto extends StatelessWidget {
  final List<AdultoVinculado> adultos;
  final String seleccionadoId;
  final ValueChanged<String> onSeleccionar;

  const _SelectorAdulto({required this.adultos, required this.seleccionadoId, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final adulto in adultos)
          ChoiceChip(
            label: Text(adulto.nombreCompleto),
            selected: adulto.id == seleccionadoId,
            selectedColor: Colors.pink[100],
            onSelected: (_) => onSeleccionar(adulto.id),
          ),
      ],
    );
  }
}