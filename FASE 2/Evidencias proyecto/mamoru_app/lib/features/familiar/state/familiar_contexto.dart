import '../../../core/sesion.dart';
import '../services/familiar_service.dart';

/// Adulto mayor "activo" del familiar: el que se ve en Inicio y Actividades.
///
/// Un familiar puede tener hasta 2. Por defecto se usa el primero y, si tiene
/// dos, puede cambiar desde la pantalla de Inicio.
class FamiliarContexto {
  static String? _usuarioId;
  static List<AdultoVinculado> _adultos = [];
  static String? _seleccionadoId;

  static List<AdultoVinculado> get adultos => _adultos;

  static AdultoVinculado? get seleccionado {
    if (_adultos.isEmpty) return null;
    for (final adulto in _adultos) {
      if (adulto.id == _seleccionadoId) return adulto;
    }
    return _adultos.first;
  }

  static void seleccionar(String id) {
    _seleccionadoId = id;
  }

  /// Pide al servidor la lista de adultos mayores vinculados.
  static Future<void> cargar() async {
    final miId = Sesion.usuario?.id;

    // Si entrÃ³ otro usuario en este mismo celular, se parte de cero.
    if (_usuarioId != miId) {
      _usuarioId = miId;
      _adultos = [];
      _seleccionadoId = null;
    }

    _adultos = await FamiliarService.listarAdultosMayores();
  }
}