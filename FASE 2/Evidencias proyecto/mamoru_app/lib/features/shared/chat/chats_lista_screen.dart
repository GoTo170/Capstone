import 'package:flutter/material.dart';
 
import '../../../core/api_exception.dart';
import 'chat_screen.dart';
import 'chat_service.dart';
 
/// Conversaciones del usuario: una por cada servicio aceptado o finalizado.
class ChatsListaScreen extends StatefulWidget {
  const ChatsListaScreen({super.key});
 
  @override
  State<ChatsListaScreen> createState() => _ChatsListaScreenState();
}
 
class _ChatsListaScreenState extends State<ChatsListaScreen> {
  List<ChatResumen> _chats = [];
  bool _cargando = true;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _cargar();
  }
 
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final lista = await ChatService.listarChats();
      if (!mounted) return;
      setState(() {
        _chats = lista;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silencioso) _error = e.mensaje;
        _cargando = false;
      });
    }
  }
 
  Future<void> _abrir(ChatResumen chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          solicitudId: chat.solicitudId,
          nombreContacto: chat.contactoNombre,
          subtitulo: 'Servicio para ${chat.adultoMayorNombre}',
          puedeEscribir: chat.puedeEscribir,
        ),
      ),
    );
    // Al volver, se actualizan los números de mensajes sin leer.
    _cargar(silencioso: true);
  }
 
  String _hora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    final hoy = DateTime.now();
    if (f.year == hoy.year && f.month == hoy.month && f.day == hoy.day) {
      return '${d(f.hour)}:${d(f.minute)}';
    }
    return '${d(f.day)}/${d(f.month)}';
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Mensajes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _cuerpo(),
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
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
 
    if (_chats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Aún no tienes conversaciones.\nEl chat se habilita cuando un cuidador acepta una solicitud.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }
 
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TarjetaChat(chat: _chats[i], hora: _chats[i].ultimoMensajeEn == null ? null : _hora(_chats[i].ultimoMensajeEn!), onTap: () => _abrir(_chats[i])),
      ),
    );
  }
}
 
class _TarjetaChat extends StatelessWidget {
  final ChatResumen chat;
  final String? hora;
  final VoidCallback onTap;
 
  const _TarjetaChat({required this.chat, required this.hora, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    final inicial = chat.contactoNombre.trim().isEmpty ? '?' : chat.contactoNombre.trim()[0].toUpperCase();
    final tieneFoto = chat.contactoFotoUrl != null && chat.contactoFotoUrl!.isNotEmpty;
    final sinLeer = chat.noLeidos > 0;
 
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[100],
              backgroundImage: tieneFoto ? NetworkImage(chat.contactoFotoUrl!) : null,
              child: tieneFoto ? null : Text(inicial, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.contactoNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: sinLeer ? FontWeight.w800 : FontWeight.bold),
                        ),
                      ),
                      if (hora != null) Text(hora!, style: TextStyle(fontSize: 11, color: sinLeer ? Colors.pink : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Servicio para ${chat.adultoMayorNombre}${chat.finalizado ? ' · Finalizado' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.ultimoMensaje ?? 'Sin mensajes todavía',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: sinLeer ? Colors.black87 : Colors.grey[600],
                            fontWeight: sinLeer ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (sinLeer)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                          child: Text('${chat.noLeidos}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}