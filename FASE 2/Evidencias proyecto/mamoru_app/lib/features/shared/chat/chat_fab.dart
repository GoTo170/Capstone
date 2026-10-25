import 'dart:async';
 
import 'package:flutter/material.dart';
 
import 'chat_service.dart';
import 'chats_lista_screen.dart';
 
/// Botón flotante de mensajes. Se muestra solo si hay conversaciones
/// (servicios aceptados) y lleva el número de mensajes sin leer.
///
/// Los datos [nombreContacto], [subtitulo] y [mensajesNoLeidos] ya no se usan:
/// se conservan para que los lugares que todavía los pasan sigan compilando.
class ChatFab extends StatefulWidget {
  final String? nombreContacto;
  final String? subtitulo;
  final int mensajesNoLeidos;
 
  const ChatFab({super.key, this.nombreContacto, this.subtitulo, this.mensajesNoLeidos = 0});
 
  @override
  State<ChatFab> createState() => _ChatFabState();
}
 
class _ChatFabState extends State<ChatFab> {
  bool _hayChats = false;
  int _noLeidos = 0;
  Timer? _temporizador;
 
  @override
  void initState() {
    super.initState();
    _actualizar();
    _temporizador = Timer.periodic(const Duration(seconds: 20), (_) => _actualizar());
  }
 
  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }
 
  Future<void> _actualizar() async {
    try {
      final chats = await ChatService.listarChats();
      if (!mounted) return;
      setState(() {
        _hayChats = chats.isNotEmpty;
        _noLeidos = ChatService.totalNoLeidos(chats);
      });
    } catch (_) {
      // Sin conexión: se conserva lo último que se mostró.
    }
  }
 
  Future<void> _abrir() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsListaScreen()));
    _actualizar();
  }
 
  @override
  Widget build(BuildContext context) {
    if (!_hayChats) return const SizedBox.shrink();
 
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.pink,
          onPressed: _abrir,
          child: const Icon(Icons.forum),
        ),
        if (_noLeidos > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _noLeidos > 99 ? '99+' : '$_noLeidos',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}