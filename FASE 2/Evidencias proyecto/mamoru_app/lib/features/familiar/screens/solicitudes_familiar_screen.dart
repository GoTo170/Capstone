import 'package:flutter/material.dart';
import '../../shared/chat/chat_screen.dart';
import '../../../core/api_exception.dart';
import '../models/solicitud_enviada.dart';
import '../services/marketplace_service.dart';
 
class SolicitudesFamiliarScreen extends StatefulWidget {
  const SolicitudesFamiliarScreen({super.key});
 
  @override
  State<SolicitudesFamiliarScreen> createState() => _SolicitudesFamiliarScreenState();
}
 
enum _FiltroSolicitud { todas, pendiente, aceptada, rechazada, finalizada }
 
class _SolicitudesFamiliarScreenState extends State<SolicitudesFamiliarScreen> {
  _FiltroSolicitud _filtro = _FiltroSolicitud.todas;
 
  List<SolicitudEnviada> _solicitudes = [];
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
      final lista = await MarketplaceService.listarSolicitudes();
 
      if (!mounted) return;
 
      setState(() {
        _solicitudes = lista;
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
 
  @override
  Widget build(BuildContext context) {
    final pendientes = _solicitudes.where((s) => s.estado == EstadoSolicitudEnviada.pendiente).toList();
    final aceptadas = _solicitudes.where((s) => s.estado == EstadoSolicitudEnviada.aceptada).toList();
    final rechazadas = _solicitudes.where((s) => s.estado == EstadoSolicitudEnviada.rechazada).toList();
    final finalizadas = _solicitudes.where((s) => s.estado == EstadoSolicitudEnviada.finalizada).toList();
 
    final mostrarPendientes = _filtro == _FiltroSolicitud.todas || _filtro == _FiltroSolicitud.pendiente;
    final mostrarAceptadas = _filtro == _FiltroSolicitud.todas || _filtro == _FiltroSolicitud.aceptada;
    final mostrarRechazadas = _filtro == _FiltroSolicitud.todas || _filtro == _FiltroSolicitud.rechazada;
    final mostrarFinalizadas = _filtro == _FiltroSolicitud.todas || _filtro == _FiltroSolicitud.finalizada;
 
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFBD5D8), Color(0xFFFDEDEB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Solicitudes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Sigue tus servicios y conversaciones', style: TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChipFiltroSolicitud(texto: 'Todas', seleccionado: _filtro == _FiltroSolicitud.todas, onTap: () => setState(() => _filtro = _FiltroSolicitud.todas)),
                    const SizedBox(width: 8),
                    _ChipFiltroSolicitud(texto: 'Pendiente', seleccionado: _filtro == _FiltroSolicitud.pendiente, onTap: () => setState(() => _filtro = _FiltroSolicitud.pendiente)),
                    const SizedBox(width: 8),
                    _ChipFiltroSolicitud(texto: 'Aceptada', seleccionado: _filtro == _FiltroSolicitud.aceptada, onTap: () => setState(() => _filtro = _FiltroSolicitud.aceptada)),
                    const SizedBox(width: 8),
                    _ChipFiltroSolicitud(texto: 'Rechazada', seleccionado: _filtro == _FiltroSolicitud.rechazada, onTap: () => setState(() => _filtro = _FiltroSolicitud.rechazada)),
                    const SizedBox(width: 8),
                    _ChipFiltroSolicitud(texto: 'Finalizada', seleccionado: _filtro == _FiltroSolicitud.finalizada, onTap: () => setState(() => _filtro = _FiltroSolicitud.finalizada)),
                  ],
                ),
              ),
            ),
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
                      : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_solicitudes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: Text('Todavía no has enviado solicitudes.', style: TextStyle(color: Colors.grey))),
                    ),
                  if (mostrarPendientes && pendientes.isNotEmpty) ...[
                    _EtiquetaSeccion(texto: 'PENDIENTE (${pendientes.length})'),
                    const SizedBox(height: 10),
                    for (final s in pendientes) ...[_TarjetaSolicitud(solicitud: s), const SizedBox(height: 12)],
                  ],
                  if (mostrarAceptadas && aceptadas.isNotEmpty) ...[
                    _EtiquetaSeccion(texto: 'ACEPTADA (${aceptadas.length})'),
                    const SizedBox(height: 10),
                    for (final s in aceptadas) ...[_TarjetaSolicitud(solicitud: s), const SizedBox(height: 12)],
                  ],
                  if (mostrarRechazadas && rechazadas.isNotEmpty) ...[
                    _EtiquetaSeccion(texto: 'RECHAZADA (${rechazadas.length})'),
                    const SizedBox(height: 10),
                    for (final s in rechazadas) ...[_TarjetaSolicitud(solicitud: s), const SizedBox(height: 12)],
                  ],
                  if (mostrarFinalizadas && finalizadas.isNotEmpty) ...[
                    _EtiquetaSeccion(texto: 'FINALIZADA (${finalizadas.length})'),
                    const SizedBox(height: 10),
                    for (final s in finalizadas) ...[_TarjetaSolicitud(solicitud: s), const SizedBox(height: 12)],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _ChipFiltroSolicitud extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
 
  const _ChipFiltroSolicitud({required this.texto, required this.seleccionado, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: seleccionado ? Colors.pink : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: TextStyle(fontSize: 12, color: seleccionado ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
 
class _EtiquetaSeccion extends StatelessWidget {
  final String texto;
  const _EtiquetaSeccion({required this.texto});
 
  @override
  Widget build(BuildContext context) {
    return Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.6));
  }
}
 
class _TarjetaSolicitud extends StatelessWidget {
  final SolicitudEnviada solicitud;
  const _TarjetaSolicitud({required this.solicitud});
 
  Color get _color {
    switch (solicitud.estado) {
      case EstadoSolicitudEnviada.pendiente:
        return Colors.orange;
      case EstadoSolicitudEnviada.aceptada:
        return Colors.green;
      case EstadoSolicitudEnviada.rechazada:
        return Colors.red;
      case EstadoSolicitudEnviada.finalizada:
        return Colors.blueGrey;
    }
  }
 
  String get _etiqueta {
    switch (solicitud.estado) {
      case EstadoSolicitudEnviada.pendiente:
        return 'Pendiente';
      case EstadoSolicitudEnviada.aceptada:
        return 'Aceptada';
      case EstadoSolicitudEnviada.rechazada:
        return 'Rechazada';
      case EstadoSolicitudEnviada.finalizada:
        return 'Finalizada';
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(solicitud.nombreCuidador, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Para: ${solicitud.nombreAdultoMayor}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(_etiqueta, style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _DatoSolicitud(etiqueta: 'FECHA', valor: solicitud.fechaTexto)),
              Expanded(child: _DatoSolicitud(etiqueta: 'HORARIO', valor: solicitud.horarioTexto)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Servicio: ${solicitud.servicio}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          if (solicitud.estado == EstadoSolicitudEnviada.rechazada && solicitud.motivoRechazo != null) ...[
            const SizedBox(height: 6),
            Text('Motivo: ${solicitud.motivoRechazo}', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          if (solicitud.estado == EstadoSolicitudEnviada.aceptada) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(nombreContacto: solicitud.nombreCuidador, subtitulo: 'Chat del servicio activo')),
                ),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.pink, side: const BorderSide(color: Colors.pink)),
                child: const Text('Abrir chat'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
 
class _DatoSolicitud extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _DatoSolicitud({required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 0.4)),
        Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}