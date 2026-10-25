import 'package:flutter/material.dart';
import 'chat_mensaje.dart';

class ChatScreen extends StatefulWidget {
  final String nombreContacto;
  final String subtitulo;

  const ChatScreen({super.key, required this.nombreContacto, required this.subtitulo});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _mensajeController = TextEditingController();

  // Datos de ejemplo (mock), aún sin conexión al backend.
  late final List<ChatMensaje> _mensajes = [
    ChatMensaje(texto: 'Hola Carlos, ya acepté la solicitud para cuidar a Rosa.', esPropio: false, hora: DateTime(2026, 9, 6, 10, 18)),
    ChatMensaje(texto: 'Gracias, María. Te envío las indicaciones de sus medicamentos.', esPropio: true, hora: DateTime(2026, 9, 6, 10, 21)),
    ChatMensaje(texto: 'Perfecto, las revisaré antes de llegar.', esPropio: false, hora: DateTime(2026, 9, 6, 10, 23)),
  ];

  bool get _puedeEnviar => _mensajeController.text.trim().isNotEmpty;

  String _formatearHora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    final horas12 = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final ampm = f.hour < 12 ? 'a.m.' : 'p.m.';
    return '$horas12:${d(f.minute)} $ampm';
  }

  void _enviar() {
    if (!_puedeEnviar) return;
    setState(() {
      _mensajes.add(ChatMensaje(texto: _mensajeController.text.trim(), esPropio: true, hora: DateTime.now()));
      _mensajeController.clear();
    });
    // Todo: aquí se enviará el mensaje real por WebSocket/API cuando conectemos el backend.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 6)]),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  CircleAvatar(radius: 18, backgroundColor: Colors.blue[100], child: Text(widget.nombreContacto[0], style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nombreContacto, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(widget.subtitulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Hoy', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final m in _mensajes) _BurbujaMensaje(mensaje: m, horaTexto: _formatearHora(m.hora)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 6, offset: const Offset(0, -2))]),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
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
                    backgroundColor: _puedeEnviar ? Colors.pink : Colors.pink.withValues(alpha:0.3),
                    child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 18), onPressed: _puedeEnviar ? _enviar : null),
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