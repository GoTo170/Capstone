import 'dart:async';
 
import 'package:flutter/material.dart';
 
import '../../../core/api_exception.dart';
import 'chat_mensaje.dart';
import 'chat_service.dart';
 
/// Conversación entre la familia y el cuidador de un servicio.
class ChatScreen extends StatefulWidget {
  final String solicitudId;
  final String nombreContacto;
  final String subtitulo;
 
  /// Si es false, el servicio ya terminó y el chat es solo de lectura.
  final bool puedeEscribir;
 
  const ChatScreen({
    super.key,
    required this.solicitudId,
    required this.nombreContacto,
    required this.subtitulo,
    this.puedeEscribir = true,
  });
 
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
 
class _ChatScreenState extends State<ChatScreen> {
  static const int _largoMaximo = 1000;
  static const Duration _cadaCuanto = Duration(seconds: 4);
 
  final _mensajeController = TextEditingController();
  final _scroll = ScrollController();
 
  final List<ChatMensaje> _mensajes = [];
  bool _cargando = true;
  String? _error;
  bool _enviando = false;
  bool _actualizando = false;
  late bool _soloLectura = !widget.puedeEscribir;
  Timer? _temporizador;
 
  bool get _puedeEnviar => !_enviando && _mensajeController.text.trim().isNotEmpty;
 
  @override
  void initState() {
    super.initState();
    _cargarTodo();
    _temporizador = Timer.periodic(_cadaCuanto, (_) => _buscarNuevos());
  }
 
  @override
  void dispose() {
    _temporizador?.cancel();
    _mensajeController.dispose();
    _scroll.dispose();
    super.dispose();
  }
 
  // ------------------------------------------------------------ datos
 
  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ChatService.listarMensajes(widget.solicitudId);
      if (!mounted) return;
      setState(() {
        _mensajes
          ..clear()
          ..addAll(lista);
        _cargando = false;
      });
      _irAlFinal(forzar: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }
 
  /// Trae solo lo nuevo. Pide desde unos segundos antes del último mensaje
  /// (por si dos se guardaron casi a la vez) y descarta los que ya están.
  Future<void> _buscarNuevos() async {
    if (_actualizando || _cargando || _error != null || !mounted) return;
    _actualizando = true;
    try {
      final DateTime? desde =
          _mensajes.isEmpty ? null : _mensajes.last.creadoUtc.subtract(const Duration(seconds: 5));
      final lista = await ChatService.listarMensajes(widget.solicitudId, despuesDe: desde);
      if (!mounted) return;
      final nuevos = _sinRepetidos(lista);
      if (nuevos.isNotEmpty) {
        final alFinal = _estaCercaDelFinal();
        setState(() => _mensajes.addAll(nuevos));
        _ordenar();
        if (alFinal) _irAlFinal();
      }
    } catch (_) {
      // Sin conexión por un momento: se vuelve a intentar en el siguiente ciclo.
    } finally {
      _actualizando = false;
    }
  }
 
  List<ChatMensaje> _sinRepetidos(List<ChatMensaje> lista) {
    final ids = _mensajes.map((m) => m.id).toSet();
    return lista.where((m) => !ids.contains(m.id)).toList();
  }
 
  void _ordenar() {
    setState(() => _mensajes.sort((a, b) => a.creadoUtc.compareTo(b.creadoUtc)));
  }
 
  Future<void> _enviar() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _enviando) return;
 
    setState(() => _enviando = true);
    try {
      final enviado = await ChatService.enviar(widget.solicitudId, texto);
      if (!mounted) return;
      _mensajeController.clear();
      setState(() {
        if (!_mensajes.any((m) => m.id == enviado.id)) _mensajes.add(enviado);
      });
      _ordenar();
      _irAlFinal(forzar: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.mensaje.contains('solo lectura')) {
        setState(() => _soloLectura = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
 
  // ------------------------------------------------------------ scroll
 
  bool _estaCercaDelFinal() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;
  }
 
  void _irAlFinal({bool forzar = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (!forzar && !_estaCercaDelFinal()) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
 
  // ------------------------------------------------------------ formato
 
  String _formatearHora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    final horas12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final ampm = f.hour < 12 ? 'a.m.' : 'p.m.';
    return '$horas12:${d(f.minute)} $ampm';
  }
 
  String _etiquetaDia(DateTime f) {
    final hoy = DateTime.now();
    final dia = DateTime(f.year, f.month, f.day);
    final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);
    final diferencia = hoySolo.difference(dia).inDays;
    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.day)}/${d(f.month)}/${f.year}';
  }
 
  bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
 
  // ------------------------------------------------------------ vista
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Column(
          children: [
            _encabezado(),
            Expanded(child: _cuerpo()),
            _soloLectura ? _avisoSoloLectura() : _barraEscribir(),
          ],
        ),
      ),
    );
  }
 
  Widget _encabezado() {
    final inicial = widget.nombreContacto.trim().isEmpty ? '?' : widget.nombreContacto.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue[100],
            child: Text(inicial, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nombreContacto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.subtitulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
 
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              TextButton(onPressed: _cargarTodo, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
 
    if (_mensajes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay mensajes.\nEscribe el primero para coordinar el servicio.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }
 
    final elementos = <Widget>[];
    DateTime? ultimoDia;
    for (final m in _mensajes) {
      if (ultimoDia == null || !_mismoDia(ultimoDia, m.hora)) {
        elementos.add(_separadorDia(_etiquetaDia(m.hora)));
        ultimoDia = m.hora;
      }
      elementos.add(_BurbujaMensaje(mensaje: m, horaTexto: _formatearHora(m.hora)));
    }
 
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: elementos,
    );
  }
 
  Widget _separadorDia(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
          child: Text(texto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ),
    );
  }
 
  Widget _avisoSoloLectura() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      color: Colors.white,
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'El servicio finalizó. Este chat es solo de lectura.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _barraEscribir() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _mensajeController,
              onChanged: (_) => setState(() {}),
              minLines: 1,
              maxLines: 4,
              maxLength: _largoMaximo,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: _puedeEnviar ? Colors.pink : Colors.pink.withValues(alpha: 0.3),
            child: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                    onPressed: _puedeEnviar ? _enviar : null,
                  ),
          ),
        ],
      ),
    );
  }
}
 
class _BurbujaMensaje extends StatelessWidget {
  final ChatMensaje mensaje;
  final String horaTexto;
 
  const _BurbujaMensaje({required this.mensaje, required this.horaTexto});
 
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mensaje.esPropio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: mensaje.esPropio ? Colors.pink[100] : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje.texto, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text(horaTexto, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
 