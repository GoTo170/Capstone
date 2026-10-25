import 'package:flutter/material.dart';
 
enum TipoActividad { medicamento, comida, higiene, citaMedica, evento, mascota, recordatorio, otro }
 
extension TipoActividadInfo on TipoActividad {
  String get etiqueta {
    switch (this) {
      case TipoActividad.medicamento:
        return 'Medicamento';
      case TipoActividad.comida:
        return 'Comida';
      case TipoActividad.higiene:
        return 'Higiene';
      case TipoActividad.citaMedica:
        return 'Cita médica';
      case TipoActividad.evento:
        return 'Evento';
      case TipoActividad.mascota:
        return 'Mascota';
      case TipoActividad.recordatorio:
        return 'Recordatorio';
      case TipoActividad.otro:
        return 'Otro';
    }
  }
 
  IconData get icono {
    switch (this) {
      case TipoActividad.medicamento:
        return Icons.medication_rounded;
      case TipoActividad.comida:
        return Icons.restaurant_rounded;
      case TipoActividad.higiene:
        return Icons.clean_hands_rounded;
      case TipoActividad.citaMedica:
        return Icons.medical_services_rounded;
      case TipoActividad.evento:
        return Icons.celebration_rounded;
      case TipoActividad.mascota:
        return Icons.pets_rounded;
      case TipoActividad.recordatorio:
        return Icons.notifications_active_rounded;
      case TipoActividad.otro:
        return Icons.more_horiz_rounded;
    }
  }
 
  Color get color {
    switch (this) {
      case TipoActividad.medicamento:
        return Colors.blue;
      case TipoActividad.comida:
        return Colors.orange;
      case TipoActividad.higiene:
        return Colors.teal;
      case TipoActividad.citaMedica:
        return Colors.redAccent;
      case TipoActividad.evento:
        return Colors.amber[800]!;
      case TipoActividad.mascota:
        return Colors.brown;
      case TipoActividad.recordatorio:
        return Colors.deepPurple;
      case TipoActividad.otro:
        return Colors.purple;
    }
  }
}
 
enum EstadoTarea { pendiente, realizada, noRealizada }
 
enum FrecuenciaMedicamento { diaria, rangoDeDias, diaEspecifico }
 
class Actividad {
  final String? id;
  final String titulo;
  final TipoActividad tipo;
  final DateTime fechaHora;
  final String? notas;
  final EstadoTarea estado;
  final DateTime? horaRegistroEstado;
  final String? observacionCuidador;
  final DateTime? horaObservacion;
 
  const Actividad({
    this.id,
    required this.titulo,
    required this.tipo,
    required this.fechaHora,
    this.notas,
    required this.estado,
    this.horaRegistroEstado,
    this.observacionCuidador,
    this.horaObservacion,
  });
 
  Actividad copyWith({
    EstadoTarea? estado,
    DateTime? horaRegistroEstado,
    String? observacionCuidador,
    DateTime? horaObservacion,
  }) {
    return Actividad(
      id: id,
      titulo: titulo,
      tipo: tipo,
      fechaHora: fechaHora,
      notas: notas,
      estado: estado ?? this.estado,
      horaRegistroEstado: horaRegistroEstado ?? this.horaRegistroEstado,
      observacionCuidador: observacionCuidador ?? this.observacionCuidador,
      horaObservacion: horaObservacion ?? this.horaObservacion,
    );
  }
}