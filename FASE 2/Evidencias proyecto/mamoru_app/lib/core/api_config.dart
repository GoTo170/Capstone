/// Configuración de conexión con el backend de Mamoru.
class ApiConfig {
  /// Dirección del backend.
  ///
  /// Con el celular conectado por USB se usa el puente de adb:
  ///   adb -s <id-del-celular> reverse tcp:8000 tcp:8000
  /// así `127.0.0.1:8000` del celular llega al backend que corre en el PC.
  ///
  /// Para el emulador de Android sin puente, usar `http://10.0.2.2:8000`.
  /// Cuando el backend esté desplegado, aquí va su dirección https.
  static const String baseUrl = 'http://127.0.0.1:8000';
}