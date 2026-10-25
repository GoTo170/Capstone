import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../../shared/services/notificaciones_service.dart';
import '../models/alerta_familiar.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<AlertaFamiliar> _alertas = [];
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
      final notificaciones = await NotificacionesService.listar();

      if (!mounted) return;

      setState(() {
        _alertas = notificaciones.map(_aAlerta).toList();
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

  AlertaFamiliar _aAlerta(NotificacionApp n) {
    final TipoAlertaFamiliar tipo;
    final String titulo;

    if (n.tipo == 'alerta_sos') {
      tipo = TipoAlertaFamiliar.sos;
      titulo = 'Emergencia SOS';
    } else if (n.tipo == 'tarea_vencida') {
      tipo = TipoAlertaFamiliar.tareaVencida;
      titulo = 'Tarea vencida';
    } else {
      tipo = TipoAlertaFamiliar.informacion;
      titulo = 'Información';
    }

    return AlertaFamiliar(id: n.id, tipo: tipo, titulo: titulo, texto: n.mensaje, hora: n.fecha, leida: n.leida);
  }

  void _mostrarError(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  int get _sinLeer => _alertas.where((a) => !a.leida).length;

  Future<void> _marcarTodasComoLeidas() async {
    try {
      await NotificacionesService.marcarTodasLeidas();

      if (!mounted) return;

      setState(() {
        for (final a in _alertas) {
          a.leida = true;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _mostrarError(e.mensaje);
    }
  }

  Future<void> _marcarLeida(AlertaFamiliar alerta) async {
    final id = alerta.id;
    if (alerta.leida || id == null) return;

    try {
      await NotificacionesService.marcarLeida(id);

      if (!mounted) return;

      setState(() => alerta.leida = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _mostrarError(e.mensaje);
    }
  }

  String _formatearHora(DateTime f) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    String d(int n) => n.toString().padLeft(2, '0');
    final horas12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final ampm = f.hour < 12 ? 'a.m.' : 'p.m.';
    return '${d(f.day)}-${meses[f.month - 1]}, $horas12:${d(f.minute)} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Alertas'),
      ),
      backgroundColor: const Color(0xFFFFF7F5),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(_sinLeer > 0 ? '$_sinLeer sin leer' : 'Todo al día', style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_sinLeer > 0)
                  TextButton(onPressed: _marcarTodasComoLeidas, child: const Text('Marcar todas como leídas')),
              ],
            ),
            const SizedBox(height: 8),
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
                      : _alertas.isEmpty
                          ? const Center(child: Text('No tienes alertas por ahora.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                itemCount: _alertas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _TarjetaAlerta(
                  alerta: _alertas[index],
                  onTap: () => _marcarLeida(_alertas[index]),
                  horaTexto: _formatearHora(_alertas[index].hora),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaAlerta extends StatelessWidget {
  final AlertaFamiliar alerta;
  final VoidCallback onTap;
  final String horaTexto;

  const _TarjetaAlerta({required this.alerta, required this.onTap, required this.horaTexto});

  IconData get _icono {
    switch (alerta.tipo) {
      case TipoAlertaFamiliar.informacion:
        return Icons.info_outline;
      case TipoAlertaFamiliar.sos:
        return Icons.warning_amber_rounded;
      case TipoAlertaFamiliar.tareaVencida:
        return Icons.schedule;
    }
  }

  Color get _color {
    switch (alerta.tipo) {
      case TipoAlertaFamiliar.informacion:
        return Colors.blue;
      case TipoAlertaFamiliar.sos:
        return Colors.red;
      case TipoAlertaFamiliar.tareaVencida:
        return Colors.orange;
    }
  }

  bool get _destacada => alerta.tipo != TipoAlertaFamiliar.informacion;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _destacada ? _color.withOpacity(0.4) : Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 16, backgroundColor: _color.withOpacity(0.12), child: Icon(_icono, size: 16, color: _color)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(alerta.titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _color)),
                      if (!alerta.leida) ...[
                        const SizedBox(width: 5),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alerta.texto,
                    style: TextStyle(fontSize: 13, fontWeight: alerta.leida ? FontWeight.normal : FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(horaTexto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}