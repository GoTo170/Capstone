import 'package:flutter/material.dart';

enum EstadoActividadCuidador {
  pendiente,
  realizada,
  noRealizada,
}

enum TipoActividadCuidador {
  medicamento,
  comida,
  higiene,
  citaMedica,
  evento,
  mascota,
  recordatorio,
  otro,
}

extension TipoActividadCuidadorInfo on TipoActividadCuidador {
  IconData get icono {
    switch (this) {
      case TipoActividadCuidador.medicamento:
        return Icons.medication_rounded;

      case TipoActividadCuidador.comida:
        return Icons.restaurant_rounded;

      case TipoActividadCuidador.higiene:
        return Icons.clean_hands_rounded;

      case TipoActividadCuidador.citaMedica:
        return Icons.medical_services_rounded;

      case TipoActividadCuidador.evento:
        return Icons.celebration_rounded;

      case TipoActividadCuidador.mascota:
        return Icons.pets_rounded;

      case TipoActividadCuidador.recordatorio:
        return Icons.notifications_active_rounded;

      case TipoActividadCuidador.otro:
        return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TipoActividadCuidador.medicamento:
        return Colors.blue;

      case TipoActividadCuidador.comida:
        return Colors.orange;

      case TipoActividadCuidador.higiene:
        return Colors.teal;

      case TipoActividadCuidador.citaMedica:
        return Colors.redAccent;

      case TipoActividadCuidador.evento:
        return Colors.amber;

      case TipoActividadCuidador.mascota:
        return Colors.brown;

      case TipoActividadCuidador.recordatorio:
        return Colors.deepPurple;

      case TipoActividadCuidador.otro:
        return Colors.purple;
    }
  }
}

class ObservacionActividad {
  final DateTime fecha;
  final String texto;

  const ObservacionActividad({
    required this.fecha,
    required this.texto,
  });
}

class ActividadCuidador {
  final String id;

  final String adultoMayorId;

  final String titulo;
  final String? descripcion;

  final DateTime horaProgramada;

  final TipoActividadCuidador tipo;

  EstadoActividadCuidador estado;

  DateTime? horaRegistroEstado;

  final List<ObservacionActividad> observaciones;

  ActividadCuidador({
    required this.id,
    required this.adultoMayorId,
    required this.titulo,
    this.descripcion,
    required this.horaProgramada,
    required this.tipo,
    this.estado = EstadoActividadCuidador.pendiente,
    this.horaRegistroEstado,
    List<ObservacionActividad>? observaciones,
  }) : observaciones = observaciones ?? [];
}