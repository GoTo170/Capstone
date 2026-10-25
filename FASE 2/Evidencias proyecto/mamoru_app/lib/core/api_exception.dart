/// Error devuelto por el backend o por la conexiÃ³n.
class ApiException implements Exception {
  final String mensaje;
  final int? codigo;

  const ApiException(this.mensaje, [this.codigo]);

  @override
  String toString() => mensaje;
}