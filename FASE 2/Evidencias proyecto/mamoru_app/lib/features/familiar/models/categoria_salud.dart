import 'package:flutter/material.dart';

class CategoriaSalud {
  final String nombre;
  final String preguntaCorta; // ej: "enfermedad o condición de salud"
  final int maxItems;
  final int minCaracteres;
  final int maxCaracteres;
  final String ejemplo;

  bool? tiene; // null = aún no responde
  List<TextEditingController> itemsControllers = [];

  CategoriaSalud({
    required this.nombre,
    required this.preguntaCorta,
    required this.maxItems,
    required this.minCaracteres,
    required this.maxCaracteres,
    required this.ejemplo,
  });

  bool get itemValido {
    if (tiene != true) return true; // si respondió "No", no hay nada que validar
    if (itemsControllers.isEmpty) return false;
    return itemsControllers.every((c) {
      final largo = c.text.trim().length;
      return largo >= minCaracteres && largo <= maxCaracteres;
    });
  }

  bool get respondida => tiene != null;
}