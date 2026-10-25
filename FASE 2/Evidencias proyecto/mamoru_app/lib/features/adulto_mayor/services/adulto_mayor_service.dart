import '../../../core/api_client.dart';
 
/// Familiar vinculado, visto desde el perfil del adulto mayor.
class FamiliarDelAdulto {
  final String nombre;
  final DateTime fechaVinculacion;
 
  const FamiliarDelAdulto({
    required this.nombre,
    required this.fechaVinculacion,
  });
}
 
/// Perfil del adulto mayor que inició sesión.
class MiPerfilAdultoMayor {
  final String nombreCompleto;
  final List<FamiliarDelAdulto> familiares;
 
  const MiPerfilAdultoMayor({
    required this.nombreCompleto,
    required this.familiares,
  });
}
 
/// Operaciones del adulto mayor contra el backend.
class AdultoMayorService {
  /// Envía la alerta de emergencia (SOS). El servidor avisa a los familiares
  /// vinculados. Si falla, lanza una excepción: la alerta NO se envió.
  static Future<void> enviarSOS() async {
    await ApiClient.post('/alertas-sos');
  }
 
  static Future<MiPerfilAdultoMayor> miPerfil() async {
    final datos =
        await ApiClient.get('/adulto-mayor/mi-perfil') as Map<String, dynamic>;
 
    final familiares = (datos['familiares'] as List<dynamic>).map((item) {
      final f = item as Map<String, dynamic>;
      return FamiliarDelAdulto(
        nombre: '${f['nombre']} ${f['apellido'] ?? ''}'.trim(),
        fechaVinculacion: DateTime.parse(f['fecha_vinculacion'] as String),
      );
    }).toList();
 
    return MiPerfilAdultoMayor(
      nombreCompleto: '${datos['nombre']} ${datos['apellido'] ?? ''}'.trim(),
      familiares: familiares,
    );
  }
}