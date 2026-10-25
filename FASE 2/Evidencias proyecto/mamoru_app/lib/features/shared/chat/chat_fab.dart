import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ChatFab extends StatelessWidget {
  final String nombreContacto;
  final String subtitulo;
  final int mensajesNoLeidos;

  const ChatFab({super.key, required this.nombreContacto, required this.subtitulo, this.mensajesNoLeidos = 0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.pink,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(nombreContacto: nombreContacto, subtitulo: subtitulo)),
          ),
          child: const Icon(Icons.forum),
        ),
        if (mensajesNoLeidos > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text('$mensajesNoLeidos', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}