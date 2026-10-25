import 'dart:io';

import 'package:flutter/material.dart';

/// Foto redonda de una persona. Muestra, en este orden:
/// 1. el archivo local, si se acaba de elegir (se ve al instante mientras sube);
/// 2. la foto guardada en el servidor (por su dirección);
/// 3. un ícono, si no hay foto o no se pudo cargar.
class AvatarFoto extends StatelessWidget {
  final double radio;
  final String? url;
  final File? archivo;
  final Color colorFondo;
  final Widget iconoVacio;

  const AvatarFoto({
    super.key,
    required this.radio,
    required this.iconoVacio,
    this.url,
    this.archivo,
    this.colorFondo = const Color(0xFFD6E8F7),
  });

  @override
  Widget build(BuildContext context) {
    final lado = radio * 2;

    final vacio = Container(
      width: lado,
      height: lado,
      color: colorFondo,
      alignment: Alignment.center,
      child: iconoVacio,
    );

    final foto = archivo;
    final direccion = url;
    final Widget contenido;

    if (foto != null) {
      contenido = Image.file(
        foto,
        width: lado,
        height: lado,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => vacio,
      );
    } else if (direccion != null && direccion.isNotEmpty) {
      contenido = Image.network(
        direccion,
        width: lado,
        height: lado,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => vacio,
        // Mientras carga se ve el ícono, y luego la foto.
        loadingBuilder: (context, hijo, progreso) => progreso == null ? hijo : vacio,
      );
    } else {
      contenido = vacio;
    }

    return ClipOval(
      child: SizedBox(width: lado, height: lado, child: contenido),
    );
  }
}